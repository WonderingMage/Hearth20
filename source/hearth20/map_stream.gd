extends RefCounted
class_name Hearth20MapStream
## Connection-scoped, content-addressed map files. Background files are encrypted;
## only the authorized live view carries their key. Never prefetch GM/token data.
const CHUNK=65536
const FILE_LIMIT=Hearth20Assets.MAP_MAX_BYTES+16
const DISK_LIMIT=2*1024*1024*1024
var folder=""
var records={}
var latest={}
var foreground_keys={}
var queue: Array=[]
var worker: Thread
var work_key=""
var work_scene=""
var received={}
var catalog={}
var disk_bytes=0
var failure=""
var opened={}
var opened_bytes=0
func _open() -> bool:
	if folder.is_empty():folder=ProjectSettings.globalize_path("user://hearth20/map-cache/"+Crypto.new().generate_random_bytes(16).hex_encode())
	return DirAccess.make_dir_recursive_absolute(folder)==OK
static func signature(scene: Dictionary) -> String:
	return Hearth20Contracts.sha256(var_to_bytes([scene.get("map_asset",""),scene.get("width_cells"),scene.get("height_cells"),scene.get("cell_pixels",64.),scene.get("feet_per_cell",5.),scene.get("dynamic_lighting",false),scene.get("fog_rects",[])]))
func scan(campaign: Dictionary,priority="") -> void:
	var live={}
	for scene in campaign.get("scenes",[]):
		if str(scene.get("map_asset","")).is_empty():continue
		var key=signature(scene);live[str(scene.id)]=key
		if records.has(key) or key==work_key or queue.any(func(item):return item.key==key):continue
		var item={"scene":str(scene.id),"key":key,"kind":"map"}
		if str(scene.id)==priority:queue.push_front(item)
		else:queue.append(item)
	latest=live
	# Foreground PNGs are independent files so shared scenery is downloaded once.
	for actor in campaign.get("actors",[]):
		var asset_id=str(actor.get("png_asset_id",""))
		if not actor.get("decorative",false) or asset_id.is_empty():continue
		var key="foreground:"+asset_id;foreground_keys[asset_id]=key
		if records.has(key) or key==work_key or queue.any(func(item):return item.key==key):continue
		queue.append({"scene":str(actor.get("scene_id","")),"key":key,"asset":asset_id,"kind":"foreground"})
	# An editor tab switch can reorder waiting work, never interrupt active work.
	for i in queue.size():
		if queue[i].scene==priority:var item=queue[i];queue.remove_at(i);queue.push_front(item);break
func ready_for(scene: Dictionary) -> Dictionary:return records.get(signature(scene),{})
func ready_asset(id: String) -> Dictionary:return records.get(foreground_keys.get(id,""),{})
func tick(campaign: Dictionary) -> bool:
	var changed=false
	if worker!=null and not worker.is_alive():
		var record: Dictionary=worker.wait_to_finish();worker=null
		changed=true
		if record.is_empty():failure="A map could not be prepared for background download."
		elif _open() and disk_bytes+int(record.size)<=DISK_LIMIT:
			var path=folder.path_join(str(record.id)+".blob");var file=FileAccess.open(path,FileAccess.WRITE)
			if file!=null:
				file.store_buffer(record.data);file.close()
				if FileAccess.get_sha256(path)==record.cipher_sha256:
					record.erase("data");record.path=path;records[work_key]=record;disk_bytes+=int(record.size);changed=true
				else:failure="The map cache could not be written. Check disk space."
			else:failure="The map cache is not writable."
		else:failure="The map cache is full. Free some disk space and reconnect."
		work_key="";work_scene=""
	if worker==null and not queue.is_empty() and failure.is_empty():
		var item: Dictionary=queue.pop_front();var scene=Hearth20Contracts.find_scene(campaign,item.scene)
		if item.kind=="foreground":
			var source=Hearth20Assets.read_asset(campaign,item.asset,"token")
			work_key=item.key;work_scene=item.scene;worker=Thread.new()
			if worker.start(func():return _encrypt(source,"foreground"))!=OK:worker=null;work_key="";failure="The foreground worker could not start."
			return changed
		if scene.is_empty() or signature(scene)!=item.key:return changed
		var context=campaign.duplicate();context.map_covered=false
		var page=scene.duplicate(true);page.blackout=false
		var source=Hearth20Assets.read_asset(campaign,str(page.get("map_asset","")),"map")
		var sight=Hearth20Vision.build_view(context,"prefetch",page)
		work_key=item.key;work_scene=item.scene;worker=Thread.new()
		if worker.start(func():return _prepare(source,page,sight))!=OK:worker=null;work_key="";failure="The background map worker could not start."
	return changed
static func _prepare(source: PackedByteArray,page: Dictionary,sight: Dictionary) -> Dictionary:
	var png=Hearth20Vision.mask_map(source,sight) if page.get("dynamic_lighting",false) else Hearth20Contracts._mask_fogged_map(source,page)
	return _encrypt(png,"map")
static func _encrypt(png: PackedByteArray,kind: String) -> Dictionary:
	if png.is_empty() or png.size()>Hearth20Assets.MAP_MAX_BYTES:return {}
	var key=Crypto.new().generate_random_bytes(32);var iv=Crypto.new().generate_random_bytes(16);var padded=png.duplicate();padded.resize(ceili(float(png.size())/16.)*16)
	var aes=AESContext.new()
	if aes.start(AESContext.MODE_CBC_ENCRYPT,key,iv)!=OK:return {}
	var data=aes.update(padded);aes.finish();var digest=Hearth20Contracts.sha256(data)
	return {"id":"map-"+digest,"cipher_sha256":digest,"size":data.size(),"data":data,"key":key,"iv":iv,"plain_size":png.size(),"map_sha256":Hearth20Contracts.sha256(png),"kind":kind}
static func descriptor(record: Dictionary) -> Dictionary:
	var result={}
	for key in ["id","cipher_sha256","size","key","iv","plain_size","map_sha256"]:result[key]=record[key]
	return result
func offers() -> Array:
	var result=[];var ids={}
	for record in records.values():
		if ids.has(record.id):continue
		ids[record.id]=true;result.append({"id":record.id,"size":record.size,"sha256":record.cipher_sha256,"kind":record.kind})
	return result
static func valid_id(id: Variant) -> bool:return id is String and id.length()==68 and id.begins_with("map-") and id.substr(4).is_valid_hex_number(false)
func offer(items: Array) -> bool:
	if items.size()>1024:return false
	var next={};var total=0
	for item in items:
		if not item is Dictionary or not valid_id(item.get("id")) or not item.get("size") is int or item.size<16 or item.size>FILE_LIMIT or item.size%16!=0 or item.get("sha256")!=str(item.id).substr(4) or next.has(item.id) or item.get("kind","") not in ["map","foreground"]:return false
		if catalog.has(item.id) and catalog[item.id]!=item:return false
		total+=int(item.size);next[item.id]=item.duplicate()
	if total>DISK_LIMIT:return false
	catalog=next;return true
func accept(packet: Dictionary) -> Dictionary:
	var id=packet.get("id");var bytes=packet.get("bytes");var offset=packet.get("offset")
	if not valid_id(id) or not catalog.has(id) or not bytes is PackedByteArray or not offset is int or offset<0 or bytes.is_empty() or bytes.size()>CHUNK:return {"ok":false,"error":"Invalid background map frame."}
	var meta: Dictionary=catalog[id];var end=offset+bytes.size()
	if end>int(meta.size) or (end<int(meta.size) and bytes.size()!=CHUNK):return {"ok":false,"error":"Background map exceeds its announced size."}
	if not received.has(id):
		if offset!=0 or not _open() or disk_bytes+int(meta.size)>DISK_LIMIT:return {"ok":false,"error":"The background map cache could not begin. Check disk space."}
		received[id]={"offset":0,"path":folder.path_join(id+".blob"),"complete":false};disk_bytes+=int(meta.size)
	var state: Dictionary=received[id]
	if state.complete:return {"ok":true,"complete":true,"replayed":true,"id":id}
	if offset!=int(state.offset):return {"ok":false,"error":"Background map frames arrived out of order."}
	var file=FileAccess.open(state.path,FileAccess.WRITE_READ if offset==0 else FileAccess.READ_WRITE)
	if file==null:return {"ok":false,"error":"The map cache is not writable. Check disk space."}
	file.seek(offset);file.store_buffer(bytes);file.flush();var error=file.get_error();file.close()
	if error!=OK:return {"ok":false,"error":"The background map could not be saved."}
	state.offset=end
	if end==int(meta.size):
		if FileAccess.get_sha256(state.path)!=meta.sha256:return {"ok":false,"error":"The background map checksum did not match."}
		state.complete=true
	return {"ok":true,"complete":state.complete,"id":id}
func resolve(info: Dictionary) -> Dictionary:
	if not valid_id(info.get("id")) or not info.get("key") is PackedByteArray or info.key.size()!=32 or not info.get("iv") is PackedByteArray or info.iv.size()!=16 or not info.get("plain_size") is int or info.plain_size<1 or info.plain_size>Hearth20Assets.MAP_MAX_BYTES:return {"ok":false,"error":"Invalid map unlock information."}
	if not received.get(info.id,{}).get("complete",false):return {"ok":true,"waiting":true}
	if opened.has(info.id) and opened[info.id].info==info:
		var retained=opened[info.id];opened.erase(info.id);opened[info.id]=retained
		return {"ok":true,"waiting":false,"bytes":retained.bytes}
	var data=FileAccess.get_file_as_bytes(received[info.id].path)
	if data.size()!=info.get("size") or Hearth20Contracts.sha256(data)!=info.get("cipher_sha256") or info.cipher_sha256!=str(info.id).substr(4):return {"ok":false,"error":"The cached map changed."}
	var aes=AESContext.new()
	if aes.start(AESContext.MODE_CBC_DECRYPT,info.key,info.iv)!=OK:return {"ok":false,"error":"The cached map could not be opened."}
	var png=aes.update(data).slice(0,info.plain_size);aes.finish()
	if Hearth20Contracts.sha256(png)!=info.get("map_sha256"):return {"ok":false,"error":"The cached map checksum did not match."}
	if opened.has(info.id):opened_bytes-=int(opened[info.id].bytes.size());opened.erase(info.id)
	opened[info.id]={"info":info.duplicate(true),"bytes":png};opened_bytes+=png.size()
	while opened_bytes>64*1024*1024 or opened.size()>64:
		var oldest=opened.keys()[0];opened_bytes-=int(opened[oldest].bytes.size());opened.erase(oldest)
	return {"ok":true,"waiting":false,"bytes":png}
func progress() -> Dictionary:
	var total=0;var amount=0;var count=0;var map_count=0
	for id in catalog:
		total+=int(catalog[id].size);amount+=int(received.get(id,{}).get("offset",0))
		if catalog[id].kind=="map":
			map_count+=1
			if received.get(id,{}).get("complete",false):count+=1
	return {"active":amount<total,"received":amount,"total":total,"completed_maps":count,"map_count":map_count,"progress":float(amount)/maxi(1,total),"phase":"Downloading maps in background…"}
func clear() -> void:
	if worker!=null:worker.wait_to_finish();worker=null
	# This random connection directory contains only files created by this instance.
	if not folder.is_empty():
		for collection in [records,received]:
			for entry in collection.values():
				var path=str(entry.get("path",""))
				if path.get_base_dir()==folder and path.ends_with(".blob"):DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(folder)
	folder="";records.clear();latest.clear();foreground_keys.clear();queue.clear();received.clear();catalog.clear();disk_bytes=0;work_key="";work_scene="";failure="";opened.clear();opened_bytes=0

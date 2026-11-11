extends RefCounted
class_name Hearth20SteamImages
## Remember only images already included in this connection's authorized views.
## The active view still drops concealed images; disconnect clears this cache.
const ASSET_LIMIT=16*1024*1024
const ASSET_COUNT=64
const MAP_COUNT=4
const MAP_LIMIT=64*1024*1024
const FIELD_LIMIT=8*1024*1024
var protocol_version=2
var map_hash=""
var map_bytes=PackedByteArray()
var maps={}
var maps_bytes=0
var fields={}
var fields_bytes=0
var assets={}
var asset_bytes=0
func clear() -> void:
	map_hash="";map_bytes=PackedByteArray();maps.clear();maps_bytes=0;fields.clear();fields_bytes=0;assets.clear();asset_bytes=0
func encode(snapshot: Dictionary) -> Dictionary:
	var packet=snapshot.duplicate(true);packet._h20_image_cache=true
	var digest: String=str(snapshot.get("map_sha256",""))
	if (protocol_version>=2 and maps.has(digest)) or (protocol_version==1 and not map_hash.is_empty() and digest==map_hash):
		packet.map_png=PackedByteArray();packet.map_cached=true
	var field: Dictionary=snapshot.get("scene",{}).get("light_field",{})
	if protocol_version>=2 and not field.is_empty():
		var field_hash:=Hearth20Contracts.sha256(var_to_bytes(field))
		packet.light_field_digest=field_hash
		if fields.has(field_hash):packet.scene.light_field={};packet.light_cached=true
	packet.asset_ids=snapshot.assets.keys();packet.assets={}
	for id in snapshot.assets:
		if not assets.has(id):packet.assets[id]=snapshot.assets[id]
	return packet
func decode(packet: Dictionary) -> Dictionary:
	if not packet.get("asset_ids") is Array or packet.asset_ids.size()>Hearth20Contracts.MAX_ACTORS or not packet.get("assets") is Dictionary:return {"ok":false,"error":"Invalid image references."}
	if not packet.get("map_png") is PackedByteArray or packet.map_png.size()>Hearth20Assets.MAP_MAX_BYTES or not packet.get("map_sha256") is String:return {"ok":false,"error":"Invalid map reference."}
	var snapshot=packet.duplicate(true)
	if packet.get("map_cached",false):
		var retained: Dictionary=maps.get(packet.get("map_sha256",""),{})
		if retained.is_empty() or retained.bytes.is_empty():return {"ok":false,"error":"The map reference is no longer available. Join the table again."}
		snapshot.map_png=retained.bytes
	if packet.get("light_cached",false):
		var retained: Dictionary=fields.get(packet.get("light_field_digest",""),{})
		if retained.is_empty() or not retained.value is Dictionary:return {"ok":false,"error":"The lighting reference is no longer available. Join the table again."}
		if not snapshot.get("scene") is Dictionary:return {"ok":false,"error":"Invalid cached lighting scene."}
		snapshot.scene.light_field=retained.value
	var resolved={}
	for id in packet.asset_ids:
		if not id is String or id.length()!=71 or not id.begins_with("sha256-") or not id.substr(7).is_valid_hex_number(false) or resolved.has(id):return {"ok":false,"error":"Invalid token image reference."}
		if packet.assets.has(id):resolved[id]=packet.assets[id]
		elif assets.has(id) and assets[id].record is Dictionary:resolved[id]=assets[id].record
		else:return {"ok":false,"error":"A token image reference is no longer available. Join the table again."}
	snapshot.assets=resolved;snapshot.erase("_h20_image_cache");snapshot.erase("map_cached");snapshot.erase("asset_ids");snapshot.erase("light_cached");snapshot.erase("light_field_digest")
	return {"ok":true,"snapshot":snapshot}
func remember(snapshot: Dictionary,metadata_only=false) -> void:
	var bytes: PackedByteArray=snapshot.get("map_png",PackedByteArray())
	if not bytes.is_empty() and snapshot.get("map_sha256","")!=map_hash and bytes.size()<=Hearth20Assets.MAP_MAX_BYTES and Hearth20Contracts.sha256(bytes)==snapshot.get("map_sha256",""):
		map_hash=str(snapshot.map_sha256);map_bytes=PackedByteArray() if metadata_only else bytes
	if not bytes.is_empty() and bytes.size()<=Hearth20Assets.MAP_MAX_BYTES and Hearth20Contracts.sha256(bytes)==snapshot.get("map_sha256",""):
		var digest: String=str(snapshot.map_sha256)
		if maps.has(digest):maps_bytes-=int(maps[digest].size);maps.erase(digest)
		maps[digest]={"size":bytes.size(),"bytes":PackedByteArray() if metadata_only else bytes};maps_bytes+=bytes.size()
		while maps.size()>(MAP_COUNT if protocol_version>=2 else 1) or maps_bytes>MAP_LIMIT:
			var oldest=maps.keys()[0];maps_bytes-=int(maps[oldest].size);maps.erase(oldest)
	var field: Dictionary=snapshot.get("scene",{}).get("light_field",{})
	if protocol_version>=2 and not field.is_empty():
		var raw:=var_to_bytes(field)
		if raw.size()<=FIELD_LIMIT:
			var key:=Hearth20Contracts.sha256(raw)
			if fields.has(key):fields_bytes-=int(fields[key].size);fields.erase(key)
			fields[key]={"size":raw.size(),"value":null if metadata_only else field};fields_bytes+=raw.size()
			while fields.size()>8 or fields_bytes>FIELD_LIMIT:
				var oldest=fields.keys()[0];fields_bytes-=int(fields[oldest].size);fields.erase(oldest)
	for id in snapshot.get("assets",{}):
		var record=snapshot.assets[id]
		if not record is Dictionary or not record.get("byte_length") is int or record.byte_length<1 or record.byte_length>Hearth20Assets.TOKEN_MAX_BYTES:continue
		if not id is String or id.length()!=71 or id!="sha256-"+str(record.get("sha256","")):continue
		if assets.has(id):asset_bytes-=int(assets[id].size);assets.erase(id)
		assets[id]={"size":int(record.byte_length),"record":null if metadata_only else record};asset_bytes+=int(record.byte_length)
		while assets.size()>ASSET_COUNT or asset_bytes>ASSET_LIMIT:
			var oldest=assets.keys()[0];asset_bytes-=int(assets[oldest].size);assets.erase(oldest)

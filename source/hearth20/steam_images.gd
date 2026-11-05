extends RefCounted
class_name Hearth20SteamImages
## Remember only images already included in this connection's authorized views.
## The active view still drops concealed images; disconnect clears this cache.
const ASSET_LIMIT=16*1024*1024
const ASSET_COUNT=64
var map_hash=""
var map_bytes=PackedByteArray()
var assets={}
var asset_bytes=0
func clear() -> void:map_hash="";map_bytes=PackedByteArray();assets.clear();asset_bytes=0
func encode(snapshot: Dictionary) -> Dictionary:
	var packet=snapshot.duplicate(true);packet._h20_image_cache=true
	if not map_hash.is_empty() and snapshot.get("map_sha256","")==map_hash:
		packet.map_png=PackedByteArray();packet.map_cached=true
	packet.asset_ids=snapshot.assets.keys();packet.assets={}
	for id in snapshot.assets:
		if not assets.has(id):packet.assets[id]=snapshot.assets[id]
	return packet
func decode(packet: Dictionary) -> Dictionary:
	if not packet.get("asset_ids") is Array or packet.asset_ids.size()>Hearth20Contracts.MAX_ACTORS or not packet.get("assets") is Dictionary:return {"ok":false,"error":"Invalid image references."}
	if not packet.get("map_png") is PackedByteArray or packet.map_png.size()>Hearth20Assets.MAP_MAX_BYTES or not packet.get("map_sha256") is String:return {"ok":false,"error":"Invalid map reference."}
	var snapshot=packet.duplicate(true)
	if packet.get("map_cached",false):
		if map_hash.is_empty() or packet.get("map_sha256","")!=map_hash or map_bytes.is_empty():return {"ok":false,"error":"The map reference is no longer available. Join the table again."}
		snapshot.map_png=map_bytes
	var resolved={}
	for id in packet.asset_ids:
		if not id is String or id.length()!=71 or not id.begins_with("sha256-") or not id.substr(7).is_valid_hex_number(false) or resolved.has(id):return {"ok":false,"error":"Invalid token image reference."}
		if packet.assets.has(id):resolved[id]=packet.assets[id]
		elif assets.has(id) and assets[id].record is Dictionary:resolved[id]=assets[id].record
		else:return {"ok":false,"error":"A token image reference is no longer available. Join the table again."}
	snapshot.assets=resolved;snapshot.erase("_h20_image_cache");snapshot.erase("map_cached");snapshot.erase("asset_ids")
	return {"ok":true,"snapshot":snapshot}
func remember(snapshot: Dictionary,metadata_only=false) -> void:
	var bytes: PackedByteArray=snapshot.get("map_png",PackedByteArray())
	if not bytes.is_empty() and snapshot.get("map_sha256","")!=map_hash and bytes.size()<=Hearth20Assets.MAP_MAX_BYTES and Hearth20Contracts.sha256(bytes)==snapshot.get("map_sha256",""):
		map_hash=str(snapshot.map_sha256);map_bytes=PackedByteArray() if metadata_only else bytes
	for id in snapshot.get("assets",{}):
		var record=snapshot.assets[id]
		if not record is Dictionary or not record.get("byte_length") is int or record.byte_length<1 or record.byte_length>Hearth20Assets.TOKEN_MAX_BYTES:continue
		if not id is String or id.length()!=71 or id!="sha256-"+str(record.get("sha256","")):continue
		if assets.has(id):asset_bytes-=int(assets[id].size);assets.erase(id)
		assets[id]={"size":int(record.byte_length),"record":null if metadata_only else record};asset_bytes+=int(record.byte_length)
		while assets.size()>ASSET_COUNT or asset_bytes>ASSET_LIMIT:
			var oldest=assets.keys()[0];asset_bytes-=int(assets[oldest].size);assets.erase(oldest)

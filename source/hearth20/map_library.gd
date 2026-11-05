extends RefCounted
class_name Hearth20MapLibrary
## Embedded, original sample scenes. Accept only stable IDs from the local catalog.
const ROOT := "res://hearth20/sample_maps/"
const SCENERY := {"lantern-larch-inn":[{"asset":"brass-chandelier","position":Vector2(13.0,11.0),"size":2.5}],"briarwood-crossroads":[{"asset":"oak-canopy","position":Vector2(8,5),"size":4.5}]}
static var _catalog: Array=[]
static var _textures: Dictionary={}

static func catalog() -> Array:
	if _catalog.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"catalog.json"))
		if parsed is Dictionary and parsed.get("maps") is Array and parsed.maps.size()==15:
			_catalog=parsed.maps
	return _catalog.duplicate(true)

static func find(map_id: String) -> Dictionary:
	for record in catalog():
		if str(record.id)==map_id: return record
	return {}

static func texture(map_id: String, thumbnail: bool=true) -> Texture2D:
	if find(map_id).is_empty(): return null
	var key:=map_id+("-thumb" if thumbnail else "")
	if not _textures.has(key):
		var resource: Variant=load(ROOT+key+".png")
		if resource is Texture2D: _textures[key]=resource
	return _textures.get(key)

static func scene(map_id: String) -> Dictionary:
	if find(map_id).is_empty(): return {}
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+map_id+".json"))
	if not parsed is Dictionary: return {}
	var result: Dictionary=parsed
	if not result.has("natural_light"): result.natural_light=Hearth20NaturalLight.DEFAULTS.duplicate()
	for object in result.get("annotations",[]):
		var points: Array=[]
		for p in object.points: points.append(Vector2(float(p.x),float(p.y)))
		object.points=points
	for door in result.get("doors",[]):
		result.annotations.append({"id":str(door.id),"owner":"dm-local","kind":"door","layer":"light","points":[Hearth20Contracts._point_from_record(door.a),Hearth20Contracts._point_from_record(door.b)],"open":bool(door.get("open",false)),"color":"#c8a36c","width":3.0})
	result.doors=[]
	if map_id=="lantern-larch-inn":
		result.annotations.append({"id":"library-chandelier-light","owner":"dm-local","kind":"light","layer":"light","points":[Vector2(13,11)],"bright":20,"dim":20,"source_type":"brazier","light_color":"#ffd397","ray_strength":0.6})
	if not Hearth20Contracts.valid_scene(result): return {}
	return result

static func add_to_campaign(campaign: Dictionary, map_id: String, move_party: bool) -> Dictionary:
	if campaign.get("scenes",[]).size()>=Hearth20Contracts.MAX_SCENES: return {"ok":false,"error":"This campaign has reached the scene limit."}
	var prepared:=scene(map_id)
	if prepared.is_empty(): return {"ok":false,"error":"That bundled sample map is unavailable or invalid."}
	var art:=texture(map_id,false)
	if art==null: return {"ok":false,"error":"The bundled background could not be loaded."}
	var image:=art.get_image()
	if image==null or image.get_width()!=2048 or image.get_height()!=1536: return {"ok":false,"error":"The bundled map dimensions are invalid."}
	var bytes:=image.save_webp_to_buffer(true,0.93)
	if bytes.is_empty() or bytes.size()>Hearth20Assets.MAP_MAX_BYTES: return {"ok":false,"error":"The sample map image exceeds supported limits."}
	var proposed:=campaign.duplicate(true)
	prepared.id="sample-%s-%d"%[map_id,Time.get_ticks_usec()]
	prepared.map_asset=Hearth20Assets.store_asset(proposed,{"ok":true,"bytes":bytes,"width":2048,"height":1536,"mime_type":"image/webp"},"map")
	proposed.scenes.append(prepared)
	proposed.active_scene=prepared.id
	for prop in SCENERY.get(map_id,[]):
		var resource: Texture2D=load(ROOT+"scenery-"+str(prop.asset)+".png")
		if resource==null: return {"ok":false,"error":"A bundled foreground image is unavailable."}
		var png:=resource.get_image().save_png_to_buffer()
		var checked_prop:=Hearth20Assets.inspect_token_png_bytes(png)
		if not checked_prop.ok: return {"ok":false,"error":"A bundled foreground image is invalid."}
		var asset_id:=Hearth20Assets.store_asset(proposed,checked_prop,"token")
		proposed.actors.append({"id":str(prepared.id)+"-scenery","name":"Chandelier" if prop.asset=="brass-chandelier" else "Oak canopy","scene_id":prepared.id,"position":prop.position,"is_hero":false,"hidden":false,"owner_player_id":"","layer":"foreground","decorative":true,"token_size":prop.size,"png_asset_id":asset_id})
	if move_party:
		var index:=0
		for actor in proposed.actors:
			if not bool(actor.get("is_hero",false)) or actor.get("in_inventory",false): continue
			var entry: Dictionary=prepared.library_entry[index%prepared.library_entry.size()]
			actor.scene_id=prepared.id
			actor.position=Hearth20TokenInventory.snap_position(prepared,Vector2(float(entry.x),float(entry.y)))
			index+=1
	proposed.revision=int(proposed.get("revision",0))+1
	var checked:=Hearth20Contracts.validate_campaign(proposed)
	if not checked.ok: return {"ok":false,"error":"; ".join(checked.errors)}
	if JSON.stringify(Hearth20Identity._encode_variant(proposed)).to_utf8_buffer().size()>Hearth20Identity.MAX_SAVE_BYTES: return {"ok":false,"error":"Adding this map would exceed the campaign save size limit."}
	campaign.merge(proposed,true)
	return {"ok":true,"id":str(prepared.id),"title":str(prepared.title)}

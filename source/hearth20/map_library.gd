extends RefCounted
class_name Hearth20MapLibrary
## Embedded, original sample scenes. Accept only stable IDs from the local catalog.
const ROOT := "res://hearth20/sample_maps/"
const SCENERY := {"lantern-larch-inn":[{"asset":"brass-chandelier","position":Vector2(13.0,11.0),"size":2.5}],"briarwood-crossroads":[{"asset":"oak-canopy","position":Vector2(8,5),"size":4.5}]}
static var _catalog: Array=[]
static var _textures: Dictionary={}

static func discard_empty_starter(campaign: Dictionary, destination_id: String) -> void:
	if destination_id=="scene-start" or Hearth20Contracts.find_scene(campaign,destination_id).is_empty():return
	for item in campaign.get("custom_items",[]):
		if item.get("scene_id","")=="scene-start" and item.get("holder","").is_empty():return
	var starter:=Hearth20Contracts.find_scene(campaign,"scene-start")
	if starter.is_empty() or starter.get("title","")!="New scene" or not str(starter.get("map_asset","")).is_empty():return
	for field in ["walls","doors","props","annotations","fx","fog_rects","lights","templates","roof_rects","notes","description","gm_notes","map_description"]:
		if not is_empty_value(starter.get(field)):return
	for actor in campaign.get("actors",[]):
		if actor.get("scene_id","")=="scene-start" and not actor.get("in_inventory",false):return
	# Stored pawns are campaign inventory, not contents of the empty board.
	for actor in campaign.get("actors",[]):
		if actor.get("scene_id","")=="scene-start":
			actor.scene_id=destination_id
			actor.position=Vector2(.5,.5)
	campaign.scenes=campaign.scenes.filter(func(scene):return scene.id!="scene-start")

static func is_empty_value(value: Variant) -> bool:
	return value==null or (value is Array and value.is_empty()) or (value is String and value.is_empty())

static func unique_scene_title(campaign: Dictionary, proposed_title: String) -> String:
	var base := proposed_title.strip_edges().left(96)
	if base.is_empty():base="Untitled map"
	var used: Dictionary={}
	for scene_record in campaign.scenes:
		used[str(scene_record.get("title","")).to_lower()]=true
	var candidate := base
	var number := 2
	while used.has(candidate.to_lower()):
		var suffix := " (%d)" % number
		candidate=base.left(96-suffix.length())+suffix
		number+=1
	return candidate

static func new_scene_id(campaign: Dictionary) -> String:
	var base := "map-"+Crypto.new().generate_random_bytes(12).hex_encode()
	var candidate := base
	var number := 2
	while not Hearth20Contracts.find_scene(campaign,candidate).is_empty():
		candidate=base+"-"+str(number)
		number+=1
	return candidate

static func default_image_columns(inspected: Dictionary) -> int:
	return clampi(floori(256.0*float(inspected.width)/float(inspected.height)),1,24)

static func add_image_scene(campaign: Dictionary, inspected: Dictionary, title: String, columns: int) -> Dictionary:
	if not inspected.get("ok",false):return inspected
	var grid: Dictionary=inspected.get("grid",{})
	columns=int(grid.get("width_cells",columns))
	if columns<1 or columns>256:
		return {"ok":false,"error":"Choose a grid width from 1 to 256 squares."}
	var rows:=ceili(float(inspected.height)*columns/float(inspected.width))
	if rows<1 or rows>256:
		return {"ok":false,"error":"This image would be taller than 256 grid squares. Choose a smaller width or crop the image."}
	var proposed:=campaign.duplicate(true)
	var prepared: Dictionary=Hearth20Identity.new_campaign().scenes[0]
	prepared.id=new_scene_id(campaign)
	prepared.title=unique_scene_title(campaign,title)
	prepared.map_asset=Hearth20Assets.store_asset(proposed,inspected,"map")
	prepared.map_width=int(inspected.width)
	prepared.map_height=int(inspected.height)
	prepared.width_cells=columns
	prepared.height_cells=rows
	prepared.calibration_width_cells=columns
	prepared.feet_per_cell=float(grid.get("feet_per_cell",5.0))
	prepared.cell_pixels=float(inspected.width)/columns
	prepared.blackout=bool(proposed.get("map_covered",false))
	proposed.scenes.append(prepared)
	proposed.active_scene=prepared.id
	var result:=commit_new_scene(campaign,proposed,prepared.id)
	if not result.ok:return result
	return {"ok":true,"id":prepared.id,"title":prepared.title,"width_cells":columns,"height_cells":rows,
		"calibration_width_cells":columns,"feet_per_cell":prepared.feet_per_cell,"width":prepared.map_width,
		"height":prepared.map_height,"auto_calibrated":not grid.is_empty(),"sha256":inspected.get("sha256","")}

static func commit_new_scene(campaign: Dictionary, proposed: Dictionary, scene_id: String) -> Dictionary:
	discard_empty_starter(proposed,scene_id)
	if proposed.scenes.size()>Hearth20Contracts.MAX_SCENES:
		return {"ok":false,"error":"This campaign already has 256 maps. Delete a map before adding another."}
	proposed.revision=int(campaign.get("revision",0))+1
	var checked:=Hearth20Contracts.validate_campaign(proposed)
	if not checked.ok:return {"ok":false,"error":"; ".join(checked.errors)}
	if JSON.stringify(Hearth20Identity._encode_variant(proposed)).to_utf8_buffer().size()>Hearth20Identity.MAX_SAVE_BYTES:
		return {"ok":false,"error":"Adding this map would exceed the 64 MiB campaign save limit. Delete a map or try a smaller image."}
	campaign.merge(proposed,true)
	return {"ok":true}

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
	var prepared:=scene(map_id)
	if prepared.is_empty(): return {"ok":false,"error":"That bundled sample map is unavailable or invalid."}
	var art:=texture(map_id,false)
	if art==null: return {"ok":false,"error":"The bundled background could not be loaded."}
	var image:=art.get_image()
	if image==null or image.get_width()!=2048 or image.get_height()!=1536: return {"ok":false,"error":"The bundled map dimensions are invalid."}
	var bytes:=image.save_webp_to_buffer(true,0.93)
	if bytes.is_empty() or bytes.size()>Hearth20Assets.MAP_MAX_BYTES: return {"ok":false,"error":"The sample map image exceeds supported limits."}
	var proposed:=campaign.duplicate(true)
	prepared.id=new_scene_id(campaign)
	prepared.title=unique_scene_title(campaign,str(prepared.title))
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
		var heroes: Array=proposed.actors.filter(func(actor):return actor.get("is_hero",false) and not actor.get("in_inventory",false))
		var places:=Hearth20TokenInventory.party_positions(prepared,prepared.library_entry,heroes.size())
		if places.size()<heroes.size():return {"ok":false,"error":"This map does not have enough clear squares for the party."}
		var index:=0
		for actor in heroes:
			actor.scene_id=prepared.id
			actor.position=places[index]
			index+=1
	var result:=commit_new_scene(campaign,proposed,prepared.id)
	if not result.ok:return result
	return {"ok":true,"id":str(prepared.id),"title":str(prepared.title)}

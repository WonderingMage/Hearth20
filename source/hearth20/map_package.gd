extends RefCounted
class_name Hearth20MapPackage
## Self-contained, data-only ZIP_STORED .hearth20map files. Never extract to disk.
const MAX_FILE_BYTES := 64*1024*1024
const MAX_FILES := 66
const MAX_FOREGROUND := 64
const MANIFEST_KEYS := ["format","version","id","title","description","credits","grid","background","walls","doors","windows","lights","foreground","environment","entry_points"]

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":"Map package: "+message}
static func _keys(value: Variant, allowed: Array) -> bool:
	if not value is Dictionary:return false
	for key in value:
		if key not in allowed:return false
	return true
static func _number(value: Variant, low: float, high: float) -> bool:
	return Hearth20Contracts._finite_number(value) and value>=low and value<=high
static func _point(value: Variant, scene: Dictionary) -> Vector2:
	return Hearth20Contracts._point_from_record(value) if value is Dictionary and value.size()==2 else Vector2.INF
static func _path_ok(value: Variant) -> bool:
	return value is String and RegEx.create_from_string("^assets/[a-z0-9][a-z0-9_-]{0,63}\\.(png|jpg|jpeg)$").search(value)!=null
static func _id(value: Dictionary, seen: Dictionary) -> bool:
	var key: Variant=value.get("id")
	if not Hearth20Contracts.valid_identifier(key) or seen.has(key):return false
	seen[key]=true
	return true

static func _directory(bytes: PackedByteArray) -> Dictionary:
	# Stored entries need no decompression. Validate both ZIP headers before slicing
	# any payload; reject ZIP64, encryption, descriptors, comments and hidden entries.
	if bytes.size()<22:return _fail("Not a complete .hearth20map file.")
	var end:=bytes.size()-22
	if bytes.decode_u32(end)!=0x06054b50 or bytes.decode_u16(end+20)!=0:return _fail("Use an uncommented ZIP_STORED archive.")
	var count:=int(bytes.decode_u16(end+10))
	var cursor:=int(bytes.decode_u32(end+16))
	if bytes.decode_u16(end+4)!=0 or bytes.decode_u16(end+6)!=0 or bytes.decode_u16(end+8)!=count or count<2 or count>MAX_FILES:return _fail("Archive entry count or disk layout is unsupported.")
	if cursor+int(bytes.decode_u32(end+12))!=end:return _fail("Archive directory is out of bounds.")
	var central:=cursor
	var local_cursor:=0
	var entries: Dictionary={}
	for index in count:
		if cursor+46>end or bytes.decode_u32(cursor)!=0x02014b50:return _fail("Archive directory is malformed.")
		var flags:=int(bytes.decode_u16(cursor+8));var method:=int(bytes.decode_u16(cursor+10))
		var length:=int(bytes.decode_u32(cursor+24));var compressed:=int(bytes.decode_u32(cursor+20))
		var name_size:=int(bytes.decode_u16(cursor+28));var extra:=int(bytes.decode_u16(cursor+30));var comment:=int(bytes.decode_u16(cursor+32))
		var local:=int(bytes.decode_u32(cursor+42))
		if flags not in [0,2048] or method!=0 or compressed!=length:return _fail("Use ZIP_STORED; encrypted or compressed entries are unsupported.")
		if extra!=0 or comment!=0 or bytes.decode_u16(cursor+34)!=0 or name_size<1 or name_size>100 or cursor+46+name_size>end:return _fail("Unsupported archive entry metadata.")
		var raw_name:=bytes.slice(cursor+46,cursor+46+name_size)
		var name:=raw_name.get_string_from_ascii()
		if name!="map.json" and not _path_ok(name):return _fail("Unsafe or unsupported archive path.")
		if entries.has(name):return _fail("Duplicate archive path: "+name)
		var limit:=Hearth20Recipes.MAX_JSON_BYTES if name=="map.json" else Hearth20Assets.MAP_MAX_BYTES
		if length<1 or length>limit or local!=local_cursor or local+30+name_size+length>central:return _fail("Archive payload exceeds its bounds or size budget.")
		if bytes.decode_u32(local)!=0x04034b50 or bytes.decode_u16(local+6)!=flags or bytes.decode_u16(local+8)!=method or bytes.decode_u16(local+26)!=name_size or bytes.decode_u16(local+28)!=0:return _fail("Archive local header disagrees with its directory.")
		if bytes.decode_u32(local+14)!=bytes.decode_u32(cursor+16) or bytes.decode_u32(local+18)!=length or bytes.decode_u32(local+22)!=length or bytes.slice(local+30,local+30+name_size)!=raw_name:return _fail("Archive local size/name/checksum disagrees with its directory.")
		entries[name]={"offset":local+30+name_size,"length":length,"crc":bytes.decode_u32(cursor+16)}
		local_cursor=local+30+name_size+length
		cursor+=46+name_size
	if cursor!=end or local_cursor!=central or not entries.has("map.json"):return _fail("Archive has missing or unlisted content.")
	return {"ok":true,"entries":entries}

static func _asset(record: Variant, data: PackedByteArray, entries: Dictionary, used: Dictionary, foreground: bool=false) -> Dictionary:
	if not _keys(record,["path","sha256"]) or not _path_ok(record.get("path")) or not record.get("sha256") is String:return _fail("Each image needs a local asset path and SHA-256.")
	var path: String=record.path
	if not entries.has(path):return _fail("Missing image: "+path)
	var entry: Dictionary=entries[path]
	if foreground and entry.length>Hearth20Assets.TOKEN_MAX_BYTES:return _fail("Foreground PNG exceeds 8 MiB.")
	if used.get(path) is Dictionary and used[path].foreground==foreground:
		return used[path].inspection if used[path].digest==record.sha256 else _fail("Conflicting checksums for "+path)
	var image_bytes:=data.slice(entry.offset,entry.offset+entry.length)
	if Hearth20Assets.sha256(image_bytes)!=record.sha256:return _fail("Image checksum mismatch: "+path)
	var inspection:=Hearth20Assets.inspect_token_png_bytes(image_bytes,path) if foreground else Hearth20Assets.inspect_map_bytes(image_bytes,path)
	inspection.erase("image")
	used[path]={"foreground":foreground,"digest":record.sha256,"inspection":inspection}
	return inspection

static func read(path: String) -> Dictionary:
	if path.get_extension().to_lower()!="hearth20map":return _fail("Choose a .hearth20map file.")
	var data:=Hearth20Assets._read_image_file(path,MAX_FILE_BYTES)
	if data.is_empty():return _fail("File is missing, empty or exceeds 64 MiB.")
	var directory:=_directory(data)
	if not directory.ok:return directory
	var entry: Dictionary=directory.entries["map.json"]
	var manifest_bytes:=data.slice(entry.offset,entry.offset+entry.length)
	if Hearth20MapMetadata.crc32(manifest_bytes)!=entry.crc:return _fail("Manifest CRC is invalid.")
	var text:=manifest_bytes.get_string_from_utf8()
	if not Hearth20Recipes._preflight_json_text(text).ok:return _fail("Manifest exceeds JSON size, depth or node limits.")
	var parser:=JSON.new()
	if parser.parse(text)!=OK:return _fail("Manifest is not valid JSON.")
	return prepare(parser.data,data,directory.entries)

static func prepare(m: Variant, data: PackedByteArray, entries: Dictionary) -> Dictionary:
	if not _keys(m,MANIFEST_KEYS) or m.get("format")!="hearth20-map" or not Hearth20Contracts._integer_number(m.get("version")) or m.version!=1:return _fail("Unsupported manifest format or version.")
	if not Hearth20Contracts.valid_identifier(m.get("id")) or not m.get("title") is String or m.title.strip_edges().is_empty() or m.title.length()>96:return _fail("Give the map a valid ID and title.")
	if not m.get("description","") is String or m.get("description","").length()>2000 or not m.get("credits","") is String or m.get("credits","").length()>4000:return _fail("Description or credits exceed their text limits.")
	var grid: Variant=m.get("grid")
	if not _keys(grid,["width_cells","height_cells","feet_per_cell"]) or not Hearth20Contracts._integer_number(grid.get("width_cells")) or not Hearth20Contracts._integer_number(grid.get("height_cells")) or not _number(grid.width_cells,1,256) or not _number(grid.height_cells,1,256) or not _number(grid.get("feet_per_cell"),0.01,1000):return _fail("Grid dimensions/scale are invalid.")
	var used: Dictionary={"map.json":true}
	var background:=_asset(m.get("background"),data,entries,used)
	if not background.ok:return background
	var pitch:=float(background.width)/float(grid.width_cells)
	if absf(float(background.height)-float(grid.height_cells)*pitch)>0.01:return _fail("Background aspect ratio must match complete square grid cells.")
	if not background.grid.is_empty() and (background.grid.width_cells!=grid.width_cells or background.grid.height_cells!=grid.height_cells or background.grid.feet_per_cell!=grid.feet_per_cell):return _fail("PNG grid metadata conflicts with the manifest.")
	var scene: Dictionary={"id":m.id,"title":m.title.strip_edges(),"width_cells":int(grid.width_cells),"height_cells":int(grid.height_cells),"feet_per_cell":float(grid.feet_per_cell),"cell_pixels":pitch,"calibration_width_cells":int(grid.width_cells),"map_width":background.width,"map_height":background.height,"map_asset":"","grid_visible":true,"snap_to_grid":true,"walls":[],"doors":[],"props":[],"annotations":[],"fx":[],"fog_rects":[],"blackout":false}
	var environment: Variant=m.get("environment",{})
	if not _keys(environment,["dynamic_lighting","ambient_light","outdoor","natural_light","roof_rects"]):return _fail("Unknown environment field.")
	scene.dynamic_lighting=environment.get("dynamic_lighting",true);scene.ambient_light=environment.get("ambient_light","dark");scene.outdoor=environment.get("outdoor",false)
	scene.natural_light=environment.get("natural_light",Hearth20NaturalLight.DEFAULTS.duplicate())
	scene.roof_rects=environment.get("roof_rects",[])
	for collection in ["walls","doors","windows","lights","foreground","entry_points"]:
		if not m.get(collection,[]) is Array:return _fail(collection+" must be an array.")
	if m.get("foreground",[]).size()>MAX_FOREGROUND:return _fail("Too many foreground objects.")
	var ids: Dictionary={};var windows: Dictionary={}
	for kind in ["wall","door","window"]:
		for segment in m.get(kind+"s",[]):
			if not _keys(segment,["id","a","b","open"] if kind=="door" else ["id","a","b"]) or not _id(segment,ids):return _fail("Invalid or duplicated "+kind+" ID/fields.")
			var a:=_point(segment.get("a"),scene);var b:=_point(segment.get("b"),scene)
			if not Hearth20BoardTools.point_ok(a,scene) or not Hearth20BoardTools.point_ok(b,scene) or a.distance_squared_to(b)<0.000001:return _fail("Invalid "+kind+" endpoints.")
			var object: Dictionary={"id":segment.id,"owner":"dm-local","kind":kind,"layer":"light","points":[a,b],"color":"#c8a36c","width":3.0,"open":segment.get("open",false)}
			scene.annotations.append(object)
			if kind=="window":windows[segment.id]=object
	for record in m.get("lights",[]):
		if not _keys(record,["id","position","source_type","bright_feet","dim_feet","light_color","angle_degrees","spread_degrees","ray_strength","enabled","window_id","window_height","sill_height"]) or not _id(record,ids):return _fail("Invalid or duplicated light ID/fields.")
		var object: Dictionary=record.duplicate(true)
		object.erase("position");object.erase("bright_feet");object.erase("dim_feet")
		object.merge({"owner":"dm-local","kind":"light","layer":"light","points":[_point(record.get("position"),scene)],"bright":record.get("bright_feet",20.0),"dim":record.get("dim_feet",20.0)},true)
		if record.get("source_type","torch")=="window":
			var window: Dictionary=windows.get(record.get("window_id",""),{})
			if window.is_empty() or object.points[0].distance_to((window.points[0]+window.points[1])*0.5)>1.5:return _fail("Window light must reference a nearby window_id.")
			var normal: Vector2=(window.points[1]-window.points[0]).normalized().orthogonal()
			if not _number(record.get("angle_degrees",0.0),-360,360) or absf(normal.dot(Vector2.from_angle(deg_to_rad(float(record.get("angle_degrees",0.0))))))<0.5:return _fail("Window light must face into the room, across its aperture.")
		scene.annotations.append(object)
	var foreground: Array=[]
	for record in m.get("foreground",[]):
		if not _keys(record,["id","name","image","position","width_cells","height_cells","rotation_degrees"]) or not _id(record,ids) or not record.get("name") is String or record.name.length()>64:return _fail("Invalid foreground ID/name/fields.")
		if not _number(record.get("width_cells"),0.1,64) or not _number(record.get("height_cells"),0.1,64) or not _number(record.get("rotation_degrees",0),-360,360):return _fail("Foreground size or rotation exceeds bounds.")
		var inspected:=_asset(record.get("image"),data,entries,used,true)
		if not inspected.ok:return inspected
		var actor: Dictionary={"id":record.id,"name":record.name,"scene_id":scene.id,"position":_point(record.get("position"),scene),"decorative":true,"layer":"foreground","is_hero":false,"hidden":false,"owner_player_id":"","token_size":maxf(float(record.width_cells),float(record.height_cells)),"display_width_cells":float(record.width_cells),"display_height_cells":float(record.height_cells),"rotation_degrees":float(record.get("rotation_degrees",0)),"movement_policy":Hearth20Contracts.default_movement_policy()}
		if not Hearth20BoardTools.point_ok(actor.position,scene) or not Rect2(Vector2.ZERO,Vector2(scene.width_cells,scene.height_cells)).encloses(Hearth20TokenInventory.visual_bounds(actor)):return _fail("Foreground footprint extends outside the map.")
		foreground.append({"actor":actor,"image":inspected})
	var starts: Array=m.get("entry_points",[])
	if starts.is_empty() or starts.size()>16:return _fail("Provide 1 to 16 party entry_points.")
	var positions: Array=[]
	for point in starts:
		var p:=_point(point,scene)
		if not Hearth20BoardTools.point_ok(p,scene) or p.x>=scene.width_cells or p.y>=scene.height_cells or not is_equal_approx(fposmod(p.x,1.),0.5) or not is_equal_approx(fposmod(p.y,1.),0.5) or positions.has(p):return _fail("Entry points must be distinct cell centers inside the map.")
		positions.append(p)
	scene.library_entry=starts.duplicate(true)
	scene.package_id=m.id
	scene.map_credits=m.get("credits","");scene.map_description=m.get("description","")
	if used.size()!=entries.size():return _fail("Archive contains unreferenced files.")
	if not Hearth20Contracts.valid_scene(scene):return _fail("Walls, lights or environment failed scene validation.")
	return {"ok":true,"scene":scene,"background":background,"foreground":foreground,"entry_points":positions}

static func import_into(campaign: Dictionary, path: String, move_party: bool=true) -> Dictionary:
	if campaign.get("scenes",[]).size()>=Hearth20Contracts.MAX_SCENES:return _fail("This campaign has reached its scene limit.")
	var prepared:=read(path)
	if not prepared.ok:return prepared
	var proposed: Dictionary=campaign.duplicate(true)
	var old_scene: String=str(proposed.active_scene)
	var scene: Dictionary=prepared.scene
	scene.id="import-%d-%d"%[Time.get_ticks_usec(),randi()%100000]
	scene.map_asset=Hearth20Assets.store_asset(proposed,prepared.background,"map")
	scene.blackout=bool(proposed.get("map_covered",false))
	proposed.scenes.append(scene);proposed.active_scene=scene.id
	for entry in prepared.foreground:
		var actor: Dictionary=entry.actor
		actor.id=scene.id+"-fg-"+Hearth20Assets.sha256(str(actor.id).to_utf8_buffer()).left(16);actor.scene_id=scene.id
		actor.png_asset_id=Hearth20Assets.store_asset(proposed,entry.image,"token")
		proposed.actors.append(actor)
	if move_party:
		var heroes: Array=proposed.actors.filter(func(actor):return actor.get("is_hero",false) and not actor.get("in_inventory",false) and actor.get("scene_id","")==old_scene)
		var places:=Hearth20TokenInventory.party_positions(scene,prepared.entry_points,heroes.size())
		if places.size()<heroes.size():return _fail("This map has insufficient clear entry squares for the party.")
		var index:=0
		for actor in proposed.actors:
			if actor.get("is_hero",false) and not actor.get("in_inventory",false) and actor.get("scene_id","")==old_scene:
				actor.scene_id=scene.id;actor.position=places[index];index+=1
	proposed.revision=int(proposed.get("revision",0))+1
	Hearth20MapLibrary.discard_empty_starter(proposed,scene.id)
	var checked:=Hearth20Contracts.validate_campaign(proposed)
	if not checked.ok:return _fail("Import rejected: "+"; ".join(checked.errors))
	if JSON.stringify(Hearth20Identity._encode_variant(proposed)).to_utf8_buffer().size()>Hearth20Identity.MAX_SAVE_BYTES:return _fail("Adding this map would exceed the 64 MiB campaign save budget.")
	campaign.merge(proposed,true)
	return {"ok":true,"id":scene.id,"title":scene.title,"width_cells":scene.width_cells,"height_cells":scene.height_cells,"foreground_count":prepared.foreground.size(),"annotation_count":scene.annotations.size()}

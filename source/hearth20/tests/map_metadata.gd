extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
static func u32(value: int) -> PackedByteArray:
	return PackedByteArray([(value>>24)&255,(value>>16)&255,(value>>8)&255,value&255])
static func embed(png: PackedByteArray,text: String) -> PackedByteArray:
	var payload="Hearth20.Map".to_ascii_buffer()+PackedByteArray([0])+text.to_utf8_buffer()
	var body="tEXt".to_ascii_buffer()+payload
	return png.slice(0,33)+u32(payload.size())+body+u32(Hearth20MapMetadata.crc32(body))+png.slice(33)
func run() -> void:
	var image=Image.create(320,240,false,Image.FORMAT_RGB8);image.fill(Color("#987654"))
	var png=image.save_png_to_buffer();var dims=Vector2i(320,240)
	expect(Hearth20MapMetadata.read(png,dims)=={"ok":true,"grid":{}},"ordinary PNG keeps manual calibration")
	var metadata={"schema":1,"width_cells":32,"height_cells":24,"feet_per_cell":5,"pixel_width":320,"pixel_height":240}
	var stamped=embed(png,JSON.stringify(metadata));var parsed=Hearth20MapMetadata.read(stamped,dims)
	expect(parsed.ok and parsed.grid.width_cells==32 and parsed.grid.height_cells==24 and parsed.grid.feet_per_cell==5,"embedded scale is read and normalized")
	var decoded=Image.new();expect(decoded.load_png_from_buffer(stamped)==OK and decoded.get_data()==image.get_data(),"metadata preserves decoded pixels")
	var output=OS.get_cmdline_user_args()[0];var path=output.path_join("generated-map.hearth20.png")
	FileAccess.open(path,FileAccess.WRITE).store_buffer(stamped)
	var inspected=Hearth20Assets.inspect_map_file(path)
	expect(inspected.ok and inspected.grid.width_cells==32,"real map inspection carries calibration to the importer")
	var ordinary=output.path_join("plain.png");FileAccess.open(ordinary,FileAccess.WRITE).store_buffer(png)
	expect(Hearth20Assets.inspect_map_file(ordinary).grid.is_empty(),"plain map inspection retains compatibility")
	for changed in [{"schema":2},{"width_cells":0},{"width_cells":257},{"width_cells":2.5},{"width_cells":"032"},{"height_cells":25},{"feet_per_cell":0},{"feet_per_cell":1001},{"pixel_width":321},{"pixel_height":241},{"unknown":true}]:
		var bad=metadata.duplicate();bad.merge(changed,true)
		expect(not Hearth20MapMetadata.read(embed(png,JSON.stringify(bad)),dims).ok,"invalid metadata is rejected: "+str(changed))
	for text in ["{}","[]","null","{oops}","[".repeat(30)+"]".repeat(30)," ".repeat(4097)]:
		expect(not Hearth20MapMetadata.read(embed(png,text),dims).ok,"malformed or oversized metadata rejected")
	expect(not Hearth20MapMetadata.read(embed(stamped,JSON.stringify(metadata)),dims).ok,"duplicate metadata cannot override scale ambiguously")
	var corrupt=stamped.duplicate();corrupt[60]=corrupt[60]^1
	expect(not Hearth20MapMetadata.read(corrupt,dims).ok,"corrupt metadata checksum rejected")
	var before=Hearth20MapMetadata.crc32("123456789".to_ascii_buffer())
	expect(before==0xcbf43926,"PNG CRC matches the independent standard vector")
	expect(not Hearth20MapMetadata.validate({"schema":1,"width_cells":32},Vector2i(128,4096)).ok,"extreme grid height rejected")
	print("Map metadata: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)

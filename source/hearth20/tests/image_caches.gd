extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func original_mask(source: PackedByteArray,context: Dictionary) -> Image:
	var image=Hearth20Assets.decode_map(source);var masked=Image.create(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8);masked.fill(Color.BLACK)
	var gray=image.duplicate();gray.convert(Image.FORMAT_LA8);gray.convert(Image.FORMAT_RGBA8)
	var px=float(context.scene.cell_pixels)/float(context.subdivisions)
	for y in int(context.rows):
		for x in int(context.columns):
			var level=int(context.levels[y*int(context.columns)+x])
			if level==0:continue
			var begin=Vector2i(ceili(x*px),ceili(y*px));var end=Vector2i(floori((x+1)*px),floori((y+1)*px))
			var rect=Rect2i(begin,end-begin).intersection(Rect2i(0,0,image.get_width(),image.get_height()))
			if rect.has_area():masked.blit_rect(gray if level==1 else image,rect,rect.position)
	return masked
func run() -> void:
	var image=Image.create(256,256,false,Image.FORMAT_RGBA8);image.fill(Color.CORAL);var bytes=image.save_png_to_buffer();var inspected=Hearth20Assets.inspect_token_png_bytes(bytes)
	var c=Hearth20Identity.new_campaign("Cache integrity");var id=Hearth20Assets.store_asset(c,inspected,"token")
	expect(Hearth20Assets.read_asset(c,id,"token")==bytes,"valid image cached")
	var copy=Hearth20Assets.read_asset(c,id,"token");copy[0]=0;expect(Hearth20Assets.read_asset(c,id,"token")==bytes,"returned bytes cannot poison validation cache")
	var good=c.assets[id].duplicate(true)
	for field in ["width","height","byte_length","sha256","base64","kind","mime_type"]:
		c.assets[id]=good.duplicate(true);c.assets[id][field]=999 if field in ["width","height","byte_length"] else "forged"
		expect(Hearth20Assets.read_asset(c,id,"token").is_empty(),"changed "+field+" must be revalidated")
	c.assets[id]=good;expect(Hearth20Assets.read_asset(c,id,"map").is_empty(),"cache cannot bypass requested image kind")
	var scene=c.scenes[0];scene.width_cells=4;scene.height_cells=4;scene.cell_pixels=64;scene.dynamic_lighting=false;scene.fog_rects=[Rect2(1,1,1,1)]
	var sight=Hearth20Vision.build_view(c,"player",scene);var first=Hearth20Vision.mask_map(bytes,sight);var hit=Hearth20Vision.mask_map(bytes,sight)
	expect(first==hit,"identical source and vision reuse identical masked image")
	var masked=Image.new();masked.load_png_from_buffer(hit);expect(masked.get_pixel(90,90)==Color.BLACK and masked.get_pixel(10,10).r>.9,"cache retains exact hidden and revealed pixels")
	image.fill(Color.BLUE);var changed=image.save_png_to_buffer();var other=Hearth20Vision.mask_map(changed,sight);expect(other!=first,"different source bytes cannot match another map's cached result")
	scene.fog_rects=[];var reveal=Hearth20Vision.mask_map(bytes,Hearth20Vision.build_view(c,"player",scene));masked.load_png_from_buffer(reveal);expect(masked.get_pixel(90,90).r>.9,"changed visibility cannot reuse an old mask")
	scene.blackout=true;var black=Hearth20Vision.mask_map(bytes,Hearth20Vision.build_view(c,"player",scene));masked.load_png_from_buffer(black);expect(masked.get_pixel(90,90)==Color.BLACK and masked.get_pixel(10,10)==Color.BLACK,"full cover cannot reuse a revealed cached image")
	for n in 10:Hearth20MaskedImageCache.put("evict-"+str(n),bytes,first)
	expect(Hearth20MaskedImageCache.entries.size()<=4 and Hearth20MaskedImageCache.used<=Hearth20MaskedImageCache.BUDGET,"masked-image cache remains bounded")
	expect(Hearth20Assets.validated_bytes<=Hearth20Assets.CACHE_BUDGET,"validated-byte cache remains bounded")
	for pixels in [64.,63.5,51.3]:
		var levels=PackedByteArray();levels.resize(16*16)
		for i in levels.size():levels[i]=(i+i/16)%4
		var fixture={"scene":{"cell_pixels":pixels},"subdivisions":4,"columns":16,"rows":16,"levels":levels}
		var actual=Image.new();actual.load_png_from_buffer(Hearth20Vision.mask_map(bytes,fixture))
		expect(actual.get_data()==original_mask(bytes,fixture).get_data(),"optimized mask matches every original pixel at calibration "+str(pixels))
	print("Image caches: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)

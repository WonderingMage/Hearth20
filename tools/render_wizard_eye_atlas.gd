extends SceneTree
## Bake smooth phosphor fields offline: runtime needs one RGBA mask sample.
const WIDTH=1024
const HEIGHT=1280
func _initialize() -> void:call_deferred("run")
func mask(path: String) -> Image:
	var image=Image.new();var error=image.load_svg_from_string(FileAccess.get_file_as_string(path));assert(error==OK);image.convert(Image.FORMAT_RGBA8);return image
func blur(source: PackedFloat32Array,radius: int,horizontal: bool) -> PackedFloat32Array:
	var result=PackedFloat32Array();result.resize(source.size());var major=HEIGHT if horizontal else WIDTH;var minor=WIDTH if horizontal else HEIGHT;var stride=1 if horizontal else WIDTH
	for line in major:
		var base=line*WIDTH if horizontal else line;var sum=0.
		for j in range(-radius,radius+1):sum+=source[base+clampi(j,0,minor-1)*stride]
		for j in minor:
			result[base+j*stride]=sum/float(radius*2+1);sum-=source[base+clampi(j-radius,0,minor-1)*stride];sum+=source[base+clampi(j+radius+1,0,minor-1)*stride]
	return result
func gaussian(source: PackedFloat32Array,radii: Array) -> PackedFloat32Array:
	var result=source
	for radius in radii:result=blur(blur(result,radius,true),radius,false)
	return result
func run() -> void:
	var image=mask("res://hearth20/wizard_eye_atlas.svg");var iris=mask("res://hearth20/wizard_eye_irises.svg");assert(image.get_size()==Vector2i(WIDTH,HEIGHT));image.save_png("res://hearth20/wizard_eye_atlas.png")
	var raw=image.get_data();var iris_raw=iris.get_data();var core=PackedFloat32Array();core.resize(WIDTH*HEIGHT)
	for i in core.size():core[i]=float(raw[i*4])*float(raw[i*4+3])/65025.
	var near_field=gaussian(core,[2,3,3]);var wide_field=gaussian(core,[6,7,8]);var bytes=PackedByteArray();bytes.resize(raw.size())
	for i in core.size():bytes[i*4]=roundi(core[i]*255.);bytes[i*4+1]=roundi(float(iris_raw[i*4])*float(iris_raw[i*4+3])/255.);bytes[i*4+2]=roundi(clampf(near_field[i],0,1)*255.);bytes[i*4+3]=roundi(clampf(wide_field[i],0,1)*255.)
	var phosphor=Image.create_from_data(WIDTH,HEIGHT,false,Image.FORMAT_RGBA8,bytes);phosphor.save_png("res://hearth20/wizard_eye_phosphor.png")
	print("Baked CRT maps: R=solid sclera, G=optional iris, B=near phosphor spread, A=wide phosphor spread.");quit.call_deferred()

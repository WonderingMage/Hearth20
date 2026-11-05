extends Node
class_name Hearth20SoftLight
## Offscreen radiance, filtered penumbra and a height-integrated scattering pass.
## Receives authorized polygons only; player clipping is enforced again in the shader.
class RadianceCanvas extends Node2D:
	var meshes: Array=[]
	var pixels_per_cell:=24.0
	var layer:=2
	func _draw() -> void:
		for mesh in meshes:
			var type:=str(mesh.get("type",""))
			var mesh_layer:=1 if type=="sky_shadow" else 0 if type.begins_with("sky_") else 2
			if mesh_layer==layer: Hearth20Lighting.draw_mesh(self,mesh,pixels_per_cell,Vector2.ZERO)

const COMPOSITE := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D radiance : filter_linear, repeat_disable;
uniform sampler2D albedo : filter_linear_mipmap, repeat_disable;
uniform sampler2D sight : filter_nearest, repeat_disable;
uniform vec2 field_size;
uniform vec2 world_size;
uniform float ambient = 0.22;
uniform float exposure = 1.0;
uniform float haze = 0.35;
uniform float solar_elevation = 0.5;
uniform bool player_view = false;
float hash(vec3 p) { p = fract(p * 0.1031); p += dot(p,p.yzx + 33.33); return fract((p.x+p.y)*p.z); }
float noise3(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
vec3 filtered(vec2 uv, float radius) {
 vec2 p=radius/field_size;
 vec3 c=texture(radiance,uv).rgb*0.227027;
 c+=(texture(radiance,uv+vec2(p.x,0)).rgb+texture(radiance,uv-vec2(p.x,0)).rgb+texture(radiance,uv+vec2(0,p.y)).rgb+texture(radiance,uv-vec2(0,p.y)).rgb)*0.1216216;
 c+=(texture(radiance,uv+p).rgb+texture(radiance,uv-p).rgb+texture(radiance,uv+vec2(p.x,-p.y)).rgb+texture(radiance,uv+vec2(-p.x,p.y)).rgb)*0.0716216;
 return c;
}
void fragment() {
 vec3 base=texture(albedo,UV).rgb;
 float level=texture(sight,UV).r*3.0;
 if(player_view && level<0.5) { COLOR=vec4(0,0,0,1); }
 else {
  vec3 direct=filtered(UV,0.8);
  vec3 bloom=filtered(UV,3.5);
  // Light transport through an artist-controlled finite 12-foot air column.
  // Beer-Lambert transmittance + normalized Henyey-Greenstein phase (g=.28).
  float g=0.28;
  float phase=(1.0-g*g)/pow(1.0+g*g-2.0*g*sin(solar_elevation),1.5);
  float transmission=1.0;
  vec3 scattering=vec3(0);
  for(int i=0;i<12;i++) {
   vec3 p=vec3(UV*world_size*0.8,float(i)*0.37);
   p.xy+=vec2(TIME*0.012,-TIME*0.009);
   float density=haze*(0.55+0.45*noise3(p));
   float step_trans=exp(-density*0.09);
   scattering+=transmission*(1.0-step_trans)*direct*phase;
   transmission*=step_trans;
  }
  vec3 irradiance=vec3(ambient*0.78,ambient*0.88,ambient)+direct*3.8;
  vec3 linear_base=pow(max(base,vec3(0.0)),vec3(2.2));
  vec3 reflected=linear_base*irradiance*exposure;
  vec3 mapped=vec3(1.0)-exp(-reflected*1.55);
  vec3 surface=pow(max(mapped,vec3(0)),vec3(1.0/2.2));
  vec3 air=scattering*0.18+bloom*haze*0.025;
  if(player_view && level<1.5) {
   float gray=dot(base,vec3(.2126,.7152,.0722));
   surface=vec3(gray)*0.62; air=vec3(0);
  }
  COLOR=vec4(clamp(surface+air,vec3(0),vec3(1)),1);
 }
}
"""
var field: SubViewport
var output: SubViewport
var painter: RadianceCanvas
var sky_painter: RadianceCanvas
var shadow_painter: RadianceCanvas
var composite: ColorRect
var shader_material: ShaderMaterial
var signature:=""
var refresh_hz=60.
var elapsed=0.
var animated=true
var active=false

func _ready() -> void:
	field=SubViewport.new()
	field.transparent_bg=true
	field.disable_3d=true
	field.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(field)
	painter=RadianceCanvas.new()
	var additive:=CanvasItemMaterial.new()
	additive.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	sky_painter=RadianceCanvas.new(); sky_painter.layer=0; sky_painter.material=additive
	field.add_child(sky_painter)
	shadow_painter=RadianceCanvas.new(); shadow_painter.layer=1
	field.add_child(shadow_painter)
	painter.material=additive
	field.add_child(painter)
	output=SubViewport.new()
	output.disable_3d=true
	output.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(output)
	composite=ColorRect.new()
	composite.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code=COMPOSITE
	shader_material=ShaderMaterial.new()
	shader_material.shader=shader
	composite.material=shader_material
	output.add_child(composite)

func configure(key: String, source: Texture2D, meshes: Array, scene: Dictionary, mask: Dictionary, player: bool) -> void:
	if field==null or source==null: return
	set_active(true)
	if key==signature: return
	signature=key
	output.render_target_update_mode=SubViewport.UPDATE_ONCE
	var world:=Vector2(float(scene.width_cells),float(scene.height_cells))
	var ppc:=minf(32.0,1024.0/maxf(world.x,world.y))
	field.size=Vector2i((world*ppc).ceil())
	output.size=Vector2i(source.get_size()*minf(1.0,1536.0/source.get_width()))
	composite.size=Vector2(output.size)
	painter.pixels_per_cell=ppc
	painter.meshes=meshes
	painter.queue_redraw()
	for pass_node in [sky_painter,shadow_painter]:
		pass_node.pixels_per_cell=ppc; pass_node.meshes=meshes; pass_node.queue_redraw()
	field.render_target_update_mode=SubViewport.UPDATE_ONCE
	var visibility:=Image.create(int(mask.get("columns",1)),int(mask.get("rows",1)),false,Image.FORMAT_R8)
	visibility.fill(Color.WHITE)
	if player and mask.get("levels") is PackedByteArray:
		var bytes: PackedByteArray=mask.levels.duplicate()
		for i in bytes.size(): bytes[i]=int(bytes[i])*85
		visibility=Image.create_from_data(int(mask.columns),int(mask.rows),false,Image.FORMAT_R8,bytes)
	var natural:=Hearth20NaturalLight.settings(scene)
	animated=float(natural.haze)>.001
	var received:=Hearth20Lighting.read_field(scene.get("light_field",{})) if player else null
	if received!=null:
		field.render_target_update_mode=SubViewport.UPDATE_DISABLED
		shader_material.set_shader_parameter("radiance",ImageTexture.create_from_image(received))
		shader_material.set_shader_parameter("field_size",Vector2(received.get_size()))
	else:
		shader_material.set_shader_parameter("radiance",field.get_texture())
		shader_material.set_shader_parameter("field_size",Vector2(field.size))
	shader_material.set_shader_parameter("albedo",source)
	shader_material.set_shader_parameter("sight",ImageTexture.create_from_image(visibility))
	shader_material.set_shader_parameter("world_size",world)
	shader_material.set_shader_parameter("ambient",0.26 if scene.get("ambient_light","dark")=="dark" else 0.55 if scene.get("ambient_light")=="dim" else 0.9)
	shader_material.set_shader_parameter("haze",float(natural.haze))
	shader_material.set_shader_parameter("exposure",float(natural.exposure))
	shader_material.set_shader_parameter("solar_elevation",float(Hearth20NaturalLight.sky(scene).altitude))
	shader_material.set_shader_parameter("player_view",player)
func _process(delta: float) -> void:
	if not active or signature.is_empty() or not animated or refresh_hz<=0.:return
	elapsed+=delta
	if elapsed>=1./refresh_hz:elapsed=fmod(elapsed,1./refresh_hz);output.render_target_update_mode=SubViewport.UPDATE_ONCE
func set_active(value: bool) -> void:
	if active==value:return
	active=value
	if output!=null:output.render_target_update_mode=SubViewport.UPDATE_ONCE if active else SubViewport.UPDATE_DISABLED

func texture() -> Texture2D:
	return output.get_texture() if output!=null and not signature.is_empty() else null

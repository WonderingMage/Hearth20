extends Node3D
class_name Hearth20TavernRoom
## A closed, static tavern shell. Architectural pieces are batched by material.
const HALF_WIDTH=8.
const FRONT=-7.
const REAR=8.
const CEILING=4.84
const BOUNDARY_LAYER=1<<19
var table: Hearth20CasinoTable
var materials={}
var batches={}
var batch_materials={}
var effects: Array=[]
var ceiling_height=CEILING
func setup(owner_table: Hearth20CasinoTable) -> void:
	table=owner_table;name="EnclosedTavern"
	materials={"wood":table.wood,"brass":table.bronze,"velvet":table.felt,"stone":_stone(),"mortar":_solid(Color("#302b25")),"iron":_solid(Color("#242326"),.72,.47),"green":_solid(Color("#26483b"),.06,.3),"amber":_solid(Color("#5b3422"),.08,.28),"wine":_solid(Color("#4a2630"),.05,.35),"paper":_solid(Color("#a28c66")),"glass":_window_glass(),"crest":_crest()}
	if Hearth20GeneratedModels.available("room"):
		_generated_room();return
	# All six room boundaries and the front fireplace/bar are modeled geometry.
	_boundary("Floor",Vector3(0,-.12,.5),Vector3(16.5,.24,15.5),"wood")
	_boundary("Ceiling",Vector3(0,CEILING+.10,.5),Vector3(16.5,.20,15.5),"wood")
	_boundary("WestWall",Vector3(-8.1,CEILING/2.,.5),Vector3(.3,CEILING+.25,15.5),"mortar")
	_boundary("EastWall",Vector3(8.1,CEILING/2.,.5),Vector3(.3,CEILING+.25,15.5),"mortar")
	_boundary("RearWall",Vector3(0,CEILING/2.,8.1),Vector3(16.5,CEILING+.25,.3),"mortar")
	_boundary("FrontWall",Vector3(0,CEILING/2.,-7.18),Vector3(16.5,CEILING+.25,.3),"mortar")
	_floor();_masonry();_timber()
	for side in [-1,1]:
		for z in [-4.,1.5,6.4]:_sconce(side,z)
	_entry();_rear_furniture();_sideboards();_front_furniture();_finish_batches()
	var fill=OmniLight3D.new();fill.position=Vector3(0,3.9,2.2);fill.light_color=Color("#d4ac7a");fill.light_energy=.40;fill.omni_range=11.;fill.shadow_enabled=false;add_child(fill)
	set_meta("fully_enclosed",true)
	set_meta("modeled_front",true)
func _prop(id: String,at: Vector3,dimensions: Vector3,yaw=0.) -> Node3D:
	var model=Hearth20GeneratedModels.make(id,dimensions)
	if model==null:return null
	model.position=at;model.rotation.y=yaw;add_child(model);Hearth20GeneratedModels.shadows(model,false);return model
func _rest_on(id: String,support: Node3D,at: Vector3,dimensions: Vector3) -> Node3D:
	# Seat decorations on the actual reconstructed counter, not its bounding-box
	# maximum (which may belong to a raised rim or carved corner).
	var height=-INF
	if support!=null:
		var world_origin=to_global(Vector3(at.x,ceiling_height+2.,at.z))
		for mesh in support.find_children("*","MeshInstance3D",true,false):
			var inverse=mesh.global_transform.affine_inverse();var origin=inverse*world_origin;var direction=(inverse.basis*Vector3.DOWN).normalized()
			for surface in mesh.mesh.get_surface_count():
				var arrays=mesh.mesh.surface_get_arrays(surface);var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
				for i in range(0,indices.size(),3):
					var hit=Geometry3D.ray_intersects_triangle(origin,direction,vertices[indices[i]],vertices[indices[i+1]],vertices[indices[i+2]])
					if hit!=null:height=maxf(height,to_local(mesh.to_global(hit)).y)
	if is_finite(height):at.y=height+.001
	var result=_prop(id,at,dimensions)
	if result!=null:result.set_meta("rests_on_surface",is_finite(height))
	return result
func _generated_room() -> void:
	# The supplied room is a camera-space front reconstruction. Preserve its
	# projection and close the unseen bays with matching ordinary geometry.
	ceiling_height=6.05
	var flooring=Hearth20GeneratedModels.surface("kit_floor")
	var stone=Hearth20GeneratedModels.surface("kit_stone")
	materials.floor=_projected_fill(flooring.albedo_texture if flooring!=null else null,Color(.75,.78,.80),Vector2(6,7),true)
	materials.floor.set_shader_parameter("saturation",.45);materials.floor.set_shader_parameter("base_rect",Vector4(.20,.01,.65,.98))
	materials.stone=_projected_fill(stone.albedo_texture if stone!=null else null,Color(.78,.72,.63),Vector2(5.5,2.0))
	materials.stone.set_shader_parameter("base_rect",Vector4(.53,.53,.45,.45))
	var stone_material=_projected_fill(stone.albedo_texture if stone!=null else null,Color(.78,.72,.63),Vector2.ONE)
	_boundary("Floor",Vector3(0,-.10,-3),Vector3(16.5,.20,22.5),"floor")
	_boundary("Ceiling",Vector3(0,ceiling_height+.10,-3),Vector3(16.5,.20,22.5),"wood")
	for side in [-1,1]:_boundary("WestWall" if side<0 else "EastWall",Vector3(side*8.12,ceiling_height*.5,-3),Vector3(.25,ceiling_height+.2,22.5),"stone")
	_boundary("RearWall",Vector3(0,ceiling_height*.5,8.12),Vector3(16.5,ceiling_height+.2,.25),"stone")
	_boundary("FrontWall",Vector3(0,ceiling_height*.5,-14.12),Vector3(16.5,ceiling_height+.2,.25),"stone")
	# Kit textures are UV atlases, not tiling wall images. Instance the actual
	# module mesh so each stone keeps the atlas coordinates authored for it.
	for row in 2:
		for column in 4:_stone_module(Vector3(-6.+column*4.,row*3.,7.98),Vector3(4.0,3.0,.20),PI,stone_material)
		for side in [-1,1]:
			for column in 6:_stone_module(Vector3(side*8.00,row*3.,-12.+column*4.),Vector3(4.,3.0,.20),-side*PI/2,stone_material)
	var backdrop=Hearth20GeneratedModels.raw("room");backdrop.name="ReconstructedTavernFront";backdrop.scale=Vector3.ONE*1.8;backdrop.position=Vector3(0,1.954,2.45);add_child(backdrop);Hearth20GeneratedModels.shadows(backdrop,false)
	for side in [-1,1]:
		for z in [-11.,-6.,-1.,4.,7.7]:_prop("kit_beam",Vector3(side*7.93,0,z),Vector3(.24,ceiling_height,.24))
		_box(Vector3(side*7.88,.33,-3),Vector3(.26,.66,22.1),"wood")
		_box(Vector3(side*7.88,ceiling_height-.26,-3),Vector3(.32,.30,22.1),"wood")
	for z in [-11.,-6.,-1.,4.,7.7]:_box(Vector3(0,ceiling_height-.20,z),Vector3(16,.24,.28),"wood")
	for x in [-5.3,-2.7,0.,2.7,5.3]:_box(Vector3(x,ceiling_height-.04,-3),Vector3(.16,.16,22.2),"wood")
	for y in [.30,ceiling_height-.25]:_box(Vector3(0,y,7.90),Vector3(16,.28,.25),"wood")
	_prop("door",Vector3(0,0,7.86),Vector3(1.65,2.9,.27),PI)
	_box(Vector3(0,.07,7.78),Vector3(1.60,.14,.30),"wood")
	_prop("bench",Vector3(-4.6,0,7.18),Vector3(3.4,1.35,.68),PI)
	_prop("small_bar_table",Vector3(-4.6,0,5.55),Vector3(1.45,.87,1.45))
	for at in [Vector3(-5.8,0,5.4),Vector3(-3.4,0,5.4)]:_prop("bar_stool",at,Vector3(.58,.73,.58))
	_prop("fireplace",Vector3(4.7,0,7.64),Vector3(2.9,3.0,1.1),PI)
	_fire_particles(Vector3(4.7,.38,7.10),false);_fire_particles(Vector3(4.7,1.05,7.15),true)
	var firelight=OmniLight3D.new();firelight.position=Vector3(4.7,1.2,6.8);firelight.light_color=Color("#ffc17b");firelight.light_energy=1.8;firelight.omni_range=6;add_child(firelight)
	var bar=_prop("bar",Vector3(-7.47,0,1.5),Vector3(3.0,1.10,.65),PI/2)
	_prop("wood_shelve",Vector3(-7.79,1.15,1.5),Vector3(2.7,2.2,.34),PI/2)
	for z in [.55,2.45]:_prop("bar_stool",Vector3(-6.3,0,z),Vector3(.55,.74,.55))
	for z in [1.15,1.80,2.1,2.4]:_rest_on("bottle",bar,Vector3(-7.4,1.1,z),Vector3(.13,.40,.13))
	_rest_on("bowl",bar,Vector3(-7.36,1.11,1.5),Vector3(.30,.13,.30))
	for side in [-1,1]:
		var cabinet=_prop("cabinet",Vector3(side*7.4,0,5.0),Vector3(2.0,.95,.52),-side*PI/2)
		_prop("large_window",Vector3(side*7.92,1.50,4.55),Vector3(2.0,1.85,.15),-side*PI/2)
		_prop("small_window",Vector3(side*7.93,1.1,-.8),Vector3(1.4,2.6,.15),-side*PI/2)
		for z in [1.5,6.6]:_generated_sconce(Vector3(side*7.80,2.4,z),-side*PI/2)
		_prop("shield",Vector3(side*2.3,3.65,7.93),Vector3(.72,1.0,.12),PI)
		for z in [4.45,5.0,5.55]:_rest_on("bottle",cabinet,Vector3(side*7.4,.95,z),Vector3(.12,.36,.12))
	var fill=OmniLight3D.new();fill.position=Vector3(0,4.0,3.8);fill.light_color=Color("#edc395");fill.light_energy=.65;fill.omni_range=13.;add_child(fill)
	_finish_batches();set_meta("fully_enclosed",true);set_meta("modeled_front",true);set_meta("uses_generated_backdrop",true)
func _stone_module(at: Vector3,dimensions: Vector3,yaw: float,mat: Material) -> void:
	var model=Hearth20GeneratedModels.part("kit_stone",dimensions)
	if model==null:return
	model.position=at;model.rotation.y=yaw
	for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.material_override=mat;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(model)
func _projected_fill(base: Texture2D,tint: Color,tiling: Vector2,swap=false) -> ShaderMaterial:
	var shader=Shader.new();shader.code="""
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D photo:source_color,filter_linear_mipmap;
uniform sampler2D base_texture:source_color,repeat_enable,filter_linear_mipmap_anisotropic;
uniform bool textured=false;
uniform bool swap_uv=false;
uniform vec4 tint:source_color=vec4(1.);
uniform vec2 tiling=vec2(1.);
uniform vec4 base_rect=vec4(0.,0.,1.,1.);
uniform float saturation=1.;
uniform vec4 projection=vec4(.55638,-.997295,.5,.5);
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec3 p=(world_point-vec3(0.,1.954,2.45))/1.8;float depth=-p.z;
 vec2 puv=vec2(projection.x*p.x/max(.001,depth)+projection.z,projection.y*p.y/max(.001,depth)+projection.w);
 float coverage=step(.01,depth)*smoothstep(0.,.025,puv.x)*smoothstep(0.,.025,1.-puv.x)*smoothstep(0.,.025,puv.y)*smoothstep(0.,.025,1.-puv.y);
 vec2 uv=base_rect.xy+fract((swap_uv?UV.yx:UV)*tiling)*base_rect.zw;
 vec3 albedo=textured?texture(base_texture,uv).rgb:vec3(1.);
 albedo=mix(vec3(dot(albedo,vec3(.2126,.7152,.0722))),albedo,saturation)*tint.rgb;
 ALBEDO=albedo*(1.-coverage);EMISSION=texture(photo,clamp(puv,vec2(0.),vec2(1.))).rgb*coverage;
 ROUGHNESS=.97;SPECULAR=.08;
}
"""
	var mat=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("photo",Hearth20GeneratedModels.surface("room").albedo_texture);mat.set_shader_parameter("base_texture",base);mat.set_shader_parameter("textured",base!=null);mat.set_shader_parameter("tint",tint);mat.set_shader_parameter("tiling",tiling);mat.set_shader_parameter("swap_uv",swap)
	var projection=Hearth20GeneratedModels.catalog.room.get("projection",[.55638,-.997295,.5,.5]);mat.set_shader_parameter("projection",Vector4(projection[0],projection[1],projection[2],projection[3]));return mat
func _generated_sconce(at: Vector3,yaw: float) -> void:
	_prop("wall_candle",at,Vector3(.24,.70,.26),yaw)
	var flame=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(.09,.17);flame.mesh=quad;flame.position=at+Vector3(0,.54,0);add_child(flame)
	var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;void vertex(){VERTEX.x+=sin(TIME*8.+UV.y*5.)*.005*UV.y;}void fragment(){vec2 p=(UV-.5)*vec2(2.,1.3);float a=pow(max(0.,1.-length(p)),2.);ALBEDO=mix(vec3(1.,.22,.02),vec3(1.,.9,.55),a);EMISSION=ALBEDO*1.4;ALPHA=a;}"
	var mat=ShaderMaterial.new();mat.shader=shader;flame.material_override=mat;flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light=OmniLight3D.new();light.position=at+Vector3(0,.6,0);light.light_color=Color("#ffd19a");light.light_energy=.9;light.omni_range=5.0;add_child(light)
func _solid(color: Color,metal=0.,rough=.88) -> StandardMaterial3D:
	var material_value=StandardMaterial3D.new();material_value.albedo_color=color;material_value.metallic=metal;material_value.roughness=rough;return material_value
func _stone() -> ShaderMaterial:
	var shader=Shader.new();shader.code="""
shader_type spatial;
varying vec3 p;
void vertex(){p=VERTEX;}
void fragment(){
 float grain=fract(sin(dot(floor(p*190.),vec3(12.9898,78.233,37.719)))*43758.5453);
 float mottling=sin(p.x*3.1+p.y*5.3)*sin(p.z*4.7-p.y*2.1);
 ALBEDO=mix(vec3(.17,.145,.115),vec3(.32,.285,.23),.45+mottling*.17+grain*.15)*COLOR.rgb;
 ROUGHNESS=.97;SPECULAR=.12;
}
""";var m=ShaderMaterial.new();m.shader=shader;return m
func _window_glass() -> ShaderMaterial:
	var shader=Shader.new();shader.code="""
shader_type spatial;
render_mode unshaded;
void fragment(){
 float clouds=sin(UV.x*11.+UV.y*8.+TIME*.006)*sin(UV.y*17.-UV.x*4.);
 vec3 haze=mix(vec3(.055,.075,.095),vec3(.23,.29,.32),UV.y*.4+.25+clouds*.07);
 ALBEDO=haze;EMISSION=haze*.13;
}
""";var m=ShaderMaterial.new();m.shader=shader;return m
func _crest() -> ShaderMaterial:
	var shader=Shader.new();shader.code="""
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas:source_color,filter_linear_mipmap;
void fragment(){ALBEDO=texture(atlas,vec2(.5)+UV*.497).rgb;ROUGHNESS=.9;}
""";var m=ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("atlas",table.materials);return m
func _merge(mesh: Mesh,at: Vector3,basis: Basis,key: String,color=Color.WHITE) -> void:
	var material_key=key
	# Small spatial batches retain material batching while letting the camera cull other bays.
	var span=(Transform3D(basis,Vector3.ZERO)*mesh.get_aabb()).size
	key+=":large" if maxf(span.x,span.z)>4.1 else ":%d:%d"%[clampi(floori((at.x+8.)/4.),0,3),clampi(floori((at.z+7.)/4.),0,3)]
	batch_materials[key]=material_key
	if not batches.has(key):var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);batches[key]=st
	var st: SurfaceTool=batches[key];var arrays=mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	for i in (indices if not indices.is_empty() else range(vertices.size())):
		st.set_normal((basis*normals[i]).normalized());st.set_uv(uv[i] if not uv.is_empty() else Vector2.ZERO);st.set_color(color);st.add_vertex(at+basis*vertices[i])
func _box(at: Vector3,size_value: Vector3,key: String,rotation_value=Vector3.ZERO,color=Color.WHITE) -> void:
	var mesh=BoxMesh.new();mesh.size=size_value;_merge(mesh,at,Basis.from_euler(rotation_value),key,color)
func _beam(a: Vector3,b: Vector3,width: float,key: String) -> void:
	var mesh=BoxMesh.new();mesh.size=Vector3(width,width,a.distance_to(b));_merge(mesh,(a+b)*.5,Basis.looking_at((b-a).normalized()),key)
func _lathe(at: Vector3,profile: Array,rx: float,rz: float,key: String,segments=20) -> void:
	var node=table._lathe(self,at,profile,rx,rz,materials[key],segments);_merge(node.mesh,node.position,node.basis,key);node.free()
func _boundary(label: String,at: Vector3,size_value: Vector3,key: String) -> void:
	_box(at,size_value,key)
	var body=StaticBody3D.new();body.name=label;body.position=at;body.collision_layer=BOUNDARY_LAYER;body.collision_mask=0;add_child(body)
	var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size_value;collision.shape=shape;body.add_child(collision)
func _floor() -> void:
	for lane in 32:
		for section in 6:
			var z=-7.+section*3.+(1.5 if lane%2 else 0.)
			_box(Vector3(-7.75+lane*.5,.014,z),Vector3(.492,.028,2.985),"wood")
func _masonry() -> void:
	for row in 13:
		var y=.19+row*.37
		for block in 20:
			var z=-6.85+block*.76+(0.38 if row%2 else 0.)
			for side in [-1,1]:
				var shade=.78+.20*fposmod(sin(float(row*71+block*13+side))*437.1,1.)
				_box(Vector3(side*7.95,y,z),Vector3(.16,.345,.735),"stone",Vector3.ZERO,Color(shade,shade,shade))
		for block in 22:
			var x=-7.85+block*.76+(0.38 if row%2 else 0.);var shade=.78+.20*fposmod(sin(float(row*41+block*17))*137.1,1.)
			_box(Vector3(x,y,7.95),Vector3(.735,.345,.16),"stone",Vector3.ZERO,Color(shade,shade,shade))
			_box(Vector3(x,y,-6.97),Vector3(.735,.345,.16),"stone",Vector3.ZERO,Color(shade,shade,shade))
func _timber() -> void:
	for side in [-1,1]:
		_box(Vector3(side*7.78,.22,.5),Vector3(.22,.40,15.2),"wood")
		_box(Vector3(side*7.78,4.48,.5),Vector3(.27,.28,15.2),"wood")
		for z in [-6.,-2.5,1.,4.5,7.7]:
			_box(Vector3(side*7.72,2.35,z),Vector3(.27,4.7,.27),"wood")
			_beam(Vector3(side*7.65,3.65,z),Vector3(side*6.72,4.57,z),.16,"wood")
	for z in [-5.5,-1.7,3.,7.6]:
		_box(Vector3(0,4.65,z),Vector3(16.,.28,.24),"wood")
		for x in [-5.3,-2.7,0.,2.7,5.3]:_box(Vector3(x,4.76,.5),Vector3(.16,.16,15.3),"wood")
	_box(Vector3(0,.22,7.75),Vector3(16.,.4,.24),"wood")
	_box(Vector3(0,4.49,7.75),Vector3(16.,.28,.24),"wood")
	_box(Vector3(0,.22,-6.76),Vector3(16.,.4,.24),"wood")
	_box(Vector3(0,4.49,-6.76),Vector3(16.,.28,.24),"wood")
func _sconce(side: int,z: float) -> void:
	var x=side*7.5
	_box(Vector3(side*7.73,2.4,z),Vector3(.08,.44,.24),"iron")
	_beam(Vector3(side*7.71,2.2,z),Vector3(x,2.45,z),.055,"iron")
	_lathe(Vector3(x,2.40,z),[[0.,0.],[.12,0.],[.14,.025],[.10,.065],[.075,.09]],1.,1.,"brass")
	_box(Vector3(x,2.63,z),Vector3(.095,.32,.095),"paper")
	var flame=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(.11,.23);flame.mesh=quad;flame.position=Vector3(x,2.90,z);add_child(flame);flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader=Shader.new();shader.code="""
shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_add;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);VERTEX.x+=sin(TIME*8.+UV.y*5.)*.007;}
void fragment(){vec2 p=(UV-.5)*vec2(2.2,1.5);float fire=pow(max(0.,1.-length(p)),2.);ALBEDO=mix(vec3(1.,.20,.035),vec3(1.,.91,.61),fire);EMISSION=ALBEDO*1.4;ALPHA=fire;}
""";var material_value=ShaderMaterial.new();material_value.shader=shader;flame.material_override=material_value
	var lamp=OmniLight3D.new();lamp.position=Vector3(x-side*.24,2.95,z);lamp.light_color=Color("#ffd198");lamp.light_energy=1.45;lamp.omni_range=6.8;lamp.shadow_enabled=false;add_child(lamp)
func _entry() -> void:
	for plank in 11:
		var x=(plank-5)*.155;var height=2.05+sqrt(maxf(0.,.87*.87-x*x))
		_box(Vector3(x,height/2.,7.78),Vector3(.15,height,.11),"wood")
	for side in [-1,1]:_box(Vector3(side*.91,1.04,7.68),Vector3(.18,2.1,.19),"wood")
	for step in 28:
		var a=float(step)*PI/28.;var b=float(step+1)*PI/28.
		_beam(Vector3(cos(a)*.91,2.05+sin(a)*.91,7.68),Vector3(cos(b)*.91,2.05+sin(b)*.91,7.68),.18,"wood")
	for y in [.40,1.35,2.0]:_box(Vector3(0,y,7.69),Vector3(1.64,.085,.06),"iron")
	var handle=MeshInstance3D.new();var ring=TorusMesh.new();ring.inner_radius=.052;ring.outer_radius=.075;ring.rings=24;ring.ring_segments=8;handle.mesh=ring;_merge(handle.mesh,Vector3(-.47,1.17,7.63),Basis(Vector3.RIGHT,PI/2),"brass");handle.free()
	for side in [-1,1]:
		_box(Vector3(side*2.15,2.58,7.72),Vector3(1.,1.95,.035),"crest")
		_box(Vector3(side*2.15,3.62,7.64),Vector3(1.22,.055,.055),"brass")
	var sign=Hearth20DiceNumeral.new();sign.setup("THE GILDED TABLE",.15,3.3,Color("#c4a66d"),.02);sign.rotation.y=PI;sign.position=Vector3(0,3.7,7.69);add_child(sign)
func _rear_furniture() -> void:
	for side in [-1,1]:
		var x=side*4.7
		_window(x,3.0,7.76)
		_box(Vector3(x,.69,7.1),Vector3(3.0,.16,.78),"wood")
		_box(Vector3(x,.81,7.08),Vector3(2.85,.13,.70),"velvet")
		_box(Vector3(x,1.24,7.49),Vector3(3.0,.85,.12),"wood")
		for dx in [-1.25,1.25]:_box(Vector3(x+dx,.33,7.1),Vector3(.17,.66,.55),"wood")
		_lathe(Vector3(x,0,5.65),[[0.,0],[.50,0],[.53,.08],[.16,.16],[.12,.74],[.68,.80],[.72,.87],[0.,.87]],1.,1.,"wood",32)
		_lathe(Vector3(x,.87,5.65),[[.70,0],[0.,0]],1.,1.,"velvet",32)
		for offset in [Vector3(0,0,-1.1),Vector3(.98,0,0)]:_lathe(Vector3(x,0,5.65)+offset,[[0.,0],[.28,0],[.24,.10],[.18,.43],[.33,.48],[0.,.50]],1.,1.,"wood",20)
	for side in [-1,1]:
		var x=side*6.9
		_box(Vector3(x,1.13,7.42),Vector3(1.2,2.26,.08),"wood")
		for dx in [-.61,.61]:_box(Vector3(x+dx,1.13,7.17),Vector3(.10,2.26,.60),"wood")
		for shelf in [0.,.72,1.44,2.16]:
			_box(Vector3(x,shelf+.06,6.94),Vector3(1.28,.10,.65),"wood")
		for shelf in 3:
			for bottle in 6:
				var height=.34+.15*fposmod(sin(float(bottle*13+shelf*41))*117.,1.);var at=Vector3(x+(bottle-2.5)*.18,.12+shelf*.72,6.96)
				_lathe(at,[[0.,0],[.060,0],[.065,.04],[.059,height*.7],[.025,height*.82],[.024,height],[0.,height]],1.,1.,["amber","green","wine"][(bottle+shelf)%3],12)
func _sideboards() -> void:
	for side in [-1,1]:
		for z in [-.4,3.1]:
			_box(Vector3(side*7.75,2.57,z),Vector3(.035,1.95,1.05),"crest")
			_box(Vector3(side*7.67,3.61,z),Vector3(.055,.055,1.22),"brass")
		_box(Vector3(side*7.6,.42,2.7),Vector3(.46,.82,2.6),"wood")
		_box(Vector3(side*7.45,.90,2.7),Vector3(.70,.12,2.76),"wood")
		for z in [1.83,2.7,3.57]:
			_box(Vector3(side*7.35,.43,z),Vector3(.025,.68,.035),"brass")
			_lathe(Vector3(side*7.25,.97,z),[[0.,0],[.065,0],[.07,.03],[.06,.24],[.025,.29],[.024,.37],[0.,.37]],1.,1.,"green",16)
		_lathe(Vector3(side*7.25,.97,2.24),[[0.,0],[.12,0],[.14,.05],[.17,.12],[.18,.17],[.14,.17],[0.,.07]],1.,1.,"brass",24)
func _window(x: float,y: float,z: float) -> void:
	_box(Vector3(x,y,z),Vector3(2.1,1.85,.05),"glass")
	for dx in [-1.1,1.1]:_box(Vector3(x+dx,y,z-.06),Vector3(.14,2.04,.14),"wood")
	for dy in [-1.,1.]:_box(Vector3(x,y+dy,z-.06),Vector3(2.34,.14,.14),"wood")
	for dx in [-.7,0.,.7]:_box(Vector3(x+dx,y,z-.10),Vector3(.025,1.85,.025),"iron")
	for dy in [-.46,0.,.46]:_box(Vector3(x,y+dy,z-.10),Vector3(2.1,.025,.025),"iron")
func _front_furniture() -> void:
	# A paneled serving counter and a deep, open-backed bottle cabinet.
	_box(Vector3(0,.54,-5.2),Vector3(5.2,1.08,.72),"wood")
	var top=table._bevel(Vector3(5.55,.16,1.05),.10,materials.wood);_merge(top.mesh,Vector3(0,1.16,-5.2),Basis.IDENTITY,"wood");top.free()
	for x in [-1.7,0.,1.7]:
		_box(Vector3(x,.57,-4.824),Vector3(1.38,.76,.025),"crest")
		_lathe(Vector3(x,0.,-3.98),[[0.,0.],[.30,0.],[.27,.09],[.16,.50],[.34,.64],[.35,.70],[0.,.70]],1.,1.,"wood",24)
		_lathe(Vector3(x,.70,-3.98),[[.33,0.],[.33,.035],[0.,.035]],1.,1.,"velvet",24)
	_beam(Vector3(-2.5,.26,-4.67),Vector3(2.5,.26,-4.67),.045,"brass")
	for x in [-2.45,0.,2.45]:_beam(Vector3(x,.26,-4.82),Vector3(x,.26,-4.65),.04,"brass")
	_box(Vector3(0,2.63,-6.80),Vector3(4.9,3.05,.10),"wood")
	for x in [-2.51,-.84,.84,2.51]:_box(Vector3(x,2.63,-6.59),Vector3(.13,3.14,.56),"wood")
	for y in [1.20,2.12,3.04,3.96]:_box(Vector3(0,y,-6.54),Vector3(5.16,.13,.66),"wood")
	for shelf in 3:
		for bottle in 16:
			var height=.31+.22*fposmod(sin(float(bottle*19+shelf*53))*317.3,1.)
			_lathe(Vector3((bottle-7.5)*.285,1.28+shelf*.92,-6.43),[[0.,0.],[.070,0.],[.073,.035],[.065,height*.66],[.027,height*.80],[.025,height],[0.,height]],1.,1.,["green","amber","wine"][(bottle+shelf)%3],14)
	for x in [-2.,-.5,1.2]:_lathe(Vector3(x,1.25,-5.15),[[0.,0.],[.075,0.],[.078,.025],[.065,.20],[.07,.23],[0.,.23]],1.,1.,"brass",18)
	var sign=Hearth20DiceNumeral.new();sign.setup("HEARTH20",.18,2.3,Color("#c4a66d"),.025);sign.position=Vector3(0,4.28,-6.63);add_child(sign)
	_fireplace()
	for x in [4.12,6.25]:_arched_window(x,-6.70)
	var moon=OmniLight3D.new();moon.position=Vector3(5.25,2.3,-5.85);moon.light_color=Color("#b4c9d4");moon.light_energy=.5;moon.omni_range=4.8;moon.shadow_enabled=false;add_child(moon)
func _arched_window(x: float,z: float) -> void:
	var radius=.78;var bottom=.75;var spring=3.05
	for pane in 12:
		var dx=(pane-5.5)*.125;var top=spring+sqrt(maxf(0.,radius*radius-dx*dx))
		_box(Vector3(x+dx,(bottom+top)/2.,z),Vector3(.12,top-bottom,.05),"glass")
	for side in [-1,1]:_box(Vector3(x+side*.84,(bottom+spring)/2.,z+.04),Vector3(.14,spring-bottom+.12,.18),"wood")
	for step in 24:
		var a=float(step)*PI/24.;var b=float(step+1)*PI/24.
		_beam(Vector3(x+cos(a)*.84,spring+sin(a)*.84,z+.04),Vector3(x+cos(b)*.84,spring+sin(b)*.84,z+.04),.14,"wood")
	_box(Vector3(x,bottom-.04,z+.04),Vector3(1.83,.16,.27),"wood")
	for dx in [-.39,0.,.39]:_box(Vector3(x+dx,1.94,z+.07),Vector3(.022,2.31,.022),"iron")
	for y in [1.30,1.87,2.44,3.01]:_box(Vector3(x,y,z+.07),Vector3(1.52,.022,.022),"iron")
func _fireplace() -> void:
	var x=-5.25
	_box(Vector3(x,.13,-6.24),Vector3(2.9,.26,1.48),"stone")
	_box(Vector3(x,1.18,-6.77),Vector3(1.87,2.10,.07),"iron")
	for side in [-1,1]:_box(Vector3(x+side*1.08,1.25,-6.30),Vector3(.43,2.35,1.),"stone")
	_box(Vector3(x,2.35,-6.30),Vector3(2.58,.36,1.02),"stone")
	_box(Vector3(x,2.58,-6.20),Vector3(2.90,.16,1.25),"wood")
	_box(Vector3(x,3.72,-6.58),Vector3(2.26,2.20,.64),"stone")
	for y in [2.96,3.32,3.68,4.04,4.40]:_box(Vector3(x,y,-6.245),Vector3(2.26,.020,.022),"mortar")
	for offset in [-.36,.36]:
		var log_mesh=CylinderMesh.new();log_mesh.top_radius=.10;log_mesh.bottom_radius=.12;log_mesh.height=1.12;log_mesh.radial_segments=12
		_merge(log_mesh,Vector3(x+offset*.3,.38,-6.20+offset),Basis.from_euler(Vector3(0,offset*.8,PI/2)),"wood")
	for dx in [-.65,-.32,0.,.32,.65]:_box(Vector3(x+dx,.49,-5.87),Vector3(.025,.52,.025),"iron")
	_box(Vector3(x,.67,-5.87),Vector3(1.45,.03,.03),"iron")
	_fire_particles(Vector3(x,.37,-6.20),false);_fire_particles(Vector3(x,.98,-6.32),true)
	var warmth=OmniLight3D.new();warmth.position=Vector3(x,1.05,-5.73);warmth.light_color=Color("#ffad60");warmth.light_energy=2.4;warmth.omni_range=7.;warmth.shadow_enabled=false;add_child(warmth)
func _fire_particles(at: Vector3,smoke: bool) -> void:
	var particles=GPUParticles3D.new();particles.name="HearthSmoke" if smoke else "HearthFlames";particles.position=at;particles.amount=12 if smoke else 32;particles.lifetime=2.4 if smoke else 1.25;particles.preprocess=particles.lifetime;particles.local_coords=true;particles.visibility_aabb=AABB(Vector3(-1,0,-1),Vector3(2,3.5,2));particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;process.emission_box_extents=Vector3(.52,.025,.22);process.direction=Vector3.UP;process.spread=18.;process.gravity=Vector3(0,.16,0);process.initial_velocity_min=.24;process.initial_velocity_max=.65;process.scale_min=.35;process.scale_max=.75
	var gradient=Gradient.new();gradient.offsets=PackedFloat32Array([0.,.15,.65,1.]);gradient.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,.9),Color(1,1,1,.6),Color(1,1,1,0)]);var ramp=GradientTexture1D.new();ramp.gradient=gradient;process.color_ramp=ramp;particles.process_material=process
	var quad=QuadMesh.new();quad.size=Vector2(.70,1.0) if not smoke else Vector2(1.1,1.4)
	var shader=Shader.new();shader.code="""
shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_mix;
uniform bool smoke=false;
void vertex(){
 vec3 size=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*size.x,INV_VIEW_MATRIX[1]*size.y,INV_VIEW_MATRIX[2]*size.z,MODEL_MATRIX[3]);
 VERTEX.x+=sin(TIME*6.+UV.y*9.)*.03*(1.-UV.y);
}
void fragment(){
 vec2 p=(UV-.5)*2.;p.x*=mix(2.5,1.,UV.y);
 float body=pow(max(0.,1.-length(p)),1.5);
 float curl=.75+.25*sin(UV.x*17.+UV.y*21.-TIME*7.);
 if(smoke){ALBEDO=vec3(.18,.16,.14);ALPHA=body*curl*COLOR.a*.15;}
 else{ALBEDO=mix(vec3(1.,.14,.01),vec3(1.,.87,.32),UV.y);EMISSION=ALBEDO*1.9;ALPHA=body*curl*COLOR.a;}
}
""";var material_value=ShaderMaterial.new();material_value.shader=shader;material_value.set_shader_parameter("smoke",smoke);quad.material=material_value;particles.draw_pass_1=quad;add_child(particles);effects.append(particles)
func set_active(active: bool) -> void:
	for effect in effects:
		if is_instance_valid(effect):effect.emitting=active;effect.speed_scale=1. if active else 0.
func _finish_batches() -> void:
	for key in batches:
		batches[key].index()
		if materials[batch_materials[key]] is StandardMaterial3D and materials[batch_materials[key]].normal_enabled:batches[key].generate_tangents()
		var node=MeshInstance3D.new();node.name="Room_"+key.replace(":","_");node.mesh=batches[key].commit();node.material_override=materials[batch_materials[key]];node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
	set_meta("spatial_batches",batches.size());batches.clear();batch_materials.clear()

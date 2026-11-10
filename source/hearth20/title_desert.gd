extends Control
class_name Hearth20TitleDesert
## The title owns this world. Its viewport and animation stop when it leaves.
const CREATURE_PATH="res://hearth20/title_desert/tarrasque.glb"
var viewport: SubViewport
var surface: TextureRect
var world: Node3D
var camera: Camera3D
var creature: Node3D
var animation: AnimationPlayer
var requested=false
var request_finished=false
var load_failed=false
var elapsed=0.0
var request_started_msec=0
var terrain_noise: FastNoiseLite

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vista=TextureRect.new();vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);vista.texture=load("res://hearth20/title_desert/amber-wastes.png");vista.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;vista.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;vista.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(vista)
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.handle_input_locally=false;viewport.size=Vector2i(1280,800);viewport.msaa_3d=Viewport.MSAA_2X;viewport.positional_shadow_atlas_size=2048;add_child(viewport)
	surface=TextureRect.new();surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;surface.stretch_mode=TextureRect.STRETCH_SCALE;surface.texture=viewport.get_texture();surface.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(surface)
	world=Node3D.new();world.name="The Amber Wastes";viewport.add_child(world)
	var environment=WorldEnvironment.new();var settings=Environment.new();var sky=Sky.new();var sky_material=ShaderMaterial.new();sky_material.shader=load("res://hearth20/title_desert/sunset.gdshader");sky.sky_material=sky_material;sky.radiance_size=Sky.RADIANCE_SIZE_128
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(0,0,0,0);settings.background_energy_multiplier=0;settings.sky=sky;settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("#b29d91");settings.ambient_light_energy=.65
	settings.reflected_light_source=Environment.REFLECTION_SOURCE_SKY;settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.environment=settings;world.add_child(environment)
	var sun=DirectionalLight3D.new();sun.name="Low desert sun";sun.rotation_degrees=Vector3(-18,-125,0);sun.light_color=Color("#ffcc88");sun.light_energy=1.65;sun.shadow_enabled=true;sun.directional_shadow_max_distance=100;sun.shadow_blur=2.;world.add_child(sun)
	var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-32,30,0);fill.light_color=Color("#ddc9ae");fill.light_energy=.85;world.add_child(fill)
	_build_land()
	_build_scale_markers()
	_build_dust()
	camera=Camera3D.new();camera.fov=43;camera.near=.2;camera.far=1200;camera.current=true;world.add_child(camera);_camera_pose()
	resized.connect(_resize_scene)
	_resize_scene()

func start_pending() -> void:
	if requested or request_finished:return
	request_started_msec=Time.get_ticks_msec()
	requested=ResourceLoader.load_threaded_request(CREATURE_PATH,"PackedScene",false)==OK
	if not requested:load_failed=true;request_finished=true

func ready_to_show() -> bool:
	return creature!=null or load_failed

func _resize_scene() -> void:
	# The title has a fixed pixel budget even on ultrawide / high-DPI monitors.
	var factor=minf(1.,minf(1600./maxf(1.,size.x),1000./maxf(1.,size.y)))
	viewport.size=Vector2i(maxi(1,int(size.x*factor)),maxi(1,int(size.y*factor)))

func _process(delta: float) -> void:
	if viewport==null:return
	var active=is_visible_in_tree() and get_window().visible and get_window().mode!=Window.MODE_MINIMIZED
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if animation!=null:animation.active=active
	if not active:return
	elapsed+=minf(delta,.1);_camera_pose()
	if requested and not request_finished:
		var status=ResourceLoader.load_threaded_get_status(CREATURE_PATH)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			var packed=ResourceLoader.load_threaded_get(CREATURE_PATH) as PackedScene
			request_finished=true;requested=false
			if packed==null:load_failed=true;return
			creature=packed.instantiate();creature.name="Tarrasque Sentinel";creature.scale=Vector3.ONE*1.6;creature.position=Vector3(12,0,-13);creature.rotation.y=-.06;world.add_child(creature)
			_finish_creature(creature)
		elif status==ResourceLoader.THREAD_LOAD_FAILED:
			request_finished=true;requested=false;load_failed=true

func _camera_pose() -> void:
	if camera==null:return
	camera.position=Vector3(36+sin(elapsed*.055)*.65,8.+sin(elapsed*.08)*.18,55)
	camera.look_at(Vector3(2,10.,-4))

func _finish_creature(node: Node) -> void:
	if node is AnimationPlayer:
		animation=node
		for clip in animation.get_animation_list():
			if clip!="RESET":animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR;animation.play(clip);break
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var original=node.mesh.surface_get_material(index)
			var label=original.resource_name if original!=null else "Ancient Hide"
			var mat=ShaderMaterial.new();mat.shader=load("res://hearth20/title_desert/creature.gdshader");mat.set_shader_parameter("hide_texture",load("res://hearth20/title_desert/ancient-hide.png"))
			var tint=Color(1.,.92,.75);var roughness=.65;var texture_amount=1.;var wetness=0.;var iris=0.;var horn=0.;var edge=Color(0,0,0,0)
			match label:
				"Layered Carapace":tint=Color(.52,.39,.29);roughness=.43
				"Wrinkled Belly":tint=Color(.90,.92,.80);roughness=.8
				"Striated Horn":tint=Color(.38,.32,.22);roughness=.44;texture_amount=0.;horn=1.
				"Claw Keratin":tint=Color(.32,.24,.14);roughness=.34;texture_amount=0.
				"Aged Ivory":tint=Color(.78,.69,.49);roughness=.30;texture_amount=0.;edge=Color(.28,.065,.065,1)
				"Mouth Tissue":tint=Color(.12,.022,.025);roughness=.44;texture_amount=0.;wetness=.25
				"Gum Tissue":tint=Color(.28,.065,.065);roughness=.38;texture_amount=0.;wetness=.35
				"Tongue":tint=Color(.31,.095,.11);roughness=.44;texture_amount=0.;wetness=.22;edge=Color(.12,.022,.025,1)
				"Dark Throat":tint=Color(.024,.006,.009);roughness=.48;texture_amount=0.;wetness=.2;edge=Color(.12,.022,.025,1)
				"Molten Amber":tint=Color(.60,.25,.015);roughness=.16;texture_amount=0.;wetness=1.;iris=1.
				"Obsidian Slit":tint=Color(.006,.003,.001);roughness=.20;texture_amount=0.;wetness=.9
			mat.set_shader_parameter("tint",tint);mat.set_shader_parameter("surface_roughness",roughness);mat.set_shader_parameter("textured",texture_amount);mat.set_shader_parameter("wetness",wetness);mat.set_shader_parameter("iris",iris);mat.set_shader_parameter("horn",horn);mat.set_shader_parameter("anatomy_layer",1.-texture_amount);mat.set_shader_parameter("edge_color",edge);node.set_surface_override_material(index,mat)
	for child in node.get_children():_finish_creature(child)

func _land_material(color: Color) -> ShaderMaterial:
	var material=ShaderMaterial.new();material.shader=load("res://hearth20/title_desert/land.gdshader");material.set_shader_parameter("rock_color",color);material.set_shader_parameter("sand_texture",load("res://hearth20/title_desert/wind-carved-sand.png"));return material

func _ground_height(point: Vector2) -> float:
	var height=terrain_noise.get_noise_2d(point.x,point.y)*1.8-1.25
	return lerpf(height,-.08,1.-smoothstep(6.,23.,point.distance_to(Vector2(12,-13))))

func _build_land() -> void:
	terrain_noise=FastNoiseLite.new();terrain_noise.seed=415;terrain_noise.frequency=.026;terrain_noise.fractal_octaves=4
	var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps=96;var width=440.;var cell=width/steps
	for z in range(steps):
		for x in range(steps):
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var p=Vector2(x+corner.x,z+corner.y)*cell-Vector2(width*.5,width*.76)
				# Keep both feet planted on a broad, believable shelf.
				tool.set_uv(p*.07);tool.add_vertex(Vector3(p.x,_ground_height(p),p.y))
	tool.generate_normals();tool.index()
	var ground=MeshInstance3D.new();ground.name="Wind-carved desert floor";ground.mesh=tool.commit();ground.material_override=_land_material(Color("#74361c"));world.add_child(ground)
	var rng=RandomNumberGenerator.new();rng.seed=718
	for side in [-1,1]:
		for i in range(3):
			var position=Vector3(side*(95+i*18),-2,-80-i*26+rng.randf_range(-10,10))
			_rock_spire(position,Vector3(rng.randf_range(8,17),rng.randf_range(8,32),rng.randf_range(8,15)),rng)
	# Nearby fractured stone repeats one mesh using instancing.
	var stones=MultiMeshInstance3D.new();stones.name="Broken sandstone";var mesh=SphereMesh.new();mesh.radial_segments=7;mesh.rings=3;mesh.height=1.;mesh.radius=.5
	var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=260
	for i in multi.instance_count:
		var position=Vector3(rng.randf_range(-100,100),-.20,rng.randf_range(-80,29));var scale=Vector3(rng.randf_range(.2,2.4),rng.randf_range(.1,.9),rng.randf_range(.2,1.8))
		position.y=_ground_height(Vector2(position.x,position.z))+scale.y*.5
		multi.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(rng.randf(),rng.randf()*TAU,rng.randf())).scaled(scale),position))
	stones.multimesh=multi;stones.material_override=_land_material(Color("#68351e"));world.add_child(stones)

func _rock_spire(position: Vector3,dimensions: Vector3,rng: RandomNumberGenerator) -> void:
	var vertices=[];var sides=17;var rings=13
	var ridges=[]
	for side in range(sides):ridges.append(rng.randf_range(.75,1.18))
	for ring in range(rings):
		var t=float(ring)/(rings-1);var radius=1.25-pow(t,.45)*.92
		var ledge=.04*sin(t*41.)+.025*cos(t*19.)
		for side in range(sides):
			var angle=float(side)/sides*TAU
			var erosion=radius*ridges[side]+ledge
			vertices.append(Vector3(cos(angle)*dimensions.x*erosion+t*dimensions.x*.13,t*dimensions.y+rng.randf_range(-.25,.25),sin(angle)*dimensions.z*erosion))
	var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(rings-1):
		for side in range(sides):
			var a=ring*sides+side;var b=ring*sides+(side+1)%sides
			for index in [a,a+sides,b,b,a+sides,b+sides]:tool.add_vertex(vertices[index])
	for side in range(1,sides-1):
		for index in [(rings-1)*sides,(rings-1)*sides+side+1,(rings-1)*sides+side]:tool.add_vertex(vertices[index])
	tool.generate_normals()
	var rock=MeshInstance3D.new();rock.mesh=tool.commit();rock.position=position;rock.material_override=_land_material(Color("#6e301b"));world.add_child(rock)

func _build_dust() -> void:
	var rng=RandomNumberGenerator.new();rng.seed=908
	var particles=MultiMeshInstance3D.new();particles.name="Saharan wind sheets"
	var quad=QuadMesh.new();quad.size=Vector2(38,3)
	var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true;multi.mesh=quad;multi.instance_count=34
	for i in multi.instance_count:
		var scale=Vector3(rng.randf_range(.8,2.5),rng.randf_range(.5,1.8),1)
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(scale),Vector3(rng.randf_range(-35,35),rng.randf_range(.5,3.5),rng.randf_range(-140,18))))
		multi.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),1))
	particles.multimesh=multi
	var mat=ShaderMaterial.new();mat.shader=load("res://hearth20/title_desert/dust.gdshader");particles.material_override=mat;particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;particles.custom_aabb=AABB(Vector3(-220,-5,-170),Vector3(440,30,240));world.add_child(particles)

func _build_scale_markers() -> void:
	var stone=StandardMaterial3D.new();stone.albedo_color=Color("#4c2c1c");stone.roughness=.95
	# A shattered human-scale gate on the same ground plane as the feet.
	for side in [-1,1]:
		var pillar=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(.8,4.4,.9);pillar.mesh=box;pillar.position=Vector3(-5+side*1.4,1.85,10);pillar.material_override=stone;pillar.rotation.z=side*.08;world.add_child(pillar)
	var lintel=MeshInstance3D.new();var top=BoxMesh.new();top.size=Vector3(3.6,.65,1.1);lintel.mesh=top;lintel.position=Vector3(-5,4.1,10);lintel.rotation.z=.05;lintel.material_override=stone;world.add_child(lintel)
	for i in range(3):
		var traveler=Node3D.new();traveler.name="Distant traveler";traveler.position=Vector3(-5+i*1.25,0,6+i*.6);traveler.position.y=_ground_height(Vector2(traveler.position.x,traveler.position.z));world.add_child(traveler)
		var cloak=MeshInstance3D.new();var shape=CylinderMesh.new();shape.top_radius=.12;shape.bottom_radius=.36;shape.height=1.35;shape.radial_segments=7;cloak.mesh=shape;cloak.position.y=.85;cloak.material_override=stone;traveler.add_child(cloak)
		var head=MeshInstance3D.new();var hood=SphereMesh.new();hood.radius=.18;hood.height=.36;hood.radial_segments=8;hood.rings=4;head.mesh=hood;head.position.y=1.65;head.material_override=stone;traveler.add_child(head)

func _exit_tree() -> void:
	if requested and not request_finished:
		var unused=ResourceLoader.load_threaded_get(CREATURE_PATH);unused=null

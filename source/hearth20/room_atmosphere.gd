extends Node3D
class_name Hearth20RoomAtmosphere
## Localized participating media for the existing Compatibility renderer.
## Static triangle geometry supplies a one-shot sunlight depth field; the main
## depth buffer clips the view integral against moving foreground geometry.
const DIRECTION=Vector3(-.797248,-.531499,.286192)
var room: Hearth20TavernRoom
var openings=[]
var shadow_view: SubViewport
var volume: MeshInstance3D
var medium: ShaderMaterial
var quality=-1
var running=true
var environment_id="fey_forest"
func setup(owner_room: Hearth20TavernRoom,apertures: Array) -> void:
	room=owner_room;openings=apertures
	var sunlight=DirectionalLight3D.new();sunlight.name="WindowSunlight";add_child(sunlight)
	sunlight.look_at_from_position(Vector3(0,3,0)-DIRECTION*15.,Vector3(0,3,0))
	sunlight.light_color=Color("#ffdda8");sunlight.light_energy=1.7;sunlight.shadow_enabled=true
	sunlight.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;sunlight.directional_shadow_max_distance=28.
	sunlight.shadow_bias=.025;sunlight.shadow_normal_bias=.7;sunlight.light_angular_distance=1.2
	set_meta("sun_direction",DIRECTION)

func finish() -> void:
	if volume!=null:return
	# Independent static depth rendering: resources are shared, not reloaded.
	shadow_view=SubViewport.new();shadow_view.name="StaticSunOcclusion";shadow_view.own_world_3d=true;shadow_view.size=Vector2i(1024,1024);shadow_view.msaa_3d=Viewport.MSAA_DISABLED;shadow_view.render_target_update_mode=SubViewport.UPDATE_ONCE;shadow_view.handle_input_locally=false;add_child(shadow_view)
	var world=Node3D.new();shadow_view.add_child(world)
	var env_node=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color.WHITE;env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env_node.environment=env;world.add_child(env_node)
	var shadow_camera=Camera3D.new();shadow_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;shadow_camera.size=27.;shadow_camera.near=.1;shadow_camera.far=48.;shadow_camera.current=true;world.add_child(shadow_camera)
	shadow_camera.look_at_from_position(Vector3(0,2.5,0)-DIRECTION*24.,Vector3(0,2.5,0))
	var depth=ShaderMaterial.new();depth.shader=load("res://hearth20/room_craft/sun_depth.gdshader")
	var roots=[room]
	if room.table.world.has_node("Generated_table"):roots.append(room.table.world.get_node("Generated_table"))
	var count=0
	for origin in roots:
		for source in origin.find_children("*","MeshInstance3D",true,false):
			if source.mesh==null or source.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:continue
			var copy=MeshInstance3D.new();copy.mesh=source.mesh;copy.transform=source.global_transform;copy.material_override=depth;world.add_child(copy);count+=1
	# A camera-attached full-screen integral has no view-dependent cone edges.
	medium=ShaderMaterial.new();medium.shader=load("res://hearth20/room_craft/scattering.gdshader")
	medium.set_shader_parameter("sun_depth",shadow_view.get_texture())
	medium.set_shader_parameter("sun_view",shadow_camera.global_transform.affine_inverse())
	medium.set_shader_parameter("sun_projection",shadow_camera.get_camera_projection())
	medium.set_shader_parameter("sun_direction",DIRECTION)
	var centers=PackedVector4Array();var dimensions=PackedVector2Array();var normals=PackedVector3Array();var lower=PackedVector3Array();var upper=PackedVector3Array()
	for op in openings:
		var n: Vector3=op.normal
		# Only windows facing this sun receive shafts. Other windows retain sky fill.
		if n.dot(DIRECTION)<.01:continue
		centers.append(Vector4(op.center.x,op.center.y,op.center.z,0));normals.append(n);dimensions.append(Vector2(op.width,op.height))
		var horizontal=Vector3.BACK if absf(n.x)>.5 else Vector3.RIGHT
		var box=AABB(op.center,Vector3.ZERO)
		for sx in [-1,1]:
			for sy in [-1,1]:
				var p: Vector3=op.center+horizontal*float(op.width)*.5*sx+Vector3.UP*float(op.height)*.5*sy
				box=box.expand(p);box=box.expand(p+DIRECTION*maxf(0.,p.y/-DIRECTION.y))
		lower.append(box.position-Vector3.ONE*.015);upper.append(box.end+Vector3.ONE*.015)
	medium.set_shader_parameter("portal_count",centers.size());medium.set_shader_parameter("portal_centers",centers);medium.set_shader_parameter("portal_dimensions",dimensions);medium.set_shader_parameter("portal_normals",normals)
	medium.set_shader_parameter("beam_lower",lower);medium.set_shader_parameter("beam_upper",upper)
	volume=MeshInstance3D.new();volume.name="DepthClippedWindowScattering";var quad=QuadMesh.new();quad.size=Vector2(2,2);volume.mesh=quad;volume.material_override=medium;volume.extra_cull_margin=16384;volume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;room.table.camera.add_child(volume)
	set_meta("shadow_mesh_instances",count);set_meta("real_triangle_occlusion",true);set_meta("raymarched",true)
	_apply_quality()
	set_environment(environment_id)
	_freeze_shadow()

func _freeze_shadow() -> void:
	await RenderingServer.frame_post_draw
	if is_instance_valid(shadow_view):shadow_view.render_target_update_mode=SubViewport.UPDATE_DISABLED

func _process(_delta: float) -> void:
	var data=Hearth20Preferences.values if Hearth20Preferences.preview_values.is_empty() else Hearth20Preferences.preview_values
	if int(data.quality)!=quality:_apply_quality()
func _apply_quality() -> void:
	var data=Hearth20Preferences.values if Hearth20Preferences.preview_values.is_empty() else Hearth20Preferences.preview_values
	quality=int(data.quality)
	if medium!=null:medium.set_shader_parameter("steps",56 if quality==2 else 48)
	if volume!=null:volume.visible=running and quality>0
func set_environment(id: String) -> void:
	environment_id=Hearth20RoomWorlds.clean(id)
	var preset=Hearth20RoomWorlds.PRESETS[environment_id]
	var light=get_node_or_null("WindowSunlight")
	if light!=null:light.light_energy=preset.sun;light.light_color=preset.color
	if medium!=null:medium.set_shader_parameter("environment_strength",preset.scatter)
func set_active(active: bool) -> void:
	running=active;_apply_quality();set_process(active)
func _exit_tree() -> void:
	if is_instance_valid(volume):volume.queue_free()

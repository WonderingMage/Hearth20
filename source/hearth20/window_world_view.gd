extends Node3D
class_name Hearth20WindowWorldView
## One selected exterior. Serial loading coalesces rapid switches to the latest.
const SplatNode=preload("res://hearth20/window_splat_node.gd")
const STORYBOOK_YAW=3.77
const EXTERIOR_REFERENCE_EYE=Vector3(0,1.96,2.45)
var room: Node3D
var material_value: ShaderMaterial
var detail_material: ShaderMaterial
var detail_panes: Array[MeshInstance3D]=[]
var exterior_transform=Transform3D.IDENTITY
var current_id=""
var desired_id="fey_forest"
var loading=false
var active=true
var active_splat: Node3D
var content_kind="panorama"
var load_error=""
var failed_id=""
var failed_lod=""
var stage=""
var pending_path=""
var target_id=""
var target_lod=""
var began_msec=0
var staged_texture: Resource
var staged_resource: Resource
var panes=[]
var window_glows=[]
var load_generation=0
var current_lod=""
var loading_msec=0
var install_msec=0
func desired_lod() -> String:
	var preferences=Hearth20Preferences.values if Hearth20Preferences.preview_values.is_empty() else Hearth20Preferences.preview_values
	return "low" if int(preferences.quality)==0 else "balanced"
func setup(owner_room: Node3D) -> void:
	set_process(false)
	room=owner_room
	material_value=ShaderMaterial.new();material_value.shader=load(Hearth20RoomWorlds.ROOT+"window_view.gdshader")
	material_value.render_priority=-100
	panes=room.find_children("RecessedSkyPane*","MeshInstance3D",true,false)
	# Godot gives repeated node names internal names; identify the original pane
	# material as well, so every opening shares this directional environment.
	for node in room.get_children():
		if node is MeshInstance3D and node.material_override!=null and node.material_override.resource_path=="res://hearth20/room_craft/window_sky.tres" and node not in panes:panes.append(node)
	for pane in panes:pane.material_override=material_value
	if room.get_meta("storybook_room",false):
		# The new windows face the opposite wall. Align the prepared world and its detail layer.
		var turn := Basis(Vector3.UP,STORYBOOK_YAW)
		exterior_transform=Transform3D(turn,EXTERIOR_REFERENCE_EYE-turn*EXTERIOR_REFERENCE_EYE)
		material_value.set_shader_parameter("panorama_yaw",STORYBOOK_YAW)
		detail_material=material_value.duplicate() as ShaderMaterial
		detail_material.render_priority=10
		detail_material.set_shader_parameter("opacity",.46)
		for pane in panes:
			var detail := MeshInstance3D.new()
			detail.name="ExteriorDetail"
			detail.mesh=pane.mesh
			detail.material_override=detail_material
			detail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			detail.hide()
			pane.add_child(detail)
			detail_panes.append(detail)
	for aperture in room.get_meta("window_apertures",[]):
		if aperture.has("arch_rise"):
			var spill := SpotLight3D.new()
			spill.name="ExteriorWindowSpill"
			spill.position=aperture.center+aperture.normal*.24
			spill.spot_range=5.0
			spill.spot_angle=55.
			spill.spot_attenuation=1.12
			spill.light_specular=.16
			spill.shadow_enabled=true
			spill.light_energy=0.
			spill.hide()
			room.add_child(spill)
			spill.look_at(spill.global_position+aperture.normal+Vector3.DOWN*.35)
			window_glows.append(spill)
		else:
			var light=OmniLight3D.new();light.name="ExteriorWindowBounce";light.position=aperture.center+aperture.normal*.65;light.omni_range=4.0;light.shadow_enabled=false;light.light_energy=0.;room.add_child(light);window_glows.append(light)
	request("fey_forest")
func request(id: String) -> void:
	id=Hearth20RoomWorlds.clean(id)
	if id!=desired_id:failed_id=""
	desired_id=id
	if id==failed_id and failed_lod==desired_lod():return
	if id==current_id and current_lod==desired_lod() and not loading:return
	if not loading:_begin_load()
func _begin_load() -> void:
	if desired_id==current_id and current_lod==desired_lod():
		loading=false;stage="";staged_texture=null;staged_resource=null;set_process(false);return
	loading=true;load_error="";target_id=desired_id;target_lod=desired_lod();began_msec=Time.get_ticks_msec();load_generation+=1
	staged_texture=null;staged_resource=null;stage="texture";set_process(true)
	_request_resource(Hearth20RoomWorlds.ROOT+target_id+"/panorama.png","Texture2D")
func _start_resource(path: String,type: String) -> Error:
	# Exported textures are remapped to imported resources inside the pack.
	if not ResourceLoader.exists(path,type):return ERR_FILE_NOT_FOUND
	return ResourceLoader.load_threaded_request(path,type)
func _request_resource(path: String,type: String) -> void:
	pending_path=path
	var error=_start_resource(path,type)
	if error not in [OK,ERR_BUSY]:pending_path="";_take_resource(null)
func _process(_delta: float) -> void:
	if not loading:return
	if stage=="install":
		if target_id!=desired_id or target_lod!=desired_lod():_begin_load()
		elif active:_install()
		return
	if pending_path.is_empty():return
	var status=ResourceLoader.load_threaded_get_status(pending_path)
	if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:return
	var resource=ResourceLoader.load_threaded_get(pending_path) if status==ResourceLoader.THREAD_LOAD_LOADED else null
	pending_path="";_take_resource(resource)
func _take_resource(resource: Resource) -> void:
	if target_id!=desired_id or target_lod!=desired_lod():_begin_load();return
	if stage=="texture":
		staged_texture=resource;stage="gaussian"
		_request_resource(Hearth20RoomWorlds.ROOT+target_id+("/gaussian-low.res" if target_lod=="low" else "/gaussian.res"),"Resource")
	else:
		staged_resource=resource;stage="install"
		if active:_install()
func _install() -> void:
	if staged_texture==null and staged_resource==null:
		load_error="Environment artwork is unavailable; keeping the last valid view.";failed_id=target_id;failed_lod=target_lod
	else:
		var install_began=Time.get_ticks_msec()
		if is_instance_valid(active_splat):remove_child(active_splat);active_splat.queue_free();active_splat=null
		if staged_texture is Texture2D:material_value.set_shader_parameter("panorama",staged_texture);material_value.set_shader_parameter("has_panorama",true)
		else:material_value.set_shader_parameter("has_panorama",false)
		content_kind="panorama"
		if staged_resource is GaussianResource and _valid_splat(staged_resource):
			active_splat=SplatNode.new();active_splat.name="ActiveWindowSplat";active_splat.gaussian=staged_resource;active_splat.relight_enabled=false;active_splat.relight_cast_shadows=false;active_splat.clip_to_windows=true;active_splat.apertures=room.get_meta("window_apertures",[])
			active_splat.transform=exterior_transform
			add_child(active_splat);active_splat.visible=active;content_kind="gaussian"
		elif staged_resource!=null:load_error="Prepared splat is invalid; using its panorama preview."
		if detail_material!=null:
			var has_detail: bool = staged_texture is Texture2D and content_kind=="gaussian"
			if has_detail:
				detail_material.set_shader_parameter("panorama",staged_texture)
				detail_material.set_shader_parameter("has_panorama",true)
			for detail in detail_panes:detail.visible=has_detail
		current_id=target_id;current_lod=target_lod;_lighting(target_id)
		install_msec=Time.get_ticks_msec()-install_began;loading_msec=Time.get_ticks_msec()-began_msec
	staged_texture=null;staged_resource=null;loading=false;stage="";set_process(false)
func _exit_tree() -> void:
	# Drain the single outstanding local read during teardown. No suspended
	# SceneTree-frame coroutine can retain a texture after its owning room dies.
	if not pending_path.is_empty() and ResourceLoader.load_threaded_get_status(pending_path) in [ResourceLoader.THREAD_LOAD_IN_PROGRESS,ResourceLoader.THREAD_LOAD_LOADED]:ResourceLoader.load_threaded_get(pending_path)
	pending_path="";staged_texture=null;staged_resource=null
static func _valid_splat(resource: GaussianResource) -> bool:
	return resource.point_count>0 and resource.point_count<=250000 and resource.xyz.size()==resource.point_count and resource.point_data_byte.size()==resource.point_count*240 and resource.aabb.size.is_finite() and resource.aabb.position.is_finite()
func _lighting(id: String) -> void:
	var preset=Hearth20RoomWorlds.PRESETS[id]
	material_value.set_shader_parameter("fallback",Vector3(preset.color.r,preset.color.g,preset.color.b)*.45)
	for light in window_glows:
		light.light_color=preset.color
		light.light_energy=preset.glow
		light.visible=preset.glow>0.
	var atmosphere=room.get_node_or_null("WindowAtmosphere")
	if atmosphere!=null:atmosphere.set_environment(id)
func set_active(value: bool) -> void:
	active=value
	if is_instance_valid(active_splat):active_splat.visible=value

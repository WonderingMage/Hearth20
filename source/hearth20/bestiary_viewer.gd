extends Control
class_name Hearth20BestiaryViewer
signal model_ready(id: String)
var viewport: SubViewport
var scene_surface: SubViewportContainer
var world: Node3D
var pivot: Node3D
var camera: Camera3D
var model: Node3D
var video: VideoStreamPlayer
var video_mode:=false
var video_paused:=false
var video_muted:=false
var video_volume:=.8
var model_id:=""
var pending_path:=""
var yaw:=-.35
var pitch:=.05
var lift:=0.0
var distance:=5.9
var dragging:=false
var lifting:=false
var still:=0.0
var load_failed:=false
var defer_loading:=false
var request_active:=false
var retiring_path:=""
var request_started_msec:=0
var fit_frames:=0
func _ready() -> void:
	custom_minimum_size=Vector2(320,320); mouse_filter=Control.MOUSE_FILTER_STOP; focus_mode=Control.FOCUS_ALL
	tooltip_text="Left drag: rotate · Right drag: lift · Wheel: zoom · Arrows: rotate/lift · Home: reset"
	scene_surface=SubViewportContainer.new(); scene_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scene_surface.stretch=true; scene_surface.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(scene_surface)
	viewport=SubViewport.new(); viewport.size=Vector2i(600,600); viewport.transparent_bg=true; viewport.own_world_3d=true; viewport.handle_input_locally=false
	viewport.positional_shadow_atlas_size=2048; viewport.msaa_3d=Viewport.MSAA_4X; scene_surface.add_child(viewport)
	world=Node3D.new(); viewport.add_child(world)
	pivot=Node3D.new(); world.add_child(pivot)
	camera=Camera3D.new(); camera.fov=38; camera.current=true; world.add_child(camera)
	var environment:=WorldEnvironment.new(); var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR; settings.background_color=Color(0,0,0,0); settings.background_energy_multiplier=0
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; settings.ambient_light_color=Color("#c2c9dc"); settings.ambient_light_energy=.25
	settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.environment=settings; world.add_child(environment)
	for spec in [[Vector3(-34,-34,0),Color("#ffe9c7"),.95,true],[Vector3(-12,146,0),Color("#879dc9"),.80,false],[Vector3(12,30,0),Color("#ddcbb6"),.20,false]]:
		var light:=DirectionalLight3D.new(); light.rotation_degrees=spec[0]; light.light_color=spec[1]; light.light_energy=spec[2]; light.shadow_enabled=spec[3]; world.add_child(light)
	_update_camera()
	video=VideoStreamPlayer.new(); video.bus="Creature Showcase"; video.expand=true; video.loop=true; video.volume=video_volume; video.hide(); video.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(video)
func choose(id: String) -> void:
	var path:=Hearth20BestiaryCatalog.model_path(id)
	if path.is_empty(): return
	if path==pending_path: return
	if request_active: retiring_path=pending_path
	request_active=false
	model_id=id; pending_path=path; load_failed=false
	if model!=null: model.queue_free(); model=null
	video.stop(); video.stream=null; video.hide(); video_paused=false
	video_mode=path.get_extension()=="ogv"
	scene_surface.visible=not video_mode
	tooltip_text="Looping video with sound. Use the playback controls below." if video_mode else "Left drag: rotate · Right drag: lift · Wheel: zoom · Arrows: rotate/lift · Home: reset"
	reset_view()
	if not defer_loading and retiring_path.is_empty(): _start_request()
func start_pending() -> void:
	defer_loading=false
	if not request_active and not pending_path.is_empty() and retiring_path.is_empty(): _start_request()
func _start_request() -> void:
	request_started_msec=Time.get_ticks_msec()
	if ResourceLoader.load_threaded_request(pending_path,"VideoStream" if video_mode else "PackedScene",false)!=OK: load_failed=true; pending_path=""
	else: request_active=true
func reset_view() -> void:
	yaw=-.35; pitch=.05; lift=0; distance=5.9; still=0
	if video_mode and video!=null and video.stream!=null: video.stop(); video.play(); video_paused=false
func ready_to_show() -> bool:
	return video.stream!=null if video_mode else (model!=null and fit_frames==0)
func toggle_playback() -> void:
	video_paused=not video_paused; video.paused=video_paused
func toggle_mute() -> void:
	video_muted=not video_muted; _video_gain()
func set_video_volume(value: float) -> void:
	video_volume=clampf(value,0,1); _video_gain()
func _video_gain() -> void:
	video.volume=0 if video_muted else video_volume
func _bounds(node: Node3D, transform: Transform3D=Transform3D.IDENTITY) -> AABB:
	var combined:=transform*node.transform
	var result:=AABB(); var found:=false
	if node is MeshInstance3D and node.mesh!=null:
		var geometry: Mesh=node.mesh
		if node.skin!=null and node.get_skin_reference()!=null: geometry=node.bake_mesh_from_current_skeleton_pose()
		result=combined*geometry.get_aabb(); found=true
	for child in node.get_children():
		if child is Node3D:
			var box:=_bounds(child,combined)
			if box.size.length_squared()>.000001: result=result.merge(box) if found else box; found=true
	return result
func _process(delta: float) -> void:
	if viewport==null: return
	if not is_visible_in_tree(): viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; video.paused=true; return
	video.paused=video_paused
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED if video_mode else SubViewport.UPDATE_ALWAYS
	var dimensions:=Vector2(size.x,minf(size.y,size.x*9.0/16.0))
	dimensions.x=dimensions.y*16.0/9.0
	video.position=(size-dimensions)*.5; video.size=dimensions
	if not retiring_path.is_empty():
		var retired_status:=ResourceLoader.load_threaded_get_status(retiring_path)
		if retired_status in [ResourceLoader.THREAD_LOAD_LOADED,ResourceLoader.THREAD_LOAD_FAILED]:
			var retired: Resource=ResourceLoader.load_threaded_get(retiring_path); retired=null; retiring_path=""
	if not request_active and not pending_path.is_empty() and not defer_loading and retiring_path.is_empty(): _start_request()
	if request_active:
		var status:=ResourceLoader.load_threaded_get_status(pending_path)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			var resource: Resource=ResourceLoader.load_threaded_get(pending_path); pending_path=""; request_active=false
			if video_mode:
				video.stream=resource; video.show(); _video_gain(); video.play()
			else:
				# Keep the imported root transform intact; normalize its wrapper.
				model=Node3D.new(); model.add_child((resource as PackedScene).instantiate()); pivot.add_child(model); model.hide(); fit_frames=3
			if video_mode: model_ready.emit(model_id)
		elif status==ResourceLoader.THREAD_LOAD_FAILED: pending_path=""; request_active=false; load_failed=true
	if model!=null and fit_frames>0:
		fit_frames-=1
		if fit_frames==0:
			var box:=_bounds(model)
			var scale_factor:=3.2/maxf(.001,maxf(maxf(box.size.x,box.size.y),box.size.z))
			model.scale=Vector3.ONE*scale_factor; model.position=-box.get_center()*scale_factor; model.show(); model_ready.emit(model_id)
	still+=delta
	if not dragging and not lifting and still>3: yaw+=delta*.07
	pivot.rotation=Vector3(pitch,yaw,0); pivot.position.y=lift
	_update_camera(); queue_redraw()
func _update_camera() -> void:
	if camera==null: return
	camera.position=Vector3(0,.20,distance); camera.look_at(Vector3.ZERO,Vector3.UP)
func _gui_input(event: InputEvent) -> void:
	if video_mode: return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed; grab_focus(); accept_event()
		elif event.button_index==MOUSE_BUTTON_RIGHT: lifting=event.pressed; grab_focus(); accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			distance=clampf(distance+(-.3 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .3),3.7,9); accept_event()
		still=0
	elif event is InputEventMouseMotion and (dragging or lifting):
		if dragging: yaw+=event.relative.x*.009; pitch=clampf(pitch+event.relative.y*.005,-.40,.40)
		if lifting: lift=clampf(lift-event.relative.y*.005,-.45,.45)
		still=0; accept_event()
	elif event is InputEventKey and event.pressed:
		if event.keycode==KEY_HOME: reset_view(); accept_event()
		elif event.keycode in [KEY_LEFT,KEY_RIGHT]: yaw+=-.12 if event.keycode==KEY_LEFT else .12; still=0; accept_event()
		elif event.keycode in [KEY_UP,KEY_DOWN]: lift=clampf(lift+(.04 if event.keycode==KEY_UP else -.04),-.45,.45); still=0; accept_event()
func _draw() -> void:
	if not pending_path.is_empty():
		var clock:=float(Time.get_ticks_msec())*.003
		draw_arc(size*.5,20,clock,clock+PI*1.45,32,Hearth20Regal.swatch(Hearth20Regal.GOLD),1.5,true)
func _exit_tree() -> void:
	if video!=null: video.stop(); video.stream=null
	# Consume a request even when the user exits during a large model load.
	# Normal navigation never blocks on this; it runs only during teardown.
	if request_active and not pending_path.is_empty():
		var unused: Resource=ResourceLoader.load_threaded_get(pending_path); unused=null
	if not retiring_path.is_empty():
		var unused: Resource=ResourceLoader.load_threaded_get(retiring_path); unused=null

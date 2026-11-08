extends SceneTree
var shell: Hearth20SeatedShell
var output=""
var checks=0
var errors=[]
func _initialize() -> void:output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func until(predicate: Callable,message: String) -> void:
	var deadline=Time.get_ticks_msec()+30000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	expect(predicate.call(),message)
func capture(name_value: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(name_value+".png"))
func pull_mode(mode: String) -> void:
	shell.look_up=true;await create_timer(.7).timeout
	var point=shell.table.camera.unproject_position(shell.pulls.handles[mode].global_position)*shell.size/Vector2(shell.table.viewport.size)
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=point;shell._input(press)
	expect(shell.held_pull==mode,"DM grabs the engraved "+mode+" rod")
	var drag=InputEventMouseMotion.new();drag.position=point+Vector2(0,70);drag.relative=Vector2(0,70);shell._input(drag)
	expect(shell.pull_amount>.14,"dragging the rope past its detent")
	press.pressed=false;press.position=drag.position;shell._input(press)
	expect(shell.desired_mode()==mode,"releasing the rope selects "+mode)
func run() -> void:
	root.size=Vector2i(1600,1000);shell=Hearth20SeatedShell.new();root.add_child(shell)
	await until(func():return shell.ready_to_show,"loads into a seated 3D table")
	var app=shell.app;app._load_sample_map("lantern-larch-inn",false);await create_timer(1).timeout
	expect(shell.focus_state=="table" and shell.home_row.visible,"offline host/join options at table")
	expect(shell.table.camera_override and shell.pulls.handles.size()==2,"one shared table and two physical pulls")
	expect(shell.papyrus.get_node("CurledPapyrusSheet").mesh.get_aabb().size.y>.02,"character sheet is a curled papyrus mesh")
	expect(shell.pulls.handles.map.has_node("TurnedCarpentersGrip"),"turned wooden tool handle replaces rectangular grip")
	await capture("seated-map")
	expect(shell.table.room.get_meta("fully_enclosed",false),"table uses a complete tavern enclosure")
	expect(int(shell.table.room.get_meta("spatial_batches",0))>12 and shell.table.room.get_children().filter(func(n):return n is MeshInstance3D).size()<=110,"room uses bounded spatial batches so unseen bays can be culled")
	await physics_frame
	var space=shell.table.camera.get_world_3d().direct_space_state
	for yaw in range(0,360,15):
		for pitch in [-80.,-55.,-25.,0.,25.,55.,80.]:
			var direction=Vector3(sin(deg_to_rad(yaw))*cos(deg_to_rad(pitch)),sin(deg_to_rad(pitch)),-cos(deg_to_rad(yaw))*cos(deg_to_rad(pitch)))
			var query=PhysicsRayQueryParameters3D.create(shell.table.camera.global_position,shell.table.camera.global_position+direction*64.,Hearth20TavernRoom.BOUNDARY_LAYER)
			expect(not space.intersect_ray(query).is_empty(),"closed room boundary at yaw %d / pitch %.0f"%[yaw,pitch])
	shell.looking=true
	for angle in [90.,180.,-90.]:
		shell.look.x=deg_to_rad(angle);await create_timer(.6).timeout;await capture("room-"+str(int(angle)))
	var motion=InputEventMouseMotion.new();motion.relative=Vector2(-900,0);shell._input(motion)
	expect(absf(shell.look.x)>.7,"head turning passes the old narrow camera limit")
	shell.looking=false;shell.look=Vector2.ZERO;await create_timer(.6).timeout
	shell.look_up=true;await create_timer(.7).timeout;await capture("ceiling-pulls")
	var position=shell.table.camera.unproject_position(shell.pulls.handles.map.global_position)
	expect(shell.pulls.hit(shell.table.camera,position)=="map","map handle can be picked through the 3D camera")
	shell.pulls.pull("casino",.25);expect(shell.pulls.handles.casino.position.y<shell.pulls.rest_y-.2,"wooden pull physically travels down")
	shell.look_up=false;var before=shell.table.get_instance_id();await pull_mode("casino")
	await until(func():return shell.current_mode=="casino" and not shell.switching,"rubbery transition reaches casino")
	expect(shell.table.get_instance_id()==before and app.casino_portal.scene==shell.table,"switch reuses the room instead of retaining a second 3D scene")
	expect(not shell.map_items.visible and shell.map_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"map rendering stops in casino")
	expect(not shell.table.stock_deck.visible and not shell.table.card_surface.visible,"casino menu has no card/deck overlay")
	await capture("seated-casino")
	shell.table.book.open_book();await create_timer(1.1).timeout
	expect(shell.table.camera.position.z<1.7 and not app.casino_portal.hud.visible,"rulebook focuses the camera and keeps menus out of its pages")
	shell.table.book.close_book();await create_timer(.95).timeout
	shell.look_up=true;await create_timer(.6).timeout;await capture("casino-pulls")
	expect(not app.casino_portal.hud.visible,"looking up clears casino UI from the rope controls")
	shell.look_up=false;await pull_mode("map")
	await until(func():return shell.current_mode=="map" and not shell.switching,"battlemap pops back into place")
	expect(is_instance_valid(shell.table) and shell.table.get_instance_id()==before,"shared table survives casino teardown")
	shell.focus_map();await process_frame;expect(shell.focus_surface.visible and not shell.table.visible,"map expands into original interactive controls")
	await capture("focused-map");shell.leave_focus();await process_frame
	app.session.local_role="player";expect(not app.session.set_table_mode("casino").ok,"players cannot switch table modes");app.session.local_role="dm"
	shell.focus_sheet();await create_timer(2).timeout
	expect(shell.focus_state=="sheet" and is_instance_valid(app.beyond_sheet.expanded),"personal sheet focuses independently")
	shell.leave_focus();await create_timer(.3).timeout;expect(shell.focus_state=="table","sheet returns to hand area")
	shell.queue_free();await create_timer(.5).timeout
	FileAccess.open(output.path_join("seated-result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"\t"));print("Seated visuals: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)

extends SceneTree
const Fakes=preload("steam_fakes.gd")
var checks=0
var errors=[]
var shell: Hearth20SeatedShell
var output=""
var save_locked=false
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func settle() -> void:
	for i in 4:await process_frame
func capture(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(label+".png"))
func pointer(point: Vector2,button: int,pressed: bool) -> void:
	point*=shell.focus_surface.size/Vector2(shell.map_viewport.size)
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;motion.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;root.push_input(motion)
	var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button;event.pressed=pressed;root.push_input(event)
func run() -> void:
	output=OS.get_cmdline_user_args()[0];root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
	create_timer(90).timeout.connect(func():
		if save_locked:Hearth20Identity.save_mutex.unlock();save_locked=false
		push_error("Session tools UI watchdog");quit(1))
	Hearth20Preferences.values.startup_updates=false
	shell=Hearth20SeatedShell.new();root.add_child(shell)
	while not shell.ready_to_show:await process_frame
	shell.focus_map();var app=shell.app;app._load_sample_map("lantern-larch-inn",false);await settle()
	var id=app.board.add_token("Autosave input hero",true,Vector2(6.5,5.5));var pawn=Hearth20Contracts.find_actor(app.campaign,id)
	app.board.activate_tool("select");app.board.fit_pending=false;app.board.camera_zoom=1.;app.board.camera_pan=Vector2.ZERO
	# Delay only the worker's file commit, reproducing slow storage without
	# delaying the main thread or introducing production test-only switches.
	Hearth20Identity.save_mutex.lock();save_locked=true
	expect(app.autosave.start(),"autosave begins without a modal save window")
	await capture("autosave-progress")
	expect(app.autosave_indicator.visible and app.autosave_indicator.active and app.autosave_indicator.mouse_filter==Control.MOUSE_FILTER_IGNORE,"bottom progress is visible and lets all input through")
	expect(not is_instance_valid(app.campaign_progress),"automatic saving never opens the exclusive manual-save window")
	var pixels=float(app.board.current_scene().get("cell_pixels",64.))
	var from=app.board.get_global_position()+app.board._world_to_screen(pawn.position,pixels)
	var destination=Vector2(7.5,5.5);var to=app.board.get_global_position()+app.board._world_to_screen(destination,pixels)
	pointer(from,MOUSE_BUTTON_LEFT,true);await settle()
	var motion=InputEventMouseMotion.new();motion.position=to*shell.focus_surface.size/Vector2(shell.map_viewport.size);motion.global_position=motion.position;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion);await settle()
	pointer(to,MOUSE_BUTTON_LEFT,false);await settle()
	expect(pawn.position==destination,"actual pointer drag moves a token while the save worker is waiting")
	Hearth20Identity.save_mutex.unlock();save_locked=false
	var deadline=Time.get_ticks_msec()+15000
	while app.autosave.active and Time.get_ticks_msec()<deadline:await process_frame
	expect(app.autosave.last_result.get("ok",false),"background save completes after storage becomes available")
	var saved=Hearth20CampaignArchive.read_table(Hearth20Autosave.PATH)
	expect(saved.ok and Hearth20Contracts.find_actor(saved.campaign,id).position==Vector2(6.5,5.5) and pawn.position==destination,"detached saved position does not roll back the live drag")
	await capture("autosave-complete")
	var link=root.get_node("SteamLink");var api=Fakes.Api.new();root.add_child(api);link.api=api;link.fake_backend=true
	link.peer_factory=func():return Fakes.Peer.new()
	link.host();api.lobby_created.emit(1,109775240000000001);link.can_send(44)
	var details=Hearth20NetworkDetails.open(app);await settle()
	expect("Requested pacing" in details.text.text and "Steam effective" in details.text.text and "Steam relay" in details.text.text,"connection details expose requested/effective/actual rates and route")
	expect(not details.text.text.contains("7656119"),"copyable diagnostics exclude Steam account IDs")
	await capture("connection-details")
	details.queue_free();link.disconnect_table();link._steam_shutdown();api.queue_free();await settle()
	var vault=Hearth20CampaignVault.open(shell,app,"open");var until=Time.get_ticks_msec()+10000
	while vault.listing!=null and Time.get_ticks_msec()<until:await process_frame
	expect(vault.rows.find_children("*","Label",true,false).any(func(label):return label.text.begins_with("Autosave ·")),"Open saved tables clearly labels the single autosave slot")
	for label in vault.rows.find_children("*","Label",true,false):expect(label.size.y>=14.,"saved slot text has a readable layout height")
	var saved_button=vault.rows.get_child(0);var point=Vector2(vault.position)+saved_button.get_global_rect().get_center()
	for pressed in [true,false]:
		var click=InputEventMouseButton.new();click.position=point;click.global_position=point;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed;root.push_input(click);await settle()
	expect(vault.selected_path==Hearth20Autosave.PATH and not vault.primary.disabled,"actual pointer click selects the autosave for restoration")
	await capture("autosave-vault");vault.queue_free();await settle()
	app.session.stop_session();shell.queue_free();await create_timer(.5).timeout
	print("Session tools UI: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

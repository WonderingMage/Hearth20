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
func click(control: Control) -> void:
	var point=control.get_global_rect().get_center();var viewport=control.get_viewport()
	if viewport is Window:
		point+=Vector2(viewport.position)
		if viewport.get_parent().get_viewport()==shell.map_viewport:point*=shell.focus_surface.size/Vector2(shell.map_viewport.size)
	elif viewport==shell.map_viewport:point*=shell.focus_surface.size/Vector2(shell.map_viewport.size)
	for pressed in [true,false]:
		var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event);await settle()
func vault_on() -> Hearth20CampaignVault:
	for child in shell.get_children():
		if child is Hearth20CampaignVault and not child.is_queued_for_deletion():return child
	return null
func wait_vault() -> Hearth20CampaignVault:
	var vault=vault_on();var until=Time.get_ticks_msec()+10000
	if vault!=null:
		while vault.listing!=null and Time.get_ticks_msec()<until:await process_frame
	await settle();return vault
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
	details.queue_free();await settle()
	expect(not app.load_button.disabled and app.load_button.visible,"View saved tables remains enabled while the DM is hosting")
	await click(app.load_button);var vault=await wait_vault()
	expect(vault!=null and vault.visible,"actual toolbar click opens saved tables during a hosted session")
	if vault==null:push_error("Cannot continue without the campaign vault");quit(1);return
	expect(vault.rows.find_children("*","Label",true,false).any(func(label):return label.text.begins_with("Autosave ·")),"Open saved tables clearly labels the single autosave slot")
	for label in vault.rows.find_children("*","Label",true,false):expect(label.size.y>=14.,"saved slot text has a readable layout height")
	await click(vault.rows.get_child(0))
	expect(vault.selected_path==Hearth20Autosave.PATH and vault.primary.disabled and vault.restore_note.visible,"host can inspect a saved table with a clear message that restoration needs an ended session")
	var campaign_before=var_to_bytes(app.campaign);vault.confirm();await settle()
	expect(not is_instance_valid(app.campaign_progress) and var_to_bytes(app.campaign)==campaign_before and link.state=="hosting","programmatic confirmation cannot replace or disconnect an active hosted campaign")
	await capture("hosted-saves")
	var back: Button
	for button in vault.find_children("*","Button",true,false):
		if button.text=="Back":back=button
	await click(back)
	expect(vault_on()==null and not shell.has_modal(),"Back closes the hosted save browser and releases modal input")
	await click(app.save_button);var manual=await wait_vault()
	expect(manual!=null and manual.action=="save" and not manual.primary.disabled,"Save remains clickable after closing the hosted save browser")
	for button in manual.find_children("*","Button",true,false):
		if button.text=="Back":back=button
	await click(back)
	await click(app.load_button);vault=await wait_vault();await click(vault.rows.get_child(0))
	expect(vault!=null and vault.visible and vault.primary.disabled,"View saved tables reopens repeatedly without leaving an input lock")
	link.disconnect_table();link._steam_shutdown();api.queue_free();await settle()
	expect(not vault.primary.disabled and not vault.restore_note.visible,"an already-open vault allows restoring once the hosted session ends")
	await capture("autosave-vault")
	await click(vault.primary);var until=Time.get_ticks_msec()+10000
	while is_instance_valid(app.campaign_progress) and app.campaign_progress.active and Time.get_ticks_msec()<until:await process_frame
	expect(is_instance_valid(app.campaign_progress) and not app.campaign_progress.active and app.current_save_path==Hearth20Autosave.PATH,"actual restore click loads the selected autosave after ending the session")
	expect(Hearth20Contracts.find_actor(app.campaign,id).position==Vector2(6.5,5.5),"restoration recovers the saved token position")
	await click(app.campaign_progress.done_button)
	expect(not shell.has_modal() and not shell.map_viewport.gui_disable_input,"Done returns to an interactive map after restoration")
	app.session.stop_session();shell.queue_free();await create_timer(.5).timeout
	print("Session tools UI: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

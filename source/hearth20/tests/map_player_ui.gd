extends SceneTree
var checks=0
var errors=[]
var shell: Hearth20SeatedShell
var output=""
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func settle() -> void:
	for i in 6:await process_frame
func capture(label: String) -> void:
	await settle();shell.app.shell._update_labels();await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run() -> void:
	output=OS.get_cmdline_user_args()[0];root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
	create_timer(90).timeout.connect(func():push_error("Player map UI watchdog");quit(1))
	Hearth20Preferences.values.startup_updates=false
	shell=Hearth20SeatedShell.new();root.add_child(shell)
	while not shell.ready_to_show:await process_frame
	shell.focus_map();var app=shell.app;app._load_sample_map("lantern-larch-inn",false);await settle()
	var pawn=Hearth20TokenInventory.new_actor("Map viewer",true,app.board.current_scene(),Vector2(7.5,6.5));pawn.owner_player_id="viewer";app.campaign.actors.append(pawn)
	var view=app.session._project_for("viewer");app.session.local_role="player";app.session.local_player_id="viewer";app.board.set_campaign(app.campaign,app.session,"player");app._update_session_ui();app.session._install_snapshot(view);await settle()
	expect(app.board.role=="player" and not app.board.snapshot.map_png.is_empty(),"deployed player's map reaches the rendered board")
	expect(not app.map_tabs.visible,"players cannot browse the DM's map tabs")
	await capture("deployed-map")
	pawn.in_inventory=true;app.campaign.revision+=1;app.session._install_snapshot(app.session._project_for("viewer"));await settle()
	expect(app.board.snapshot.scene.id=="unplaced" and app.board.snapshot.map_png.is_empty() and app.board.snapshot.actors.is_empty(),"inventory waiting screen replaces all map artwork and pawns")
	app._show_sidebar_page(app.chat_page);app._update_session_ui();await settle()
	expect(app.inspector_tabs.get_current_tab_control()==app.chat_page,"chat remains usable while no pawn is placed")
	var state={"id":"background-maps","active":true,"progress":.4,"received":4194304,"total":10485760,"phase":"Downloading maps in background…","map_count":3,"completed_maps":1,"rate_bps":2097152.}
	app.session.map_transfer_state=state;app.session.map_transfer_progress.emit(state);await settle()
	var meter=app.shell.download_meter
	expect(meter.visible and "1/3 maps" in meter.caption.text and "2.0 MB/s" in meter.caption.text,"map progress displays background counts, bytes and measured rate")
	expect(meter.mouse_filter==Control.MOUSE_FILTER_IGNORE,"background status never traps board input")
	await capture("inventory-background-download")
	expect(app.shell.welcome_card.visible and "Waiting for your hero" in app.shell.welcome_title.text and not app.shell.welcome_import.visible,"inventory view explains the wait without offering map-import controls")
	root.size=Vector2i(1000,650);await capture("inventory-compact")
	expect(not app.shell.map_detail.visible and "2.0 MB/s" in meter.caption.text,"compact download status keeps speed visible without overlapping token counts")
	state.active=false;app.session.map_transfer_state=state;app.session.map_transfer_progress.emit(state);await settle();expect(not meter.visible,"completed background downloads dismiss the bar")
	app.session.stop_session();shell.queue_free();await create_timer(.5).timeout
	print("Player map UI: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

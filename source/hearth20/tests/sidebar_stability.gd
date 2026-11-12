extends SceneTree
var checks=0
var errors=[]
var output=""
var shell: Hearth20SeatedShell
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func settle() -> void:
	for i in 5:await process_frame
func pointer(point: Vector2,button: int,pressed: bool) -> void:
	point*=shell.focus_surface.size/Vector2(shell.map_viewport.size)
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
	var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button;event.pressed=pressed;root.push_input(event)
func click(control: Control) -> void:
	for pressed in [true,false]:pointer(control.get_global_rect().get_center(),MOUSE_BUTTON_LEFT,pressed);await settle()
func run() -> void:
	output=OS.get_cmdline_user_args()[0];root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
	create_timer(90).timeout.connect(func():push_error("Sidebar stability watchdog");quit(1))
	Hearth20Preferences.values.startup_updates=false
	shell=Hearth20SeatedShell.new();root.add_child(shell)
	while not shell.ready_to_show:await process_frame
	shell.focus_map();var app=shell.app;app._load_sample_map("lantern-larch-inn",false);await settle()
	var id=app.board.add_token("Sidebar creature",false,Vector2(5.5,5.5));Hearth20Contracts.find_actor(app.campaign,id).hidden=false;app._on_selection(id);app._show_sidebar_page(app.token_page);await settle()
	await click(app.token_visibility_button)
	expect(Hearth20Contracts.find_actor(app.campaign,id).hidden,"conceal click still changes the selected token")
	expect(app.workspace_tabs.get_current_tab_control()==app.token_page,"conceal keeps the Token tab selected")
	await click(app.token_visibility_button)
	expect(not Hearth20Contracts.find_actor(app.campaign,id).hidden and app.workspace_tabs.get_current_tab_control()==app.token_page,"reveal changes visibility without changing tabs")
	app._show_sidebar_page(app.scene_page);await settle()
	var before=app.scene_page.scroll_vertical
	for i in 5:pointer(app.scene_page.get_global_rect().get_center(),MOUSE_BUTTON_WHEEL_DOWN,true);await settle()
	expect(app.scene_page.scroll_vertical>before,"wheel scroll moves the Scene content")
	app.session._broadcast_snapshots();await settle()
	expect(app.workspace_tabs.get_current_tab_control()==app.scene_page,"Scene scrolling and refresh keep Scene selected")
	var scroll_offset=app.scene_page.scroll_vertical;app.session._broadcast_snapshots();await settle()
	expect(app.scene_page.scroll_vertical==scroll_offset,"refresh preserves the Scene scroll position")
	for page in [app.scene_page,app.token_page,app.session_page,app.author_page,app.token_sheet_page,app.chat_page,app.journal_page,app.sheet_page]:
		app._show_sidebar_page(page);await settle()
		for i in 3:app._update_session_ui()
		await settle()
		expect(app.inspector_tabs.get_current_tab_control()==(app.workspace_tabs if page.get_parent()==app.workspace_tabs else page),"refresh preserves the outer sidebar on "+page.name)
		if page.get_parent()==app.workspace_tabs:expect(app.workspace_tabs.get_current_tab_control()==page,"refresh preserves workspace tab "+page.name)
	var titles=[]
	for i in app.workspace_tabs.get_tab_count():titles.append(app.workspace_tabs.get_tab_title(i))
	expect(not "Help" in titles and "Token Sheet" in titles,"Help is replaced by Token Sheet")
	expect(app.token_sheet_page.find_children("*","Label",true,false).any(func(label):return label.text=="In development"),"the Token Sheet placeholder has the requested text")
	app._show_sidebar_page(app.scene_page);await settle()
	var bar=app.workspace_tabs.get_tab_bar();var index=app.workspace_tabs.get_tab_idx_from_control(app.token_sheet_page)
	for dimensions in [Vector2i(1000,650),Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size=dimensions;await settle()
		var position=bar.get_global_position()+bar.get_tab_rect(index).get_center()
		for pressed in [true,false]:pointer(position,MOUSE_BUTTON_LEFT,pressed);await settle()
		expect(app.workspace_tabs.get_current_tab_control()==app.token_sheet_page,"Token Sheet is clickable at "+str(dimensions))
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("token-sheet-"+str(dimensions.x)+".png"))
	app.session.local_role="player";app._update_session_ui();app._show_sidebar_page(app.chat_page);app._update_session_ui();await settle()
	expect(app.workspace_tabs.is_tab_hidden(index),"the future creature sheet stays DM-only")
	expect(app.inspector_tabs.get_current_tab_control()==app.chat_page,"player refresh preserves Chat instead of forcing Sheet")
	app.session.local_role="dm";app._update_session_ui();await settle();expect(not app.workspace_tabs.is_tab_hidden(index),"DM role restores access to Token Sheet")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("sidebar-stability.png"))
	app.session.stop_session();shell.queue_free();await create_timer(.5).timeout
	print("Sidebar stability: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

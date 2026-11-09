extends SceneTree
const Party=preload("party_onboarding.gd")
const Fakes=preload("steam_fakes.gd")
class QuietBoot extends Hearth20Boot:
	func _on_first_title_draw() -> void:pass
var output=""
var records=[]
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for frame in 5:await process_frame
func route_button(point: Vector2,button: int,pressed: bool) -> void:
	var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button;event.pressed=pressed;root.push_input(event)
func route_motion(from: Vector2,to: Vector2) -> void:
	var event=InputEventMouseMotion.new();event.position=to;event.global_position=to;event.relative=to-from;event.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(event)
func inspect_route(shell: Hearth20SeatedShell) -> void:
	var board=shell.app.board
	if not board.get("drag_points") is Array:return
	shell.focus_map();board.active_layer="tokens";shell.app.toolbox.open("select")
	shell.app.session.place_inventory_token("layout-guest-0",Vector2(8.5,8.5));await settle()
	var cell=float(board.current_scene().cell_pixels);var offset=board.get_global_rect().position
	var begin=offset+board._world_to_screen(Vector2(8.5,8.5),cell)
	var corner=offset+board._world_to_screen(Vector2(11.1,8.9),cell)
	var finish=offset+board._world_to_screen(Vector2(11.9,12.1),cell)
	route_button(begin,MOUSE_BUTTON_LEFT,true);await settle();route_motion(begin,corner);await settle()
	route_button(corner,MOUSE_BUTTON_RIGHT,true);route_button(corner,MOUSE_BUTTON_RIGHT,false);route_motion(corner,finish)
	await capture("token-waypoint-preview-1000",shell)
	var routed=board.dragging_actor and board.drag_points.size()==3 and board.drag_points[1]==Vector2(11.5,8.5) and board.drag_points[2]==Vector2(11.5,12.5)
	if not routed:records.back().issues.append({"kind":"native drag did not preserve center-snapped waypoints"})
	route_button(finish,MOUSE_BUTTON_LEFT,false);await settle()
	var actor=Hearth20Contracts.find_actor(shell.app.campaign,"layout-guest-0")
	if actor.position!=Vector2(11.5,12.5):records.back().issues.append({"kind":"native release did not apply route"})
	var drop=shell.app.inventory_drop_button.get_global_rect().get_center()
	route_button(finish,MOUSE_BUTTON_LEFT,true);await settle();route_motion(finish,finish+Vector2(22,0));await settle()
	route_motion(finish+Vector2(22,0),drop);await settle();route_button(drop,MOUSE_BUTTON_LEFT,false);await settle()
	if not actor.get("in_inventory",false):records.back().issues.append({"kind":"dragging a map token to the inventory target did not stow it"})
func capture(label: String,scope: Node) -> void:
	await settle()
	var issues=[]
	for control in scope.find_children("*","Control",true,false):
		if not control.is_visible_in_tree() or not (control is BaseButton or control is Label or control is LineEdit):continue
		if scope is Hearth20SeatedShell and scope.focus_state=="table" and control.get_viewport()==scope.map_viewport:continue
		var bounds=control.get_global_rect();var area=control.get_viewport().get_visible_rect()
		if bounds.position.x<area.position.x-1 or bounds.end.x>area.end.x+1:
			issues.append({"path":str(scope.get_path_to(control)),"text":str(control.get("text")).left(75),"rect":str(bounds),"kind":"horizontal overflow"})
		var ancestor=control.get_parent();var scrolls=false
		while ancestor!=null and not ancestor is Viewport:
			if ancestor is ScrollContainer:scrolls=true;break
			ancestor=ancestor.get_parent()
		if not scrolls and (bounds.position.y<area.position.y-1 or bounds.end.y>area.end.y+1):
			issues.append({"path":str(scope.get_path_to(control)),"text":str(control.get("text")).left(75),"rect":str(bounds),"kind":"vertical overflow"})
	if scope is Window and (scope.position.y<24 or scope.position.y+scope.size.y>root.size.y):issues.append({"kind":"dialog outside main window"})
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(label.trim_prefix("before-")+".png"))
	records.append({"screen":label.trim_prefix("before-"),"issues":issues})
func run() -> void:
	output=OS.get_cmdline_user_args()[0];root.gui_embed_subwindows=true
	create_timer(150).timeout.connect(func():push_error("Layout audit watchdog");quit(1))
	Hearth20Preferences.values.startup_updates=false
	var boot=QuietBoot.new();root.add_child(boot)
	for dimensions in [Vector2i(1280,720),Vector2i(1000,650)]:
		root.size=dimensions;await capture("before-title-"+str(dimensions.x),boot)
	boot.queue_free();await settle()
	var party=Party.AppFixture.new();root.add_child(party);var link=root.get_node("SteamLink");var api=Fakes.Api.new();root.add_child(api)
	link.api=api;link.fake_backend=true;link.peer_factory=func():return Fakes.Peer.new()
	var connections=party.open_connections("host");await settle();api.lobby_created.emit(1,109775240000000001);await settle()
	await capture("before-connection-host",connections)
	connections._toggle_advanced();await capture("before-connection-direct",connections)
	connections._close();link.disconnect_table();link._steam_shutdown();party.queue_free();api.queue_free();await settle()
	var shell=Hearth20SeatedShell.new();root.add_child(shell)
	while not shell.ready_to_show:await process_frame
	var app=shell.app;app._load_sample_map("lantern-larch-inn",false)
	for index in 6:
		var actor=Hearth20TokenInventory.new_actor("Adventurer with a long display name "+str(index+1),true,app.board.current_scene(),Vector2(index+.5,2.5))
		actor.id="layout-guest-"+str(index);actor.coins={"gp":1000};actor.in_inventory=true;app.campaign.actors.append(actor)
	for dimensions in [Vector2i(1280,720),Vector2i(1000,650)]:
		root.size=dimensions;await capture("before-table-"+str(dimensions.x),shell)
		shell.focus_map()
		for tool in ["dice","fx","tokens","lighting"]:
			app.toolbox.open(tool);await capture("before-map-"+tool+"-"+str(dimensions.x),shell)
		shell.leave_focus()
	var settings=Hearth20SettingsWindow.open(shell,app);settings.tabs.current_tab=2
	await capture("before-settings-updates",settings);settings._cancel();await settle()
	shell.focus_map();var inventory=app.open_token_inventory();inventory.select_token("layout-guest-0")
	await capture("token-inventory-1000",inventory);inventory.queue_free();await settle()
	var vault=Hearth20CampaignVault.open(shell,app,"save");await capture("campaign-vault-1000",vault);vault.queue_free();await settle()
	var studio=app.open_fx_studio();await capture("effects-atelier-1000",studio);studio.queue_free();await settle()
	var library=app._open_map_library();await capture("map-library-1000",library);library.queue_free();await settle();shell.leave_focus()
	await inspect_route(shell);shell.leave_focus()
	app.session.set_table_mode("casino")
	while shell.current_mode!="casino" or shell.switching:await process_frame
	for dimensions in [Vector2i(1280,720),Vector2i(1000,650),Vector2i(1920,1080)]:
		root.size=dimensions;await capture("before-casino-catalog-"+str(dimensions.x),shell)
	var portal=app.casino_portal
	app.session.casino_action({"action":"open","game":"gambit_of_ord","chip_cp":10,"buyin":100,"minimum":5})
	for index in 6:
		var game=app.campaign.tavern_game
		app.session.casino_action({"action":"join","game_id":game.id,"revision":game.revision,"actor_id":"layout-guest-"+str(index)})
	root.size=Vector2i(1280,720)
	await capture("before-casino-lobby",shell)
	portal.scene.book.open_book();await create_timer(1.1).timeout;await capture("rulebook-navigation-1280",shell)
	portal.scene.book.close_book();await create_timer(1.1).timeout
	await portal.close_local()
	shell.queue_free();await create_timer(.6).timeout
	FileAccess.open(output.path_join("layout.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	print("Layout audit: %d screens"%records.size());quit()

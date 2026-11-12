extends SceneTree
const Fakes=preload("steam_fakes.gd")
var checks=0
var errors=[]
var output=""
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func settle() -> void:
	for frame in 5:await process_frame
func screenshot(name: String) -> void:
	await settle();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	output=OS.get_cmdline_user_args()[0];root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
	create_timer(100).timeout.connect(func():push_error("Map package UI watchdog");quit(1))
	Hearth20Preferences.values.startup_updates=false
	var shell=Hearth20SeatedShell.new();root.add_child(shell)
	while not shell.ready_to_show:await process_frame
	shell.focus_map();var app=shell.app
	var fixture=OS.get_environment("H20_MAP_FIXTURES")
	if fixture.is_empty():fixture=ProjectSettings.globalize_path("res://../qa/map-packages/fixtures")
	app._on_map_selected(fixture.path_join("lantern-larch.hearth20map"));await settle()
	expect(app.campaign.scenes.size()==1 and not is_instance_valid(shell.get_node_or_null("GridCalibration")),"actual import installs the package without a starter tab or scale popup")
	expect(app.map_tabs.tabs.get_child_count()==1 and app.map_tabs.visible,"DM sees tabs for actual loaded maps")
	var first_id: String=app.campaign.active_scene
	await screenshot("complete-map-package")
	app._on_map_selected(fixture.path_join("lantern-larch.hearth20map"));await settle()
	expect(app.campaign.scenes.size()==2 and app.map_tabs.tabs.get_child_count()==2,"duplicate imports get independent campaign tabs")
	var hero=Hearth20TokenInventory.new_actor("Tab traveler",true,app.board.current_scene(),Vector2(15.5,16.5));hero.in_inventory=true;app.campaign.actors.append(hero)
	app.session.set_blackout(true);await settle()
	var tab: Button
	for button in app.map_tabs.tabs.get_children():
		if button.get_meta("scene_id")==first_id:tab=button
	var point=tab.get_global_rect().get_center()*shell.focus_surface.size/Vector2(shell.map_viewport.size)
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true;event.position=point;event.global_position=point;root.push_input(event);await settle()
	expect(app.map_tabs.menu.visible and app.map_tabs.target==first_id,"native right-click targets the clicked map rather than the active map")
	await screenshot("map-tab-context")
	app.map_tabs.menu.id_pressed.emit(1);app.map_tabs.menu.hide();await settle()
	expect(app.campaign.active_scene==first_id and hero.scene_id==first_id and not hero.in_inventory,"context action brings heroes to its own map")
	expect(app.cover_map_button.button_pressed and app.session._project_for("tab-player").scene.id=="blackout","tab movement preserves the global cover and pressed cover control")
	app.session.set_blackout(false);await settle()
	for dimensions in [Vector2i(1000,650),Vector2i(1280,720)]:
		root.size=dimensions;await settle()
		expect(app.map_tabs.size.x<=app.size.x and app.map_tabs.size.y<=64,"tab strip remains bounded at "+str(dimensions))
		await screenshot("map-tabs-"+str(dimensions.x))
	var original_scenes=app.campaign.scenes.duplicate()
	for i in 20:
		var extra=app.board.current_scene().duplicate(true);extra.id="overflow-tab-"+str(i);extra.title="An extremely long map title to test horizontal overflow "+str(i);app.campaign.scenes.append(extra)
	app.map_tabs.refresh();await settle()
	expect(app.map_tabs.tabs.get_child_count()==22 and app.map_tabs.size.x<=app.size.x,"many long map names scroll inside the strip instead of widening the interface")
	await screenshot("map-tabs-overflow")
	app.campaign.scenes=original_scenes;app.map_tabs.refresh();await settle()
	var link=root.get_node("SteamLink");var api=Fakes.Api.new();root.add_child(api);link.api=api;link.fake_backend=true;link.peer_factory=func():return Fakes.Peer.new()
	var window=app.open_connections("host");await settle();api.lobby_created.emit(1,109775240000000001);await settle()
	window.quick_invite();await settle()
	expect(window.invite_button.visible and window.friend_search.has_focus(),"Quick invite focuses searchable friends when overlay is unavailable")
	window.friend_search.text="Aure";window.friend_search.text_changed.emit("Aure");await screenshot("quick-invite-search")
	expect(window.friend_list.item_count==1,"search makes a friend accessible without scrolling")
	window.friend_search.text_submitted.emit("Aure");await settle()
	expect(window.invitation_sent and window.invite_button.visible,"Quick invite remains available after the first invitation")
	window._close();link.disconnect_table();link._steam_shutdown();api.queue_free();await settle()
	var scene=app.board.current_scene();var snapshot=app.session._project_for("meter-player")
	app.session.local_role="player";app.board.set_role("player");app.board.set_player_snapshot(snapshot)
	app.session.map_transfer_state={"id":"new-transfer","active":true,"progress":.42,"received":4404019,"total":10485760,"phase":"Downloading map…"}
	app.session.map_transfer_progress.emit(app.session.map_transfer_state);await settle()
	expect(app.shell.download_meter.visible and "42%" in app.shell.download_meter.caption.text,"player map view has a real-byte percentage at its bottom edge")
	expect(app.shell.download_meter.mouse_filter==Control.MOUSE_FILTER_IGNORE,"download indicator does not block map interactions")
	await screenshot("player-map-download")
	app.session._finish_map_download("old-transfer");await settle()
	expect(app.shell.download_meter.visible,"a late completion or cancellation cannot dismiss a newer download")
	app.session._finish_map_download();await settle();expect(not app.shell.download_meter.visible,"progress disappears after installation/cancellation")
	app.session.local_role="dm";shell.queue_free();await create_timer(.5).timeout
	print("Map package UI: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)

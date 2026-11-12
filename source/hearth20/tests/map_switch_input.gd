extends SceneTree
var output=""
var checks=0
var errors=[]
var clicks=0
var shell: Hearth20SeatedShell
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func settle() -> void:
	for frame in 5:await process_frame
func pointer(point: Vector2,button: int,pressed: bool) -> void:
	var move=InputEventMouseMotion.new();move.position=point;move.global_position=point;root.push_input(move)
	var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button;event.pressed=pressed;root.push_input(event)
func click(point: Vector2,button: int=MOUSE_BUTTON_LEFT) -> void:
	pointer(point,button,true);await settle();pointer(point,button,false);await settle()
func screen_point(point: Vector2) -> Vector2:return point*shell.focus_surface.size/Vector2(shell.map_viewport.size)
func run() -> void:
	output=OS.get_cmdline_user_args()[0];root.size=Vector2i(1280,800)
	create_timer(70).timeout.connect(func():push_error("Map input watchdog");quit(1))
	Hearth20Preferences.values.startup_updates=false
	shell=Hearth20SeatedShell.new();root.add_child(shell)
	while not shell.ready_to_show:await process_frame
	shell.focus_map();var app=shell.app
	var fixture=OS.get_environment("H20_MAP_FIXTURES")
	if fixture.is_empty():fixture=ProjectSettings.globalize_path("res://../qa/map-packages/fixtures")
	app._on_map_selected(fixture.path_join("lantern-larch.hearth20map"));await settle()
	var destination: String=app.campaign.active_scene
	app._on_map_selected(fixture.path_join("lantern-larch.hearth20map"));await settle()
	var hero=Hearth20TokenInventory.new_actor("Input traveler",true,app.board.current_scene(),Vector2(15.5,16.5));hero.in_inventory=true;app.campaign.actors.append(hero)
	app.inspector_toggle.pressed.connect(func():clicks+=1)
	await click(screen_point(app.inspector_toggle.get_global_rect().get_center()))
	expect(clicks==1,"toolbar accepts a real click before switching")
	var tab: Button
	for button in app.map_tabs.tabs.get_children():
		if button.get_meta("scene_id")==destination:tab=button
	await click(screen_point(tab.get_global_rect().get_center()),MOUSE_BUTTON_RIGHT)
	expect(app.map_tabs.menu.visible,"real right-click opens the map context menu")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("context-before.png"))
	var menu_point=app.map_tabs.menu.items[1].get_global_rect().get_center()
	await click(screen_point(menu_point))
	expect(app.campaign.active_scene==destination and hero.scene_id==destination and not hero.in_inventory,"real context-menu click moves heroes to its target")
	expect(not app.map_tabs.menu.visible,"the selected context menu releases its popup")
	await click(screen_point(app.inspector_toggle.get_global_rect().get_center()))
	expect(clicks==2,"toolbar accepts a real click after bringing heroes")
	for repeat in 3:
		var other_id: String=app.campaign.scenes[(repeat+1)%2].id
		for button in app.map_tabs.tabs.get_children():
			if button.get_meta("scene_id")==other_id:tab=button
		await click(screen_point(tab.get_global_rect().get_center()),MOUSE_BUTTON_RIGHT)
		await click(screen_point(app.map_tabs.menu.items[1].get_global_rect().get_center()))
		expect(app.campaign.active_scene==other_id and not app.map_tabs.menu.visible,"repeated real hero-transfer click completes without a modal grab")
		await click(screen_point(app.inspector_toggle.get_global_rect().get_center()))
		expect(clicks==3+repeat,"toolbar remains clickable after repeated transfers")
	var selected_tab=app.map_tabs.tabs.get_child(0)
	await click(screen_point(selected_tab.get_global_rect().get_center()),MOUSE_BUTTON_RIGHT)
	await click(screen_point(app.save_button.get_global_rect().get_center()))
	expect(not app.map_tabs.menu.visible,"clicking outside dismisses the context without activating the underlying button")
	await click(screen_point(app.inspector_toggle.get_global_rect().get_center()))
	expect(clicks==6,"dismissal releases input for the next click")
	await click(screen_point(selected_tab.get_global_rect().get_center()),MOUSE_BUTTON_RIGHT)
	var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE;root.push_input(escape);await settle()
	expect(not app.map_tabs.menu.visible and shell.focus_state=="map","Escape dismisses the menu without leaving the map")
	await click(screen_point(app.inspector_toggle.get_global_rect().get_center()))
	expect(clicks==7,"Escape dismissal leaves toolbar input active")
	var keyboard_destination: String=selected_tab.get_meta("scene_id")
	await click(screen_point(selected_tab.get_global_rect().get_center()),MOUSE_BUTTON_RIGHT)
	for code in [KEY_DOWN,KEY_ENTER]:
		var key=InputEventKey.new();key.pressed=true;key.keycode=code;root.push_input(key);await settle();key.pressed=false;root.push_input(key);await settle()
	expect(not app.map_tabs.menu.visible and app.campaign.active_scene==keyboard_destination,"keyboard navigation activates the selected context action")
	await click(screen_point(app.inspector_toggle.get_global_rect().get_center()))
	expect(clicks==8,"keyboard activation also releases input")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("context-after.png"))
	print("Map switching input: %d checks, %d failures"%[checks,errors.size()]);shell.queue_free();await create_timer(.5).timeout;quit(0 if errors.is_empty() else 1)

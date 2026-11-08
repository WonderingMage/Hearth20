extends SceneTree
var app: Hearth20App
var count:=0
var failed: Array[String]=[]

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	count+=1
	if not ok:
		failed.append(message)
		push_error("FAIL: "+message)
func capture(name_value: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join(name_value+".png"))
func click(control: Control) -> void:
	var event:=InputEventMouseButton.new()
	event.position=control.get_global_rect().get_center()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=event.duplicate(); event.pressed=false
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	root.size=Vector2i(1440,900)
	app=load("res://hearth20_main.tscn").instantiate()
	root.add_child(app)
	await create_timer(0.25).timeout
	check(app.shell.welcome_card.visible,"empty table presents a useful welcome card")
	check(app.shell.welcome_import.get_global_rect().size.y>=30,"welcome import action is a proper interactive control")
	await capture("refined-welcome-1440")
	for key in app.toolbox.rail_buttons:
		var button: Button=app.toolbox.rail_buttons[key]
		check(button.icon!=null and not button.tooltip_text.is_empty(),"rail icon and accessible tooltip: "+str(key))
	app.shell.toggle_palette()
	app.shell.search.text="dice"
	app.shell.search.text_changed.emit("dice")
	check(app.shell.command_buttons.size()==1,"command search finds the dice roller without unrelated results")
	await capture("refined-command-search")
	app.shell._run_command(0)
	check(app.toolbox.current=="dice" and not app.shell.palette.visible,"search action opens the actual Dice tool and closes the palette")
	app.campaign.title="The Ashen Gate · Session prep"
	var scene: Dictionary=app.campaign.scenes[0]
	scene.title="The old watchtower"
	var floor:=Image.create(768,512,false,Image.FORMAT_RGBA8)
	floor.fill(Color("#1c222b"))
	for y in 16:
		for x in 24:
			var color:=Color("#343b43") if (x+y)%2==0 else Color("#30373e")
			floor.fill_rect(Rect2i(x*32+1,y*32+1,30,30),color)
	scene.cell_pixels=32.0
	scene.map_asset=Hearth20Assets.store_asset(app.campaign,Hearth20Assets.inspect_token_png_bytes(floor.save_png_to_buffer(),"synthetic-ui-floor.png"),"map")
	var hero_id: String=app.board.add_token("Mira Stonebrook",true,Vector2(8,8))
	var hero:=Hearth20Contracts.find_actor(app.campaign,hero_id)
	hero.merge({"race":"Wood Elf","class":"Ranger","level":5,"hp":32,"max_hp":41,"ac":16,"speed":35,"abilities":[12,18,14,11,16,10]},true)
	app.board.selected_actor_id=hero_id
	app._on_selection(hero_id)
	app._show_sidebar_page(app.sheet_page)
	app.board.fit_map()
	await create_timer(0.2).timeout
	check(app.character_card.visible and app.character_card.get_global_rect().end.x<=1440,"character identity and stat cards stay inside the inspector")
	check(not app.shell.welcome_card.visible,"welcome card gets out of the way when the scene has content")
	await capture("refined-character-1440")
	app.toolbox.open("dice")
	app.toolbox._roll()
	check(app.toolbox.roll_history.get_child_count()>=1,"designed history cards display a genuine recorded roll")
	await capture("refined-dice-1440")
	app.toolbox.open("measure")
	app.board.ruler_settings.shape="cone"; app.board.ruler_settings.angle=60
	app.board.local_ruler=app.board.ruler_settings.duplicate(true)
	app.board.local_ruler.points=[Vector2(8,8),Vector2(15,7)]
	app.board.local_ruler.linger=true
	await capture("refined-measure-1440")
	await click(app.shell.layer_button)
	check(app.toolbox.current=="layers","floating layer control opens the layer inspector")
	root.size=Vector2i(1000,650)
	app.toolbox.open("dice")
	app.board.fit_map()
	await create_timer(0.2).timeout
	check(app.shell.search_button.text=="Ctrl K","header search condenses at compact widths")
	check(app.save_button.get_global_rect().end.x<=1000 and app.inspector_tabs.get_global_rect().end.x<=1000,"header and inspector stay within the compact window")
	for child in app.toolbox.action_area.get_children():
		if child is Button:
			check(child.get_global_rect().end.y<650,"primary roll action stays visible in the compact window")
	await capture("refined-dice-1000")
	app.session.local_role="player"
	app._update_session_ui()
	app.shell.toggle_palette()
	check(app.shell.commands.all(func(command): return not bool(command.get("dm",false))),"player command search excludes DM-only tools")
	app.shell.search.text="lighting"; app.shell.search.text_changed.emit("lighting")
	check(app.shell.command_buttons.is_empty(),"player search cannot surface a lighting editor command")
	app.shell.close_palette()
	app.session.local_role="dm"
	app._update_session_ui()
	print("Refined UI: %d assertions, %d failures."%[count,failed.size()])
	quit(0 if failed.is_empty() else 1)

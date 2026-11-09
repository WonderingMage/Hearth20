extends SceneTree
var app: Hearth20App
var session: Hearth20Session
var campaign: Dictionary
var scene: Dictionary
var count := 0
var failures: Array[String] = []
var serial := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	count += 1
	if not value:
		failures.append(message)
		push_error("FAIL: "+message)
func action(command: Dictionary, player: String = "dm-local") -> Dictionary:
	serial+=1
	command.request_id="test-board-%d" % serial
	session.request_rates.clear()
	return session._apply_board_action(command,player)
func object(kind: String="rectangle", layer: String="tokens") -> Dictionary:
	return {"kind":kind,"layer":layer,"points":[Vector2(3,3),Vector2(5,5)],"color":"#76e0ca","fill":"#102d3b80","width":3.0,"opacity":1.0,"font":"Serif","font_size":24.0,"text":"Northern gate","bold":true,"italic":true,"border":true,"border_color":"#e8bf78"}
func pointer(point: Vector2, pressed: bool, button: int=MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event:=InputEventMouseButton.new()
	event.position=app.board._world_to_screen(point,float(scene.cell_pixels))
	event.button_index=button
	event.pressed=pressed
	return event
func capture(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join(name_value+".png"))
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://hearth20_main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	session=app.session
	campaign=app.campaign
	scene=campaign.scenes[0]
	scene.width_cells=24
	scene.height_cells=16
	session.remote_players={"player-a":{"nickname":"A"},"player-b":{"nickname":"B"}}
	var hero_a: String=app.board.add_token("Mira · Elf ranger",true,Vector2(6,8))
	var actor:=Hearth20Contracts.find_actor(campaign,hero_a)
	actor.owner_player_id="player-a"
	actor.senses="Darkvision 60 ft., passive Perception 15"
	actor.vision.darkvision_override=false
	actor.prof_bonus=3
	var hero_b: String=app.board.add_token("Toren · Human fighter",true,Vector2(9,8))
	Hearth20Contracts.find_actor(campaign,hero_b).owner_player_id="player-b"
	check(Hearth20BoardTools.darkvision(actor)==60,"recorded imported senses supply darkvision")
	var explicit:=actor.duplicate(true)
	explicit.vision={"darkvision_feet":0.0}
	check(Hearth20BoardTools.darkvision(explicit)==0,"an explicit zero overrides imported senses")
	for kind in ["freehand","line","rectangle","ellipse","text"]:
		check(action({"action":"add","object":object(kind)},"player-a").ok,"player can create "+kind)
	check(scene.annotations.size()==5,"all drawing objects persist in scene data")
	var moved_private: Dictionary=scene.annotations[0].duplicate(true)
	moved_private.layer="gm"
	check(action({"action":"update","object":moved_private}).ok,"DM can move an owned player drawing to the private layer")
	var private_id:=str(moved_private.id)
	check(not action({"action":"delete","id":private_id},"player-a").ok,"owner cannot delete an object after the DM moves it private")
	moved_private.layer="tokens"
	check(not action({"action":"update","object":moved_private},"player-a").ok,"owner cannot reclaim a DM-private drawing with a stale ID")
	action({"action":"update","object":moved_private})
	check(not action({"action":"add","object":object("text","gm")},"player-a").ok,"player cannot author GM layer")
	check(not action({"action":"add","object":object("wall","light")},"player-a").ok,"player cannot author lighting")
	var id:=str(scene.annotations[0].id)
	check(not action({"action":"delete","id":id},"player-b").ok,"another player cannot delete a drawing")
	var changed: Dictionary=scene.annotations[0].duplicate(true)
	changed.color="#ff3344"
	check(not action({"action":"update","object":changed},"player-b").ok,"another player cannot edit a drawing")
	check(action({"action":"update","object":changed},"player-a").ok,"owner can restyle their drawing")
	check(action({"action":"delete","id":id},"player-a").ok,"owner can delete their drawing")
	check(action({"action":"undo"},"player-a").ok and scene.annotations.size()==5,"owner undo restores removed object")
	var bad:=object()
	bad.points=[Vector2(INF,1)]
	check(not action({"action":"add","object":bad}).ok,"nonfinite drawing rejected")
	bad=object(); bad.points=[Vector2(-1,1)]
	check(not action({"action":"add","object":bad}).ok,"off-map drawing rejected")
	bad=object(); bad.text="x".repeat(2001)
	check(not action({"action":"add","object":bad}).ok,"oversized label rejected")
	check(action({"action":"add","object":object("text","gm")}).ok,"DM can create a private label")
	var view: Dictionary=session._project_for("player-a")
	check(view.scene.annotations.size()==5 and view.scene.annotations.all(func(o): return o.get("mine",false)),"GM annotation absent and own drawings identified")
	check(not JSON.stringify(view).contains("owner_player_id"),"annotation projection contains no owner principal")
	var ruler: Dictionary=app.board.ruler_settings.duplicate(true)
	ruler.points=[Vector2(4,4),Vector2(7,8),Vector2(7,10)]
	ruler.distance="euclidean"
	check(is_equal_approx(Hearth20BoardTools.distance(ruler,5),35),"waypoint distances add actual segment lengths")
	ruler.distance="grid"
	check(is_equal_approx(Hearth20BoardTools.distance(ruler,5),30),"grid rule measures diagonals as one square")
	ruler.distance="alternating"
	check(is_equal_approx(Hearth20BoardTools.distance(ruler,5),35),"alternating diagonals carry across waypoints")
	ruler.points=[Vector2(8,8),Vector2(10,8)]
	for origin in ["center","edge","corner"]:
		ruler.shape="square"; ruler.origin=origin
		var bounds:=Hearth20BoardTools._polygon_bounds(Hearth20BoardTools.polygon(ruler,5))
		check(is_equal_approx(bounds.size.x,4 if origin=="center" else 2),"square origin "+origin+" has expected dimensions")
	ruler.shape="circle"; ruler.origin="edge"
	check(is_equal_approx(Hearth20BoardTools._polygon_bounds(Hearth20BoardTools.polygon(ruler,5)).size.x,2),"circle edge origin uses a diameter")
	for angle in [45,60,90]:
		ruler.shape="cone"; ruler.angle=angle; ruler.round=false
		var bounds:=Hearth20BoardTools._polygon_bounds(Hearth20BoardTools.polygon(ruler,5))
		check(is_equal_approx(bounds.size.y,4*tan(deg_to_rad(float(angle))*0.5)),"flat cone "+str(angle)+" width follows angle")
		ruler.round=true
		check(Hearth20BoardTools.polygon(ruler,5).size()==42,"rounded cone uses a curved end")
	for width in [5,10,15]:
		ruler.shape="beam"; ruler.beam_width=width
		check(is_equal_approx(Hearth20BoardTools._polygon_bounds(Hearth20BoardTools.polygon(ruler,5)).size.y,float(width)/5),"beam has exact "+str(width)+" foot width")
	check(action({"action":"mask_all","reveal":false}).ok,"DM hides full page")
	check(action({"action":"mask","rect":Rect2(2,2,4,4),"reveal":true}).ok,"DM reveals part of full-page mask")
	check(Hearth20Contracts.point_is_visible(Vector2(3,3),scene) and not Hearth20Contracts.point_is_visible(Vector2(8,8),scene),"reveal subtracts only the selected area")
	check(not action({"action":"mask_all","reveal":true},"player-a").ok,"player cannot clear mask")
	action({"action":"mask_all","reveal":true})
	check(action({"action":"mask_polygon","points":[Vector2(2,2),Vector2(8,2),Vector2(2,8)],"reveal":false}).ok,"polygon conceal accepted")
	check(not Hearth20Contracts.point_is_visible(Vector2(3,3),scene) and Hearth20Contracts.point_is_visible(Vector2(8,8),scene),"polygon mask follows its covered cells")
	action({"action":"mask_all","reveal":true})
	scene.annotations=[]
	scene.dynamic_lighting=true; scene.ambient_light="dark"
	var sight:=Hearth20Vision.build_view(campaign,"player-a",scene)
	check(Hearth20Vision.visible(Vector2(15,8),sight) and not Hearth20Vision.visible(Vector2(21,8),sight),"darkvision sees up to the recorded range")
	var wall:=object("wall","light"); wall.points=[Vector2(12,0),Vector2(12,16)]
	action({"action":"add","object":wall})
	sight=Hearth20Vision.build_view(campaign,"player-a",scene)
	check(not Hearth20Vision.visible(Vector2(15,8),sight),"authored wall blocks darkvision")
	check(Hearth20Contracts._crosses_blocking_geometry(Vector2(11,8),Vector2(13,8),scene),"authored wall blocks movement")
	scene.annotations=[]
	wall.kind="window"; action({"action":"add","object":wall})
	sight=Hearth20Vision.build_view(campaign,"player-a",scene)
	check(Hearth20Vision.visible(Vector2(15,8),sight) and Hearth20Contracts._crosses_blocking_geometry(Vector2(11,8),Vector2(13,8),scene),"window passes vision while blocking movement")
	scene.annotations=[]
	var light:=object("light","light"); light.points=[Vector2(10,8)]; light.bright=20.0; light.dim=20.0; light.enabled=true
	action({"action":"add","object":light})
	sight=Hearth20Vision.build_view(campaign,"player-b",scene)
	check(Hearth20Vision.visible(Vector2(12,8),sight),"placed light illuminates for ordinary vision")
	check(action({"action":"actor_layer","id":hero_a,"layer":"gm"}).ok,"DM moves token to GM layer")
	check(session._project_for("player-a").actors.all(func(a): return a.id!=hero_a),"even an owned token on GM layer is absent from player packets")
	action({"action":"actor_layer","id":hero_a,"layer":"tokens"})
	scene.dynamic_lighting=false
	scene.annotations=[]
	campaign.table_timeline=[]
	session.request_rates.clear()
	for visibility in ["self","public","secret"]:
		session.local_role="dm"
		serial+=1
		var roll:=session._apply_table_request({"request_id":"roll-%d"%serial,"action":"roll","kind":"dice","actor_id":hero_a,"expression":"1d20+2","visibility":visibility,"proficiency":true},"player-a")
		check(roll.ok,"GUI roll visibility "+visibility+" accepted")
	check(session._timeline_for("player-a").size()==2,"roller sees self and public but no GM-only result")
	check(session._timeline_for("player-b").size()==1,"other player sees only public result")
	check(session._timeline_for("dm-local").size()==2,"DM interface sees public and secret but no self-only result")
	check(campaign.table_timeline.all(func(e): return e.modifier==5),"host adds recorded proficiency exactly once")
	check(action({"action":"save_fx_preset","name":"Azure breath","settings":app.board.fx_settings}).ok,"DM saves a custom data-only FX preset")
	check(session._project_for("player-a").fx_presets.has("Azure breath"),"custom FX library is shared with admitted players")
	for effect in Hearth20BoardTools.EFFECTS:
		var settings: Dictionary=app.board.fx_settings.duplicate(true)
		settings.effect=effect; settings.start=Vector2(5,5); settings.end=Vector2(9,5)
		check(action({"action":"fx","effect":settings},"player-a").ok,"player can share "+effect+" FX")
	var validation:=Hearth20Contracts.validate_campaign(campaign)
	print("Toolkit campaign validation: ",validation)
	check(validation.ok,"new objects, light fields and FX survive campaign validation")
	var save_path:=Hearth20Identity.SAVE_ROOT+"/board-tools-fixture.h20campaign"
	var saved:=Hearth20Identity.save_campaign(campaign,save_path)
	check(saved.ok,"new toolkit saves through the normal campaign boundary")
	if saved.ok:
		var loaded:=Hearth20Identity.load_campaign(save_path)
		check(loaded.ok,"toolkit save reloads through the normal campaign boundary")
	await ui_checks()
	print("Board tools: %d assertions, %d failures."%[count,failures.size()])
	quit(0 if failures.is_empty() else 1)

func ui_checks() -> void:
	session.remote_players.clear()
	scene.fx=[]
	var image:=Image.create(768,512,false,Image.FORMAT_RGBA8)
	image.fill(Color("#302d2d"))
	for y in 16:
		for x in 24:
			image.fill_rect(Rect2i(x*32+1,y*32+1,30,30),Color("#514a43") if (x+y)%2==0 else Color("#4c463f"))
	scene.cell_pixels=32.0
	scene.map_asset=Hearth20Assets.store_asset(campaign,Hearth20Assets.inspect_token_png_bytes(image.save_png_to_buffer(),"synthetic-floor.png"),"map")
	app.board.fit_map()
	await process_frame
	await click_control(app.toolbox.rail_buttons.measure)
	check(app.toolbox.current=="measure" and app.board.tool_name=="measure","Godot pointer dispatch opens the Measure panel and activates the tool")
	await click_control(app.toolbox.rail_buttons.draw)
	check(app.toolbox.current=="draw" and app.board.tool_name=="draw","Godot pointer dispatch opens Draw from the tool rail")
	app.toolbox.open("draw")
	app.board.tool_settings.kind="rectangle"
	app.board._gui_input(pointer(Vector2(2,2),true))
	app.board._gui_input(pointer(Vector2(5,4),false))
	check(scene.annotations.size()==1 and scene.annotations[0].kind=="rectangle","actual board gesture creates rectangle")
	app.toolbox.open("select")
	app.board._gui_input(pointer(Vector2(3,3),true))
	app.board._gui_input(pointer(Vector2(4,3),false))
	check(not app.board.selected_object_id.is_empty(),"drawing is selectable through board input")
	var before: Vector2=scene.annotations[0].points[0]
	app.board._gui_input(pointer(Vector2(3,3),true))
	var motion:=InputEventMouseMotion.new()
	motion.position=app.board._world_to_screen(Vector2(4,3),float(scene.cell_pixels))
	app.board._gui_input(motion)
	app.board._gui_input(pointer(Vector2(4,3),false))
	check(scene.annotations[0].points[0].is_equal_approx(before+Vector2(1,0)),"drag gesture moves drawing in map coordinates")
	app.toolbox.open("text")
	app.toolbox.fields.text.text="NORTHERN GATE\nKeep the watch fires burning."
	app.toolbox.fields.text.text_changed.emit()
	app.board._gui_input(pointer(Vector2(7,2),true))
	app.board._gui_input(pointer(Vector2(16,5),false))
	check(scene.annotations.size()==2 and scene.annotations[1].text.begins_with("NORTHERN"),"text panel and gesture create formatted label")
	await capture("tools-text-1280")
	for tool in ["draw","measure","dice","fx","mask","lighting","layers"]:
		app.toolbox.open(tool)
		await process_frame
		check(app.toolbox.get_global_rect().end.x<=1280,"tool panel fits window: "+tool)
		await capture("tools-"+tool+"-1280")
	app.toolbox.open("measure")
	app.board.ruler_settings.shape="line"; app.board.ruler_settings.snap="none"; app.board.ruler_settings.linger=true
	app.board._gui_input(pointer(Vector2(4,6),true))
	app.board._gui_input(pointer(Vector2(8,6),true,MOUSE_BUTTON_RIGHT))
	app.board._gui_input(pointer(Vector2(8,10),false))
	check(app.board.local_ruler.points.size()==3,"right click during left drag adds a waypoint")
	check(not app.board.local_ruler.is_empty(),"linger retains measurement on release")
	await capture("tools-waypoints-1280")
	app.board._gui_input(pointer(Vector2(10,10),true))
	check(app.board.local_ruler.points.size()==2,"next left click replaces lingering measurement")
	app.board._gui_input(pointer(Vector2(12,10),false))
	app.toolbox.open("measure")
	app.board.ruler_settings.shape="cone"; app.board.ruler_settings.angle=90; app.board.ruler_settings.round=true
	app.board._gui_input(pointer(Vector2(6,8),true))
	app.board._gui_input(pointer(Vector2(14,8),false))
	await capture("tools-cone-1280")
	root.size=Vector2i(1000,650)
	app.toolbox.open("dice")
	await process_frame
	check(app.toolbox.get_global_rect().end.x<=1000,"dice GUI fits compact window")
	await capture("tools-dice-1000")

func click_control(control: Control) -> void:
	await process_frame
	var event:=InputEventMouseButton.new()
	event.position=control.get_global_rect().get_center()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame

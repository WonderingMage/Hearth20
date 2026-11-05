extends SceneTree
var errors=[]
var checks=0
func _initialize() -> void:call_deferred("run")
func expect(ok: bool, text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error(text)
func run() -> void:
	root.size=Vector2i(1440,900);var boot=load("res://hearth20_boot.tscn").instantiate();root.add_child(boot);await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join("lab-title-menu.png"))
	var buttons=boot.find_children("*","Button",true,false).filter(func(b):return b.text=="Multiplayer Lab · DM + 2 Players");expect(buttons.size()==1,"debug title offers the three-window lab")
	if buttons.is_empty():quit(1);return
	buttons[0].pressed.emit();var stop=Time.get_ticks_msec()+70000;var app: Hearth20App
	while Time.get_ticks_msec()<stop:
		for child in root.get_children():
			if child is Hearth20SeatedShell:app=child.app
		if app!=null and app.multiplayer_lab.active and app.session.remote_players.size()==2 and app.campaign.actors.size()==2:break
		await process_frame
	expect(app!=null and app.multiplayer_lab.active and app.session.remote_players.size()==2 and app.campaign.actors.size()==2,"one title click opens the DM and joins both actual player windows with owned PNG pawns")
	if app!=null:
		expect(Hearth20Contracts.find_scene(app.campaign,app.campaign.active_scene).get("library_id","")=="sunspire-sanctum","title lab starts a lit sample table")
		var experience=app.seated_shell;var lab=app.multiplayer_lab
		for mode in ["casino","map"]:
			app.session.set_table_mode(mode);var transition_end=Time.get_ticks_msec()+20000
			while Time.get_ticks_msec()<transition_end:
				if lab._status("player1").get("table_mode","")==mode and lab._status("player2").get("table_mode","")==mode and lab._status("player1").get("table_ready",false) and lab._status("player2").get("table_ready",false) and experience.current_mode==mode and not experience.switching:break
				await process_frame
			expect(lab._status("player1").get("table_mode","")==mode and lab._status("player2").get("table_mode","")==mode and experience.current_mode==mode,"DM and both native player windows transition to "+mode)
		lab.stop_players();var end=Time.get_ticks_msec()+10000
		while (lab._alive("player1") or lab._alive("player2")) and Time.get_ticks_msec()<end:await process_frame
		expect(not lab._alive("player1") and not lab._alive("player2"),"title-launched child windows close");experience.queue_free()
	await process_frame;await process_frame;print("Multiplayer Lab title: %d assertions, %d failures."%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

extends SceneTree
var app: Hearth20App
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool, text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error(text)
func until(predicate: Callable, text: String, seconds=50) -> bool:
	var end=Time.get_ticks_msec()+seconds*1000
	while not predicate.call() and Time.get_ticks_msec()<end:await process_frame
	var ok=predicate.call();expect(ok,text);return ok
func run() -> void:
	root.size=Vector2i(1440,900);app=load("res://hearth20_main.tscn").instantiate();root.add_child(app);await process_frame;app._load_sample_map("sunspire-sanctum",false)
	var lab=app.multiplayer_lab;expect(Hearth20MultiplayerLab.enabled(),"debug build exposes local lab");lab.open_panel();expect(lab.names.size()==2 and lab.samples.button_pressed and lab.placement.button_pressed,"gilded setup provides exactly two named players and optional sample characters")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join("lab-setup.png"))
	var original_env=OS.get_environment("APPDATA");lab.panel.find_child("LaunchTwoPlayers",true,false).pressed.emit();expect(lab.active and app.session.listening_port>0 and lab.strip.visible,"one setup action hosts and starts the two real processes");expect(OS.get_environment("APPDATA")==original_env,"launch restores the DM environment")
	var ready=await until(func():return app.campaign.actors.size()==2 and not lab._status("player1").get("character","").is_empty() and not lab._status("player2").get("character","").is_empty(),"both authenticated player windows import unique sample characters")
	if not ready:lab.stop_players();await create_timer(2.).timeout;quit(1);return
	await until(func():return app.campaign.actors.all(func(a):return not a.in_inventory),"sample tokens are placed through DM host commands")
	await until(func():return lab._status("player1").get("own_token_visible",false) and lab._status("player2").get("own_token_visible",false),"each actual player receives its placed token in the board snapshot")
	var first=lab._status("player1");var second=lab._status("player2");var roots=[ProjectSettings.globalize_path("user://"),str(first.user_path),str(second.user_path)]
	expect(first.principal!=second.principal and first.principal!="dm-local" and second.principal!="dm-local","each real client proves a distinct signing identity")
	expect(first.pid!=second.pid and int(first.pid)!=OS.get_process_id() and int(second.pid)!=OS.get_process_id(),"exactly DM plus two independent game processes")
	expect(roots[0]!=roots[1] and roots[1]!=roots[2] and roots[0]!=roots[2],"three separate user-data roots preserve DM and player profiles")
	expect(app.session.remote_players.size()==2,"host sees exactly two connected players")
	for i in 2:
		var s=[first,second][i];var a=Hearth20JoinCharacter.current(app.campaign,s.principal)
		expect(a.id==s.character and a.token_size==1. and a.movement_policy.mode=="free_until_revoked" and a.movement_policy.controllers==[s.principal],"placed size-one token grants movement only to its player")
		expect(a.vision.darkvision_feet==(300 if i==0 else 0) and Hearth20TavernGames.purse(a)==100000,"normal import records sample senses and exact casino gold")
		var private_view=app.session._project_for(s.principal);expect(private_view.sheets.size()==1 and private_view.sheets[0].id==a.id and private_view.actors.any(func(v):return v.id==a.id),"host recipient projection contains own board token and only its private character")
	lab.focus_view("player1");var cmd=Hearth20MultiplayerLab.read_record(lab.root_path.path_join("cmd-player1.json"));await until(func():return lab._status("player1").get("focus_ack","")==cmd.id,"window switch reaches the actual first player")
	lab.focus_view("player2");cmd=Hearth20MultiplayerLab.read_record(lab.root_path.path_join("cmd-player2.json"));await until(func():return lab._status("player2").get("focus_ack","")==cmd.id,"window switch reaches the actual second player")
	for id in ["player1","player2"]:lab._command(id,"capture")
	await create_timer(1.).timeout;lab.focus_view("dm");await create_timer(.5).timeout
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join("lab-dm.png"))
	var actor_ids=app.campaign.actors.map(func(a):return a.id);lab.stop_players();await until(func():return not lab._alive("player1") and not lab._alive("player2") and app.session.remote_players.is_empty(),"close test players shuts down only the two owned clients")
	expect(app.session.listening_port>0 and app.campaign.actors.size()==2,"closing players keeps the DM host and campaign records")
	lab.start(true);await until(func():return app.session.remote_players.size()==2 and lab._status("player1").get("connected",false) and lab._status("player2").get("connected",false),"same two local profiles reconnect")
	expect(lab._status("player1").principal==first.principal and lab._status("player2").principal==second.principal and app.campaign.actors.map(func(a):return a.id)==actor_ids,"reopening preserves ownership and cannot duplicate tokens or starting gold")
	lab.stop_players();await until(func():return not lab._alive("player1") and not lab._alive("player2"),"reopened clients also close cleanly")
	lab.fresh_profiles.button_pressed=true;lab.start(false)
	await until(func():return lab._status("player1").get("character_required",false) and lab._status("player2").get("character_required",false),"fresh profiles with samples disabled reach normal character import in both windows")
	expect(lab._status("player1").principal!=first.principal and lab._status("player2").principal!=second.principal and app.campaign.actors.size()==2,"fresh test identities leave existing characters untouched and do not auto-create samples")
	lab.stop_players();await until(func():return not lab._alive("player1") and not lab._alive("player2"),"manual-import windows close cleanly too")
	ProjectSettings.set_setting("application/config/hearth20_debug",false);expect(not lab.start().ok and Hearth20MultiplayerLab.child_slot().is_empty(),"normal builds cannot start debug clients");ProjectSettings.set_setting("application/config/hearth20_debug",true)
	var evidence={"checks":checks,"errors":errors,"first_pid":first.pid,"second_pid":second.pid,"dm_pid":OS.get_process_id(),"private_profile_roots":roots};FileAccess.open(OS.get_environment("H20_QA_EVIDENCE").path_join("lab-results.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"));app.session.stop_session();app.queue_free();await process_frame;await process_frame;print("Multiplayer Lab: %d assertions, %d failures."%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

extends SceneTree
var app: Hearth20App
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func act(action: String, data: Dictionary={}) -> Dictionary:
	var g=app.campaign.get("tavern_game",{});var c={"action":action,"game_id":g.get("id",""),"revision":g.get("revision",0)};c.merge(data);var result=app.session.casino_action(c);expect(result.ok,"UI scenario action "+action+": "+str(result.get("error","")));return result
func capture(name_value: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join(name_value+".png"))
func wait_view() -> void:
	var stop=Time.get_ticks_msec()+30000
	while (app.casino_portal.phase!="ready" or app.casino_portal.scene.game_view.preparing) and Time.get_ticks_msec()<stop:await process_frame
	expect(app.casino_portal.phase=="ready" and not app.casino_portal.scene.game_view.preparing,"local game loader finishes its actual3D warmup")
func wait_motion() -> void:
	var stop=Time.get_ticks_msec()+15000
	while app.casino_portal.scene.game_view.animating and Time.get_ticks_msec()<stop:await process_frame
	expect(not app.casino_portal.scene.game_view.animating,"game presentation finishes its motion")
func run() -> void:
	root.size=Vector2i(1600,900);app=load("res://hearth20_main.tscn").instantiate();root.add_child(app);await process_frame;app._load_sample_map("sunspire-sanctum",false)
	app.campaign.casino_house_cp=1000000
	for i in 3:
		var a=Hearth20TokenInventory.new_actor("Guest "+str(i+1),true,app.board.current_scene(),Vector2(.5,.5));a.id="extra-ui-"+str(i);a.coins={"gp":1000};a.in_inventory=true;app.campaign.actors.append(a)
	var baseline=app.find_children("*","SubViewport",true,false).size();app.casino_portal.open();await wait_view();await capture("all-four-game-catalog")
	for type in Hearth20CasinoGames.TYPES:
		app.casino_portal.table_prefs[type]={"denomination":1,"buyin":100,"minimum":2};app.casino_portal.signature="";app.casino_portal._refresh()
		var choices=app.casino_portal.catalog_panel.find_children("*","Button",true,false).filter(func(b):return b.text=="Open for the party");choices[Hearth20CasinoGames.TYPES.find(type)+1].pressed.emit()
		expect(app.campaign.tavern_game.game==type and app.campaign.tavern_game.chip_cp==10 and app.campaign.tavern_game.minimum==2,"actual catalog button opens its own game and selected stakes");await wait_view()
		for i in 3:act("join",{"actor_id":"extra-ui-"+str(i)})
		act("start");var portal=app.casino_portal;portal.selected_view_seat=0;portal.signature="";portal._refresh();await create_timer(1.5).timeout
		expect(not app.board.can_process() and app.session.can_process(),"map rests while casino and network run")
		if type=="gambit_of_ord":
			await capture("ord-soul-glass-private-d8")
			var seen=0
			while app.campaign.tavern_game.phase!="between" and seen<25:
				if app.campaign.tavern_game.phase=="await_die":act("roll_next");await create_timer(1.4).timeout
				else:act("check")
				seen+=1
			expect(app.campaign.tavern_game.phase=="between" and portal.scene.game_view.dice.size()==9,"showdown displays the nine revealed soul dice")
			var frames=[]
			for n in 40:
				var tick=Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw
				if n>5:frames.append((Time.get_ticks_usec()-tick)/1000.)
			frames.sort();FileAccess.open(OS.get_environment("H20_QA_EVIDENCE").path_join("ord-performance.json"),FileAccess.WRITE).store_string(JSON.stringify({"median_frame_ms":frames[frames.size()/2],"p95_frame_ms":frames[floori(frames.size()*.95)],"dice_volumes":9,"renderer":RenderingServer.get_video_adapter_name()},"\t"))
			expect(frames[frames.size()/2]<65.,"nine soul volumes remain interactive on native GPU")
			await capture("ord-soul-dice-showdown")
		elif type=="run_of_luck":
			var view=portal.scene.game_view;expect(view.racers.size()==5 and view.racers.all(func(r):return not r.walk.is_empty() and not r.idle.is_empty()),"five supplied colored lizards retain real walking and idle clips")
			portal._wager_pick({"kind":"racer","number":3});expect(portal.actions.get_node("WagerKind").selected==3,"clicking a physical race lane selects the matching wager control")
			for i in 3:act("wager",{"actor_id":"extra-ui-"+str(i),"amount":5,"kind":"racer","number":i})
			act("lock_bets");await capture("lizard-race-bets-locked")
			for stage in 3:
				act("race_stage");await create_timer(1.).timeout
				if stage==0:
					expect(view.racers.any(func(r):return r.gait_started and "walk" in str(r.player.current_animation).to_lower()),"pace motion plays the authored skeletal walk, not a sliding static model")
					var skeleton=view.racers[0].model.find_children("*","Skeleton3D",true,false)[0];var poses=[]
					for bone in skeleton.get_bone_count():poses.append(skeleton.get_bone_pose(bone))
					await create_timer(.1).timeout;var changed=false
					for bone in skeleton.get_bone_count():changed=changed or skeleton.get_bone_pose(bone)!=poses[bone]
					expect(changed,"the supplied skeleton actually changes bone poses during its gait")
					await capture("lizard-walk-and-green-d4")
				await wait_motion()
			for i in 5:expect(view.racers[i].total_paces==app.campaign.tavern_game.positions[i],"racer walks exactly its total d4 pace count")
			await capture("lizard-race-final-placing")
		else:
			expect(not portal.scene.card_surface.visible,"switching from race to wheel hides the empty dice layer instead of retaining its last green-d4 texture")
			portal._wager_pick({"kind":"number","number":12});expect(portal.actions.get_node("WagerKind").selected==5 and portal.actions.get_node("WagerNumber").value==12,"physical wheel cell selects an exact-number wager without spending gold")
			act("wager",{"actor_id":"extra-ui-0","amount":5,"kind":"number","number":12});act("wager",{"actor_id":"extra-ui-1","amount":8,"kind":"red","number":0});act("wager",{"actor_id":"extra-ui-2","amount":4,"kind":"ends","number":0});act("lock_bets");await capture("roulette-red-black-velvet")
			act("spin");await create_timer(.8).timeout;expect(portal.scene.game_view.animating,"wheel animates its committed host outcome");await capture("roulette-spinning");await wait_motion();await capture("roulette-settled-result")
		act("cashout");act("close");await process_frame
	var book=app.casino_portal.scene.book;book.open_book();await create_timer(1.).timeout
	for chapter in [1,2,3]:
		book.select_chapter(chapter);await create_timer(.95).timeout
		for spread in book.spread_count():
			if spread>0:book.turn_spread(1);await create_timer(.55).timeout
			for page in book.pages:
				for label in page.get_children():
					if label.has_meta("book_body"):expect(label.get_rect().end.y<=(620 if page==book.pages[1] else 940),"large-print chapter body fits its reading area")
			await capture("book-chapter-"+str(chapter)+"-spread-"+str(spread))
	book.close_book();await book.closed
	await app.casino_portal.close_local();await process_frame;await process_frame
	expect(app.board.can_process() and app.find_children("*","SubViewport",true,false).size()==baseline,"all game models, soul volumes and extra viewports release on exit")
	app.queue_free();await process_frame;await process_frame;print("Additional casino presentation: %d assertions, %d failures."%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

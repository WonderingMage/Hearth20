extends SceneTree
var role=""
var port=0
var output=""
var secret=""
var folder=""
var session: Hearth20Session
var last={}
var replies=[]
var snack_replies=[]
var snack_events=[]
var checks=0
var errors=[]
func _initialize() -> void:
	var args=OS.get_cmdline_user_args();role=args[0];port=int(args[1]);output=args[2];secret=args[3];folder=args[4];call_deferred("run")
func expect(ok: bool, text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error(text)
func same_values(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):return a==b
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not same_values(a[i],b[i]):return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not same_values(a[key],b[key]):return false
		return true
	return typeof(a)==typeof(b) and a==b
func mark(label: String) -> void:FileAccess.open(folder.path_join(label+".ready"),FileAccess.WRITE).store_string("ready")
func wait(label: String) -> void:
	await until(func():return FileAccess.file_exists(folder.path_join(label+".ready")),"sync "+label)
func until(predicate: Callable, label: String) -> void:
	var end=Time.get_ticks_msec()+25000
	while not predicate.call() and Time.get_ticks_msec()<end:await process_frame
	expect(predicate.call(),label)
func host(action: String, data: Dictionary={}) -> Dictionary:
	var g=session.campaign.get("tavern_game",{});var cmd={"action":action,"game_id":g.get("id",""),"revision":g.get("revision",0)};cmd.merge(data);var result=session.casino_action(cmd);expect(result.ok,"CM action "+action+": "+str(result.get("error","")));return result
func send(action: String, data: Dictionary={}) -> Dictionary:
	await create_timer(.18).timeout;var g=last.casino;var cmd={"action":action,"game_id":g.id,"revision":g.revision};cmd.merge(data);replies.clear();session.casino_action(cmd);await until(func():return not replies.is_empty(),"authenticated action acknowledgement");return replies.back() if not replies.is_empty() else {"ok":false}
func run() -> void:
	session=Hearth20Session.new();root.add_child(session);session.snapshot_received.connect(func(s):last=s.duplicate(true));session.casino_action_result.connect(func(r):replies.append(r));session.refreshment_event.connect(func(e):snack_events.append(e));session.refreshment_action_result.connect(func(r):snack_replies.append(r))
	var id="";var principal=""
	if role=="host":
		session.configure(Hearth20Identity.new_campaign("Synthetic multi-game network QA"));session.campaign.casino_house_cp=100000;session.dice_rng.seed=876123;expect(session.start_host(port).ok,"host starts");FileAccess.open(secret,FileAccess.WRITE).store_string(session.invite_secret)
		await wait("A-imported");await wait("B-imported")
	else:
		await until(func():return FileAccess.file_exists(secret),"invitation ready");expect(session.join_host("127.0.0.1",port,FileAccess.get_file_as_string(secret),role).ok,"player joins")
		await until(func():return last.get("character_required",false),"join requires named PNG pawn")
		var image=Image.create(48,48,false,Image.FORMAT_RGBA8);image.fill(Color.CORAL)
		expect(session.submit_join_character({"name":"Network guest "+role},image.save_png_to_buffer()).ok,"create named PNG pawn")
		await until(func():return not last.get("character_required",true),"pawn accepted");id=last.join_character_id;principal=session.local_player_id;mark(role+"-imported")
	# Real authenticated serving requests and events use the same stable RPC path.
	if role=="host":
		mark("snacks-admitted")
		await wait("A-snack-ordered");await wait("B-snack-ordered");mark("snacks-ordered")
		await wait("A-snack-bitten");await wait("B-snack-bitten")
		expect(snack_events.size()==4,"host hears exactly two orders and two eating events")
		expect(session.campaign.refreshments.size()==2 and session.campaign.refreshments.values().all(func(s):return s.food_bites==1 and s.drink_sips==0 and s.beers.is_empty()),"host counts one completed bite per identity")
		mark("snacks-checked");await wait("A-snacks-checked");await wait("B-snacks-checked")
	else:
		await wait("snacks-admitted")
		var own_food="chips" if role=="A" else "cake"
		session.refreshments_action({"action":"order","food":own_food,"drink":"beer" if role=="A" else "water"})
		await until(func():return not snack_replies.is_empty(),"server acknowledges order");expect(snack_replies.back().ok,"authenticated order accepted")
		await until(func():return last.get("refreshments",{}).get("order",{}).get("food","")==own_food,"own serving projected privately");mark(role+"-snack-ordered");await wait("snacks-ordered");await create_timer(.9).timeout
		snack_replies.clear();session.refreshments_action({"action":"bite","order_id":last.refreshments.order.id,"player_id":"forged-other-player"})
		await until(func():return not snack_replies.is_empty(),"bite acknowledgement");expect(snack_replies.back().ok,"server binds bite to authenticated identity")
		await until(func():return last.refreshments.food_bites==1,"server finishes bite");mark(role+"-snack-bitten");await wait("snacks-checked")
		expect(snack_events.size()==4 and snack_events.filter(func(e):return e.kind=="bite").size()==2,"each client receives each party eating event once")
		expect(last.refreshments.order.food==own_food and not last.refreshments.has("participants") and not last.refreshments.has("player_id"),"snapshot contains only own refreshment state")
		if role=="A":
			var order=last.refreshments.order.id;session.stop_session();await create_timer(.4).timeout;expect(session.join_host("127.0.0.1",port,FileAccess.get_file_as_string(secret),"A snacks restored").ok,"reconnect with unfinished serving")
			await until(func():return last.get("refreshments",{}).get("order",{}).get("id","")==order,"same serving restored");expect(last.refreshments.food_bites==1 and last.refreshments.drink_sips==0,"reconnect retains exact portions")
		mark(role+"-snacks-checked")
	for game_type in Hearth20CasinoGames.TYPES:
		var tag=game_type+"-"
		if role=="host":
			expect(session.set_table_mode("casino").ok,"DM selects shared casino mode");host("open",{"game":game_type,"chip_cp":10,"buyin":100,"minimum":1});mark(tag+"opened");await wait(tag+"A-ready");await wait(tag+"B-ready");host("start");mark(tag+"started")
			var funded=var_to_bytes(session.campaign.tavern_game);var funded_game=session.campaign.tavern_game
			expect(not session.casino_action({"action":"close","game_id":funded_game.id,"revision":funded_game.revision}).ok and funded==var_to_bytes(session.campaign.tavern_game),"changing game cannot discard funded escrow")
			await wait(tag+"A-checked");await wait(tag+"B-checked")
			var preserved=session.campaign.tavern_game.duplicate(true)
			expect(session.set_table_mode("map").ok,"DM switches away during active escrow");mark(tag+"map")
			await wait(tag+"A-map");await wait(tag+"B-map")
			expect(same_values(session.campaign.tavern_game,preserved),"switching to map preserves game, private dice and escrow")
			expect(session.set_table_mode("casino").ok,"DM resumes casino");mark(tag+"resumed")
			var path=Hearth20Identity.SAVE_ROOT+"/new-games."+Hearth20Identity.SAVE_EXTENSION
			expect(Hearth20Identity.save_campaign(session.campaign,path).ok,"save live gold escrow and game state");var loaded=Hearth20Identity.load_campaign(path)
			expect(loaded.ok and same_values(loaded.campaign.tavern_game,session.campaign.tavern_game) and loaded.campaign.casino_house_cp==session.campaign.casino_house_cp,"save/load preserves exact private dice, wagers and house reserve: "+str(loaded.get("errors",[])))
			if game_type=="gambit_of_ord":
				while session.campaign.tavern_game.phase!="between":
					if session.campaign.tavern_game.phase=="await_die":host("roll_next")
					else:host("check")
			elif game_type=="run_of_luck":
				host("lock_bets")
				for n in 3:host("race_stage")
			else:host("lock_bets");host("spin")
			mark(tag+"settled");await wait(tag+"A-settled");await wait(tag+"B-settled")
			if game_type=="gambit_of_ord":
				host("next");host("ruling_fold",{"actor_id":session.campaign.tavern_game.seats[0].actor_id});mark(tag+"folded");await wait(tag+"A-folded");await wait(tag+"B-folded")
			host("cashout");var bytes=var_to_bytes(session.campaign);var g=session.campaign.tavern_game;var again=session.casino_action({"action":"cashout","game_id":g.id,"revision":g.revision});expect(not again.ok and var_to_bytes(session.campaign)==bytes,"duplicate cashout cannot change a purse or ledger")
			mark(tag+"paid");await wait(tag+"A-paid");await wait(tag+"B-paid");host("close");mark(tag+"closed");await wait(tag+"A-closed");await wait(tag+"B-closed")
		else:
			await wait(tag+"opened");await until(func():return last.get("casino",{}).get("game","")==game_type,"party forced into selected table")
			if role=="B":await wait(tag+"A-ready")
			expect((await send("join",{"actor_id":id})).ok,"own token takes a seat");expect((await send("declare_balance",{"actor_id":id,"gp":100,"sp":3,"cp":7})).ok,"player declares own money");expect((await send("ready",{"actor_id":id})).ok,"own ready");mark(tag+role+"-ready");await wait(tag+"started")
			await until(func():return last.casino.phase=="betting","funded table snapshot")
			var mine=0 if role=="A" else 1;var other=1-mine;var g=last.casino
			expect(not g.has("house_cp") and not g.seats[other].has("wallet_cp") and not JSON.stringify(last).contains("PRIVATE_"+("B" if role=="A" else "A")),"other purse, raw sheet and casino bank are absent from packet")
			expect(not (await send("house_reserve",{"amount_cp":99999999})).ok,"player cannot fund casino money")
			expect(not (await send("fold" if game_type=="gambit_of_ord" else "wager",{"actor_id":g.seats[other].actor_id,"amount":5,"kind":"racer","number":0})).ok,"foreign token action is rejected")
			expect(not (await send("ready",{"actor_id":id,"revision":0})).ok,"stale game revision is rejected")
			if game_type=="gambit_of_ord":
				expect(g.seats[mine].dice.size()==1 and not g.seats[other].has("dice"),"private d8 never enters other player's packet")
				if role=="A":
					var remembered=g.seats[mine].dice.duplicate();session.stop_session();await create_timer(.4).timeout;expect(session.join_host("127.0.0.1",port,FileAccess.get_file_as_string(secret),"A returning").ok,"reconnect mid-gambit")
					await until(func():return session.local_player_id==principal and last.get("join_character_id","")==id and not last.get("casino",{}).is_empty(),"same identity and saved token restored")
					expect(last.casino.seats[mine].dice==remembered and not last.character_required,"reconnect retains private die without another buy-in or sheet")
			else:
				if role=="B":await wait(tag+"A-checked")
				expect((await send("wager",{"actor_id":id,"amount":5,"kind":"racer" if game_type=="run_of_luck" else "number","number":mine if game_type=="run_of_luck" else 12})).ok,"owned wager uses declared table balance")
			mark(tag+role+"-checked");await wait(tag+"map")
			await until(func():return last.get("table_mode","")=="map","shared map mode reaches player")
			expect(not last.casino.is_empty() and last.casino.game==game_type,"mode change retains private game snapshot")
			expect(not session.set_table_mode("casino").ok,"player cannot pull a DM mode control")
			mark(tag+role+"-map");await wait(tag+"resumed")
			await until(func():return last.get("table_mode","")=="casino","shared casino mode resumes for player")
			await wait(tag+"settled");await until(func():return last.casino.phase=="between","shared settlement arrives")
			if game_type=="gambit_of_ord":expect(last.casino.seats.all(func(s):return s.has("dice") and s.dice.size()==3),"surviving showdown totals are public")
			elif game_type=="run_of_luck":expect(last.casino.stage==3 and last.casino.race_rolls.size()==3,"all three host d4 stages are shared")
			else:expect(last.casino.result>=1 and last.casino.result<=20,"host committed wheel outcome is shared")
			mark(tag+role+"-settled")
			if game_type=="gambit_of_ord":
				await wait(tag+"folded");await until(func():return last.casino.round==2 and last.casino.phase=="between","fold-only settlement")
				expect(not last.casino.revealed and not last.casino.seats[other].has("dice"),"fold-only finish keeps both opponents' dice private");mark(tag+role+"-folded")
			await wait(tag+"paid");await until(func():return last.casino.phase=="complete","settlement updates persistent purse");expect(last.casino_receipts.size()==1 and last.casino_receipts[0].player_id==principal,"only own final balance notice arrives");var receipt=last.casino_receipts[0];expect(receipt.after_cp>=0 and receipt.delta_cp==receipt.after_cp-10037,"exact D&D Beyond update totals");expect((await send("acknowledge_balance",{"receipt_id":receipt.id})).ok,"player confirms manual website update");mark(tag+role+"-paid")
			await wait(tag+"closed");await until(func():return last.get("casino",{}).is_empty(),"CM returns all clients to map");mark(tag+role+"-closed")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"role":role,"checks":checks,"errors":errors},"\t"));session.stop_session();session.queue_free();await process_frame;print("Seated casino network %s: %d checks, %d failures."%[role,checks,errors.size()]);quit(0 if errors.is_empty() else 1)

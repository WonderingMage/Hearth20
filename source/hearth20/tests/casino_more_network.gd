extends SceneTree
var role=""
var port=0
var output=""
var secret=""
var folder=""
var session: Hearth20Session
var last={}
var replies=[]
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
	session=Hearth20Session.new();root.add_child(session);session.snapshot_received.connect(func(s):last=s.duplicate(true));session.casino_action_result.connect(func(r):replies.append(r))
	var id="";var principal=""
	if role=="host":
		session.configure(Hearth20Identity.new_campaign("Synthetic multi-game network QA"));session.campaign.casino_house_cp=100000;session.dice_rng.seed=876123;expect(session.start_host(port).ok,"host starts");FileAccess.open(secret,FileAccess.WRITE).store_string(session.invite_secret)
		await wait("A-imported");await wait("B-imported")
	else:
		await until(func():return FileAccess.file_exists(secret),"invitation ready");expect(session.join_host("127.0.0.1",port,FileAccess.get_file_as_string(secret),role).ok,"player joins")
		await until(func():return last.get("character_required",false),"join requires import")
		var sheet=Hearth20CharacterImport.new().from_fields({"CharacterName":"Network guest "+role,"CLASS LEVEL":"Cleric 3","GP":"100","AdditionalSenses":"Darkvision 300 ft.","AdditionalNotes1":"PRIVATE_"+role}).sheet
		expect(session.submit_join_character(sheet,PackedByteArray()).ok,"import synthetic campaign purse")
		await until(func():return not last.get("character_required",true),"import accepted");id=last.join_character_id;principal=session.local_player_id;mark(role+"-imported")
	for game_type in Hearth20CasinoGames.TYPES:
		var tag=game_type+"-"
		if role=="host":
			host("open",{"game":game_type,"chip_cp":10,"buyin":100,"minimum":1});mark(tag+"opened");await wait(tag+"A-ready");await wait(tag+"B-ready");host("start");mark(tag+"started")
			await wait(tag+"A-checked");await wait(tag+"B-checked")
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
			expect((await send("join",{"actor_id":id})).ok,"own token takes a seat");expect((await send("ready",{"actor_id":id})).ok,"own ready");mark(tag+role+"-ready");await wait(tag+"started")
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
				expect((await send("wager",{"actor_id":id,"amount":5,"kind":"racer" if game_type=="run_of_luck" else "number","number":mine if game_type=="run_of_luck" else 12})).ok,"owned wager uses imported hoard")
			mark(tag+role+"-checked");await wait(tag+"settled");await until(func():return last.casino.phase=="between","shared settlement arrives")
			if game_type=="gambit_of_ord":expect(last.casino.seats.all(func(s):return s.has("dice") and s.dice.size()==3),"surviving showdown totals are public")
			elif game_type=="run_of_luck":expect(last.casino.stage==3 and last.casino.race_rolls.size()==3,"all three host d4 stages are shared")
			else:expect(last.casino.result>=1 and last.casino.result<=20,"host committed wheel outcome is shared")
			mark(tag+role+"-settled")
			if game_type=="gambit_of_ord":
				await wait(tag+"folded");await until(func():return last.casino.round==2 and last.casino.phase=="between","fold-only settlement")
				expect(not last.casino.revealed and not last.casino.seats[other].has("dice"),"fold-only finish keeps both opponents' dice private");mark(tag+role+"-folded")
			await wait(tag+"paid");await until(func():return last.casino.phase=="complete","settlement updates persistent purse");expect(last.sheets[0].coins is Dictionary,"settled coin denominations remain in imported sheet");mark(tag+role+"-paid")
			await wait(tag+"closed");await until(func():return last.get("casino",{}).is_empty(),"CM returns all clients to map");mark(tag+role+"-closed")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"role":role,"checks":checks,"errors":errors},"\t"));session.stop_session();session.queue_free();await process_frame;print("More casino network %s: %d checks, %d failures."%[role,checks,errors.size()]);quit(0 if errors.is_empty() else 1)

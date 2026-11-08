extends SceneTree
var role=""
var port=0
var output=""
var secret=""
var folder=""
var session: Hearth20Session
var last: Dictionary={}
var replies: Array=[]
var submitted: Array=[]
var checks=0
var errors=[]
func _initialize() -> void:
	var args=OS.get_cmdline_user_args();role=args[0];port=int(args[1]);output=args[2];secret=args[3];folder=args[4];call_deferred("run")
func expect(ok: bool, text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error("FAIL: "+text)
func mark(name_value: String) -> void:FileAccess.open(folder.path_join("casino-"+name_value+".ready"),FileAccess.WRITE).store_string("ready")
func wait_mark(name_value: String) -> void:
	var file=folder.path_join("casino-"+name_value+".ready");var end=Time.get_ticks_msec()+20000
	while not FileAccess.file_exists(file) and Time.get_ticks_msec()<end:await process_frame
	expect(FileAccess.file_exists(file),"sync "+name_value)
func until(predicate: Callable, label: String) -> void:
	var end=Time.get_ticks_msec()+20000
	while not predicate.call() and Time.get_ticks_msec()<end:await process_frame
	expect(predicate.call(),label)
func command(action: String, extra: Dictionary={}) -> Dictionary:
	await create_timer(.16).timeout;var g=last.get("casino",{});var request={"action":action,"game_id":g.get("id",""),"revision":g.get("revision",0)};request.merge(extra)
	replies.clear();var result=session.casino_action(request)
	if not result.ok:return result
	await until(func():return not replies.is_empty(),"casino command acknowledged")
	return replies.back() if not replies.is_empty() else {"ok":false}
func host_command(action: String, extra: Dictionary={}) -> Dictionary:
	var g=session.campaign.get("tavern_game",{});var request={"action":action,"game_id":g.get("id",""),"revision":g.get("revision",0)};request.merge(extra);return session.casino_action(request)
func sheet() -> Dictionary:
	return Hearth20CharacterImport.new().from_fields({"CharacterName":"Synthetic guest "+role,"CLASS LEVEL":"Wizard 3","STR":"10","DEX":"14","CON":"12","INT":"18","WIS":"12","CHA":"10","AC":"12","MaxHP":"23","CurrentHP":"23","Speed":"30","GP":"25","AdditionalSenses":"Darkvision 60 ft.","AdditionalNotes1":"PRIVATE_OWNER_"+role}).sheet
func run() -> void:
	session=Hearth20Session.new();session.name="CasinoSession";root.add_child(session);session.snapshot_received.connect(func(s):last=s.duplicate(true));session.casino_action_result.connect(func(result):replies.append(result));session.character_submission_result.connect(func(result):submitted.append(result))
	if role=="host":
		var campaign=Hearth20Identity.new_campaign("Casino network fixture");session.configure(campaign);session.dice_rng.seed=373311
		expect(session.start_host(port).ok,"host starts");FileAccess.open(secret,FileAccess.WRITE).store_string(session.invite_secret)
		await wait_mark("A-imported");await wait_mark("B-imported")
		expect(campaign.actors.size()==2 and campaign.actors.all(func(a):return a.in_inventory and a.token_size==1. and a.movement_policy.mode=="blocked"),"player imports create two distinct stored size-one blocked tokens")
		expect(campaign.actors.all(func(a):return a.coins.gp==25 and a.vision.darkvision_feet==60 and not a.png_asset_id.is_empty()),"sheet gold, senses and custom PNG received")
		expect(campaign.participants.size()==2 and campaign.participants.values().all(func(p):return p.has("character_id")),"authenticated player-character mappings recorded")
		expect(host_command("open",{"chip_cp":10}).ok,"only CM opens the synchronized game");mark("open")
		await wait_mark("A-ready");await wait_mark("B-ready")
		expect(host_command("start").ok,"CM deals both ready player seats")
		var g=campaign.tavern_game;FileAccess.open(folder.path_join("casino-private-hands.json"),FileAccess.WRITE).store_string(JSON.stringify({"a":g.seats[0].hand[0],"b":g.seats[1].hand[0],"actor_a":g.seats[0].actor_id}));mark("dealt")
		await wait_mark("A-rejoined");await wait_mark("B-private-checked")
		expect(campaign.actors.size()==2 and campaign.actors.all(func(a):return Hearth20TavernGames.purse(a)==2300),"reconnect and repeat import cannot duplicate actors or restore spent buy-ins")
		var path=Hearth20Identity.SAVE_ROOT+"/live-casino."+Hearth20Identity.SAVE_EXTENSION;var saved=Hearth20Identity.save_campaign(campaign,path);var loaded=Hearth20Identity.load_campaign(path)
		expect(saved.ok and loaded.ok and loaded.campaign.tavern_game.seats[0].ante==campaign.tavern_game.seats[0].ante and loaded.campaign.tavern_game.escrow_cp==400,"saved live game retains private ante and exact escrow")
		mark("reveal");await wait_mark("B-anted")
		g=campaign.tavern_game;expect(g.phase=="play" and g.ante.size()==2,"all antes reveal together")
		expect(host_command("play",{"card_id":g.seats[g.turn].hand[0]}).ok,"CM can resolve a controlled dealer action");mark("played")
		await wait_mark("A-public-checked");await wait_mark("B-public-checked")
		expect(host_command("cancel").ok,"CM cancels and refunds active game")
		expect(campaign.actors.all(func(a):return Hearth20TavernGames.purse(a)==2500) and campaign.tavern_ledger.size()==4,"two buy-ins and two exact refunds recorded once")
		mark("refunded");await wait_mark("A-refund-checked");await wait_mark("B-refund-checked")
		expect(host_command("close").ok,"CM returns the whole party to the map");mark("closed");await wait_mark("A-closed");await wait_mark("B-closed")
	else:
		await until(func():return FileAccess.file_exists(secret),"host invitation ready")
		expect(session.join_host("127.0.0.1",port,FileAccess.get_file_as_string(secret),role).ok,"player authenticates")
		await until(func():return not session.local_player_id.is_empty() and last.get("character_required",false),"first join requires character import")
		expect(last.get("sheets",[]).is_empty(),"no character sheet is manufactured by the DM before import")
		var image=Image.create(64,64,false,Image.FORMAT_RGBA8);image.fill(Color.CORAL if role=="A" else Color.GOLD);var imported_sheet=sheet()
		expect(session.submit_join_character(imported_sheet,image.save_png_to_buffer()).ok,"player sends reviewed sheet and PNG")
		await until(func():return not last.get("character_required",true) and not last.get("join_character_id","").is_empty(),"host accepts one unique campaign character")
		var id=str(last.get("join_character_id",""));var principal=session.local_player_id
		expect(last.sheets.size()==1 and last.sheets[0].coins.gp==25 and not JSON.stringify(last).contains("PRIVATE_OWNER_"+("B" if role=="A" else "A")),"only own imported gold and raw sheet data returned")
		mark(role+"-imported");await wait_mark("open")
		if role=="B":await wait_mark("A-ready")
		var result=await command("join",{"actor_id":id});expect(result.ok,"player chooses own imported casino seat")
		result=await command("ready",{"actor_id":id});expect(result.ok,"player readies the stated purse buy-in");mark(role+"-ready")
		await wait_mark("dealt");await until(func():return last.get("casino",{}).get("phase","")=="ante","private hand arrives")
		var hidden=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("casino-private-hands.json")));var own_index=0 if role=="A" else 1;var other_index=1-own_index;var g=last.casino
		expect(g.seats[own_index].hand.size()==6 and not g.seats[other_index].has("hand") and not g.has("deck") and not JSON.stringify(g).contains('"'+str(hidden.b if role=="A" else hidden.a)+'"'),"recipient has own faces, other hand counts only, no deck order")
		expect(last.sheets[0].coins.gp==23,"buy-in taken from actual imported purse")
		if role=="A":
			result=await command("ante",{"actor_id":id,"card_id":hidden.a});expect(result.ok,"own hidden ante committed")
			session.stop_session();await create_timer(.5).timeout;expect(session.join_host("127.0.0.1",port,FileAccess.get_file_as_string(secret),"A returning").ok,"same identity reconnects")
			await until(func():return session.local_player_id==principal and last.get("join_character_id","")==id,"returning identity restores the same unique token")
			expect(not last.character_required and last.sheets[0].coins.gp==23 and last.casino.seats[0].private_ante==hidden.a,"rejoin resumes saved purse and hidden ante without another PDF")
			imported_sheet.coins.gp=999;submitted.clear();session.submit_join_character(imported_sheet,PackedByteArray());await until(func():return not submitted.is_empty(),"repeat submission acknowledged")
			expect(submitted.back().get("existing",false) and last.sheets[0].coins.gp==23,"repeat import cannot mint gold");mark("A-rejoined")
		else:
			result=await command("ante",{"actor_id":hidden.actor_a,"card_id":hidden.a});expect(not result.ok,"foreign hidden-card command rejected")
			mark("B-private-checked");await wait_mark("reveal")
			g=last.casino;var selected=""
			for card_id in g.seats[1].hand:
				if Hearth20TavernGames.card(card_id).strength!=Hearth20TavernGames.card(hidden.a).strength:selected=card_id;break
			result=await command("ante",{"actor_id":id,"card_id":selected});expect(result.ok,"second ante reveals public cards");mark("B-anted")
		await wait_mark("played");await until(func():return last.get("casino",{}).get("seats",[]).any(func(s):return not s.flight.is_empty()),"played card is public on shared table")
		expect(not last.casino.seats[other_index].has("hand"),"public play never exposes the rest of another hand");mark(role+"-public-checked")
		await wait_mark("refunded");await until(func():return last.sheets[0].coins.gp==25,"refund returns exact imported gold");mark(role+"-refund-checked")
		await wait_mark("closed");await until(func():return last.get("casino",{}).is_empty(),"CM closes every client's casino");mark(role+"-closed")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"role":role,"checks":checks,"errors":errors},"\t"));session.stop_session();session.queue_free();await process_frame
	print("Casino network %s: %d checks, %d failures."%[role,checks,errors.size()]);quit(0 if errors.is_empty() else 1)

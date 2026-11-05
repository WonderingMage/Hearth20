extends SceneTree
var session: Hearth20Session
var role: String
var output: String
var secret: String
var folder: String
var port:=0
var checks:=0
var errors: Array=[]
var rolls: Array=[]
var snapshots:=0
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args(); role=args[0]; port=int(args[1]); output=args[2]; secret=args[3]; folder=args[4]; call_deferred("run")
func expect(ok: bool, note: String) -> void:
	checks+=1
	if not ok: errors.append(note); push_error("FAIL: "+note)
func marker(name_value: String) -> String: return folder.path_join("dice-"+name_value+".ready")
func wait_marker(name_value: String) -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while not FileAccess.file_exists(marker(name_value)) and Time.get_ticks_msec()<deadline: await process_frame
	expect(FileAccess.file_exists(marker(name_value)),"synchronization: "+name_value)
func mark(name_value: String) -> void: FileAccess.open(marker(name_value),FileAccess.WRITE).store_string("ready")
func run() -> void:
	session=Hearth20Session.new(); root.add_child(session); session.dice_rolled.connect(func(entry): rolls.append(entry.duplicate(true))); session.snapshot_received.connect(func(_entry): snapshots+=1)
	if role=="host":
		session.configure(Hearth20Identity.new_campaign("Live dice visibility test")); expect(session.start_host(port).ok,"DM starts real ENet host"); FileAccess.open(secret,FileAccess.WRITE).store_string(session.invite_secret)
		await wait_marker("A-joined"); await wait_marker("B-joined"); mark("start")
		await wait_marker("A-rolled"); await create_timer(.5).timeout
		expect(session.submit_roll("","dice","","normal","secret","1d8+401").ok,"DM-only roll accepted")
		await create_timer(.5).timeout; mark("settled"); await wait_marker("A-checked"); await wait_marker("B-checked")
		expect(rolls.size()==3,"host sees public, player-and-GM, and GM-only live animations")
		expect(rolls.any(func(entry): return entry.formula=="1d20+101" and entry.dice.size()==2),"host receives both advantage d20 values")
		expect(not rolls.any(func(entry): return entry.formula=="1d6+202"),"roller-only animation never reaches the DM")
		var stored: Array=session.campaign.table_timeline.filter(func(entry): return entry.formula=="1d20+101")
		var live:=rolls.filter(func(entry): return entry.formula=="1d20+101")
		expect(not stored.is_empty() and not live.is_empty() and live[0].dice==stored[0].dice,"live animation packet matches the authoritative result")
		expect(rolls.filter(func(entry): return entry.formula=="1d8+401").all(func(entry): return entry.dice_set=="dm"),"DM private roll is forced to the supplied DM collection")
		expect(rolls.filter(func(entry): return entry.formula=="1d20+101").all(func(entry): return entry.dice_set=="set-7"),"host uses the roller-selected player collection")
		var received_ids:=rolls.map(func(entry): return entry.id)
		expect(not received_ids.has("FORGED_DICE"),"host rejects a client-authored animation packet")
		mark("done")
	else:
		var deadline:=Time.get_ticks_msec()+15000
		while not FileAccess.file_exists(secret) and Time.get_ticks_msec()<deadline: await process_frame
		expect(FileAccess.file_exists(secret),"host invitation exists")
		expect(session.join_host("127.0.0.1",port,FileAccess.get_file_as_string(secret),role).ok,"player joins real host")
		while (session.local_player_id.is_empty() or session.client_snapshot.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
		expect(not session.local_player_id.is_empty() and not session.client_snapshot.is_empty() and rolls.is_empty(),"authenticated initial campaign history produces no dice animation")
		mark(role+"-joined"); await wait_marker("start")
		if role=="A":
			Hearth20PlayerProfile.remember_dice_set("set-7")
			session.submit_roll("","dice","","advantage","public","1d20+101")
			session.submit_roll("","dice","","normal","self","1d6+202")
			session.submit_roll("","dice","","normal","gm","1d4+303")
			var forged:=Hearth20Identity.network_identity(); forged.merge({"id":"FORGED_DICE","type":"roll","dice":[20,20],"formula":"2d20","total":40})
			session.receive_dice_animation.rpc_id(1,forged); await create_timer(.5).timeout; mark("A-rolled")
		await wait_marker("settled"); await create_timer(.3).timeout
		if role=="A":
			expect(rolls.size()==3,"roller sees public, own-only, and player-and-GM animations")
			expect(not rolls.any(func(entry): return entry.formula=="1d8+401"),"GM-only animation never reaches the roller")
		else:
			expect(rolls.size()==1 and rolls[0].formula=="1d20+101","other player receives only the public animation")
		expect(not rolls.is_empty() and rolls[0].dice.size()==2 and rolls[0].mode=="advantage","public advantage has two actual d20 outcomes")
		expect(rolls[0].dice_set=="set-7","public audience receives the roller-selected collection")
		mark(role+"-checked"); await wait_marker("done")
	session.stop_session(); session.queue_free(); await process_frame; await process_frame; Hearth20PlayerProfile.cached_key=null
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"role":role,"checks":checks,"errors":errors,"rolls":rolls}))
	print("Cinematic network %s: %d checks, %d failures."%[role,checks,errors.size()]); quit(0 if errors.is_empty() else 1)

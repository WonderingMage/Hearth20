extends SceneTree
var role=""
var folder=""
var port=0
var checks=0
var errors=[]
var session: Hearth20Session
var replies=[]
func _initialize() -> void:
	var args=OS.get_cmdline_user_args();role=args[0];port=int(args[1]);folder=args[2];call_deferred("run")
func expect(ok: bool,text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error(text)
func mark(file: String) -> void:FileAccess.open(folder.path_join(file+".ready"),FileAccess.WRITE).store_string("ready")
func until(predicate: Callable,text: String) -> void:
	var end=Time.get_ticks_msec()+20000
	while not predicate.call() and Time.get_ticks_msec()<end:await process_frame
	expect(predicate.call(),text)
func wait(file: String) -> void:await until(func():return FileAccess.file_exists(folder.path_join(file+".ready")),file)
func run() -> void:
	session=Hearth20Session.new();root.add_child(session);session.avatar_result.connect(func(result):replies.append(result))
	var secret=folder.path_join("invitation.txt")
	if role=="host":
		session.configure(Hearth20Identity.new_campaign("Wizard RPC fixture"));expect(session.set_avatar(Hearth20AvatarStyle.defaults(true)).ok,"host wears a D20")
		expect(session.start_host(port).ok,"host starts");FileAccess.open(secret,FileAccess.WRITE).store_string(session.invite_secret)
		await wait("A-checked");await wait("B-checked")
		expect(session.remote_players.size()==2,"two authenticated guests joined")
		for id in session.remote_players:expect(session.campaign.participants[id].avatar.pendant=="none","no guest gained a D20")
		expect(session.campaign.host_avatar.pendant=="d20","forged requests did not alter host")
		mark("host-checked");await wait("A-departure-checked")
	else:
		await until(func():return FileAccess.file_exists(secret),"invitation ready")
		expect(session.join_host("127.0.0.1",port,FileAccess.get_file_as_string(secret),role).ok,"guest connects")
		await until(func():return session.table_roster.size()==3,"all participants visible while tokens remain in inventory")
		expect(session.table_roster.filter(func(entry):return entry.host and entry.style.pendant=="d20").size()==1,"authoritative DM alone wears D20")
		await create_timer(.4).timeout;replies.clear()
		# Bypass the local UI validator deliberately: exercise the authenticated RPC.
		session.request_avatar.rpc_id(1,Hearth20AvatarStyle.defaults(true))
		await until(func():return not replies.is_empty(),"forged equip acknowledged")
		expect(not replies.back().ok,"server rejects forged player D20")
		await create_timer(.3).timeout;replies.clear();var forged=Hearth20AvatarStyle.defaults(false);forged.role="dm-local"
		session.request_avatar.rpc_id(1,forged);await until(func():return not replies.is_empty(),"role spoof acknowledged");expect(not replies.back().ok,"role spoof rejected")
		await create_timer(.3).timeout;replies.clear();var bad_eyes=Hearth20AvatarStyle.defaults(false);bad_eyes.eye_style="untrusted/path";session.request_avatar.rpc_id(1,bad_eyes)
		await until(func():return not replies.is_empty(),"invalid eye style acknowledged");expect(not replies.back().ok,"host rejects unsupported eye choices")
		await create_timer(.3).timeout;replies.clear();bad_eyes=Hearth20AvatarStyle.defaults(false);bad_eyes.eye_treatment="untrusted/path";session.request_avatar.rpc_id(1,bad_eyes)
		await until(func():return not replies.is_empty(),"invalid eye treatment acknowledged");expect(not replies.back().ok,"host rejects unsupported eye treatment")
		await create_timer(.3).timeout;replies.clear();var style=Hearth20AvatarStyle.defaults(false);style.robe="emerald" if role=="A" else "crimson";style.metal="silver";style.eye_style="hearts" if role=="A" else "stars";style.eye_color="ice" if role=="A" else "violet"
		style.eye_treatment="cartoon" if role=="A" else "visor"
		expect(session.set_avatar(style).ok,"valid wardrobe sent")
		await until(func():return not replies.is_empty(),"valid wardrobe acknowledged");expect(replies.back().ok,"server accepts ordinary jewelry")
		await until(func():return session.table_roster.any(func(entry):return entry.mine and entry.style==style),"roster reflects own approved appearance")
		expect(session.table_roster.all(func(entry):return entry.size()==5 and entry.get("sheet")==null and entry.get("public_key")==null),"public presence has no sheet or private key data")
		mark(role+"-checked");await wait("host-checked")
		var other="B" if role=="A" else "A";var other_eyes="stars" if role=="A" else "hearts"
		var other_treatment="visor" if role=="A" else "cartoon"
		expect(session.table_roster.any(func(entry):return entry.name==other and entry.style.eye_style==other_eyes and entry.style.eye_treatment==other_treatment),"other guest's selected eyes and treatment replicate across authenticated clients")
		if role=="A":
			await until(func():return session.table_roster.size()==2,"departed player disappears from other client's roster");mark("A-departure-checked")
	session.stop_session();session.queue_free();await process_frame;await process_frame
	FileAccess.open(folder.path_join(role+".json"),FileAccess.WRITE).store_string(JSON.stringify({"role":role,"checks":checks,"errors":errors},"  "));quit.call_deferred(0 if errors.is_empty() else 1)

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
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func mark(file: String) -> void:FileAccess.open(folder.path_join(file+".ready"),FileAccess.WRITE).store_string("ready")
func until(predicate: Callable,note: String) -> void:
	var end=Time.get_ticks_msec()+15000
	while not predicate.call() and Time.get_ticks_msec()<end:await process_frame
	expect(predicate.call(),note)
func wait(file: String) -> void:await until(func():return FileAccess.file_exists(folder.path_join(file+".ready")),file)
func action(command: Dictionary,ok=true) -> void:
	replies.clear();expect(session.board_action(command).ok,"board request submitted")
	await until(func():return not replies.is_empty(),"board result arrives")
	expect((replies.back()=="Recorded at the table.")==ok,"host enforces "+command.action)
func objects() -> Array:return session.client_snapshot.get("scene",{}).get("annotations",[])
func run() -> void:
	session=Hearth20Session.new();root.add_child(session);session.status_changed.connect(func(note):replies.append(note))
	var invitation=folder.path_join("invitation.txt")
	if role=="host":
		session.configure(Hearth20Identity.new_campaign("Drawing selection RPC fixture"));expect(session.start_host(port).ok,"host starts");FileAccess.open(invitation,FileAccess.WRITE).store_string(session.invite_secret)
		await until(func():return session.remote_players.size()==2,"two authenticated players joined")
		for player in session.remote_players:
			var hero=Hearth20TokenInventory.new_actor("Hero",true,session.campaign.scenes[0],Vector2(1.5,1.5));hero.owner_player_id=player;session.campaign.actors.append(hero)
		session._broadcast_snapshots();mark("setup")
		await wait("A-drawn");await wait("B-drawn");var page=session.campaign.scenes[0];var order=page.annotations.map(func(object):return object.id)
		expect(order.size()==3,"host records all three drawings")
		await wait("B-forgery");expect(page.annotations.map(func(object):return object.id)==order,"forged mixed-owner deletion changed no drawings");mark("delete-now")
		await wait("A-deleted");expect(page.annotations.size()==1,"one network action deleted only A's group");mark("undo-now")
		await wait("A-undone");expect(page.annotations.map(func(object):return object.id)==order,"network undo restored original drawing order");mark("done");await wait("B-checked")
	else:
		await until(func():return FileAccess.file_exists(invitation),"invitation ready")
		expect(session.join_host("127.0.0.1",port,FileAccess.get_file_as_string(invitation),role).ok,"guest joins")
		await wait("setup");await until(func():return session.client_snapshot.get("scene",{}).get("id","") not in ["","unplaced"],"token-bound map is ready")
		var count=2 if role=="A" else 1
		for i in count:await action({"action":"add","object":{"kind":"line","layer":"tokens","points":[Vector2(3+i,3),Vector2(4+i,4)],"color":"#22d5fa","width":3.}})
		await until(func():return objects().filter(func(object):return object.get("mine",false)).size()==count,"own drawings replicate")
		var ids=objects().filter(func(object):return object.get("mine",false)).map(func(object):return str(object.id))
		if role=="A":FileAccess.open(folder.path_join("a-ids.json"),FileAccess.WRITE).store_string(JSON.stringify(ids))
		mark(role+"-drawn");await wait("A-drawn");await wait("B-drawn")
		if role=="A":
			await wait("delete-now");await action({"action":"delete_many","ids":ids});await until(func():return objects().size()==1,"deleted group disappears from A's map");mark("A-deleted")
			await wait("undo-now");await action({"action":"undo"});await until(func():return objects().size()==3,"undo group returns to A's map");mark("A-undone");await wait("done")
		else:
			var other=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("a-ids.json")))
			await action({"action":"delete_many","ids":[ids[0],other[0]]},false);expect(objects().any(func(object):return object.id==ids[0]),"rejected group keeps B's own drawing too");mark("B-forgery")
			await wait("done");await until(func():return objects().size()==3,"B sees the restored group");expect(objects().filter(func(object):return object.get("mine",false)).size()==1,"B retains only their own editing rights");mark("B-checked")
	session.stop_session();session.queue_free();await process_frame;await process_frame
	FileAccess.open(folder.path_join(role+".json"),FileAccess.WRITE).store_string(JSON.stringify({"role":role,"checks":checks,"errors":errors},"  "));quit.call_deferred(0 if errors.is_empty() else 1)

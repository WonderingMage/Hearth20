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
func action(command: Dictionary,ok: bool) -> void:
	replies.clear();expect(session.belongings_action(command).ok,"request sent: "+command.action)
	await until(func():return not replies.is_empty(),"host acknowledges "+command.action);expect(replies.back().ok==ok,"host enforces "+command.action)
func connect_guest(secret: String) -> void:
	expect(session.join_host("127.0.0.1",port,secret,role).ok,"guest connects")
	await until(func():return session.client_snapshot.get("belongings_supported",false),"updated host advertises items and journals")
func run() -> void:
	session=Hearth20Session.new();root.add_child(session);session.belongings_result.connect(func(result):replies.append(result))
	var invitation=folder.path_join("invitation.txt")
	if role=="host":
		session.configure(Hearth20Identity.new_campaign("Inventory RPC fixture"));expect(session.start_host(port).ok,"host starts");FileAccess.open(invitation,FileAccess.WRITE).store_string(session.invite_secret)
		await until(func():return session.remote_players.size()==2,"two authenticated identities admitted")
		for player in session.remote_players:
			var hero=Hearth20TokenInventory.new_actor("Hero",true,session.campaign.scenes[0],Vector2(2.5,2.5));hero.owner_player_id=player;session.campaign.actors.append(hero)
		var image=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.ORANGE)
		var created=session.create_custom_item("NETWORK ORANGE KEY","UNIQUE ITEM",image.save_png_to_buffer());var id=str(created.id)
		session.belongings_action({"action":"place","id":id,"position":Vector2(3.5,3.5)});session.belongings_action({"action":"hide","id":id,"hidden":false});mark("item-ready")
		await wait("A-claimed");await wait("B-notes")
		var path=Hearth20Identity.SAVE_ROOT+"/rpc-items.h20scampaign";expect(Hearth20Identity.save_campaign(session.campaign,path).ok,"host saves network-received notes and inventory")
		var loaded=Hearth20Identity.load_campaign(path);expect(loaded.ok and loaded.campaign.player_journals.values().has("PRIVATE-A-NOTES") and loaded.campaign.player_journals.values().has("PRIVATE-B-NOTES") and loaded.campaign.custom_items[0].holder.begins_with("player-"),"save reload preserves both journals and item owner")
		mark("saved");await wait("A-reconnected");await wait("B-attacked");mark("destroy-now");await wait("A-destroyed")
		expect(session.campaign.custom_items.is_empty(),"owner destruction reaches host")
		expect(Hearth20Identity.save_campaign(session.campaign,path).ok and Hearth20Identity.load_campaign(path).campaign.custom_items.is_empty(),"final host save keeps destruction")
		mark("finished");await wait("B-finished")
	else:
		await until(func():return FileAccess.file_exists(invitation),"invitation ready")
		var secret=FileAccess.get_file_as_string(invitation);await connect_guest(secret)
		await wait("item-ready");await until(func():return session.client_snapshot.get("board_items",[]).size()==1,"visible item arrives with authorized snapshot")
		var id=str(session.client_snapshot.board_items[0].id);var mine=session.local_player_id
		await action({"action":"notes","text":"PRIVATE-"+role+"-NOTES"},true)
		await until(func():return session.client_snapshot.get("personal_notes")=="PRIVATE-"+role+"-NOTES","own journal echoes from host")
		if role=="A":
			await action({"action":"pickup","id":id},true);await until(func():return session.client_snapshot.get("item_inventory",[]).size()==1,"claimed item reaches owner inventory");mark("A-claimed")
			await wait("saved");session.stop_session();await create_timer(.3).timeout;await connect_guest(secret)
			expect(session.local_player_id==mine,"same authenticated identity restored after reconnect")
			await until(func():return session.client_snapshot.get("item_inventory",[]).size()==1 and session.client_snapshot.get("personal_notes")=="PRIVATE-A-NOTES","reconnect restores private notes and inventory without a new token")
			expect(not JSON.stringify(session.client_snapshot).contains("PRIVATE-B-NOTES"),"A never receives B's notes");mark("A-reconnected")
			await wait("destroy-now");await action({"action":"destroy","id":id},true);await until(func():return session.client_snapshot.get("item_inventory",[]).is_empty(),"destroyed item disappears from owner view");mark("A-destroyed");await wait("finished")
		else:
			mark("B-notes");await wait("A-claimed");await wait("A-reconnected")
			expect(session.client_snapshot.get("item_inventory",[]).is_empty() and not JSON.stringify(session.client_snapshot).contains("PRIVATE-A-NOTES"),"B never receives A's owned item or journal")
			await action({"action":"pickup","id":id},false);await action({"action":"destroy","id":id},false)
			var target=""
			for entry in session.table_roster:
				if entry.name=="A":target=entry.id
			await action({"action":"notes","target":target,"text":"HACKED"},false);mark("B-attacked");await wait("finished");mark("B-finished")
	session.stop_session();session.queue_free();await process_frame;await process_frame
	FileAccess.open(folder.path_join(role+".json"),FileAccess.WRITE).store_string(JSON.stringify({"role":role,"checks":checks,"errors":errors},"  "));quit.call_deferred(0 if errors.is_empty() else 1)

extends SceneTree
## Five independent authenticated processes; no Steam account or user game.
class LinkFixture extends Node:
	var session: Hearth20Session
	var initialized=true
	var closing=false
	var hold=false
	var next_send=0
	func allows_peer(id: int) -> bool:return id in session.multiplayer.get_peers()
	func can_send(id: int) -> bool:
		if hold or not allows_peer(id) or Time.get_ticks_msec()<next_send:return false
		next_send=Time.get_ticks_msec()+12;return true
	func transfer_update(_value: float,_note: String) -> void:pass
	func connection_lost() -> void:session.stop_session()
	func disconnect_table() -> void:pass
var session: Hearth20Session
var link: LinkFixture
var role=""
var folder=""
var output=""
var port=0
var last={}
var checks=0
var errors=[]
var progress=[]
var pings=[]
func _initialize() -> void:
	var args=OS.get_cmdline_user_args();role=args[0];port=int(args[1]);output=args[2];folder=args[3];call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func until(predicate: Callable,note: String) -> void:
	var deadline=Time.get_ticks_msec()+30000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	expect(predicate.call(),note)
func mark(label: String) -> void:FileAccess.open(folder.path_join(label+".ready"),FileAccess.WRITE).store_string("ready")
func wait(label: String) -> void:await until(func():return FileAccess.file_exists(folder.path_join(label+".ready")),"sync "+label)
func all_marked(label: String) -> bool:
	for i in range(1,5):
		if not FileAccess.file_exists(folder.path_join(label+"-"+str(i)+".ready")):return false
	return true
func noise(seed_value: int) -> PackedByteArray:
	var random=RandomNumberGenerator.new();random.seed=seed_value;var bytes=PackedByteArray();bytes.resize(512*384*3)
	for i in bytes.size():bytes[i]=random.randi()%256
	return Image.create_from_data(512,384,false,Image.FORMAT_RGB8,bytes).save_png_to_buffer()
func expected_map(index: int) -> PackedByteArray:
	return Hearth20Contracts._mask_fogged_map(noise(1871+index),{"cell_pixels":32.,"fog_rects":[Rect2(0,0,1,1)]})
func my_map(index: int) -> bool:
	return last.get("scene",{}).get("id","")==Hearth20Contracts._neutral_id(session.local_player_id,"scene:page-"+str(index))
func run() -> void:
	create_timer(110).timeout.connect(func():push_error("Map network watchdog");quit(1))
	session=Hearth20Session.new();session.name="Hearth20Session";root.add_child(session);session.configure(Hearth20Identity.new_campaign("Background map fixture"))
	session.status_changed.connect(func(note):print(role+" STATUS "+note))
	session.snapshot_received.connect(func(value):last=value)
	session.map_transfer_progress.connect(func(value):progress.append(value))
	session.ping_received.connect(func(value):pings.append(value))
	link=LinkFixture.new();root.add_child(link);link.session=session;session.steam_link=link
	var peer=ENetMultiplayerPeer.new();var gate="b".repeat(32)
	if role=="host":
		for i in 3:
			var scene=session.campaign.scenes[0].duplicate(true);scene.id="page-"+str(i);scene.width_cells=16;scene.height_cells=12;scene.cell_pixels=32.;scene.fog_rects=[Rect2(0,0,1,1)];scene.annotations=[]
			scene.map_asset=Hearth20Assets.store_asset(session.campaign,Hearth20Assets.inspect_map_bytes(noise(1871+i)),"map")
			if i==0:session.campaign.scenes[0]=scene
			else:session.campaign.scenes.append(scene)
		session.campaign.active_scene="page-0";session.campaign.dm_notes="MAP-NETWORK-GM-SECRET"
		var decoration=Image.create(40,40,false,Image.FORMAT_RGBA8);decoration.fill(Color.CORAL)
		var art=Hearth20Assets.store_asset(session.campaign,Hearth20Assets.inspect_token_png_bytes(decoration.save_png_to_buffer()),"token")
		for i in 2:
			var prop=Hearth20TokenInventory.new_actor("Foreground",false,session.campaign.scenes[i],Vector2(10.5,5.5));prop.decorative=true;prop.hidden=false;prop.layer="foreground";prop.png_asset_id=art;session.campaign.actors.append(prop)
		decoration.fill(Color.MAGENTA)
		var secret=Hearth20TokenInventory.new_actor("GM-FORE-SECRET",false,session.campaign.scenes[2],Vector2(9.5,5.5));secret.decorative=true;secret.layer="gm";secret.png_asset_id=Hearth20Assets.store_asset(session.campaign,Hearth20Assets.inspect_token_png_bytes(decoration.save_png_to_buffer()),"token");session.campaign.actors.append(secret)
		link.hold=true
		expect(peer.create_server(port,8)==OK and session.adopt_steam_peer(peer,true,gate,"").ok,"map host starts the authenticated Steam RPC path on ENet")
		mark("host");await until(func():return session.peer_to_player.size()==4,"four independent signed identities connect")
		await until(func():return session.campaign.actors.filter(func(actor):return actor.get("is_hero",false)).size()==4,"four PNG characters enter the inventory")
		var characters={}
		for player in session.remote_players:
			var number=int(str(session.remote_players[player].nickname).trim_prefix("Player "));characters[number]=Hearth20JoinCharacter.current(session.campaign,player)
		for i in range(1,4):
			session.switch_library_scene("page-1" if i==3 else "page-0",false)
			expect(session.place_inventory_token(str(characters[i].id),Vector2(2.5+i,4.5)).ok,"place hero "+str(i)+" on its own map")
			expect(session.grant_token_control(str(characters[i].id),str(characters[i].owner_player_id),true).ok,"grant existing owner movement")
		session.switch_library_scene("page-2",false)
		await until(func():return session.map_stream.records.size()==5,"maps and shared foreground files prepare on an unrelated DM tab")
		mark("placed");link.hold=false
		await until(func():return session.peer_map_downloads.values().all(func(slot):return not slot.active.is_empty() and slot.offset>0),"background files are partially streamed for all players")
		link.hold=true
		var first_peer=int(session.remote_players[str(characters[1].owner_player_id)].peer_id);var first_slot: Dictionary=session.peer_map_downloads[first_peer]
		var original_id=str(first_slot.active);var original_offset=int(first_slot.offset)
		session.switch_library_scene("page-1",false);session.place_inventory_token(str(characters[1].id),Vector2(4.5,4.5));link.hold=false
		var destination=str(session.map_stream.ready_for(session.campaign.scenes[1]).id)
		await until(func():return first_slot.active==destination and first_slot.offset>0,"moving a pawn prioritizes its destination without cancelling the old file")
		link.hold=true;session.switch_library_scene("page-0",false);session.place_inventory_token(str(characters[1].id),Vector2(3.5,4.5))
		await until(func():return first_slot.active==original_id,"returning to a partial map resumes its file")
		expect(int(first_slot.offset)==original_offset,"resumed map keeps its original received-byte offset")
		var held={}
		for id in session.peer_map_downloads:held[id]=[session.peer_map_downloads[id].active,session.peer_map_downloads[id].offset]
		for i in 20:session.switch_library_scene("page-"+str(i%3),false)
		expect(session.set_blackout(true).ok,"DM can cover while background downloads are paused")
		mark("covered");await until(func():return all_marked("covered"),"cover reaches all four clients without waiting for map data")
		for id in held:
			expect(session.peer_map_downloads[id].active==held[id][0] and session.peer_map_downloads[id].offset==held[id][1],"map switching and concealment retain the exact in-flight offset")
		expect(session.set_blackout(false).ok,"reveal resumes the authorized live view")
		link.hold=false;mark("download")
		await until(func():return all_marked("ready"),"every client downloads all three maps")
		await until(func():return session.peer_map_downloads.values().all(func(slot):return slot.done.size()==5),"complete map/foreground acknowledgements reach the DM")
		session.switch_library_scene("page-2",false);mark("actions")
		await wait("drawn")
		expect(session.campaign.scenes[0].annotations.size()==1 and session.campaign.scenes[2].annotations.is_empty(),"player drawing targets its pawn map while DM browses another")
		await wait("moved")
		expect(characters[1].position==Vector2(4.5,4.5),"player route is authorized on its map while DM is elsewhere")
		expect(pings.is_empty(),"off-map player pings never appear on the DM's other map")
		expect(session.load_sample_map("lantern-larch-inn",false).ok,"DM imports an additional map during the live session without moving heroes")
		mark("imported");await until(func():return all_marked("imported"),"newly imported map finishes on every client in the background")
		# Transfer one player; cached pages should require no new image bytes.
		session.switch_library_scene("page-1",false);session.place_inventory_token(str(characters[2].id),Vector2(6.5,4.5));session.switch_library_scene("page-2",false);mark("transfer")
		await until(func():return all_marked("transfer"),"only the transferred hero changes map")
		session.store_inventory_token(str(characters[1].id));mark("stowed")
		await wait("stowed-1")
		mark("host-done");await until(func():return all_marked("done"),"all map clients finish")
	else:
		var number=int(role.trim_prefix("player-"));await wait("host")
		expect(peer.create_client("127.0.0.1",port)==OK and session.adopt_steam_peer(peer,false,gate,"Player "+str(number)).ok,"player connects without a Steam sign-in")
		await until(func():return not session.local_player_id.is_empty() and last.get("character_required",false),"player gets an inventory-only waiting view")
		expect(last.get("scene",{}).get("id","")=="unplaced" and last.map_png.is_empty(),"no character means no map")
		var portrait=Image.create(32,32,false,Image.FORMAT_RGBA8);portrait.fill(Color.GOLD)
		expect(session.submit_join_character({"name":"Hero "+str(number)},portrait.save_png_to_buffer()).ok,"player submits their PNG character")
		await wait("placed");await wait("covered")
		await until(func():return last.get("scene",{}).get("id","")==("unplaced" if number==4 else "blackout"),"cover or inventory status remains authoritative during prefetch")
		expect(last.map_png.is_empty() and last.assets.is_empty() and last.actors.is_empty(),"hidden live views contain no map pixels or tokens")
		mark("covered-"+str(number));await wait("download")
		await until(func():return session.map_stream.progress().completed_maps==3 and not session.map_stream.progress().active and not session.map_preparing,"all future maps and foreground files finish independently of the current view")
		if number==4:
			expect(last.get("scene",{}).get("id","")=="unplaced" and last.map_png.is_empty(),"inventory player stays blind after every future map is cached")
			expect(session.map_stream.opened.is_empty(),"stored character never receives a key for future cached images")
		else:
			await until(func():return my_map(1 if number==3 else 0),"deployed player sees its own map, not the DM editor")
			expect(last.map_png==expected_map(1 if number==3 else 0),"only the exact fog-redacted map pixels are installed")
			var decoration=Image.create(40,40,false,Image.FORMAT_RGBA8);decoration.fill(Color.CORAL);var bytes=decoration.save_png_to_buffer();var id="sha256-"+Hearth20Contracts.sha256(bytes)
			expect(Hearth20Assets.read_asset(last,id,"token")==bytes,"prefetched foreground restores its exact authorized PNG")
		expect(not str(last).contains("GM-FORE-SECRET"),"future decorative data never reveals GM records")
		var secret=Image.create(40,40,false,Image.FORMAT_RGBA8);secret.fill(Color.MAGENTA)
		expect(not last.assets.has("sha256-"+Hearth20Contracts.sha256(secret.save_png_to_buffer())),"secret foreground art never enters the live asset set")
		expect(not str(last).contains("MAP-NETWORK-GM-SECRET"),"private DM records never enter a map view")
		var previous=0;var monotonic=true
		for state in progress:
			if state.get("id","")!="background-maps":continue
			if int(state.received)<previous:monotonic=false
			previous=int(state.received)
		expect(monotonic,"background received-byte progress never resets on tab changes")
		var total=session.map_stream.progress().received;mark("ready-"+str(number));await wait("actions")
		if number==1:
			session.board_action({"action":"add","object":{"kind":"line","layer":"tokens","points":[Vector2(3,6),Vector2(4,6)],"color":"#aabbcc"}})
			await until(func():return last.get("scene",{}).get("annotations",[]).size()==1,"drawing is visible on the player's own map");mark("drawn")
			var pawn={}
			for actor in last.actors:
				if actor.id==last.join_character_id:pawn=actor
			session.board_action({"action":"move_path","actor_id":pawn.id,"points":[pawn.position,Vector2(4.5,4.5)],"expected_revision":last.revision})
			await until(func():return last.actors.any(func(actor):return actor.id==pawn.id and actor.position==Vector2(4.5,4.5)),"route movement works away from the DM tab")
			session.send_ping(Vector2(5.5,4.5));await until(func():return not pings.is_empty(),"same-map player receives its own ping");mark("moved")
		await wait("imported")
		await until(func():return session.map_stream.progress().map_count==4 and not session.map_stream.progress().active and not session.map_preparing,"map imported during play downloads without switching the player's map")
		expect(session.map_stream.progress().received>total,"new map adds received bytes instead of resetting previous downloads")
		total=session.map_stream.progress().received
		if number==4:expect(last.get("scene",{}).get("id","")=="unplaced","new imports cannot reveal a board to a stored character")
		else:expect(my_map(1 if number==3 else 0),"DM's new imported tab does not move deployed player views")
		mark("imported-"+str(number));await wait("transfer")
		if number==2:await until(func():return my_map(1),"transferred player enters the cached destination")
		elif number==1:expect(my_map(0),"unmoved hero remains on the original map")
		elif number==3:expect(my_map(1),"hero already on the destination remains there")
		else:expect(last.get("scene",{}).get("id","")=="unplaced","stored hero remains blind")
		expect(session.map_stream.progress().received==total,"cached scene transitions do not download map files again")
		if number>=3:expect(pings.is_empty(),"pings from a different map remain hidden")
		mark("transfer-"+str(number))
		if number==1:
			await wait("stowed");await until(func():return last.get("scene",{}).get("id","")=="unplaced","stowing immediately clears the player's map")
			expect(last.map_png.is_empty() and last.actors.is_empty() and last.assets.is_empty(),"stowed player retains no live board content");mark("stowed-1")
		await wait("host-done");mark("done-"+str(number));await create_timer(.3).timeout
	var cache_folder=session.map_stream.folder;session.stop_session();session.queue_free();link.queue_free();await process_frame
	expect(cache_folder.is_empty() or not DirAccess.dir_exists_absolute(cache_folder),"disconnect releases downloaded map files")
	expect(not Engine.has_singleton("Steam"),"test never signs into Steam")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"role":role,"checks":checks,"errors":errors}))
	print("Map stream "+role+": %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

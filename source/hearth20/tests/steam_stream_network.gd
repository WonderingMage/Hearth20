extends SceneTree
## Real RPCs on windowless loopback; Steam's account/relay backend is not contacted.
class LinkFixture extends Node:
	var initialized=true
	var closing=false
	var session: Hearth20Session
	var progress=[]
	func allows_peer(id: int) -> bool:return id in session.multiplayer.get_peers()
	func can_send(id: int) -> bool:return allows_peer(id)
	func transfer_update(value: float,_note: String) -> void:progress.append(value)
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
func _initialize() -> void:
	var args=OS.get_cmdline_user_args();role=args[0];port=int(args[1]);output=args[2];folder=args[3];call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func until(predicate: Callable,note: String) -> void:
	var end=Time.get_ticks_msec()+25000
	while not predicate.call() and Time.get_ticks_msec()<end:await process_frame
	expect(predicate.call(),note)
func mark(name_value: String) -> void:FileAccess.open(folder.path_join(name_value+".ready"),FileAccess.WRITE).store_string("ready")
func wait(name_value: String) -> void:await until(func():return FileAccess.file_exists(folder.path_join(name_value+".ready")),"sync "+name_value)
func noise_png(width: int,height: int,seed_value: int) -> PackedByteArray:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value
	var bytes=PackedByteArray();bytes.resize(width*height*3)
	for index in bytes.size():bytes[index]=rng.randi()%256
	return Image.create_from_data(width,height,false,Image.FORMAT_RGB8,bytes).save_png_to_buffer()
func run() -> void:
	session=Hearth20Session.new();session.name="Hearth20Session";root.add_child(session);session.configure(Hearth20Identity.new_campaign("Chunked Steam campaign fixture"))
	session.status_changed.connect(func(note):print(role+" STATUS "+note))
	session.snapshot_received.connect(func(value):last=value)
	link=LinkFixture.new();root.add_child(link);link.session=session;session.steam_link=link
	var peer=ENetMultiplayerPeer.new();var gate="a".repeat(32)
	if role=="host":
		var png=noise_png(800,600,1831);expect(png.size()>524288,"map fixture exceeds the native Steam message limit")
		var inspected=Hearth20Assets.inspect_token_png_bytes(png);expect(inspected.ok,"large fixture PNG is valid")
		var scene=session.campaign.scenes[0];scene.map_asset=Hearth20Assets.store_asset(session.campaign,inspected,"map")
		session.campaign.dm_notes="STEAM-PRIVATE-NOTES-DO-NOT-SEND"
		expect(peer.create_server(port,8)==OK,"loopback server starts without Steam")
		expect(session.adopt_steam_peer(peer,true,gate,"").ok,"host adopts the chunked transport path")
		mark("host")
		await until(func():return not session.peer_to_player.is_empty(),"RSA handshake authenticates the player")
		var client=int(session.peer_to_player.keys()[0]) if not session.peer_to_player.is_empty() else 0
		await until(func():return session.steam_outgoing.has(client) and not session.steam_outgoing[client].active.is_empty(),"first large snapshot is streaming")
		for index in 10:
			scene.grid_opacity=.1+.05*index;session.campaign.revision+=1;session._broadcast_snapshots()
		expect(session.steam_outgoing.size()==1 and not session.steam_outgoing[client].pending.is_empty(),"repeated updates coalesce behind the active image stream")
		await wait("latest-map")
		await until(func():return not Hearth20JoinCharacter.current(session.campaign,str(session.peer_to_player.get(client,""))).is_empty(),"chunked portrait upload creates one character")
		var character=Hearth20JoinCharacter.current(session.campaign,str(session.peer_to_player.get(client,"")))
		expect(character.get("in_inventory",false) and character.get("token_size",0)==1.,"PNG pawn enters the DM inventory at one square")
		expect(Hearth20Assets.read_asset(session.campaign,str(character.get("png_asset_id","")),"token")==noise_png(512,512,598),"uploaded portrait is byte-for-byte intact")
		expect(session.place_inventory_token(str(character.get("id","")),Vector2(4.2,5.8)).ok,"DM can place the uploaded pawn")
		await wait("portrait")
		await until(func():return session.steam_outgoing.is_empty(),"all coalesced send buffers drain")
		expect(session.steam_chunks.reserved==0,"host releases completed upload buffers")
		mark("host-done");await wait("client-done")
	else:
		await wait("host")
		expect(peer.create_client("127.0.0.1",port)==OK,"loopback client starts without Steam")
		expect(session.adopt_steam_peer(peer,false,gate,"Steam fixture player").ok,"client adopts the chunked transport path")
		await until(func():return is_equal_approx(float(last.get("scene",{}).get("grid_opacity",0.)),.55),"latest queued campaign state reaches the client")
		var expected_map=Hearth20Contracts._mask_fogged_map(noise_png(800,600,1831),session.campaign.scenes[0])
		expect(last.get("map_png",PackedByteArray())==expected_map,"map remains intact after a cached follow-up snapshot")
		expect(not str(last).contains("STEAM-PRIVATE-NOTES-DO-NOT-SEND"),"chunked snapshots preserve DM note redaction")
		expect(last.get("character_required",false),"new authenticated players still need a character name and PNG")
		expect(link.progress.any(func(value):return value>0. and value<1.),"chunked download reports intermediate progress")
		mark("latest-map")
		var portrait=noise_png(512,512,598);expect(portrait.size()>524288,"portrait fixture exceeds the native Steam message limit")
		expect(session.submit_join_character({"name":"Steam portrait fixture"},portrait).ok,"portrait upload is queued")
		await until(func():return not last.get("character_required",true) and not last.get("character_in_inventory",true),"placed pawn reaches the player's view")
		var own={}
		for actor in last.get("actors",[]):
			if actor.get("id","")==last.get("join_character_id",""):own=actor
		expect(not own.is_empty(),"player sees their assigned pawn")
		expect(own.get("position",Vector2.ZERO)==Vector2(4.5,5.5),"placed pawn is centered within a square")
		expect(Hearth20Assets.read_asset(last,str(own.get("asset_id","")),"token")==portrait,"returned portrait bytes survive another chunked snapshot")
		expect(session.steam_chunks.reserved==0,"client releases completed download buffers")
		mark("portrait");await wait("host-done");mark("client-done");await create_timer(.2).timeout
	session.stop_session();session.queue_free();link.queue_free();await process_frame
	expect(not Engine.has_singleton("Steam"),"loopback test never loads or contacts Steam")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"role":role,"checks":checks,"errors":errors}))
	print("Steam stream "+role+": "+str(checks)+" checks, "+str(errors.size())+" failures");quit(0 if errors.is_empty() else 1)

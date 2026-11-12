extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func image(color: Color) -> PackedByteArray:
	var value=Image.create(128,128,false,Image.FORMAT_RGBA8);value.fill(color);return value.save_png_to_buffer()
func run() -> void:
	var campaign=Hearth20Identity.new_campaign("Background maps")
	for i in 3:
		var scene=campaign.scenes[0].duplicate(true);scene.id="map-"+str(i);scene.map_asset=Hearth20Assets.store_asset(campaign,Hearth20Assets.inspect_map_bytes(image([Color.RED,Color.GREEN,Color.BLUE][i])),"map")
		if i==0:campaign.scenes[0]=scene
		else:campaign.scenes.append(scene)
	campaign.active_scene="map-0"
	var first=Hearth20TokenInventory.new_actor("First",true,campaign.scenes[0],Vector2(2.5,2.5));first.owner_player_id="p1"
	var second=Hearth20TokenInventory.new_actor("Second",true,campaign.scenes[1],Vector2(2.5,2.5));second.owner_player_id="p2"
	campaign.actors=[first,second]
	expect(Hearth20PlayerMap.scene(campaign,"p1").id=="map-0" and Hearth20PlayerMap.scene(campaign,"p2").id=="map-1","players resolve independent pawn maps")
	campaign.active_scene="map-2"
	expect(Hearth20PlayerMap.scene(campaign,"p1").id=="map-0","DM tab browsing does not move a player's map")
	first.in_inventory=true;expect(Hearth20PlayerMap.scene(campaign,"p1").is_empty(),"inventory tokens give no map view")
	var waiting=Hearth20PlayerMap.waiting(campaign,"p1");expect(waiting.map_png.is_empty() and waiting.actors.is_empty() and waiting.assets.is_empty(),"waiting snapshots contain no map or pawns")
	first.in_inventory=false
	first.movement_policy={"mode":"free_until_revoked","controllers":["p1"],"remaining_feet":0.,"revision":0}
	expect(Hearth20Contracts.authorize_and_apply_move(campaign,"p1","player",first.id,first.position,Vector2(3.5,2.5),5.).ok,"player movement works on its map while DM is elsewhere")
	campaign.map_covered=true
	expect(not Hearth20Contracts.authorize_and_apply_move(campaign,"p1","player",first.id,first.position,Vector2(4.5,2.5),5.).ok,"forged movement cannot bypass a covered map")
	campaign.map_covered=false
	var session=Hearth20Session.new();root.add_child(session);session.configure(campaign);session.remote_players.p1={}
	var rejected=session._apply_board_action({"action":"add","request_id":"stale-scene-draw","view_scene_id":Hearth20Contracts._neutral_id("p1","scene:map-2"),"object":{"kind":"line","layer":"tokens","points":[Vector2(2,3),Vector2(4,3)]}},"p1")
	expect(not rejected.ok and "changed maps" in rejected.error,"a stale draw request cannot edit the token's next map")
	session.queue_free();await process_frame
	var server=Hearth20MapStream.new();var client=Hearth20MapStream.new();server.scan(campaign,"map-0")
	var deadline=Time.get_ticks_msec()+10000
	while server.records.size()<3 and Time.get_ticks_msec()<deadline:server.tick(campaign);await process_frame
	expect(server.records.size()==3 and server.failure.is_empty(),"all imported maps prepare on the bounded worker")
	expect(client.offer(server.offers()),"opaque map catalog accepts complete bounded files")
	var selected=server.ready_for(campaign.scenes[0]);var info=Hearth20MapStream.descriptor(selected)
	expect(client.resolve(info).get("waiting",false),"view waits for its file without inventing a completed download")
	for record in server.records.values():
		var bytes=FileAccess.get_file_as_bytes(record.path)
		expect(not bytes.slice(0,8)==PackedByteArray(Hearth20Assets.PNG_SIGNATURE),"future maps are ciphertext, never readable PNGs")
		var result={}
		for offset in range(0,bytes.size(),Hearth20MapStream.CHUNK):result=client.accept({"id":record.id,"offset":offset,"bytes":bytes.slice(offset,mini(offset+Hearth20MapStream.CHUNK,bytes.size()))})
		expect(result.ok and result.complete,"background file finishes independently")
	var resolved=client.resolve(info)
	expect(resolved.ok and resolved.bytes==Hearth20Contracts._mask_fogged_map(image(Color.RED),campaign.scenes[0]),"unlock restores only the exact authorized map pixels")
	var damaged=info.duplicate(true);damaged.key=PackedByteArray();damaged.key.resize(32)
	expect(not client.resolve(damaged).ok,"another key cannot open the cached map")
	expect(client.progress().completed_maps==3 and not client.progress().active,"aggregate progress completes all maps")
	expect(not client.offer([{"id":"../../escape","size":16,"sha256":"a".repeat(64)}]),"catalog cannot name a path outside the cache")
	expect(not client.accept({"id":info.id,"offset":-1,"bytes":PackedByteArray([1])}).ok,"negative map offsets are rejected")
	var duplicates=server.offers();duplicates.append(duplicates[0]);expect(not client.offer(duplicates),"duplicate catalog identifiers are rejected")
	var folders=[server.folder,client.folder];server.clear();client.clear()
	expect(folders.all(func(path):return not DirAccess.dir_exists_absolute(path)),"disconnect deletes this connection's map cache and keys")
	var updater=Hearth20Updater.new();root.add_child(updater);updater.verified=true;updater.staged_path=OS.get_cmdline_user_args()[0].path_join("quarantined.exe");updater.manifest={"sha256":"a".repeat(64)}
	updater._install_verified()
	expect(not updater.verified and "Security software" in updater.message and "unchanged" in updater.message,"quarantined downloads are explained before any restart")
	updater.queue_free();await process_frame
	print("Background maps: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

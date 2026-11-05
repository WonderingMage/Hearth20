extends SceneTree
var session: Hearth20Session
var role: String
var port: int
var output: String
var secret: String
var phase:=0
var received: Array[int]=[]
var errors: Array[String]=[]
var checks:=0
var deadline:=0
var first_hash:=""
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	role=args[0]; port=int(args[1]); output=args[2]; secret=args[3]
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: errors.append(message); push_error(message)
func run() -> void:
	session=Hearth20Session.new(); root.add_child(session)
	deadline=Time.get_ticks_msec()+45000
	if role=="host":
		var c:=Hearth20Identity.new_campaign("Synthetic lighting network")
		expect(Hearth20MapLibrary.add_to_campaign(c,"sunspire-sanctum",false).ok,"host opens bundled map")
		var scene:=Hearth20Contracts.find_scene(c,str(c.active_scene))
		scene.annotations.append({"id":"PRIVATE_EMITTER_TEST_DOOR","owner":"dm-local","kind":"door","layer":"light","points":[Vector2(7,0),Vector2(7,24)],"open":false})
		for id in ["A","B"]:
			c.actors.append({"id":"hero-"+id,"name":"Hero "+id,"is_hero":true,"owner_player_id":"","scene_id":scene.id,"position":Vector2(5,9 if id=="A" else 14),"vision":{"enabled":true,"darkvision_feet":60,"bright_light_feet":0,"dim_light_feet":0},"abilities":[10,10,10,10,10,10]})
		session.configure(c)
		expect(session.start_host(port).ok,"host starts ENet")
		FileAccess.open(secret,FileAccess.WRITE).store_string(str(session.invite_secret))
		while session.remote_players.size()<2 and Time.get_ticks_msec()<deadline: await process_frame
		expect(session.remote_players.size()==2,"two actual players join")
		for id in session.remote_players:
			var nickname: String=session.remote_players[id].nickname
			session.assign_hero("hero-"+nickname,str(id))
		for next_phase in [1,2,3,4,5]:
			phase=next_phase
			print("Sample phase %d begins at %.2f s"%[phase,float(Time.get_ticks_msec())/1000.0])
			if phase==2:
				var object: Dictionary=Hearth20Contracts.find_scene(c,str(c.active_scene)).annotations.filter(func(o): return o.id=="PRIVATE_EMITTER_TEST_DOOR")[0].duplicate(true)
				object.open=true
				expect(session.board_action({"action":"update","object":object}).ok,"DM opens door live")
			if phase==3: expect(session.set_natural_lighting({"time_hours":0.0,"north_degrees":90.0,"sun_intensity":1.0,"moon_intensity":0.65}).ok,"DM changes time, compass and moon strength live")
			if phase==4: expect(session.set_blackout(true).ok,"DM enables blackout live")
			if phase==5: expect(session.load_sample_map("echoing-caverns",true).ok,"DM loads another bundled map live")
			var marked: Dictionary=session.send_chat("LIGHT_PHASE_%d"%phase,"public")
			expect(bool(marked.get("ok",false)),"host publishes phase marker %d: %s"%[phase,str(marked)])
			for recipient in session.remote_players:
				var projected: Dictionary=session._project_for(str(recipient))
				print("Phase %d projection: bytes=%d light-bytes=%d timeline=%d"%[phase,var_to_bytes(projected).size(),projected.get("scene",{}).get("light_field",{}).get("data",PackedByteArray()).size(),projected.get("timeline",[]).size()])
			while Time.get_ticks_msec()<deadline:
				var timeline: Array=c.get("table_timeline",[])
				if timeline.any(func(e): return e.get("text","")=="ACK_A_%d"%phase) and timeline.any(func(e): return e.get("text","")=="ACK_B_%d"%phase): break
				await process_frame
			expect(Time.get_ticks_msec()<deadline,"both players acknowledge phase %d"%phase)
		session.send_chat("LIGHT_DONE","public")
		await create_timer(0.5).timeout
		session.stop_session()
	else:
		while not FileAccess.file_exists(secret) and Time.get_ticks_msec()<deadline: await process_frame
		session.snapshot_received.connect(snapshot)
		expect(session.join_host("127.0.0.1",port,FileAccess.get_file_as_string(secret).strip_edges(),role).ok,"player joins")
		while phase<6 and Time.get_ticks_msec()<deadline: await process_frame
		expect(received==[1,2,3,4,5],"player receives all lighting and map transitions")
		# Keep recipients alive while the host finishes its final broadcast and
		# closes the table, rather than tearing down two ENet channels mid-send.
		await create_timer(1.0).timeout
		session.stop_session()
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"role":role,"checks":checks,"errors":errors,"phases":received}))
	print("Sample network %s: %d checks, %d failures."%[role,checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
func snapshot(value: Dictionary) -> void:
	var timeline: Array=value.get("timeline",[])
	if timeline.any(func(e): return e.get("text","")=="LIGHT_DONE"): phase=6; return
	var latest:=0
	for entry in timeline:
		var message:=str(entry.get("text",""))
		if message.begins_with("LIGHT_PHASE_"): latest=maxi(latest,int(message.trim_prefix("LIGHT_PHASE_")))
	if latest==0 or latest in received: return
	received.append(latest)
	var scene: Dictionary=value.get("scene",{})
	var lighting:=Hearth20Lighting.read_field(scene.get("light_field",{}))
	var image:=Image.new()
	var png: PackedByteArray=value.get("map_png",PackedByteArray())
	expect(not JSON.stringify(scene).contains("PRIVATE_EMITTER"),"player does not receive private source IDs")
	if latest in [1,2,3,5]:
		expect(not png.is_empty() and image.load_png_from_buffer(png)==OK and image.get_size()==Vector2i(2048,1536),"player receives self-contained redacted sample map phase %d"%latest)
		expect(lighting!=null,"player receives a compact authorized light field phase %d"%latest)
	if latest==1:
		first_hash=str(value.map_sha256)
		expect(lighting!=null and not lit_after(lighting,7.01),"closed door clips all received light samples")
	if latest==2: expect(lighting!=null and lit_after(lighting,7.01),"open door extends the received light field")
	if latest==3:
		expect(float(scene.natural_light.time_hours)==0 and float(scene.natural_light.north_degrees)==90,"players receive authoritative midnight and compass settings")
		expect(lighting!=null and has_blue(lighting),"players receive soft blue lunar light")
		expect(not session.set_natural_lighting({"time_hours":12}).ok,"player cannot change the host clock")
	if latest==4: expect(lighting==null and scene.id=="blackout" and value.sheets.size()==1,"blackout clears light but retains own sheet")
	if latest==5: expect(str(value.map_sha256)!=first_hash,"scene switch refreshes downloaded artwork")
	session.send_chat("ACK_%s_%d"%[role,latest],"public")

func lit_after(image: Image, x: float) -> bool:
	var start:=ceili(x/32.0*image.get_width())
	for y in image.get_height():
		for px in range(start,image.get_width()):
			var color:=image.get_pixel(px,y)
			if maxf(color.r,maxf(color.g,color.b))>.003: return true
	return false
func has_blue(image: Image) -> bool:
	var pixels:=image.get_data()
	for i in range(0,pixels.size(),3):
		if int(pixels[i+2])>int(pixels[i])*1.15+2: return true
	return false

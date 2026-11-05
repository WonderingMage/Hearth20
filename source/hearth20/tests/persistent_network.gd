extends SceneTree
class ImpostorSession extends Hearth20Session:
	var stolen_public:=""
	func _on_connected_to_server() -> void:
		send_handshake.rpc_id(1,Hearth20Identity.network_identity(),invite_secret,pending_nickname,stolen_public)
var session: Hearth20Session
var role:=""
var round_number:=1
var port:=24990
var output:=""
var secret_file:=""
var shared_dir:=""
var checks:=0
var errors: Array[String]=[]
var received: Array=[]
var done:=false
var deadline:=0
var own_id:=""
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<6: quit(2); return
	role=args[0]; round_number=int(args[1]); port=int(args[2]); output=args[3]; secret_file=args[4]; shared_dir=args[5]
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: errors.append(message); push_error("FAIL: "+message)
func attach(value: Hearth20Session) -> void:
	session=value; session.name="Session"; root.add_child(session)
func id_for(label: String) -> String:
	return Hearth20PlayerProfile.principal(FileAccess.get_file_as_string(shared_dir.path_join(label+".public")))
func fixture() -> Dictionary:
	var c:=Hearth20Identity.new_campaign("Persistent grant fixture")
	for label in ["A","B","pet"]:
		c.actors.append({"id":"token-"+label,"name":"Token "+label,"is_hero":label!="pet","owner_player_id":"","scene_id":c.active_scene,"position":Vector2(2 if label=="A" else 6 if label=="B" else 4,2),"hidden":false,"abilities":[10,10,10,10,10,10],"hp":1,"max_hp":1,"movement_policy":Hearth20Contracts.default_movement_policy(),"vision":{"enabled":true,"darkvision_feet":60,"bright_light_feet":0,"dim_light_feet":0}})
	return c
func run() -> void:
	deadline=Time.get_ticks_msec()+35000
	if role=="host": await host_run()
	else: await player_run()
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"role":role,"round":round_number,"checks":checks,"errors":errors,"phases":received,"principal":own_id}))
	if session!=null: session.stop_session()
	await create_timer(.2).timeout
	print("Persistent network %s round %d: %d checks, %d failures."%[role,round_number,checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
func host_run() -> void:
	attach(Hearth20Session.new())
	var c: Dictionary
	if round_number==1: c=fixture()
	else:
		var loaded:=Hearth20Identity.load_campaign(Hearth20Identity.SAVE_ROOT+"/persistent-network.h20campaign")
		expect(loaded.ok,"fresh host process reloads saved campaign")
		if not loaded.ok: return
		c=loaded.campaign
	session.configure(c); expect(session.start_host(port).ok,"host starts")
	FileAccess.open(secret_file,FileAccess.WRITE).store_string(session.invite_secret)
	var count:=2 if round_number==1 else 3
	while session.remote_players.size()<count and Time.get_ticks_msec()<deadline: await process_frame
	expect(session.remote_players.size()==count,"all actual players join")
	var a:=id_for("A"); var b:=id_for("B")
	expect(a!=b and session.remote_players.has(a) and session.remote_players.has(b),"different local keys produce distinct authenticated players")
	if round_number==1:
		expect(c.actors.all(func(actor): return actor.owner_player_id=="" and actor.movement_policy.mode=="blocked"),"all tokens start under DM control")
		await marker(0,["A","B"])
		expect(c.actors[0].position==Vector2(2,2),"unassigned move request cannot move a token")
		expect(session.grant_token_control("token-A",a,true).ok and session.grant_token_control("token-B",b,true).ok and session.grant_token_control("token-pet",a,true).ok,"DM grants specific hero and creature tokens")
		expect(session.set_grid_style(.72,2.5,"#eee4c2").ok,"host changes shared grid appearance")
		await marker(1,["A","B"])
		expect(c.actors[0].position==Vector2(3,2) and c.actors[1].position==Vector2(6,2),"assigned move succeeds and foreign token move is rejected")
		expect(Hearth20Identity.save_campaign(c,Hearth20Identity.SAVE_ROOT+"/persistent-network.h20campaign").ok,"campaign and control grants saved to disk")
	else:
		expect(c.actors[0].owner_player_id==a and c.actors[1].owner_player_id==b and c.actors[2].owner_player_id==a,"fresh host restores exact per-token grants without reassignment")
		expect(session.remote_players[a].nickname=="Aster renamed","returning player changes name without losing identity")
		await marker(2,["A","B","impostor"])
		expect(c.actors[0].position==Vector2(3,2),"same-name intruder cannot move another player's token")
		expect(c.participants.size()==3,"forged public-key proof did not register an extra player")
		expect(not JSON.stringify(session._project_for(a)).contains("BEGIN PUBLIC KEY"),"campaign key registry never enters player snapshots")
	session.send_chat("PERSIST_DONE","public")
	await create_timer(.5).timeout
func marker(phase: int, roles: Array) -> void:
	session.send_chat("PERSIST_PHASE_%d"%phase,"public")
	while Time.get_ticks_msec()<deadline:
		var all_seen:=true
		for label in roles:
			if not session.campaign.get("table_timeline",[]).any(func(entry): return entry.get("text","")=="PERSIST_ACK_%s_%d"%[label,phase]): all_seen=false
		if all_seen: break
		await process_frame
	expect(Time.get_ticks_msec()<deadline,"actual players acknowledge phase %d"%phase)
func player_run() -> void:
	var public_pem:=Hearth20PlayerProfile.public_key()
	var public_path:=shared_dir.path_join(role+".public")
	if round_number==1: FileAccess.open(public_path,FileAccess.WRITE).store_string(public_pem)
	elif role!="impostor": expect(public_pem==FileAccess.get_file_as_string(public_path),"fresh player process reloads its original local identity")
	own_id=Hearth20PlayerProfile.principal(public_pem)
	while not FileAccess.file_exists(secret_file) and Time.get_ticks_msec()<deadline: await process_frame
	var secret:=FileAccess.get_file_as_string(secret_file).strip_edges()
	if role=="impostor":
		var fraud:=ImpostorSession.new(); fraud.stolen_public=FileAccess.get_file_as_string(shared_dir.path_join("A.public")); attach(fraud)
		var disconnected: Array=[false]
		root.multiplayer.server_disconnected.connect(func(): disconnected[0]=true,CONNECT_ONE_SHOT)
		session.join_host("127.0.0.1",port,secret,"Aster renamed")
		var reject_deadline:=Time.get_ticks_msec()+6000
		while not disconnected[0] and Time.get_ticks_msec()<reject_deadline: await process_frame
		expect(disconnected[0] and session.local_player_id.is_empty() and session.client_snapshot.is_empty(),"copied public key and display name cannot prove ownership without the private key")
		session.stop_session(); session.queue_free(); await process_frame; await process_frame
	attach(Hearth20Session.new()); session.snapshot_received.connect(snapshot)
	var nickname: String="Aster renamed" if role=="impostor" or (role=="A" and round_number==2) else "Aster" if role=="A" else "Briar"
	expect(session.join_host("127.0.0.1",port,secret,nickname).ok,"player queues authenticated join")
	while not done and Time.get_ticks_msec()<deadline: await process_frame
	expect(done,"player receives completion after verified transitions")
	expect(received==([0,1] if round_number==1 else [2]),"player sees every expected phase")
	expect(session.local_player_id==own_id,"host principal matches proved local identity")
	expect(Hearth20PlayerProfile.preferences().display_name==nickname,"display name is stored for the next launch")
	await create_timer(.8).timeout
func snapshot(value: Dictionary) -> void:
	if value.get("connection_closed",false): return
	var timeline: Array=value.get("timeline",[])
	if timeline.any(func(entry): return entry.get("text","")=="PERSIST_DONE"): done=true; return
	var phase:=-1
	for entry in timeline:
		if str(entry.get("text","")).begins_with("PERSIST_PHASE_"): phase=maxi(phase,int(str(entry.text).trim_prefix("PERSIST_PHASE_")))
	if phase<0 or phase in received: return
	if round_number==2 and phase!=2: return
	if role=="B" and phase==1 and not timeline.any(func(entry): return entry.get("text","")=="PERSIST_ACK_A_1"): return
	received.append(phase)
	if phase==0:
		expect(value.sheets.is_empty() and value.actors.all(func(actor): return not actor.has("movement")),"before DM grant no tokens or sheets are owned")
		if role=="A": session.request_move.rpc_id(1,"token-A",Vector2(2,2),Vector2(3,2),int(value.revision))
	else:
		var mine: Array=value.actors.filter(func(actor): return actor.has("movement"))
		if role=="impostor":
			expect(mine.is_empty() and value.sheets.is_empty(),"same display name grants no tokens or private sheets")
			session.request_move.rpc_id(1,"token-A",Vector2(3,2),Vector2(9,2),int(value.revision))
		else:
			expect(mine.size()==(2 if role=="A" else 1) and value.sheets.size()==1 and value.sheets[0].id=="token-"+role,"returning owner receives only their own tokens and sheet")
			expect(is_equal_approx(float(value.scene.grid_opacity),.72) and is_equal_approx(float(value.scene.grid_thickness),2.5),"grid appearance crosses actual ENet and survives saved campaign")
			if phase==1 and role=="A":
				session.request_move.rpc_id(1,"token-B",Vector2(6,2),Vector2(7,2),int(value.revision))
				session.request_move.rpc_id(1,"token-A",Vector2(2,2),Vector2(3,2),int(value.revision))
	session.send_chat("PERSIST_ACK_%s_%d"%[role,phase],"public")

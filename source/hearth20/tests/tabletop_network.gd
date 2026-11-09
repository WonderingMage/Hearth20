extends SceneTree
const Identity = preload("res://hearth20/identity.gd")
const Session = preload("res://hearth20/session.gd")
var session: Node
var role := ""
var port := 24851
var output_path := ""
var secret_path := ""
var ready_setup := false
var sent_actions := false
var seconds := 0.0
var last_snapshot: Dictionary = {}
var snapshots_seen := 0
var errors: Array[String] = []
var old_principal_id := ""
var new_principal_id := ""
var stale_view_cleared := false
var rejoined := false
var post_rejoin_private_count := -1
var post_rejoin_sheet_count := -1
var native_ui := false
var app: Node
var captured := false
var before_rejoin: Dictionary = {}
var last_authorized_snapshot: Dictionary = {}
var host_disconnect_cleared := false
var pings_received: Array = []
var tool_previews: Array = []
var last_tool_send := 0
var actions_started_msec := 0
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		quit(2); return
	role = args[0]; port = int(args[1]); output_path = args[2]; secret_path = args[3]
	native_ui = args.size() > 4 and args[4] == "ui"
	call_deferred("prepare")
func prepare() -> void:
	if native_ui:
		root.size = Vector2i(1000,650) if role == "player_a" else Vector2i(1280,800)
		app = load("res://hearth20_main.tscn").instantiate()
		root.add_child(app)
		session = app.session
	else:
		session = Session.new(); root.add_child(session)
	session.ping_received.connect(func(event: Dictionary): pings_received.append(event.duplicate(true)))
	session.tool_preview_received.connect(func(event: Dictionary):
		if not event.get("measure",{}).is_empty() and not bool(event.get("own",false)):
			tool_previews.append(event.duplicate(true)))
	call_deferred("setup")
func setup() -> void:
	if role == "host":
		start_host()
	else:
		start_player()
	tick()
func start_host() -> void:
	var c := Identity.new_campaign("Disposable live roll privacy session")
	var s: Dictionary = c.scenes[0]
	s.width_cells=24; s.height_cells=16; s.cell_pixels=8.0; s.feet_per_cell=5.0
	s.dynamic_lighting=true; s.ambient_light="dark"
	var hero_a := {"id":"hero-a","name":"Private Hero A","is_hero":true,"owner_player_id":"","scene_id":s.id,"position":Vector2(2,2),"hidden":false,"abilities":[16,14,12,10,10,10],"prof_bonus":3,"skills":{"Acrobatics":1},"hp":31,"ac":17,"notes":"A's private notes"}
	var hero_b := {"id":"hero-b","name":"Private Hero B","is_hero":true,"owner_player_id":"","scene_id":s.id,"position":Vector2(3,2),"hidden":false,"abilities":[8,10,10,10,10,10],"hp":25,"ac":15,"notes":"B's private notes"}
	var enemy := {"id":"enemy-secret","name":"Hidden Wraith","is_hero":false,"owner_player_id":"","scene_id":s.id,"position":Vector2(8,2),"hidden":true,"hp":99,"ac":23,"initiative":19,"private_notes":"never expose"}
	c.actors=[hero_a,hero_b,enemy]
	for actor in c.actors:
		var token := Image.create(4,4,false,Image.FORMAT_RGBA8)
		token.fill(Color("#b73535") if actor.id=="enemy-secret" else Color("#3787b7") if actor.id=="hero-a" else Color("#4f9a62"))
		actor.png_asset_id=Hearth20Assets.store_asset(c,Hearth20Assets.inspect_token_png_bytes(token.save_png_to_buffer(),"fixture-token.png"),"token")
	var art := Image.create(192,128,false,Image.FORMAT_RGBA8)
	art.fill(Color("#52615b"))
	art.fill_rect(Rect2i(150,10,32,24), Color("#b73535"))
	s.map_asset = Hearth20Assets.store_asset(c, Hearth20Assets.inspect_token_png_bytes(art.save_png_to_buffer(),"network-fixture.png"),"map")
	if native_ui:
		app.campaign = c
		app.board.set_campaign(c,session,"dm")
	session.configure(c)
	session.share_handout("Public handout","Readable by both admitted players",true)
	session.share_handout("DM handout","Private DM notes",false)
	session.start_host(port)
	session.board_action({"action":"add","object":{"kind":"text","layer":"gm","points":[Vector2(3,2),Vector2(4,3)],"text":"PRIVATE_ANNOTATION_NEVER_SEND"}})
	var secret := str(session.invite_secret)
	var f := FileAccess.open(secret_path,FileAccess.WRITE)
	f.store_string(secret); f.close()
	var host_roll: Dictionary = session._apply_table_request({"action":"roll","request_id":"dm-private-roll","actor_id":"hero-a","kind":"ability","key":"dex","mode":"normal","visibility":"gm","expression":"1d20"},"dm-local")
	if not host_roll.ok: errors.append("host private roll rejected")
func start_player() -> void:
	var deadline := Time.get_ticks_msec()+10000
	while not FileAccess.file_exists(secret_path) and Time.get_ticks_msec()<deadline:
		await create_timer(0.1).timeout
	if not FileAccess.file_exists(secret_path): errors.append("invite secret missing"); write_result(); quit(2); return
	var secret := FileAccess.get_file_as_string(secret_path).strip_edges()
	session.snapshot_received.connect(on_snapshot)
	var nickname := "Player A" if role == "player_a" else "Player B"
	var joined: Dictionary = session.join_host("127.0.0.1",port,secret,nickname)
	if native_ui:
		app.board.set_role("player")
		app._update_session_ui()
	if not joined.ok: errors.append("join failed: %s" % joined.get("error",""))
func on_snapshot(snapshot: Dictionary) -> void:
	last_snapshot=snapshot.duplicate(true); snapshots_seen+=1
	if bool(snapshot.get("connection_closed",false)):
		if sent_actions:
			host_disconnect_cleared=session.client_snapshot.is_empty() and session.local_player_id.is_empty() and session.timeline_for_local().is_empty()
			if native_ui:
				host_disconnect_cleared=host_disconnect_cleared and app.chat_feed.get_parsed_text().is_empty() and app.handout_body.text.is_empty() and app.board.snapshot.get("assets",{}).is_empty() and app.selected_sheet_actor_id.is_empty()
		return
	last_authorized_snapshot=snapshot.duplicate(true)
	if rejoined:
		new_principal_id=session.local_player_id
		post_rejoin_private_count=snapshot.get("timeline",[]).filter(func(entry): return str(entry.get("visibility","public"))=="gm").size()
		post_rejoin_sheet_count=snapshot.get("sheets",[]).size()
		return
	if sent_actions or not snapshot.get("sheets",[]) is Array or snapshot.sheets.is_empty(): return
	sent_actions=true
	actions_started_msec=Time.get_ticks_msec()
	old_principal_id=session.local_player_id
	var my_hero := "hero-a" if role == "player_a" else "hero-b"
	var foreign_hero := "hero-b" if role == "player_a" else "hero-a"
	var pub: Dictionary = session.submit_roll(my_hero,"ability","dex","normal","public","1d20")
	if not pub.ok: errors.append("public ability roll not accepted locally")
	var wrong_owner: Dictionary = session.submit_roll(foreign_hero,"ability","dex","normal","public","1d20")
	if not wrong_owner.ok: errors.append("foreign roll request should be queued for authoritative rejection")
	var chat: Dictionary = session.send_chat("public hello from " + role,"public")
	if not chat.ok: errors.append("public chat not accepted locally")
	session.send_ping(Vector2(12,2)) # A can see 50 ft; B's shared torch stops at 30 ft.
	if role == "player_a":
		session.board_action({"action":"add","object":{"kind":"rectangle","layer":"tokens","points":[Vector2(3,2),Vector2(4,3)],"color":"#76e0ca"}})
		session.board_action({"action":"fx","effect":{"effect":"beam","color":"#76e0ca","size":1.0,"duration":3.0,"density":32,"start":Vector2(3,2),"end":Vector2(4,2)}})
		session.submit_dice("","1d4+77","self",false)
		session.submit_dice("","1d6+88","secret",false)
		var private_roll: Dictionary = session.submit_roll(my_hero,"ability","dex","normal","gm","1d20")
		if not private_roll.ok: errors.append("private ability roll not accepted locally")
		var replay := {"action":"chat","request_id":"fixed-replay-24851","text":"first replay marker","visibility":"public","total":999}
		session.request_table_action.rpc_id(1,replay)
		await create_timer(0.1).timeout
		replay.text="second replay marker"
		session.request_table_action.rpc_id(1,replay)
	else:
		session.board_action({"action":"mask_all","reveal":true})
		session.board_action({"action":"add","object":{"kind":"text","layer":"gm","points":[Vector2(3,2),Vector2(4,3)],"text":"FORGED_GM_ANNOTATION"}})
		var forged := {"action":"roll","request_id":"forged-total-24851","actor_id":"hero-b","kind":"ability","key":"dex","mode":"normal","visibility":"public","expression":"1d20","total":999,"dice":[20],"modifier":999}
		session.request_table_action.rpc_id(1,forged)
func _process(delta: float) -> bool:
	seconds+=delta
	return false
func tick() -> void:
	var action_seconds:=float(Time.get_ticks_msec()-actions_started_msec)/1000.0
	if role=="player_a" and sent_actions and not session.local_player_id.is_empty() and Time.get_ticks_msec()-last_tool_send>150:
		last_tool_send=Time.get_ticks_msec()
		session.send_tool_preview({"shape":"line","points":[Vector2(3,2),Vector2(4,2)],"linger":true})
	if role=="host" and not ready_setup and session.remote_players.size()>=2:
		ready_setup=true
		var ids: Array = session.remote_players.keys()
		var player_a := ""; var player_b := ""
		for id in ids:
			var n := str(session.remote_players[id].nickname)
			if n=="Player A": player_a=str(id)
			if n=="Player B": player_b=str(id)
		if player_a.is_empty() or player_b.is_empty(): errors.append("host did not map both player names")
		else:
			session.assign_hero("hero-a",player_a); session.assign_hero("hero-b",player_b)
			session.set_scene_lighting(true,"dark")
			session.set_actor_vision("hero-a",true,60.0,10.0,20.0)
		var dmchat: Dictionary = session.send_chat("DM public message","public")
		if not dmchat.ok: errors.append("DM chat rejected")
	var own_private_ready: bool=last_snapshot.get("timeline",[]).any(func(entry): return entry.get("visibility","")=="gm" and entry.get("type","")=="roll")
	var own_self_ready: bool=last_snapshot.get("timeline",[]).any(func(entry): return entry.get("formula","")=="1d4+77")
	if role=="player_a" and sent_actions and not rejoined and action_seconds>=3.0 and own_private_ready and own_self_ready:
		before_rejoin=last_snapshot.duplicate(true)
		session.stop_session()
		stale_view_cleared=session.client_snapshot.is_empty() and session.local_player_id.is_empty() and session.timeline_for_local().is_empty() and session.client_snapshot.get("map_png",PackedByteArray()).is_empty()
		var join_result: Dictionary=session.join_host("127.0.0.1",port,FileAccess.get_file_as_string(secret_path).strip_edges(),"Player A Rejoin")
		if not join_result.ok: errors.append("rejoin failed")
		rejoined=true
	if native_ui and not captured and seconds>=2.5 and (role=="host" or sent_actions):
		captured=true
		await capture_ui()
	var finish_after:=18.0 if role=="host" else 20.0 if role=="player_b" else 14.0
	var finished:=seconds>=finish_after
	if role=="player_b": finished=host_disconnect_cleared or seconds>=40.0
	if finished:
		write_result()
		if role=="host":
			session.stop_session()
			await create_timer(.2).timeout
		quit(1 if not errors.is_empty() else 0); return
	await process_frame
	tick()
func write_result() -> void:
	var player_b_id := ""
	if role == "host":
		for player_id in session.remote_players:
			if str(session.remote_players[player_id].get("nickname", "")) == "Player B": player_b_id = str(player_id)
	var image:=Image.new()
	var map_bytes: PackedByteArray=last_authorized_snapshot.get("map_png",PackedByteArray())
	var valid_map := not map_bytes.is_empty() and image.load_png_from_buffer(map_bytes)==OK and Hearth20Contracts.sha256(map_bytes)==str(last_authorized_snapshot.get("map_sha256",""))
	var data := {"role":role,"errors":errors,"snapshots_seen":snapshots_seen,"sent_actions":sent_actions,"old_principal_id":old_principal_id,"new_principal_id":new_principal_id,"stale_view_cleared":stale_view_cleared,"rejoined":rejoined,"post_rejoin_private_count":post_rejoin_private_count,"post_rejoin_sheet_count":post_rejoin_sheet_count,"players":session.remote_players if role=="host" else {},"campaign_timeline":session.campaign.get("table_timeline",[]) if role=="host" else [],"local_timeline":session.timeline_for_local() if role=="host" else last_snapshot.get("timeline",[]),"last_snapshot":last_snapshot if role!="host" else {},"before_rejoin":before_rejoin,"native_ui":native_ui,"captured":captured,"valid_merged_map":valid_map,"host_player_b_projection":session._project_for(player_b_id) if role=="host" and not player_b_id.is_empty() else {}}
	data.last_authorized_snapshot=last_authorized_snapshot
	data.host_disconnect_cleared=host_disconnect_cleared
	data.pings_received=pings_received
	data.tool_previews=tool_previews
	if role=="host": data.annotations=session.campaign.scenes[0].get("annotations",[])
	var f:=FileAccess.open(output_path,FileAccess.WRITE)
	if f==null: errors.append("result file not writable"); return
	f.store_string(JSON.stringify(data)); f.close()

func capture_ui() -> void:
	if role=="host":
		app.board.selected_actor_id="hero-a"
		app._on_selection("hero-a")
	app._show_sidebar_page(app.sheet_page)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_path.get_base_dir()+"/"+role+"-sheet.png")
	var panel: Rect2=app.sheet_page.get_global_rect()
	for row in app.sheet_actions.get_children().slice(0,6):
		for button in row.get_children():
			if button is Button and button.get_global_rect().end.x>panel.end.x:
				errors.append("sheet button overflows the sidebar: "+button.text)
	app._show_sidebar_page(app.chat_page)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_path.get_base_dir()+"/"+role+"-chat.png")

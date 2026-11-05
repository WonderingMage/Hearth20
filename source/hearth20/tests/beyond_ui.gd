extends SceneTree
var app: Hearth20App
var checks=0
var errors=[]
var output=""
func _initialize() -> void:
	output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func capture(name_value: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name_value+".png"))
func act(action: String, values: Dictionary={}) -> Dictionary:
	var g=app.campaign.get("tavern_game",{});var cmd={"action":action,"game_id":g.get("id",""),"revision":g.get("revision",0)};cmd.merge(values);var result=app.session.casino_action(cmd);expect(result.ok,action+": "+str(result.get("error","")));return result
func run() -> void:
	root.size=Vector2i(1600,1000);app=Hearth20App.new();app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(app)
	await create_timer(.7).timeout
	expect(is_instance_valid(app.cover_map_button) and app.cover_map_button.get_parent()!=null,"map-cover button survives styled toolbar")
	expect(is_instance_valid(app.inventory_drop_button),"permanent token-vault drop target")
	expect(app.beyond_sheet.get_parent().is_visible_in_tree()==false,"inactive website is hidden")
	var a=Hearth20TokenInventory.new_actor("Casino master",true,app.campaign.scenes[0],Vector2(4.5,4.5));a.id="cm-guest";a.owner_player_id="";app.campaign.actors.append(a)
	var data=Hearth20TokenDrag.payload(app.session,a.id);expect(Hearth20TokenDrag.accepts(app.session,data),"current-campaign DM token drag")
	expect(not Hearth20TokenDrag.accepts(app.session,{"kind":"hearth20-token","scope":"foreign","actor_id":a.id}),"cross-campaign drag rejected")
	expect(app.session.store_inventory_token(a.id).ok and a.in_inventory,"stow from map")
	expect(app.board._can_drop_data(Vector2(400,350),data),"board accepts inventory card")
	app.board._drop_data(Vector2(400,350),data);expect(not a.in_inventory and is_equal_approx(fposmod(a.position.x,1),.5),"drop places in square center")
	var vault=app.open_token_inventory();await process_frame;expect(vault.cards.get_child_count()>0,"inventory cards populated");vault.queue_free();await process_frame
	await capture("map-controls")
	app.casino_portal.open()
	var deadline=Time.get_ticks_msec()+30000
	while app.casino_portal.phase!="ready" and Time.get_ticks_msec()<deadline:await process_frame
	var p=app.casino_portal;expect(p.phase=="ready","casino loads behind custom loading view")
	if p.phase!="ready":quit(1);return
	expect(not app.board.can_process() and app.session.can_process(),"map processing pauses while casino and network run")
	expect(p.hud.z_index>p.scene.card_surface.z_index,"casino selection controls above independent card surface")
	expect(not p.scene.stock_deck.visible and not p.scene.card_surface.visible,"no deck or card render over the casino selector")
	await capture("casino-catalog")
	for type in ["three_dragon_ante"]+Hearth20CasinoGames.TYPES:
		act("open",{"game":type,"chip_cp":10,"buyin":100,"minimum":1});act("join",{"actor_id":a.id});act("declare_balance",{"actor_id":a.id,"gp":125,"sp":3,"cp":7})
		var money=var_to_bytes([a.coins,app.campaign.get("tavern_ledger",[]),app.campaign.get("casino_receipts",[]),app.campaign.get("casino_house_cp",0)])
		expect(p.change_game_button.visible and not p.change_game_button.disabled,"DM can change an unfunded "+type+" lobby")
		p.change_game_button.pressed.emit();await process_frame
		expect(p.current().is_empty() and is_instance_valid(p.catalog_panel),"change game reopens the casino selector")
		expect(money==var_to_bytes([a.coins,app.campaign.get("tavern_ledger",[]),app.campaign.get("casino_receipts",[]),app.campaign.get("casino_house_cp",0)]),"switching an unfunded game leaves declared coins, bank, ledger and receipts unchanged")
	act("open",{"game":"gambit_of_ord","chip_cp":10,"buyin":100,"minimum":1});act("join",{"actor_id":a.id});act("declare_balance",{"actor_id":a.id,"gp":125,"sp":3,"cp":7})
	app.session.local_role="player";p._update_game_change();expect(not p.change_game_button.visible,"players are not offered the CM game switch");app.session.local_role="dm";p._update_game_change()
	expect(p.actions.find_children("*","SpinBox",true,false).size()==3,"three denomination inputs in lobby")
	await capture("declare-coins")
	# A two-seat private-dice snapshot exercises rendering without a campaign run.
	var state={"game":"gambit_of_ord","id":"visual","phase":"betting","round":1,"stage":3,"pot":6,"revealed":true,"seats":[{"name":"Guest","mine":true,"dice":[7,5,3],"dice_count":3,"folded":false,"flight":[]},{"name":"Other seat","dice":[2,4,1],"dice_count":3,"folded":false,"flight":[]}]}
	p.phase="visual-proof";p.scene.present(state,0);p.hud.hide()
	for die in p.scene.game_view.dice.values():die.set_process(false);die.place(die.resting,p.scene.card_camera,false)
	deadline=Time.get_ticks_msec()+15000
	while p.scene.game_view.preparing and Time.get_ticks_msec()<deadline:await process_frame
	expect(not p.scene.game_view.preparing,"reveal begins after the game's loading overlay finishes")
	await process_frame
	var elapsed=0.
	for stage in [[.65,"souls-gather"],[1.25,"white-aura"],[1.75,"forming-number"],[2.35,"soft-result-rays"],[4.6,"ice-and-wandering-souls"]]:
		while elapsed<float(stage[0])-.00001:
			var delta=minf(1./60.,float(stage[0])-elapsed)
			for die in p.scene.game_view.dice.values():die._process(delta)
			elapsed+=delta
			await process_frame
		for _warm in 3:await process_frame
		var first_die=p.scene.game_view.dice.values()[0]
		if float(stage[0])<1.3:expect(not first_die.number.visible,"aura builds before the result glyph is exposed")
		if is_equal_approx(float(stage[0]),1.25):expect(float(first_die.aura.material_override.get_shader_parameter("flash"))>.99,"camera-facing pane reaches white confluence")
		if is_equal_approx(float(stage[0]),2.35):expect(first_die.number.visible and float(first_die.aura.material_override.get_shader_parameter("rays"))==1.,"aura resolves into result and soft rays")
		await capture(str(stage[1]))
	for die in p.scene.game_view.dice.values():die.set_process(true)
	await create_timer(1.2).timeout
	expect(p.scene.game_view.dice.size()==6,"all visible soul dice created")
	for die in p.scene.game_view.dice.values():
		expect(die.get_meta("frame_vertices")>10000,"sculpted came mesh replaces cylinder rods")
		expect(die.detached_mist and die.mist.get_parent()==p.scene.soul_world,"wisps rendered behind the refractive glass")
		expect(die.number.visible and die.body.get_meta("result_value")==die.value,"revealed result retains host value")
		expect(die.mist.material_override.get_shader_parameter("heads").size()==5 and die.mist.material_override.get_shader_parameter("trails").size()==40,"GPU receives five animated souls and their independent trails")
		expect(die.body.has_node("FreezingCrystalSpears"),"raised crystal spears remain on the glass after the reveal")
	await capture("soul-dice")
	var first=p.scene.card_viewport.get_texture().get_image();await create_timer(.65).timeout
	var second=p.scene.card_viewport.get_texture().get_image()
	if DisplayServer.get_name()!="headless":expect(first.get_data()!=second.get_data(),"souls animate inside glass")
	await capture("soul-dice-motion")
	FileAccess.open(output.path_join("dice-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"fps":Performance.get_monitor(Performance.TIME_FPS),"visible_dice":p.scene.game_view.dice.size(),"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"render_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)},"\t"))
	p.scene.book.opened=true;p.scene._book_state(true);await process_frame;expect(p.scene.soul_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"book pauses soul rendering");p.scene.book.opened=false;p.scene._book_state(false)
	act("cancel");act("close");await p.close_local();await process_frame
	expect(app.find_children("SoulTransmissionBuffer","SubViewport",true,false).is_empty(),"extra soul viewport freed on casino exit")
	app.campaign.casino_receipts=[{"id":"receipt-ui","game_id":"casino-ui","actor_id":a.id,"player_id":"dm-local","name":"Casino master","kind":"payout","before_cp":12537,"after_cp":13203,"delta_cp":666,"acknowledged":false}]
	p.balance_notice.refresh();await process_frame
	expect(p.balance_notice.veil.visible and p.balance_notice.badge.visible,"settlement notice remains on map")
	expect(p.balance_notice.body.find_children("*","Label",true,false).any(func(l):return l.text=="132 gp · 0 sp · 3 cp"),"notice displays exact three-denomination final balance")
	await capture("balance-notice")
	p.balance_notice.body.find_children("*","Button",true,false).filter(func(b):return b.text=="I updated D&D Beyond")[0].pressed.emit();await process_frame
	expect(not p.balance_notice.badge.visible,"confirmation removes pending notice")
	# Open guest browser only; no account credentials are supplied by this test.
	if DisplayServer.get_name()!="headless":
		app.open_beyond_sheet();await create_timer(2).timeout
		deadline=Time.get_ticks_msec()+20000
		while not app.beyond_sheet.browser_ready and Time.get_ticks_msec()<deadline:await create_timer(.2).timeout
		expect(app.beyond_sheet.browser_ready,"native WebView2 initializes")
		await create_timer(5).timeout
		app.beyond_sheet._write({"visible":true,"x":35,"y":200,"width":1450,"height":740,"action":"capture","qa":true})
		await create_timer(1).timeout
		var guest=app.beyond_sheet.channel.path_join("guest-preview.png")
		expect(FileAccess.file_exists(guest),"embedded guest site can be rendered")
		if FileAccess.file_exists(guest):DirAccess.copy_absolute(guest,output.path_join("beyond-guest.png"))
		var browser_pid=app.beyond_sheet.pid;var browser_channel=app.beyond_sheet.channel
		app.beyond_sheet.toggle_expanded();app._show_sidebar_page(app.chat_page);await create_timer(.5).timeout
		var state_json=Hearth20MultiplayerLab.read_record(app.beyond_sheet.channel.path_join("status.json"))
		deadline=Time.get_ticks_msec()+15000
		while (not state_json is Dictionary or not state_json.get("suspended",false)) and Time.get_ticks_msec()<deadline:
			await create_timer(.2).timeout
			state_json=Hearth20MultiplayerLab.read_record(app.beyond_sheet.channel.path_join("status.json"))
		expect(state_json is Dictionary and not state_json.get("visible",true),"website hides outside Sheet")
		expect(state_json is Dictionary and state_json.get("suspended",false),"hidden website suspends rendering")
		expect(app.beyond_sheet.pid==browser_pid and OS.is_process_running(browser_pid),"closing expanded sheet preserves the existing browser process")
		for poll in 4:
			await create_timer(.3).timeout
			state_json=Hearth20MultiplayerLab.read_record(app.beyond_sheet.channel.path_join("status.json"))
			# Windows can briefly deny a read while the helper atomically replaces this file.
			# Retry incomplete records, while a valid unpaused state still fails immediately.
			for retry in 8:
				if state_json.has_all(["ready","visible","suspended"]):break
				await create_timer(.025).timeout;state_json=Hearth20MultiplayerLab.read_record(app.beyond_sheet.channel.path_join("status.json"))
			var diagnostic=state_json.duplicate(true) if state_json is Dictionary else {"invalid":true};diagnostic.erase("nonce");diagnostic.erase("url");FileAccess.open(output.path_join("browser-paused-"+str(poll)+".json"),FileAccess.WRITE).store_string(JSON.stringify(diagnostic,"\t"))
			expect(state_json is Dictionary and state_json.get("suspended",false) and not state_json.get("visible",true),"hidden sheet stays suspended across layout polls "+str(poll))
		app.open_beyond_sheet();deadline=Time.get_ticks_msec()+10000
		while Time.get_ticks_msec()<deadline:
			state_json=Hearth20MultiplayerLab.read_record(app.beyond_sheet.channel.path_join("status.json"))
			if state_json is Dictionary and state_json.get("visible",false) and not state_json.get("suspended",true):break
			await create_timer(.2).timeout
		expect(state_json is Dictionary and state_json.get("visible",false) and not state_json.get("suspended",true),"sheet resumes its existing page when reopened")
		expect(app.beyond_sheet.channel==browser_channel and app.beyond_sheet.pid==browser_pid,"reopening reuses the page and local browser channel")
		app.beyond_sheet.toggle_expanded();app._show_sidebar_page(app.chat_page)
		await create_timer(.5).timeout
		app.beyond_sheet.suspend_native();await create_timer(.5).timeout
	app.queue_free();await create_timer(.7).timeout
	FileAccess.open(output.path_join("ui-result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"\t"));print("Beyond UI: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)

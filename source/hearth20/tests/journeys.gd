extends SceneTree
var checks:=0
var errors: Array[String]=[]
var evidence: String
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: errors.append(message); push_error("FAIL: "+message)
func capture(window: Window, filename: String) -> void:
	await create_timer(.18).timeout; await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_png(evidence.path_join(filename+".png"))
func run() -> void:
	evidence=OS.get_environment("H20_QA_EVIDENCE")
	root.size=Vector2i(1440,900)
	var boot: Hearth20Boot=load("res://hearth20_boot.tscn").instantiate();root.add_child(boot)
	var deadline=Time.get_ticks_msec()+30000
	while not boot.desert.ready_to_show() and Time.get_ticks_msec()<deadline:await process_frame
	expect(boot.desert.creature!=null and boot.menu.visible and not boot.loading,"animated desert menu precedes the table")
	await capture(root,"title-tarrasque-desert")
	boot.begin_loading("new")
	while is_instance_valid(boot):await process_frame
	var shell=root.get_children().filter(func(node):return node is Hearth20SeatedShell).front()
	while not shell.ready_to_show:await process_frame
	var app: Hearth20App=shell.app
	app.toolbox.open("tokens")
	await create_timer(.2).timeout
	expect(app.toolbox.rail_buttons.has("tokens") and app.toolbox.rail_buttons.tokens.visible,"dedicated DM token side button")
	var panel: Hearth20TokenPanel=app.toolbox.content.find_children("*","Hearth20TokenPanel",true,false).front() if not app.toolbox.content.find_children("*","Hearth20TokenPanel",true,false).is_empty() else null
	if panel==null:
		for child in app.toolbox.content.get_children():
			if child is Hearth20TokenPanel: panel=child
	expect(panel!=null,"dedicated token editor opens")
	var id: String=app.board.add_token("Controlled creature",false,Vector2(2,2)); app.board.selected_actor_id=id
	await create_timer(.1).timeout
	var actor:=Hearth20Contracts.find_actor(app.campaign,id)
	expect(actor.owner_player_id.is_empty() and actor.movement_policy.mode=="blocked","new token defaults to DM only")
	var public_pem:=Hearth20PlayerProfile.public_key()
	var principal:=Hearth20PlayerProfile.principal(public_pem)
	app.campaign.participants[principal]={"public_key":public_pem,"display_name":"Test player"}
	expect(app.session.grant_token_control(id,principal,true).ok,"DM grants a saved player this specific creature")
	var moved:=Hearth20Contracts.authorize_and_apply_move(app.campaign,principal,"player",id,actor.position,actor.position+Vector2.RIGHT,5)
	expect(moved.ok,"granted player can move that token")
	expect(not Hearth20Contracts.authorize_and_apply_move(app.campaign,"another-player","player",id,actor.position,actor.position+Vector2.RIGHT,5).ok,"unassigned player cannot move it")
	var path:=Hearth20Identity.SAVE_ROOT+"/persistent-token-test.h20campaign"
	var saved:=Hearth20Identity.save_campaign(app.campaign,path)
	var restored:=Hearth20Identity.load_campaign(path)
	expect(saved.ok and restored.ok and restored.campaign.participants[principal].display_name=="Test player" and Hearth20Contracts.find_actor(restored.campaign,id).owner_player_id==principal,"saved campaign retains player identity and token grant")
	var nonce:=Crypto.new().generate_random_bytes(32)
	expect(Hearth20PlayerProfile.verify(nonce,public_pem,Hearth20PlayerProfile.sign(nonce)),"saved private identity proves its public key")
	expect(not Hearth20PlayerProfile.verify(Crypto.new().generate_random_bytes(32),public_pem,Hearth20PlayerProfile.sign(nonce)),"replayed signature fails a different challenge")
	expect(app.session.grant_token_control(id,"",false).ok and actor.owner_player_id.is_empty() and actor.movement_policy.mode=="blocked","DM revocation restores exclusive DM control")
	app.session.local_role="player"
	expect(not app.session.grant_token_control(id,principal,true).ok and not app.session.set_grid_style(.9,3,"#ffffff").ok,"players cannot grant token control or change host grid")
	app.session.local_role="dm"
	app._load_sample_map("sunspire-sanctum",false)
	expect(app.session.set_grid_style(.78,2.5,"#eee4c2").ok,"DM sets readable grid style")
	var scene: Dictionary=app.board.current_scene()
	expect(float(scene.grid_opacity)==.78 and float(scene.grid_thickness)==2.5,"grid settings are scene state")
	expect(not app.session.set_grid_style(2,1,"#ffffff").ok,"grid rejects unsupported opacity")
	app._show_sidebar_page(app.scene_page)
	await capture(root,"adjustable-grid-controls")
	app.toolbox.open("tokens"); await capture(root,"dedicated-token-controls")
	Hearth20PlayerProfile.remember("Returning adventurer","127.0.0.1",28930)
	expect(Hearth20PlayerProfile.preferences().display_name=="Returning adventurer","display name persists locally")
	for kind in Hearth20BoardTools.EFFECTS:
		var event: Dictionary=app.session.make_effect({"effect":kind,"material":"Blood","color":"#b51f42","size":1,"duration":2,"density":48},Vector2(2,2),Vector2(5,5))
		expect((event.source!=event.destination)==(kind in Hearth20BoardTools.CAST_EFFECTS),"trajectory matches effect placement type: "+kind)
	await material_gallery(app)
	shell.queue_free()
	await process_frame; await process_frame
	Hearth20PlayerProfile.cached_key=null
	print("Regal journeys: %d assertions, %d failures."%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
func material_gallery(app: Hearth20App) -> void:
	var window:=Window.new(); window.title="Hearth20 · Living materials"; window.size=Vector2i(1440,900); window.theme=Hearth20Design.theme(); root.add_child(window)
	var background:=ColorRect.new(); background.color=Color("#100e0b"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); window.add_child(background)
	var grid:=GridContainer.new(); grid.columns=4; grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12); window.add_child(grid)
	var renderers: Array=[]; var canvases: Array=[]
	for material_name in Hearth20BoardTools.COLORS:
		var card:=VBoxContainer.new(); card.custom_minimum_size=Vector2(348,280); grid.add_child(card)
		var label:=Label.new(); label.text=material_name; label.add_theme_color_override("font_color",Color("#e0bd75")); card.add_child(label)
		var canvas:=Control.new(); canvas.custom_minimum_size=Vector2(348,245); canvas.clip_contents=true; card.add_child(canvas); canvases.append(canvas)
		var fx:=Hearth20FxRenderer.new(); fx.world_scale=85; canvas.add_child(fx); renderers.append(fx)
		var event: Dictionary=app.session.make_effect({"effect":"explode","material":material_name,"color":Hearth20BoardTools.COLORS[material_name],"size":1,"duration":4,"density":64},Vector2(1,1),Vector2(2,1.4))
		fx.add_authorized_event(event)
	window.popup_centered()
	await create_timer(.45).timeout
	for fx in renderers: fx.events[0].started_usec=Time.get_ticks_usec()-1200000
	await capture(window,"fx-distinct-colored-materials")
	for fx in renderers: fx.events[0].color="#cccccc"; fx.events[0].started_usec=Time.get_ticks_usec()-1200000
	await capture(window,"fx-distinct-same-tint-materials")
	var image:=window.get_texture().get_image(); var hashes: Array=[]
	for canvas in canvases:
		var region:=image.get_region(Rect2i(canvas.get_global_rect()))
		hashes.append(Hearth20Contracts.sha256(region.get_data()))
	expect(hashes.size()==11 and hashes.all(func(value): return hashes.count(value)==1),"all eleven materials have distinct rendered geometry with the same tint")
	var before:=Hearth20Contracts.sha256(image.get_data())
	await create_timer(.45).timeout; await RenderingServer.frame_post_draw
	expect(before!=Hearth20Contracts.sha256(window.get_texture().get_image().get_data()),"material silhouettes animate over time")
	await capture(window,"fx-material-animation-later")
	window.queue_free()
	await process_frame; await process_frame

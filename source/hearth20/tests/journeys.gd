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
func wait_model(viewer: Hearth20BestiaryViewer) -> void:
	var deadline:=Time.get_ticks_msec()+30000
	while not viewer.ready_to_show() and not viewer.load_failed and Time.get_ticks_msec()<deadline: await process_frame
	await process_frame; await RenderingServer.frame_post_draw
func run() -> void:
	evidence=OS.get_environment("H20_QA_EVIDENCE")
	root.size=Vector2i(1440,900)
	var records:=Hearth20BestiaryCatalog.all()
	expect(records.size()==20,"twenty compendium creatures")
	var names: Array=[]; var ids: Array=[]; var tips: Array=[]
	for record in records:
		expect(not record.id in ids and not record.name in names,"distinct named creature: "+record.name); ids.append(record.id); names.append(record.name)
		expect(record.tips.size()==10 and record.tips.all(func(value): return value is String and value.length()>25),"ten complete field notes: "+record.name)
		tips.append_array(record.tips)
	expect(tips.size()==200,"two hundred tailored notes")
	ProjectSettings.set_setting("application/config/hearth20_debug",true)
	var boot: Hearth20Boot=load("res://hearth20_boot.tscn").instantiate(); root.add_child(boot)
	boot.choose_creature(1); await wait_model(boot.viewer)
	expect(boot.viewer.model!=null and boot.menu.visible and not boot.loading,"title appears before the heavy table loads")
	expect(boot.menu_drawn_msec>0 and boot.viewer.request_started_msec>=boot.menu_drawn_msec,"selected creature request begins only after the start menu renders")
	await capture(root,"title-beholder-black")
	boot._show_debug_lab(); await process_frame
	expect(boot.debug_enabled and boot.debug_dialog.visible and boot.debug_creature.item_count==20 and boot.debug_tip.item_count==10,"Loading Lab offers every creature and ten tips")
	expect(boot.debug_dialog.size.y<700 and boot.debug_dialog.size.x<800,"Loading Lab opens at a usable desktop size")
	expect(OS.is_debug_build(),"native showcase validation uses a debug-enabled engine")
	boot.debug_creature.select(11); boot.debug_creature.item_selected.emit(11); await wait_model(boot.viewer)
	expect(boot.viewer.video_mode and boot.creature_index==11,"Loading Lab selects the Skeleton video")
	boot.debug_tip.select(4); boot.debug_tip.item_selected.emit(4)
	expect(boot.tip_index==4 and boot.tip.text==records[11].tips[4],"Loading Lab selects an exact field note")
	await capture(boot.debug_dialog,"debug-loading-lab-controls")
	boot.set_debug_preview(true); boot.debug_dialog.hide(); await create_timer(.2).timeout
	expect(boot.debug_preview and not boot.loading and not boot.menu.visible and boot.progress.visible,"debug loading preview holds without entering the table")
	boot.debug_progress_slider.value=73; await RenderingServer.frame_post_draw; expect(boot.progress.value==73,"debug loading progress can be held at a chosen point")
	await capture(root,"debug-loading-preview-skeleton")
	boot.set_debug_preview(false); boot.debug_dialog.queue_free(); await process_frame
	expect(boot.menu.visible and not boot.debug_preview and not boot.progress.visible,"debug preview returns to the title menu")
	boot.choose_creature(1); await wait_model(boot.viewer)
	var old_tip:=boot.tip.text; boot.next_tip(); expect(old_tip!=boot.tip.text,"next field note changes the tip")
	var viewer:=boot.viewer; viewer.grab_focus()
	var key:=InputEventKey.new(); key.pressed=true; key.keycode=KEY_RIGHT; Input.parse_input_event(key); await process_frame
	expect(viewer.yaw>-.35,"viewer rotates with keyboard input")
	key=key.duplicate(); key.keycode=KEY_UP; Input.parse_input_event(key); await process_frame
	expect(viewer.lift>0,"viewer permits limited vertical movement")
	viewer.reset_view(); expect(is_zero_approx(viewer.lift) and is_equal_approx(viewer.yaw,-.35),"viewer reset restores position")
	var contact:=Image.create(1600,1280,false,Image.FORMAT_RGBA8); contact.fill(Color("#100e0b"))
	for i in records.size():
		boot.choose_creature(i); await wait_model(viewer)
		expect(viewer.ready_to_show() and not viewer.load_failed,"showcase loads: "+records[i].name)
		if not viewer.ready_to_show(): continue
		if viewer.video_mode: await verify_video(viewer); await capture(root,"skeleton-looping-video-with-audio")
		var image: Image=viewer.video.get_video_texture().get_image() if viewer.video_mode else viewer.viewport.get_texture().get_image()
		image.resize(320,180 if viewer.video_mode else 320,Image.INTERPOLATE_LANCZOS)
		var colored:=0; var solid:=0
		for y in range(0,image.get_height(),4):
			for x in range(0,320,4):
				var color:=image.get_pixel(x,y)
				if color.a>.2 and color.v>.05:
					solid+=1
					if color.s>.12: colored+=1
		expect(solid>100 and colored>50,"visible colored geometry: "+records[i].name)
		contact.blend_rect(image,Rect2i(0,0,image.get_width(),image.get_height()),Vector2i(i%5*320,i/5*320))
		if i in [0,1,4,5,14,16,18,19]: await capture(root,"creature-"+str(records[i].id))
	contact.save_png(evidence.path_join("twenty-colored-compendium-creatures.png"))
	boot.choose_creature(0); await wait_model(viewer)
	expect(viewer.video.stream==null and not viewer.video.is_playing(),"leaving Skeleton stops its decoder and audio")
	Hearth20Regal.toggle(); await capture(root,"title-dragon-parchment"); Hearth20Regal.toggle()
	root.size=Vector2i(1000,650); await create_timer(.2).timeout
	expect(boot.menu.get_global_rect().end.y<=650 and boot.creature_name.get_global_rect().end.x<=1000,"title actions and creature copy fit compact window")
	await capture(root,"title-compact")
	root.size=Vector2i(1440,900)
	boot.begin_loading("new")
	expect(boot.loading and boot.progress.visible and not boot.menu.visible,"title action starts actual threaded loading")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join("loading-creature-and-tip.png"))
	var deadline:=Time.get_ticks_msec()+15000
	while is_instance_valid(boot) and Time.get_ticks_msec()<deadline: await process_frame
	var app: Hearth20App=root.get_children().filter(func(node): return node is Hearth20App).front()
	expect(app!=null,"loading enters actual tabletop")
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
	app.queue_free()
	await process_frame; await process_frame
	Hearth20PlayerProfile.cached_key=null
	print("Regal journeys: %d assertions, %d failures."%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
func verify_video(viewer: Hearth20BestiaryViewer) -> void:
	var player:=viewer.video
	expect(player.loop and player.is_playing() and player.volume>0 and not viewer.scene_surface.visible,"Skeleton video loops with audio and hides the previous 3D surface")
	await create_timer(.25).timeout
	var before:=Hearth20Contracts.sha256(player.get_video_texture().get_image().get_data())
	await create_timer(.35).timeout
	expect(before!=Hearth20Contracts.sha256(player.get_video_texture().get_image().get_data()),"Skeleton decodes changing video frames")
	var deadline:=Time.get_ticks_msec()+7200; var previous:=player.stream_position; var wrapped:=false; var peak:=-100.0
	while Time.get_ticks_msec()<deadline:
		peak=maxf(peak,AudioServer.get_bus_peak_volume_left_db(0,0)); peak=maxf(peak,AudioServer.get_bus_peak_volume_right_db(0,0))
		if player.stream_position<previous-.5: wrapped=true
		previous=player.stream_position; await process_frame
	expect(wrapped and player.is_playing(),"Skeleton restarts automatically at the end of the clip")
	expect(peak> -65,"Skeleton audio reaches the native audio mixer")
	viewer.toggle_mute(); expect(is_zero_approx(player.volume),"Skeleton mute control silences playback"); viewer.toggle_mute()
	viewer.toggle_playback(); var paused_at:=player.stream_position; await create_timer(.2).timeout
	expect(absf(player.stream_position-paused_at)<.06,"Skeleton pause holds its current frame"); viewer.toggle_playback()
	viewer.set_video_volume(.35); expect(is_equal_approx(player.volume,.35),"Skeleton volume is adjustable"); viewer.set_video_volume(.8)
	viewer.reset_view(); expect(player.stream_position<.2 and player.is_playing(),"Skeleton replay starts from the beginning")
	print("Skeleton audio mixer peak: ",peak," dB; loop observed: ",wrapped)
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

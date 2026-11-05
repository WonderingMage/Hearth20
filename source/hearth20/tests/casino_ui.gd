extends SceneTree
var checks=0
var errors=[]
var app: Hearth20App
func _initialize() -> void:call_deferred("run")
func expect(ok: bool, text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error("FAIL: "+text)
func capture(name_value: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join(name_value+".png"))
func wait_ready(portal: Hearth20CasinoPortal) -> void:
	var end=Time.get_ticks_msec()+25000
	while portal.phase!="ready" and Time.get_ticks_msec()<end:await process_frame
	expect(portal.phase=="ready","custom loader reaches a rendered casino")
func act(action: String, values: Dictionary={}) -> Dictionary:
	var g=app.campaign.get("tavern_game",{});var c={"action":action,"game_id":g.get("id",""),"revision":g.get("revision",0)};c.merge(values);return app.session.casino_action(c)
func run() -> void:
	root.size=Vector2i(1440,900);app=load("res://hearth20_main.tscn").instantiate();root.add_child(app);await process_frame;app._load_sample_map("sunspire-sanctum",false)
	for i in 2:
		var actor=Hearth20TokenInventory.new_actor("Test guest "+str(i+1),true,app.board.current_scene(),Vector2(.5,.5));actor.id="casino-ui-"+str(i);actor.coins={"gp":25};actor.in_inventory=true;app.campaign.actors.append(actor)
	var audio=AudioStreamPlayer.new();var silence=AudioStreamWAV.new();silence.format=AudioStreamWAV.FORMAT_16_BITS;silence.mix_rate=22050;var data=PackedByteArray();data.resize(4096);silence.data=data;silence.loop_mode=AudioStreamWAV.LOOP_FORWARD;silence.loop_end=2048;audio.stream=silence;app.add_child(audio);audio.play()
	var baseline=app.find_children("*","SubViewport",true,false).size();app.toolbox.rail_buttons.casino.pressed.emit();var portal=app.casino_portal
	expect(portal.phase=="loading" and is_instance_valid(portal.loader),"Games rail immediately shows branded loading screen")
	expect(not app.board.can_process() and not app.board.is_visible_in_tree() and app.session.can_process(),"map pauses while networking stays active")
	expect(audio.stream_paused,"existing audio pauses instead of playing behind the casino")
	var shortcut=InputEventKey.new();shortcut.keycode=KEY_F7;shortcut.pressed=true;app._unhandled_key_input(shortcut);expect(app.get_children().filter(func(n):return n is Hearth20FxStudioWindow).is_empty(),"map shortcuts cannot start a second hidden 3D preview")
	await capture("casino-loading");await wait_ready(portal)
	expect(portal.saved.filter(func(r):return r.kind=="viewport").all(func(r):return r.node.get_ref().render_target_update_mode==SubViewport.UPDATE_DISABLED),"every background SubViewport is disabled")
	await capture("casino-catalog")
	app.session.submit_roll("","dice","","normal","public","1d20")
	expect(app.dice_stage.suspended and app.dice_stage.queue.is_empty() and app.dice_stage.active_entry.is_empty(),"background dice signals cannot start a hidden 3D animation or model load")
	expect(act("open",{"chip_cp":10}).ok,"CM opens a party table")
	for i in 2:expect(act("join",{"actor_id":"casino-ui-"+str(i)}).ok,"CM can seat an NPC character")
	expect(act("start").ok,"CM deals ready NPC seats")
	await create_timer(.8).timeout;expect(portal.scene.hand_hits.is_empty(),"CM has no participant hand by default")
	await capture("casino-dealer-view")
	portal.selected_view_seat=0;portal.signature="";portal._refresh();await create_timer(.8).timeout
	expect(portal.scene.hand_hits.size()==6 and portal.scene.pieces.size()==12,"six own faces and six opposite card backs rendered")
	expect(portal.scene.viewport.size.x>=1400 and portal.scene.viewport.size.y>=850,"card typography renders at window resolution through1080p")
	expect(portal.scene.card_viewport.own_world_3d and portal.scene.card_root.get_viewport()==portal.scene.card_viewport and portal.scene.card_camera!=portal.scene.camera,"cards render in an independent camera presentation world without table depth")
	for value in [1,5,13]:
		var proof=Node3D.new();var record={}
		for c in Hearth20TavernGames.cards().values():
			if c.strength==value:record=c;break
		portal.scene.card_style.decorate(proof,record);var numeral=proof.get_node("SilverValue");var bounds=numeral.mesh.get_aabb();var fits=true
		for x in [bounds.position.x,bounds.end.x]:
			for y in [bounds.position.y,bounds.end.y]:
				var p=numeral.transform*Vector3(x,y,0);fits=fits and Vector2(p.x,p.z).distance_to(Hearth20CasinoCard.MEDAL)<.0675
		expect(fits,"visible ink bounds of value "+str(value)+" fit wholly inside the velvet medallion");proof.free()
	portal.scene.set_process(false);await process_frame;await RenderingServer.frame_post_draw
	var before_layer=portal.scene.card_viewport.get_texture().get_image();var before_world=portal.scene.viewport.get_texture().get_image()
	var obstruction=MeshInstance3D.new();var box_mesh=BoxMesh.new();box_mesh.size=Vector3(8,8,.1);obstruction.mesh=box_mesh;var black=StandardMaterial3D.new();black.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;black.albedo_color=Color.BLACK;obstruction.material_override=black;portal.scene.world.add_child(obstruction);obstruction.global_transform=portal.scene.camera.global_transform;obstruction.global_position-=portal.scene.camera.global_basis.z*.6
	await process_frame;await RenderingServer.frame_post_draw
	expect(Hearth20Contracts.sha256(before_layer.get_data())==Hearth20Contracts.sha256(portal.scene.card_viewport.get_texture().get_image().get_data()) and Hearth20Contracts.sha256(before_world.get_data())!=Hearth20Contracts.sha256(portal.scene.viewport.get_texture().get_image().get_data()),"opaque environment in front of the camera changes table pixels while card presentation stays unchanged")
	await capture("casino-cards-in-front-of-opaque-environment");obstruction.queue_free();portal.scene.set_process(true);await process_frame
	var separated=true
	for k in range(1,portal.scene.hand_hits.size()):
		var previous=portal.scene.hand_hits[k-1].node;var next=portal.scene.hand_hits[k].node;var normal=next.global_transform.basis.y.normalized();var low=INF;var high=-INF
		for x in [-.225,.225]:
			for z in [-.34,.34]:
				var distance=normal.dot(previous.to_global(Vector3(x,0,z))-next.global_position);low=minf(low,distance);high=maxf(high,distance)
		if not (low>.010 or high<-.010):separated=false
	expect(separated,"adjacent card slabs and printed faces have physical depth clearance")
	var hit=portal.scene.hand_hits[3];var vp=portal.scene.viewport;var point=portal.scene.camera.unproject_position(hit.node.global_position)*portal.scene.size/Vector2(vp.size)
	var motion=InputEventMouseMotion.new();motion.position=point;portal.scene._input_table(motion);await create_timer(.25).timeout
	expect(not portal.scene.hovered.is_empty() and portal.scene.hand_hits.any(func(h):return h.node.get_meta("aura").visible),"3D pointer hover raises a card and animates its gold aura")
	var click=InputEventMouseButton.new();click.position=point;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;portal.scene._input_table(click)
	expect(not portal.selected.is_empty(),"ray-picked private card opens its actual action")
	await capture("casino-floating-hand-hover")
	var game_signature=Hearth20Contracts.sha256(var_to_bytes(app.campaign.tavern_game));var first_selected=portal.selected
	portal.scene.selected="";portal.scene.hovered="";await create_timer(.5).timeout
	var peek_click=InputEventMouseButton.new();peek_click.button_index=MOUSE_BUTTON_LEFT;peek_click.pressed=true;var found_empty=false
	for x in [-.6,0.,.6]:
		for z in [-.4,0.,.4]:
			var candidate=portal.scene.camera.unproject_position(Vector3(x,.84,z))*portal.scene.size/Vector2(portal.scene.viewport.size)
			if portal.scene._hit_card(candidate).is_empty():peek_click.position=candidate;found_empty=true;break
		if found_empty:break
	expect(found_empty,"an unobstructed center-table target is available to click")
	portal.scene._input_table(peek_click);await create_timer(1.2).timeout
	var top=INF;var bottom=-INF;var shown=portal.scene.hand_hits[2]
	for x in [-.225,.225]:
		for z in [-.34,.34]:
			var peek_point=portal.scene.camera.unproject_position(shown.node.to_global(Vector3(x,0,z)));top=minf(top,peek_point.y);bottom=maxf(bottom,peek_point.y)
	var visible=(minf(bottom,float(portal.scene.viewport.size.y))-maxf(0.,top))/maxf(1.,bottom-top)
	expect(portal.scene.peeking and visible>.12 and visible<.28,"peek lowers hand to only its top20percent while centering table")
	# A projected bounding box can pass even when the table occludes the cards.
	portal.scene.set_process(false);portal.scene.material.set_shader_parameter("grain_strength",0.)
	await process_frame;await RenderingServer.frame_post_draw
	var with_hand=portal.scene.card_viewport.get_texture().get_image()
	for h in portal.scene.hand_hits:h.node.hide()
	await process_frame;await RenderingServer.frame_post_draw
	var without_hand=portal.scene.card_viewport.get_texture().get_image();var visible_pixels=0
	for y in range(maxi(0,with_hand.get_height()-100),with_hand.get_height()):
		for x in with_hand.get_width():
			var a=with_hand.get_pixel(x,y);var b=without_hand.get_pixel(x,y)
			if a.r>.30 and absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.20:visible_pixels+=1
	for h in portal.scene.hand_hits:h.node.show()
	portal.scene.material.set_shader_parameter("grain_strength",.035);portal.scene.set_process(true)
	expect(visible_pixels>1200,"peek card tops are rendered in front of the rim, not merely projected offscreen")
	await capture("casino-peek-over-hand");portal.scene.toggle_peek();await create_timer(.6).timeout
	expect(not portal.scene.peeking and portal.scene.hand_hits[2].node.position.y>.95,"peek restores the private hand")
	var book=portal.scene.book;expect(book.pages.is_empty() and not book.opened,"personal rules book has no running page viewports while closed")
	await capture("casino-personal-da-rolls-book");var book_click=InputEventMouseButton.new();book_click.button_index=MOUSE_BUTTON_LEFT;book_click.pressed=true;book_click.position=portal.scene.camera.unproject_position(book.to_global(Vector3(.33,.20,0)))*portal.scene.size/Vector2(portal.scene.viewport.size);portal.scene._input_table(book_click);await create_timer(1.1).timeout
	expect(book.opened and book.pages.size()==2 and not portal.hud.visible,"personal thick book opens with four game chapters")
	expect(book.straps.all(func(s):return book._strap_point(.5,1.).x>.67),"open leather straps curve outside the reading pages")
	await capture("casino-da-rolls-contents");var chapter_click=InputEventMouseButton.new();chapter_click.button_index=MOUSE_BUTTON_LEFT;chapter_click.pressed=true;chapter_click.position=portal.scene.camera.unproject_position(book.to_global(Vector3(-.33,.19,-.10)))*portal.scene.size/Vector2(portal.scene.viewport.size);portal.scene._input_table(chapter_click);await create_timer(.15).timeout
	expect(book.riffles.size()>=8 and book.retired_pages.size()==2,"chapter jump riffles multiple physical sheets while preserving outgoing page textures")
	await capture("casino-da-rolls-rapid-pages");await create_timer(.9).timeout
	expect(book.chapter==0 and book.pages.size()==2,"physical page turn reaches the current game's rules")
	await capture("casino-da-rolls-three-dragon-ante")
	expect(book.pages.all(func(p):return p.get_children().filter(func(n):return n.has_meta("book_body")).all(func(n):return n.get_theme_font_size("font_size")==40 and n.get_rect().end.y<=(620 if p==book.pages[1] else 940))),"large40-point rules text fits its page without overlapping the action panel")
	var before=Hearth20Contracts.sha256(book.pages[1].get_texture().get_image().get_data());await create_timer(.8).timeout
	expect(before!=Hearth20Contracts.sha256(book.pages[1].get_texture().get_image().get_data()) and book.guides.size()==1,"in-book action illustration visibly loops in the local page")
	book.turn_spread(1);await create_timer(.65).timeout;expect(book.spread==1 and book.riffles.is_empty(),"page corners and arrows advance to the next large-print spread")
	book.select_chapter(3);await create_timer(.9).timeout;expect(book.chapter==3,"bookmarks reach all four playable chapters")
	book.close_book();await book.closed;await process_frame;expect(not book.opened and book.pages.is_empty() and book.leaves.is_empty() and portal.hud.visible,"closing personal book frees page viewports and restores table UI")
	expect(is_instance_valid(book.right_stack) and book.right_stack.visible and is_equal_approx(book.right_stack.scale.y,1.) and book.right_stack.mesh.get_aabb().size.y>.11,"resting closed book retains its full opaque paper stack after reading pages are freed")
	await create_timer(.8).timeout;await capture("casino-resting-book-full-page-block")
	expect(Hearth20Contracts.sha256(var_to_bytes(app.campaign.tavern_game))==game_signature,"peek and personal rules reading send no game mutations")
	portal._select_card(first_selected)
	var g=app.campaign.tavern_game;var first=portal.selected;expect(act("ante",{"actor_id":"casino-ui-0","card_id":first}).ok,"selected card becomes face-down ante")
	await create_timer(.6).timeout;expect(portal.scene.pieces.has("pending-ante:0"),"hidden play remains a black-and-gold card on the table")
	await capture("casino-hidden-ante")
	g=app.campaign.tavern_game;var other=""
	for id in g.seats[1].hand:
		if Hearth20TavernGames.card(id).strength!=Hearth20TavernGames.card(first).strength:other=id;break
	expect(not other.is_empty() and act("ante",{"actor_id":"casino-ui-1","card_id":other}).ok,"all committed antes reveal together")
	await create_timer(.7).timeout;expect(portal.scene.pieces.keys().filter(func(k):return str(k).begins_with("ante:")).size()==2,"public ante faces appear at shared positions")
	g=app.campaign.tavern_game;var id=g.seats[g.turn].hand[0];expect(act("play",{"card_id":id}).ok,"legal card plays onto public flight")
	await create_timer(.7).timeout;await capture("casino-public-card-play")
	for n in 4:
		var count=n+3;var seats=[]
		for i in count:seats.append({"name":"Seat "+str(i),"hand_count":3,"hand":["black-1","blue-2","red-3"] if i==0 else [],"flight":[],"ante_chosen":false})
		portal.scene.present({"seats":seats,"phase":"play","ante":[]},0);expect(portal.scene.pieces.size()==count*3,"floating hands evenly arrange for "+str(count)+" seated players, CM excluded")
		if count in [4,5]:await create_timer(.7).timeout;await capture("casino-"+str(count)+"-seat-layout")
	portal.signature="";portal._refresh();await create_timer(.5).timeout
	var times=[]
	for i in 90:
		var at=Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw
		if i>15:times.append((Time.get_ticks_usec()-at)/1000.)
	times.sort();FileAccess.open(OS.get_environment("H20_QA_EVIDENCE").path_join("casino-performance.json"),FileAccess.WRITE).store_string(JSON.stringify({"median_frame_ms":times[times.size()/2],"p95_frame_ms":times[floori(times.size()*.95)],"frames":times.size(),"renderer":RenderingServer.get_video_adapter_name(),"map_paused":not app.board.can_process(),"world_resolution":str(portal.scene.viewport.size)},"\t"))
	expect(times[times.size()/2]<50,"first-person table remains interactive on native GPU")
	expect(act("cancel").ok and act("close").ok,"CM refunds and closes party table")
	var weak=weakref(portal.scene);await portal.close_local();await process_frame;await process_frame
	expect(weak.get_ref()==null and portal.phase=="closed" and portal.assets.is_empty(),"casino 3D scene and assets release on exit")
	expect(app.board.can_process() and app.board.is_visible_in_tree() and app.session.can_process() and not app.dice_stage.suspended,"2D map and networking restore after teardown")
	expect(app.find_children("*","SubViewport",true,false).size()==baseline,"no extra casino viewport remains running")
	expect(not audio.stream_paused,"existing audio pause state restores with the map")
	await capture("casino-returned-to-map")
	portal.open();await wait_ready(portal);portal.scene.book.open_book();await create_timer(.35).timeout;await portal.close_local();await process_frame
	expect(app.find_children("*","SubViewport",true,false).size()==baseline and app.board.can_process(),"forced casino exit during book animation leaves no page or game viewport alive")
	portal.open();await wait_ready(portal);portal.scene.book.open_book();await create_timer(1.).timeout;portal.scene.book.select_chapter(3);await create_timer(.1).timeout;await portal.close_local();await process_frame
	expect(app.find_children("*","SubViewport",true,false).size()==baseline and app.board.can_process(),"forced exit mid-riffle frees retained textures and looping action panels")
	app.queue_free();await process_frame;await process_frame
	print("First-person casino UI: %d assertions, %d failures."%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

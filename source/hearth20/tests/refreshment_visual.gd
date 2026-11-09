extends SceneTree
var shell: Hearth20SeatedShell
var output=""
var checks=0
var errors=[]
func _initialize() -> void:output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func until(predicate: Callable,message: String) -> void:
	var deadline=Time.get_ticks_msec()+20000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	expect(predicate.call(),message)
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(label+".png"))
func finish_pending() -> void:
	var pending=shell.app.campaign.refreshments["dm-local"].pending
	if pending.is_empty():await process_frame;return
	pending.ends_at=Time.get_unix_time_from_system()-.01
	Hearth20Refreshments.advance(shell.app.campaign,Time.get_unix_time_from_system());await create_timer(.22).timeout
func run() -> void:
	root.size=Vector2i(1600,1000);shell=Hearth20SeatedShell.new();root.add_child(shell);await until(func():return shell.ready_to_show,"table ready")
	var tray=shell.refreshments;await create_timer(.3).timeout;tray.glance();await create_timer(.7).timeout
	expect(tray.menu_model.visible and tray.stool.position.x>0.,"physical menu on right-hand stool")
	expect(tray.stool.get_child(0).material_override==shell.table.wood,"stool shares game table wood")
	await capture("refreshment-stool-menu")
	var screen=shell.table.camera.unproject_position(tray.menu_model.global_position);expect(tray.hit(screen) and tray.menu.visible,"click physical menu opens provisions")
	expect(tray.menu.choices.size()==21,"all 15 foods and six drinks selectable")
	for sound in ["drink","chewy","pastry","wet","crisp","chips","lick"]:
		var clip=load(Hearth20RefreshmentCatalog.BASE+"audio/"+sound+".ogg")
		expect(clip is AudioStream and absf(clip.get_length()-3.)<.04,"three-second "+sound+" recording")
	tray.menu._select("chips",true);tray.menu._select("beer",false);await capture("refreshment-menu")
	tray.menu.confirm.pressed.emit();await until(func():return is_instance_valid(tray.food_model) and is_instance_valid(tray.drink_model),"selected models load lazily")
	expect(not tray.menu.visible and not tray.menu_model.visible,"ordering removes menu")
	await create_timer(.4).timeout;await capture("smoke-serving");await create_timer(.7).timeout;await capture("chips-beer")
	expect(not is_instance_valid(tray.plate),"bag needs no plate")
	var s=shell.app.campaign.refreshments["dm-local"]
	for kind in ["bite","bite","sip","sip","sip"]:
		var result=shell.app.session.refreshments_action({"action":kind,"order_id":s.order.id});expect(result.ok,"click "+kind)
		await create_timer(.9).timeout
		if kind=="bite":await capture("eating")
		else:await capture("drinking")
		await finish_pending()
		s=shell.app.campaign.refreshments["dm-local"]
		if int(s.food_bites)==2 and int(s.drink_sips)==0:expect(not is_instance_valid(tray.food_model) and tray.menu_model.visible==false,"food disappears after two bites but drink blocks menu")
	expect(s.food_bites==2 and s.drink_sips==3 and tray.menu_model.visible,"third sip finishes both and restores menu")
	expect(s.beers.size()==1,"finished beer adds one dose")
	var foreign={"id":"other-party-snack","player_id":"other-player","kind":"bite","food":"chips","number":0}
	tray._event(foreign);tray._event(foreign)
	expect(tray.get_children().filter(func(n):return n is AudioStreamPlayer).size()>=2,"other player's bag and crunch play locally")
	var count=tray.get_children().filter(func(n):return n is AudioStreamPlayer).size();tray._event(foreign)
	expect(tray.get_children().filter(func(n):return n is AudioStreamPlayer).size()==count,"duplicate party event cannot replay sound")
	# Allow the natural 3-second party sounds to finish before tearing down.
	await create_timer(3.6).timeout
	shell.app.session.refreshments_action({"action":"order","food":"cake","drink":"water"});await until(func():return is_instance_valid(tray.plate),"uncontained cake served on plate")
	await create_timer(1.).timeout;await capture("cake-water-plate")
	var time=Time.get_unix_time_from_system();s=shell.app.campaign.refreshments["dm-local"]
	s.beers=[time,time,time,time];await create_timer(.3).timeout;await capture("four-beer-blur")
	expect(tray.effect.visible and float(tray.effect.material.get_shader_parameter("beers"))==4.,"four beers drive blur and sway")
	s.beers=[time,time,time,time,time,time];s.blackout_until=time+300.;await create_timer(.3).timeout;await capture("blackout-spectator")
	expect(tray.veil.visible and shell.map_viewport.gui_disable_input,"six beers enable read-only spectator layer")
	shell.focus_sheet();expect(shell.focus_state=="table","blackout cannot open interactive sheet")
	s.blackout_until=Time.get_unix_time_from_system()-.01;Hearth20Refreshments.advance(shell.app.campaign,Time.get_unix_time_from_system());await create_timer(.3).timeout
	expect(not tray.veil.visible and not shell.map_viewport.gui_disable_input and s.beers.is_empty(),"five-minute wake clears every beer effect and restores play")
	expect(is_instance_valid(tray.wake_player) and tray.wake_player.playing and tray.blackout_flash>0.,"supplied MP3 plays as camera unfades from black")
	var wake_id=tray.wake_player.get_instance_id();tray._sync();tray._sync();expect(tray.wake_player.get_instance_id()==wake_id,"wake sound plays once per blackout")
	await create_timer(2.7).timeout;expect(not tray.effect.visible,"view clears completely after wake fade")
	await capture("finally-awake")
	shell.queue_free();await create_timer(.6).timeout;Hearth20RefreshmentModels.cache.clear();await process_frame
	print("Refreshment visuals: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)

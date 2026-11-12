extends SceneTree
var output=""
var checks=0
var errors=[]
var clicks=0
var shell: Hearth20SeatedShell
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func settle() -> void:
	for i in 5:await process_frame
func point(control: Control) -> Vector2:
	var position=control.get_global_rect().get_center();var viewport=control.get_viewport()
	if viewport is Window:
		var parent_view=viewport.get_parent().get_viewport();position+=Vector2(viewport.position)
		if parent_view==shell.map_viewport:position*=shell.focus_surface.size/Vector2(shell.map_viewport.size)
	elif viewport==shell.map_viewport:position*=shell.focus_surface.size/Vector2(shell.map_viewport.size)
	return position
func click(position: Vector2) -> void:
	for pressed in [true,false]:
		var motion=InputEventMouseMotion.new();motion.position=position;motion.global_position=position;root.push_input(motion)
		var event=InputEventMouseButton.new();event.position=position;event.global_position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event);await settle()
func key(code: int,unicode_value: int=0) -> void:
	for pressed in [true,false]:
		var event=InputEventKey.new();event.keycode=code;event.unicode=unicode_value;event.pressed=pressed;root.push_input(event)
	await settle()
func choose_file(app: Hearth20App,name_value: String) -> void:
	var field=app.token_dialog.get_line_edit();field.text="";await click(point(field))
	for character in name_value:await key(0,character.unicode_at(0))
	expect(field.text==name_value,"file name accepts real typing")
	await key(KEY_ENTER)
func native_step(app: Hearth20App,phase: String,id: String) -> void:
	app.token_dialog.current_dir=output;app.token_dialog.use_native_dialog=true;app._open_token_dialog(id)
	FileAccess.open(output.path_join("native-phase.json"),FileAccess.WRITE).store_string(JSON.stringify({"phase":phase,"pid":OS.get_process_id(),"title":app.token_dialog.title,"path":output.path_join("native.png")}))
	var until=Time.get_ticks_msec()+15000
	while not app.token_image_actor_id.is_empty() and Time.get_ticks_msec()<until:await process_frame
	expect(app.token_image_actor_id.is_empty(),"native Windows picker completes "+phase)
	await settle();FileAccess.open(output.path_join("native-"+phase+".done"),FileAccess.WRITE).store_string("done")
func run() -> void:
	output=OS.get_cmdline_user_args()[0];root.size=Vector2i(1280,800);root.gui_embed_subwindows=not "--native-picker" in OS.get_cmdline_user_args()
	create_timer(100).timeout.connect(func():push_error("Token picker watchdog");quit(1))
	Hearth20Preferences.values.startup_updates=false
	shell=Hearth20SeatedShell.new();root.add_child(shell)
	while not shell.ready_to_show:await process_frame
	shell.focus_map();var app=shell.app
	var id=app.board.add_token("Picker hero",true,Vector2(3.5,3.5));app.board.selected_actor_id=id
	app.inspector_toggle.pressed.connect(func():clicks+=1)
	var image=Image.create(64,64,false,Image.FORMAT_RGBA8);image.fill(Color.GOLD);image.save_png(output.path_join("valid.png"))
	image.fill(Color.CYAN);image.save_png(output.path_join("native.png"))
	if "--native-picker" in OS.get_cmdline_user_args():
		for phase in ["cancel","select"]:await native_step(app,phase,id)
		expect(Hearth20Assets.read_asset(app.campaign,Hearth20Contracts.find_actor(app.campaign,id).get("png_asset_id",""),"token")==FileAccess.get_file_as_bytes(output.path_join("native.png")),"real Windows Open installs the exact selected PNG")
		var native_inventory=app.open_token_inventory();native_inventory.select_token(id);await settle();await native_step(app,"inventory-cancel",id)
		native_inventory.queue_free();await settle()
		expect(not app.token_dialog.visible and not app.token_dialog.exclusive and not shell.has_modal() and not shell.map_viewport.gui_disable_input and not app.inspector_toggle.disabled,"native picker cleanup leaves no visible modal or exclusive input lock")
		app.session.stop_session();shell.queue_free();await create_timer(.5).timeout
		print("Token picker input: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1);return
	app.token_dialog.use_native_dialog=false
	app._open_token_dialog();await settle()
	expect(app.token_dialog.visible,"the token picker opens")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("token-picker-before.png"))
	await click(point(app.token_dialog.get_cancel_button()))
	expect(not app.token_dialog.visible,"real Cancel click dismisses the token picker")
	await click(point(app.inspector_toggle))
	expect(clicks==1,"DM toolbar responds after cancelling the picker")
	FileAccess.open(output.path_join("corrupt.png"),FileAccess.WRITE).store_string("not a PNG")
	app.token_dialog.current_dir=output
	for repeat in 2:
		app._open_token_dialog(id);await settle();await key(KEY_ESCAPE)
		expect(not app.token_dialog.visible,"Escape closes the picker on repeated use")
	app._open_token_dialog(id);await settle()
	await click(Vector2(app.token_dialog.position)+Vector2(app.token_dialog.size.x-12,-16))
	expect(not app.token_dialog.visible,"real title-bar X closes the picker")
	app._open_token_dialog(id);await settle();await choose_file(app,"valid.png")
	var actor=Hearth20Contracts.find_actor(app.campaign,id);var original_asset=actor.get("png_asset_id","")
	expect(not original_asset.is_empty() and not app.token_dialog.visible,"choosing a valid PNG changes the token and releases the dialog")
	app._open_token_dialog(id);await settle();await choose_file(app,"corrupt.png")
	expect(actor.png_asset_id==original_asset and not app.token_dialog.visible,"invalid PNG leaves appearance intact and releases input")
	var other=app.board.add_token("Other token",false,Vector2(5.5,3.5));app._open_token_dialog(id);await settle();app.board.selected_actor_id=other
	await choose_file(app,"valid.png")
	expect(Hearth20Contracts.find_actor(app.campaign,other).get("png_asset_id","").is_empty(),"a changed board selection cannot redirect the chosen portrait")
	app.board.selected_actor_id=id
	var inventory=app.open_token_inventory();inventory.select_token(id);await settle()
	var choose: Button
	for button in inventory.editor.find_children("*","Button",true,false):
		if button.text=="Choose token image…":choose=button
	var ancestor=choose.get_parent()
	while ancestor!=null and not ancestor is ScrollContainer:ancestor=ancestor.get_parent()
	if ancestor is ScrollContainer:ancestor.ensure_control_visible(choose);await settle()
	await click(point(choose));expect(app.token_dialog.visible,"the inventory image button uses the same working picker")
	await click(point(app.token_dialog.get_cancel_button()));expect(not app.token_dialog.visible and inventory.visible,"cancelling returns to the inventory")
	inventory.queue_free();await settle()
	await click(point(app.inspector_toggle));expect(clicks==2,"DM buttons remain usable after all file-selection paths")
	app.session.stop_session();await create_timer(.5).timeout
	print("Token picker input: %d checks, %d failures"%[checks,errors.size()]);shell.queue_free();await create_timer(.5).timeout;quit(0 if errors.is_empty() else 1)

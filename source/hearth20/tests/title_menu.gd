extends SceneTree
const MapMetadataFixture=preload("map_metadata.gd")
class MenuFixture extends Hearth20Boot:
	var requested_actions=[]
	var permit_loading=false
	func begin_loading(action: String,save_path="") -> void:
		if permit_loading:super.begin_loading(action,save_path)
		else:requested_actions.append(action)
var checks=0
var errors=[]
var output=""
func _initialize() -> void:call_deferred("run")
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func settle() -> void:
	for frame in 5:await process_frame
func capture(name: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func click(button: Button) -> void:
	var point=button.get_global_rect().get_center()
	if button.get_window()!=root:point+=Vector2(button.get_window().position)
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.position=point;event.global_position=point;root.push_input(event)
	await settle()
func run() -> void:
	output=OS.get_cmdline_user_args()[0];root.gui_embed_subwindows=true;root.size=Vector2i(1600,900)
	create_timer(120).timeout.connect(func():push_error("Menu/map calibration watchdog");quit(1))
	Hearth20Preferences.values.startup_updates=false
	var boot=MenuFixture.new();root.add_child(boot);await settle()
	expect(boot.menu.visible and not boot.loading,"Join and Host are immediately available")
	expect(boot.artwork.texture.get_size()==Vector2(2752,1536),"the original artwork retains its full native resolution")
	# Exported image paths remap to lossless texture containers, not raw JPG bytes.
	# Compare every decoded pixel instead; the source JPG hash is in build evidence.
	var original_pixels=boot.artwork.texture.get_image();original_pixels.clear_mipmaps();original_pixels.convert(Image.FORMAT_RGB8)
	expect(Hearth20Contracts.sha256(original_pixels.get_data())=="90f1bdb451a2831cc2026c0056082722241bcec749cfb144e818d26bccbda6a7","every decoded base-image pixel matches the revised JPG; no face replacement")
	original_pixels=null
	expect(boot.find_children("*","SubViewport",true,false).is_empty(),"the menu does not render an unused 3D showcase")
	await click(boot.find_child("JoinTable",true,false));await click(boot.find_child("HostTable",true,false))
	expect(boot.requested_actions==["join","host"],"native clicks select the correct Join and Host flows")
	await capture("title-1600")
	for dimensions in [Vector2i(1000,650),Vector2i(1280,720),Vector2i(2560,1080)]:
		root.size=dimensions;await settle()
		for button in boot.menu.find_children("*","Button",true,false):
			expect(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(button.get_global_rect()),"menu action remains reachable at "+str(dimensions)+button.text)
		await capture("title-"+str(dimensions.x))
	boot._show_scene_credits();await settle()
	var credits=boot.find_children("*","AcceptDialog",true,false).front();await click(credits.get_ok_button())
	expect(not is_instance_valid(credits),"artwork credits close cleanly")
	root.size=Vector2i(1280,720);await settle()
	var art_ref=weakref(boot.artwork);boot.permit_loading=true;boot.begin_loading("new");boot.begin_loading("host")
	expect(boot.mode=="new" and boot.loading and boot.progress.visible and not boot.menu.visible,"duplicate clicks start one transition with progress")
	await capture("loading-party")
	while is_instance_valid(boot):await process_frame
	expect(art_ref.get_ref()==null,"the menu artwork node is released after loading")
	art_ref=null
	var shell: Hearth20SeatedShell
	for node in root.get_children():
		if node is Hearth20SeatedShell:shell=node
	while not shell.ready_to_show:await process_frame
	shell.focus_map();var app=shell.app
	# Exercise the same import callback as the file chooser, with a genuinely tall map.
	var image=Image.create(128,1024,false,Image.FORMAT_RGB8);image.fill(Color("#b39167"))
	var map_path=output.path_join("tall-import.png");image.save_png(map_path)
	app._on_map_selected(map_path);await settle()
	var dialog=shell.get_node("GridCalibration") as AcceptDialog
	expect(dialog!=null and dialog.get_parent()==shell,"calibration belongs to the main window rather than the embedded map")
	expect(app._calibrate_prompt()==dialog,"repeated calibration reuses the same dialog")
	for dimensions in [Vector2i(640,480),Vector2i(1000,650),Vector2i(1280,720)]:
		root.size=dimensions;Hearth20Design.popup_window(dialog);await settle()
		expect(dialog.position.y>=24 and dialog.position.y+dialog.size.y<=dimensions.y and dialog.size.x<=dimensions.x,"calibration stays within the actual window at "+str(dimensions))
		for button in [dialog.get_ok_button(),dialog.get_cancel_button()]:
			expect(Rect2(Vector2.ZERO,Vector2(dialog.size)).encloses(button.get_global_rect()),"calibration footer stays reachable at "+str(dimensions)+button.text)
		await capture("map-calibration-"+str(dimensions.x))
	var cells=dialog.find_child("WidthCells",true,false) as SpinBox
	for text in ["", "0", "257", "1/0", "2.5"]:
		cells.get_line_edit().text=text;cells.get_line_edit().text_changed.emit(text)
		await click(dialog.get_ok_button())
		expect(is_instance_valid(dialog) and dialog.visible and not (dialog.find_child("ValidationError",true,false) as Label).text.is_empty(),"bad calibration is explained without trapping the user: "+text)
	cells.get_line_edit().text="032";cells.get_line_edit().text_changed.emit("032")
	await click(dialog.get_ok_button())
	expect(not is_instance_valid(dialog) and int(app.board.current_scene().calibration_width_cells)==32,"a native Apply click commits the typed value before focus loss")
	dialog=app._calibrate_prompt();await settle();var before=app.campaign.revision
	await click(dialog.get_cancel_button())
	expect(not is_instance_valid(dialog) and app.campaign.revision==before,"Keep current grid dismisses without changing the map")
	dialog=app._calibrate_prompt();await settle();dialog.close_requested.emit();await settle()
	expect(not is_instance_valid(dialog),"the window Close action also releases calibration")
	var auto_image=Image.create(320,240,false,Image.FORMAT_RGB8);auto_image.fill(Color("#badcaa"))
	var auto_png=MapMetadataFixture.embed(auto_image.save_png_to_buffer(),JSON.stringify({"schema":1,"width_cells":32,"height_cells":24,"feet_per_cell":10}))
	var auto_path=output.path_join("auto-map.hearth20.png")
	var generated_file=FileAccess.open(auto_path,FileAccess.WRITE);generated_file.store_buffer(auto_png);generated_file.close()
	app._on_map_selected(auto_path);await settle()
	expect(not is_instance_valid(shell.get_node_or_null("GridCalibration")),"generated-map import skips manual calibration")
	var scene=app.board.current_scene()
	expect(scene.width_cells==32 and scene.height_cells==24 and scene.feet_per_cell==10 and scene.cell_pixels==10.,"embedded scale is installed in the actual board: "+str([scene.width_cells,scene.height_cells,scene.feet_per_cell,scene.cell_pixels]))
	expect(Hearth20Contracts.valid_scene(scene),"the automatically calibrated scene satisfies campaign limits")
	await capture("auto-calibrated-map")
	var save_path=Hearth20Identity.SAVE_ROOT.path_join("auto-grid.h20scampaign")
	expect(Hearth20Identity.save_campaign(app.campaign,save_path).ok,"the calibrated map can be saved")
	var saved=Hearth20Identity.load_campaign(save_path)
	expect(saved.ok and saved.campaign.scenes[0].width_cells==32 and saved.campaign.scenes[0].feet_per_cell==10,"grid scale survives a campaign round trip")
	shell.queue_free();await settle()
	print("Title menu and calibration: %d checks, %d failures"%[checks,errors.size()])
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"ok":errors.is_empty()}))
	quit.call_deferred(0 if errors.is_empty() else 1)

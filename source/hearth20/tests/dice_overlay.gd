extends SceneTree
## Check pixels in the final window, not just the offscreen dice buffer.
var shell: Hearth20SeatedShell
var output=""
var checks=0
var errors=[]
var pixel_proofs=[]
func _initialize() -> void:output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func until(predicate: Callable,message: String) -> void:
	var deadline=Time.get_ticks_msec()+25000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	expect(predicate.call(),message)
func image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func roll_proof(name_value: String,visibility: String,mode="normal",count=1,sides=20) -> void:
	var app=shell.app;var stage=app.dice_stage;stage.clear_rolls()
	app.toolbox.open("dice")
	await process_frame;await process_frame
	var before: Image=await image()
	app.toolbox.dice_visibility=visibility;app.toolbox.dice_mode=mode;app.toolbox.dice_count=count;app.toolbox.dice_sides=sides
	app.toolbox._roll()
	await until(func():return not stage.preparing and not stage.pieces.is_empty(),name_value+": dice controls produce loaded models")
	stage.age=3.;await process_frame;await process_frame
	var after: Image=await image();after.save_png(output.path_join(name_value+".png"))
	var buffer=stage.viewport.get_texture().get_image();var rect=stage.get_global_rect();var opaque=0;var composited=0
	for y in range(0,buffer.get_height(),3):
		for x in range(0,buffer.get_width(),3):
			if buffer.get_pixel(x,y).a<.9:continue
			var screen=Vector2i(rect.position+Vector2(float(x)/buffer.get_width(),float(y)/buffer.get_height())*rect.size)
			if screen.x<0 or screen.y<0 or screen.x>=after.get_width() or screen.y>=after.get_height():continue
			opaque+=1
			var a=before.get_pixelv(screen);var b=after.get_pixelv(screen)
			if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()>.06:composited+=1
	pixel_proofs.append({"case":name_value,"opaque_samples":opaque,"visible_in_window":composited})
	expect(opaque>100,name_value+": dice buffer contains actual rendered model pixels")
	expect(composited>opaque*.7,name_value+": dice are visible in final window above the battlemap")
	expect(stage.pieces.size()==(2 if mode!="normal" else count),name_value+": all requested dice are displayed")
	expect(stage.pieces.all(func(p):return (p.node.quaternion*p.node.get_meta("result_normal")).dot(stage.camera.global_basis.z)>.999),name_value+": results face the camera")
	expect(stage.mouse_filter==Control.MOUSE_FILTER_IGNORE,name_value+": animation does not block map input")
	stage.clear_rolls();await process_frame
func run() -> void:
	root.size=Vector2i(1600,1000);root.gui_disable_input=true
	shell=Hearth20SeatedShell.new();root.add_child(shell)
	await until(func():return shell.ready_to_show,"seated table loads")
	shell.app._load_sample_map("sunspire-sanctum",false);shell.app.session.set_scene_lighting(false)
	shell.focus_map();await create_timer(.3).timeout
	await roll_proof("focused-public-advantage","public","advantage")
	await roll_proof("focused-private-dm","self","normal",2,6)
	shell.leave_focus();await create_timer(.3).timeout
	await roll_proof("seated-public","public")
	shell.app.session.set_table_mode("casino")
	await until(func():return shell.current_mode=="casino" and not shell.switching,"casino transition completes")
	expect(shell.app.dice_stage.suspended and not shell.app.dice_stage.visible,"casino keeps its own dice presentation")
	shell.app.session.set_table_mode("map")
	await until(func():return shell.current_mode=="map" and not shell.switching,"return from casino completes")
	shell.focus_map();await create_timer(.3).timeout
	await roll_proof("returned-map-private-dm","secret")
	shell.queue_free();await create_timer(.3).timeout
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"pixel_proofs":pixel_proofs},"\t"))
	print("Dice overlay: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)

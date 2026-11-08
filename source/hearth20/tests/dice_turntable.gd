extends SceneTree
## Artifact-only inspection of the production meshes/materials; no campaign loads.
const FPS=30
var output=""
var quick=false
var table: Hearth20CasinoTable
var dice: Array=[]
var bases: Array=[]
func _initialize() -> void:
	var args=OS.get_cmdline_user_args();output=args[0];quick=args.size()>1 and args[1]=="quick";call_deferred("render_preview")
func text_at(caption: String, points: int, rect: Rect2, color: Color, title_font=false) -> Label:
	var label=Label.new();label.text=caption;label.add_theme_font_override("font",Hearth20Design.font(title_font));label.add_theme_font_size_override("font_size",points);label.add_theme_color_override("font_color",color);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.position=rect.position;label.size=rect.size;root.add_child(label);return label
func render_preview() -> void:
	root.size=Vector2i(1920,1080);root.title="Hearth20 · Rendering dice turntable";root.content_scale_size=Vector2i(1920,1080)
	var textures={}
	for spec in [["art","card-art.png"],["materials","materials.png"],["salon","tavern-v2.png"],["catalog","salon.png"],["book","book-materials.png"],["cover","da-rolls-cover.png"]]:textures[spec[0]]=load("res://hearth20/casino/"+str(spec[1]))
	table=Hearth20CasinoTable.new();root.add_child(table);table.setup(textures);table.set_process(false)
	table.book.hide();table.book.process_mode=Node.PROCESS_MODE_DISABLED;table.stock_deck.hide();table.center_props.hide();table.game_view.set_process(false)
	table.card_surface.material=Hearth20FxPost.material()
	for _k in 5:await process_frame
	table.camera.position=Vector3(0,2.02,3.48);table.camera.fov=42;table.camera.look_at(Vector3(0,1.31,1.08),Vector3.UP)
	table.card_camera.global_transform=table.camera.global_transform;table.card_camera.fov=table.camera.fov
	table.soul_viewport.size=table.card_viewport.size;table.soul_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	table.soul_camera.global_transform=table.card_camera.global_transform;table.soul_camera.fov=table.card_camera.fov
	for i in 3:
		var die=Hearth20CasinoDie.new();table.presentation_content.add_child(die);die.target_scale=.44;die.setup([8,6,4][i],[7,5,3][i],"soul");die.place(Vector3((i-1)*1.03,1.30,1.08),table.card_camera)
		die.attach_scene_buffers(table.viewport.get_texture(),table.soul_viewport.get_texture(),table.soul_world);die.set_process(false);die.number.double_sided=false;dice.append(die);bases.append(die.final_rotation)
	var top=ColorRect.new();top.color=Color(.025,.019,.012,.87);top.position=Vector2.ZERO;top.size=Vector2(1920,153);root.add_child(top)
	var line=ColorRect.new();line.color=Color("#a9864d");line.position=Vector2(100,152);line.size=Vector2(1720,1);root.add_child(line)
	text_at("H E A R T H 2 0   /   T H E   G I L D E D   T A B L E",17,Rect2(0,15,1920,35),Color("#bc995e"))
	text_at("SOUL-GLASS DICE",43,Rect2(0,48,1920,65),Color("#f0dfba"),true)
	text_at("FIVE SOULS  ·  CRYSTALLINE ICE  ·  SOUL-FORGED RESULTS",16,Rect2(0,113,1920,29),Color("#b9aa93"))
	var bottom=ColorRect.new();bottom.color=Color(.025,.019,.012,.88);bottom.position=Vector2(0,899);bottom.size=Vector2(1920,181);root.add_child(bottom)
	for i in 3:
		var center=table.camera.unproject_position(dice[i].global_position).x
		text_at(["D8","D6","D4"][i],29,Rect2(center-190,911,380,49),Color("#e4c88f"),true)
		text_at(["THE OPENING SECRET","THE DEEPENING WAGER","THE FINAL RECKONING"][i],14,Rect2(center-240,960,480,28),Color("#b1a08a"))
	text_at("Forged brass  ·  Frosted blue glass  ·  Volumetric souls",18,Rect2(0,1018,1920,43),Color("#dec69b"))
	for _k in 5:await process_frame
	var count=3 if quick else 450
	for frame in count:
		var t=float(frame)/FPS;var progress=clampf((t-4.5)/9.8,0.,1.)
		if quick:progress=[.0,.19,.46][frame];t=3.+frame*1.2
		var angle=TAU*smoothstep(0.,1.,progress)
		for i in dice.size():
			var die=dice[i];die.body.quaternion=Quaternion(Vector3.UP,angle)*bases[i]*Quaternion(Vector3.RIGHT,sin(progress*TAU)*.10)
			die._process(1./FPS);die.mist.global_transform=die.body.global_transform
		await RenderingServer.frame_post_draw
		var shot=root.get_texture().get_image()
		shot.save_jpg(output.path_join("frame-%05d.jpg"%frame),.94)
		if (quick and frame==1) or (not quick and frame==105):shot.save_png(output.path_join("poster.png"))
		if frame%90==0:print("Turntable frame ",frame," / ",count)
		await process_frame
	var meta={"fps":FPS,"frames":count,"width":1920,"height":1080,"production_classes":["Hearth20CasinoDie","Hearth20CathedralDie","Hearth20CasinoSoulVolume"],"sides":[8,6,4],"campaign_loaded":false}
	FileAccess.open(output.path_join("render.json"),FileAccess.WRITE).store_string(JSON.stringify(meta,"\t"))
	table.queue_free();await process_frame;await process_frame;quit()

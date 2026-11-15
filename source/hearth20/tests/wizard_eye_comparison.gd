extends SceneTree
## Matching, native-rendered A/B previews; no user account or game session involved.
var output=""
var checks=0
var errors=[]
var picture: Image
func _initialize() -> void:output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func capture(file: String) -> void:
	for _i in 4:await process_frame
	await RenderingServer.frame_post_draw;picture=root.get_texture().get_image();picture.save_png(output.path_join(file+".png"))
func run() -> void:
	root.size=Vector2i(1500,1100)
	await Hearth20GeneratedModels.prepare(self)
	var world=Node3D.new();root.add_child(world)
	var env=WorldEnvironment.new();var settings=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("#100f17");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_energy=.55;env.environment=settings;world.add_child(env)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-28,-22,0);light.light_energy=1.1;world.add_child(light)
	var camera=Camera3D.new();camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.6;world.add_child(camera);camera.position=Vector3(0,1.12,8);camera.look_at(Vector3(0,1.12,0))
	var title=Label.new();title.position=Vector2(45,24);title.add_theme_font_size_override("font_size",34);title.add_theme_color_override("font_color",Color("#f1dfae"));root.add_child(title)
	var sub=Label.new();sub.position=Vector2(46,70);sub.add_theme_font_size_override("font_size",20);sub.text="Same hood · same yellow · same expressions · local CRT phosphor glow";sub.modulate=Color("#bcb4a4");root.add_child(sub)
	var avatars=[]
	var ids=["oval","half","angry","worried","tears","lopsided"]
	for i in ids.size():
		var style=Hearth20AvatarStyle.defaults(false);style.chain="none";style.eye_style=ids[i];style.eye_treatment="cartoon"
		var avatar=Hearth20WizardAvatar.new();world.add_child(avatar);avatar.setup(style,false);avatar.position=Vector3((i%3-1)*1.08,(.5-i/3)*1.06,0);avatar.get_node("Generated_wizard_body").hide();avatars.append(avatar)
		var label=Label3D.new();label.text=Hearth20AvatarStyle.EYES[ids[i]];label.font_size=52;label.pixel_size=.0013;label.position=Vector3(0,.47,.5);avatar.add_child(label)
		expect(avatar.style.eye_treatment=="cartoon","cartoon treatment bound to "+ids[i])
	title.text="TEST 1  /  YELLOW SCLERA + BLACK IRIS"
	await capture("test-1-yellow-sclera")
	var cartoon_bytes=picture.get_data()
	var iris_center=picture.get_pixel(195,363);expect(maxf(iris_center.r,iris_center.g)<.15,"cartoon iris is visibly black in the rendered hood")
	for avatar in avatars:
		avatar.set_eyes(avatar.style.eye_style,"gold","visor")
		expect(not avatar.eyes.material_override.get_shader_parameter("cartoon"),"visor treatment disables iris mask")
	title.text="TEST 2  /  SOLID PROTOGEN-STYLE EYES"
	await capture("test-2-solid-visor")
	expect(picture.get_data()!=cartoon_bytes,"native captures differ between treatments")
	var filled_center=picture.get_pixel(195,363);expect(filled_center.r>.7 and filled_center.g>.6 and filled_center.b<.6,"same pupil location glows yellow in the solid-eye render")
	var packed=Hearth20WizardEyes.phosphor.get_image();expect(packed.has_mipmaps(),"packed phosphor texture includes mipmaps")
	if packed.is_compressed():packed.decompress()
	# The oval's iris channel is isolated; solid R stays fully filled at its centre.
	var center=packed.get_pixel(80,128);expect(center.r>.95 and center.g>.95,"solid sclera has no pupil cutout; separate iris channel is available")
	world.free();title.free();sub.free();await process_frame;await process_frame
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"  "));print("Eye comparison: "+str(checks)+" checks, "+str(errors));quit.call_deferred(0 if errors.is_empty() else 1)

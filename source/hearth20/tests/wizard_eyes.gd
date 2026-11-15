extends SceneTree
var output=""
var checks=0
var errors=[]
var last_picture: Image
func _initialize() -> void:output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool,text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error(text)
func image_after(file: String) -> void:
	for _i in 3:await process_frame
	await RenderingServer.frame_post_draw;last_picture=root.get_texture().get_image();last_picture.save_png(output.path_join(file+".png"))
func energy(picture: Image) -> float:
	var total=0.
	for y in range(0,picture.get_height(),2):
		for x in range(0,picture.get_width(),2):
			var pixel=picture.get_pixel(x,y);total+=pixel.r+pixel.g+pixel.b
	return total
func run() -> void:
	root.size=Vector2i(1600,1300)
	var legacy={"robe":"crimson","metal":"silver","chain":"rope","pendant":"none"}
	expect(Hearth20AvatarStyle.valid(legacy,false),"existing four-field preferences are accepted")
	var migrated=Hearth20AvatarStyle.clean(legacy,false);expect(migrated.eye_style=="oval" and migrated.eye_color=="gold" and migrated.robe=="crimson","existing preferences migrate without losing robe/jewelry")
	legacy.eye_style="round";legacy.eye_color="ice";expect(Hearth20AvatarStyle.valid(legacy,false) and Hearth20AvatarStyle.clean(legacy,false).eye_treatment=="visor","six-field preferences migrate to pupil-free visor")
	for field in ["eye_style","eye_color","eye_treatment"]:
		for invalid in [null,{},[],42,"res://untrusted","unsupported"]:
			var bad=Hearth20AvatarStyle.defaults(false);bad[field]=invalid;expect(not Hearth20AvatarStyle.valid(bad,false),"reject invalid "+field+" "+str(invalid));expect(Hearth20AvatarStyle.valid(Hearth20AvatarStyle.clean(bad,false),false),"stored malformed eye settings sanitize safely")
	await Hearth20GeneratedModels.prepare(self)
	var texture=Hearth20WizardEyes.texture();var atlas=texture.get_image();expect(atlas.has_mipmaps(),"emissive UV atlas has mipmaps for distant seats");if atlas.is_compressed():atlas.decompress()
	expect(atlas.get_size()==Vector2i(1024,1280),"one bounded 4 × 5 UV atlas")
	var hashes={}
	for i in Hearth20AvatarStyle.EYES.size():
		var tile=atlas.get_region(Rect2i(i%4*256,i/4*256,256,256));var hash=Hearth20Contracts.sha256(tile.get_data());expect(not hashes.has(hash),"each eye style has a distinct mask");hashes[hash]=true
		var bright=0
		for y in range(0,256,2):
			for x in range(0,256,2):
				var pixel=tile.get_pixel(x,y);bright+=int(pixel.r>.95 and pixel.a>.5)
		expect(bright>80 and bright<6000,"bright usable core and transparent margins in every mask")
	var world=Node3D.new();root.add_child(world);var env=WorldEnvironment.new();var settings=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("#17121d");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_energy=.65;env.environment=settings;world.add_child(env)
	var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-28,-22,0);key.light_energy=1.;world.add_child(key)
	var camera=Camera3D.new();camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.1;world.add_child(camera);camera.position=Vector3(0,1.1,12);camera.look_at(Vector3(0,1.1,0))
	var avatars=[];var labels=[]
	for i in Hearth20AvatarStyle.EYES.size():
		var id=Hearth20AvatarStyle.EYES.keys()[i];var style=Hearth20AvatarStyle.defaults(false);style.chain="none";style.eye_style=id;style.eye_color=Hearth20AvatarStyle.EYE_COLORS.keys()[i%6]
		var avatar=Hearth20WizardAvatar.new();world.add_child(avatar);avatar.setup(style,false);avatar.position=Vector3((i%4-1.5)*1.18,(2.-i/4)*1.1,0);avatar.get_node("Generated_wizard_body").hide();avatars.append(avatar)
		expect(not avatar.has_method("set_voice_level") and not avatar.is_processing() and avatar.find_children("*Mouth*","",true,false).is_empty(),"no voice, mouth or head processing: "+id)
		expect(avatar.eyes.mesh==Hearth20WizardEyes.face_mesh and not avatar.eyes.mesh is QuadMesh,"eye art follows a shared actual hood surface: "+id)
		var label=Label3D.new();label.text=Hearth20AvatarStyle.EYES[id];label.font_size=46;label.pixel_size=.002;label.position=Vector3(0,.55,.5);avatar.add_child(label);labels.append(label)
	if DisplayServer.get_name()!="headless":
		await image_after("solid-eye-gallery")
		for label in labels:label.hide()
		settings.ambient_light_energy=0.;key.light_energy=0.
		for mat in Hearth20WizardEyes.materials.values():mat.set_shader_parameter("halo_strength",0.)
		await image_after("eyes-dark-core");var no_halo=last_picture
		for mat in Hearth20WizardEyes.materials.values():mat.set_shader_parameter("halo_strength",.8)
		await image_after("eyes-in-darkness");var glow=last_picture
		expect(energy(glow)>energy(no_halo)+10.,"emissive eyes have a visible halo even with room lights off")
		settings.ambient_light_energy=.65;key.light_energy=1.
	var old=avatars[0].hood.transform;await create_timer(.3).timeout;expect(avatars[0].hood.transform==old,"head never turns or nods")
	var session=Hearth20Session.new();root.add_child(session);session.configure(Hearth20Identity.new_campaign("Eyes persistence fixture"))
	var window=Hearth20AvatarWardrobe.open(root,session,true);window.size=Vector2i(740,700);window.appearance_tabs.current_tab=1
	for _i in 4:await process_frame
	expect(window.eye_buttons.size()==20 and window.eye_color_buttons.size()==6 and window.eye_treatment_buttons.size()==2,"visual eye picker includes all styles, treatments and glow colors")
	var same_avatar=window.avatar.get_instance_id();window.eye_buttons.stars.pressed.emit();window.eye_color_buttons.ice.pressed.emit();window.eye_treatment_buttons.cartoon.pressed.emit()
	expect(window.value.eye_style=="stars" and window.value.eye_color=="ice" and window.avatar.style.eye_treatment=="cartoon","visible controls update eye choices and treatment")
	expect(window.avatar.get_instance_id()==same_avatar,"eye changes reuse the existing preview avatar")
	for button in window.eye_buttons.values()+window.eye_color_buttons.values()+window.eye_treatment_buttons.values():expect(Rect2(Vector2.ZERO,window.size).encloses(button.get_global_rect()),"eye controls fit the minimum wardrobe size")
	var visible_eye_page=window.appearance_tabs.get_child(1).get_global_rect()
	for button in window.eye_color_buttons.values():expect(visible_eye_page.encloses(button.get_global_rect()),"every glow color is visible without scrolling at minimum size")
	if DisplayServer.get_name()!="headless":await image_after("eye-picker-minimum")
	window._save();await process_frame
	expect(session.campaign.host_avatar.eye_style=="stars" and Hearth20AvatarStyle.remembered(true).eye_color=="ice" and Hearth20AvatarStyle.remembered(true).eye_treatment=="cartoon","appearance saves to campaign and local profile")
	var path=Hearth20Identity.SAVE_ROOT+"/eye-fixture.h20scampaign";expect(Hearth20Identity.save_campaign(session.campaign,path).ok,"save eye-equipped campaign");var loaded=Hearth20Identity.load_campaign(path);expect(loaded.ok and loaded.campaign.host_avatar.eye_treatment=="cartoon","eye choices survive campaign reload")
	world.free();session.free();await process_frame;await process_frame
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"  "));print("Wizard eyes: "+str(checks)+" checks, "+str(errors));quit.call_deferred(0 if errors.is_empty() else 1)

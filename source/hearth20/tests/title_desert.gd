extends SceneTree
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
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=button.get_global_rect().get_center();event.global_position=event.position;root.push_input(event)
	await settle()
func run() -> void:
	output=OS.get_cmdline_user_args()[0];root.gui_embed_subwindows=true;root.size=Vector2i(1600,900)
	Hearth20Preferences.values.startup_updates=false
	var boot=MenuFixture.new();root.add_child(boot)
	expect(boot.menu.visible and not boot.loading,"join/host controls exist before the creature is requested")
	expect(boot.desert.request_started_msec==0,"heavy creature request is deferred until the first rendered frame")
	await settle()
	var deadline=Time.get_ticks_msec()+30000
	while not boot.desert.ready_to_show() and Time.get_ticks_msec()<deadline:await process_frame
	expect(boot.desert.creature!=null and not boot.desert.load_failed,"detailed textured tarrasque loads in the title world")
	expect(boot.menu_drawn_msec>0 and boot.desert.request_started_msec>=boot.menu_drawn_msec,"the interactive menu renders before the model load starts")
	expect(boot.desert.animation!=null and boot.desert.animation.is_playing(),"tarrasque has a playing skeletal idle animation")
	var skeletons=boot.desert.creature.find_children("*","Skeleton3D",true,false)
	expect(skeletons.size()==1 and skeletons[0].get_bone_count()>=24,"the creature uses a full articulated skeleton")
	var playhead=boot.desert.animation.current_animation_position
	var skinned_nodes=boot.desert.creature.find_children("*","MeshInstance3D",true,false).filter(func(node):return node.skin!=null)
	var skinned=skinned_nodes.front()
	var surfaces={}
	for node in skinned_nodes:
		if node.mesh.get_surface_count()>skinned.mesh.get_surface_count():skinned=node
		for index in node.mesh.get_surface_count():
			var original=node.mesh.surface_get_material(index)
			var material=node.get_surface_override_material(index)
			if original!=null:
				surfaces[original.resource_name]=int(surfaces.get(original.resource_name,0))+node.mesh.surface_get_arrays(index)[Mesh.ARRAY_INDEX].size()/3
				if original.resource_name in ["Aged Ivory","Mouth Tissue","Gum Tissue","Tongue","Molten Amber","Obsidian Slit","Claw Keratin","Striated Horn"]:
					expect(material is ShaderMaterial and material.get_shader_parameter("textured")==0.,"anatomy uses its own finish instead of hide texture "+original.resource_name)
	for label in ["Aged Ivory","Mouth Tissue","Gum Tissue","Tongue","Molten Amber","Obsidian Slit","Claw Keratin","Striated Horn"]:
		expect(int(surfaces.get(label,0))>40,"visible anatomical surface geometry exists for "+label)
	var before_mesh=skinned.bake_mesh_from_current_skeleton_pose()
	var before_vertices=Hearth20Contracts.sha256(before_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].to_byte_array())
	var poses=[]
	for index in skeletons[0].get_bone_count():poses.append(skeletons[0].get_bone_pose_rotation(index))
	await create_timer(1.1).timeout
	expect(boot.desert.animation.current_animation_position>playhead,"the idle advances after loading")
	var after_mesh=skinned.bake_mesh_from_current_skeleton_pose()
	expect(before_vertices!=Hearth20Contracts.sha256(after_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].to_byte_array()),"the visible skinned vertices deform with the idle")
	var moved=0
	for index in skeletons[0].get_bone_count():
		if not poses[index].is_equal_approx(skeletons[0].get_bone_pose_rotation(index)):moved+=1
	expect(moved>=10,"independent body and tail joints animate instead of rotating a rigid statue")
	var join=boot.find_child("JoinTable",true,false) as Button
	var host=boot.find_child("HostTable",true,false) as Button
	await click(join);await click(host)
	expect(boot.requested_actions==["join","host"],"native mouse clicks select the correct Join and Host flows")
	boot._show_scene_credits();await settle()
	var credits=boot.find_children("*","AcceptDialog",true,false).front()
	expect(credits.visible and credits.find_children("*","RichTextLabel",true,false).front().text.contains("mz4250"),"scene credits retain creator attribution in the portable")
	credits.canceled.emit();await settle()
	expect(boot.find_children("*","Hearth20BestiaryViewer",true,false).is_empty(),"the starting menu has no old rotating creature showcase")
	await capture("title-1600")
	boot.desert.animation.seek(9.,true);await capture("title-idle-nine-seconds")
	boot.desert.animation.seek(19.8,true);await create_timer(.5).timeout
	expect(boot.desert.animation.current_animation_position<1.,"the twenty-second idle loops continuously")
	Hearth20Regal.toggle();await capture("title-parchment");Hearth20Regal.toggle()
	var hidden=[]
	for child in boot.get_children():
		if child is CanvasItem and child!=boot.desert and child.visible:child.hide();hidden.append(child)
	boot.desert.set_process(false);boot.desert.animation.pause();root.size=Vector2i(1200,900);await settle()
	boot.desert.camera.fov=25.4
	for view in [["side",Vector3(13,15,22),Vector3(0,11.7,12)],["front",Vector3(0,13,29),Vector3(0,11.7,12)],["inside",Vector3(6,10,24),Vector3(0,10.5,12)]]:
		boot.desert.camera.position=boot.desert.creature.transform*view[1]
		boot.desert.camera.look_at(boot.desert.creature.transform*view[2])
		await capture("anatomy-"+view[0])
		if view[0]=="side":
			var image=root.get_texture().get_image()
			var amber=0;var ivory=0;var mouth=0
			for y in range(340,395,3):
				for x in range(690,760,3):
					var color=image.get_pixel(x,y)
					if color.r>.25 and color.g>color.r*.25 and color.g<color.r*.75 and color.b<color.g*.35:amber+=1
			for y in range(480,580,3):
				for x in range(280,670,3):
					var color=image.get_pixel(x,y)
					if color.r>.55 and color.g>color.r*.78 and color.b>color.r*.32:ivory+=1
			for y in range(550,690,3):
				for x in range(420,675,3):
					var color=image.get_pixel(x,y)
					if color.r>.12 and color.r>color.g*1.6 and color.b>color.g*.9:mouth+=1
			expect(amber>12,"rendered eye contains amber pigment")
			expect(ivory>80,"rendered tooth crowns contain ivory pigment")
			expect(mouth>60,"rendered mouth has its own red tissue color")
	for child in hidden:child.show()
	boot.desert.camera.fov=43;boot.desert.set_process(true);boot.desert.animation.play();root.size=Vector2i(1600,900)
	for dimensions in [Vector2i(1000,650),Vector2i(1280,720),Vector2i(2560,1080)]:
		root.size=dimensions;await settle()
		for button in boot.menu.find_children("*","Button",true,false):
			expect(button.get_global_rect().end.x<=dimensions.x and button.get_global_rect().position.x>=0,"menu button fits width "+str(dimensions)+button.text)
			expect(button.get_global_rect().end.y<=dimensions.y and button.get_global_rect().position.y>=0,"menu button fits height "+str(dimensions)+button.text)
		expect(boot.desert.viewport.size.x<=1600,"title render width is bounded at "+str(dimensions))
		await capture("title-"+str(dimensions.x))
	boot.desert.hide();await settle()
	expect(boot.desert.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and not boot.desert.animation.active,"hidden title stops rendering and skeleton processing")
	boot.desert.show();await settle()
	expect(boot.desert.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS and boot.desert.animation.active,"returning title resumes the scene")
	root.size=Vector2i(1280,720);await settle()
	var desert_ref=weakref(boot.desert)
	boot.permit_loading=true
	boot.begin_loading("new");boot.begin_loading("host")
	expect(boot.mode=="new" and boot.loading and boot.progress.visible and not boot.menu.visible,"repeated activation starts one table transition with visible progress")
	await capture("loading-desert")
	deadline=Time.get_ticks_msec()+45000
	while is_instance_valid(boot) and Time.get_ticks_msec()<deadline:await process_frame
	expect(not is_instance_valid(boot),"loading reaches the actual seated table")
	expect(desert_ref.get_ref()==null,"the title world and its viewport are released after the transition")
	for node in root.get_children():
		if node is Hearth20SeatedShell:
			while not node.ready_to_show:await process_frame
			node.queue_free()
	await settle()
	print("Desert title: %d checks, %d failures"%[checks,errors.size()])
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"ok":errors.is_empty()}))
	quit(0 if errors.is_empty() else 1)

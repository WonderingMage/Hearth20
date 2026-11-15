extends SceneTree
var checks=0
var errors=[]
var output=""
func _initialize() -> void:output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	root.size=Vector2i(1300,1100);root.title="Hearth20 · Baked collar jewelry verification"
	await Hearth20GeneratedModels.prepare(self)
	Hearth20WizardJewelry.record("cuban");var bake=Hearth20WizardJewelry.data
	expect(bake.get("engine")=="Jolt Physics" and bake.get("physics_hz")==240,"bake came from the offline high-rate Jolt simulation")
	expect(bake.get("failed",["missing"]).is_empty() and bake.variants.size()==6,"all six simulated jewelry configurations settled")
	expect(bake.body_sha256==FileAccess.get_sha256("res://hearth20/generated_models/wizard_body.scn"),"poses bind to the exact current torso mesh")
	var world=Node3D.new();root.add_child(world)
	var env=WorldEnvironment.new();var settings=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("#211b26");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_energy=.75;env.environment=settings;world.add_child(env)
	var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,-30,0);key.light_energy=1.25;world.add_child(key)
	var camera=Camera3D.new();camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.65;world.add_child(camera)
	for id in bake.variants:
		var record=bake.variants[id];var style=Hearth20AvatarStyle.defaults(id.ends_with("_d20"));style.chain=id.replace("_d20","")
		var avatar=Hearth20WizardAvatar.new();world.add_child(avatar);avatar.setup(style,id.ends_with("_d20"));avatar.set_process(false)
		var node=avatar.get_node_or_null("BakedCollarChains") as MultiMeshInstance3D
		expect(node!=null and node.multimesh.instance_count==record.links.size(),"all simulated links are rendered: "+id)
		expect(record.closed and record.contact_links>record.links.size()*.7,"complete necklace has sufficient torso contact: "+id)
		expect(record.last_second_motion_band_m<.0002,"settled replacement shape moved under 0.2 mm in its final second: "+id)
		var index=0
		for group in record.groups:
			var first=index
			for j in int(group.count):
				var pose=Hearth20WizardJewelry.pose(record.links[index]);var rendered=node.multimesh.get_instance_transform(index)
				expect(pose.origin.is_finite() and absf(pose.basis.determinant()-1.)<.001,"finite rigid physical link pose: "+id)
				# Dummy headless rendering has no GPU-backed MultiMesh readback.
				if DisplayServer.get_name()!="headless":expect(rendered.origin.distance_to(pose.origin)<.000001,"rendered center equals the captured physics position: "+id)
				var next=first+(j+1)%int(group.count);var neighbor=Hearth20WizardJewelry.vector(record.links[next].position)
				expect(pose.origin.distance_to(neighbor)<.065,"closed loop has no disconnected ends: "+id)
				index+=1
		expect(index==node.multimesh.instance_count,"both simulated loops present for layered jewelry: "+id)
		expect(avatar.find_children("*","PhysicsBody3D",true,false).is_empty() and avatar.find_children("*","Joint3D",true,false).is_empty(),"jewelry requires no runtime physics bodies or joints: "+id)
		var duplicate=Hearth20WizardJewelry.make(id,Hearth20WizardAvatar.metal("silver"));expect(duplicate.multimesh==node.multimesh,"gold and silver share the immutable baked batch: "+id);duplicate.free()
		if id.ends_with("_d20"):
			var pendant=avatar.get_node("DMOnlyD20Pendant") as Node3D
			expect(pendant.position.distance_to(Hearth20WizardJewelry.vector(record.pendant.position))<.000001,"pendant uses its simulated weighted position: "+id)
			expect(record.pendant.contact,"weighted pendant settled in contact: "+id)
			expect(pendant.get_meta("replaceable_model",false) and pendant.get_meta("attachment_local")==Vector3(0,.095,-.035),"pendant mount is separate from its replaceable visual model: "+id)
			var visual=pendant.get_node_or_null("GeneratedPendantVisual") as Node3D
			expect(visual!=null and visual.get_meta("source_model","")=="dm_d20_pendant","the supplied pendant replaces procedural charm geometry: "+id)
			expect(not pendant.has_node("PendantPlaceholder") and not pendant.has_node("CenteredPendantValue") and not pendant.has_node("PendantBail"),"no duplicate number or bail is drawn over the supplied model: "+id)
			var fit=Hearth20GeneratedModels.catalog.dm_d20_pendant.pendant_fit
			expect((visual.transform*Hearth20GeneratedModels.vector(fit.source_bail)).distance_to(Vector3(0,.095,-.035))<.000001,"generated attachment hole aligns with the simulated chain: "+id)
			expect(visual.scale.distance_to(Vector3.ONE*float(fit.scale))<.000001,"uniform fitting preserves the generated proportions: "+id)
			expect((pendant.basis*Vector3.BACK).dot(Vector3.BACK)>.5,"engraved face remains oriented toward the viewer: "+id)
			expect(bake.get("pendant_sha256","")==FileAccess.get_sha256("res://hearth20/generated_models/dm_d20_pendant.scn"),"physical pose binds to the exact replacement mesh: "+id)
		if DisplayServer.get_name()!="headless":
			for view in [["front",Vector3(.10,.91,3.)],["side",Vector3(3.,.91,.10)],["back",Vector3(.1,.91,-3.)]]:
				camera.position=view[1];camera.look_at(Vector3(0,.81,-.06))
				for _i in 4:await process_frame
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(id+"-"+view[0]+".png"))
			if id=="cuban_d20":
				avatar.hide();var silver=Hearth20WizardAvatar.new();world.add_child(silver);style.metal="silver";silver.setup(style,true);silver.set_process(false)
				var visual=silver.get_node("DMOnlyD20Pendant/GeneratedPendantVisual")
				for mesh in visual.find_children("*","MeshInstance3D",true,false):
					for s in mesh.mesh.get_surface_count():expect(mesh.get_surface_override_material(s).get_shader_parameter("silver")==true,"silver finish preserves the new textured pendant and rear repair")
				camera.position=Vector3(.10,.91,3.);camera.look_at(Vector3(0,.81,-.06))
				for _i in 4:await process_frame
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("silver-pendant-front.png"));silver.free();avatar.show()
		avatar.free()
	world.free();await process_frame;await process_frame
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"bake_sha256":FileAccess.get_sha256(Hearth20WizardJewelry.BAKE)},"  "));print("Baked collar jewelry: "+str(checks)+" checks, "+str(errors));quit.call_deferred(0 if errors.is_empty() else 1)

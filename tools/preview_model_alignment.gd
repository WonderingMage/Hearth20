extends SceneTree
var output=""
func _initialize() -> void:output=OS.get_cmdline_user_args()[0];call_deferred("run")
func run() -> void:
	root.size=Vector2i(600,600);root.title="Hearth20 · Model alignment inspection · closes automatically"
	await Hearth20GeneratedModels.prepare(self)
	var poses=JSON.parse_string(FileAccess.get_file_as_string(output.get_base_dir().path_join("poses.json")))
	for id in poses:
		if Hearth20GeneratedModels.catalog.has(id):Hearth20GeneratedModels.catalog[id].merge(poses[id],true)
	var world=Node3D.new();root.add_child(world)
	var environment=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("#393c40");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.5;environment.environment=env;world.add_child(environment)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=1.;world.add_child(light)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.65;camera.current=true;world.add_child(camera)
	var floor_mesh=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(3.8,3.8);floor_mesh.mesh=plane;var mat=StandardMaterial3D.new();mat.albedo_color=Color("#70777d");mat.roughness=.95;floor_mesh.material_override=mat;world.add_child(floor_mesh)
	for x in range(-5,6):
		for axis in 2:
			var line=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(.003,.001,3.8) if axis==0 else Vector3(3.8,.001,.003);line.mesh=box;var ink=StandardMaterial3D.new();ink.albedo_color=Color("#414a50");line.material_override=ink;line.position=Vector3(x*.25,.001,0) if axis==0 else Vector3(0,.001,x*.25);world.add_child(line)
	for id in Hearth20GeneratedModels.ACTIVE:
		if id=="room" or id.begins_with("kit_"):continue
		var record=Hearth20GeneratedModels.catalog[id];var box=record.get("oriented_bounds",record.bounds);var size_value=Hearth20GeneratedModels.vector(box.size);size_value*=1.65/maxf(size_value.x,maxf(size_value.y,size_value.z))
		var model=Hearth20GeneratedModels.make(id,size_value);world.add_child(model)
		for view in [["front",Vector3(2.3,1.8,4.0)],["side",Vector3(4.0,1.2,.05)]]:
			camera.position=view[1];camera.look_at(Vector3(0,size_value.y*.45,0))
			for _i in 3:await process_frame
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(id+"-"+view[0]+".png"))
		model.queue_free();await process_frame
	print("Alignment previews complete");quit.call_deferred()

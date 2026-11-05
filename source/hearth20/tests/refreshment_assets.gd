extends SceneTree
var errors=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(600,600)
	var viewport=SubViewport.new();viewport.size=Vector2i(256,256);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.msaa_3d=Viewport.MSAA_4X;root.add_child(viewport)
	var world=Node3D.new();viewport.add_child(world)
	var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0,0,0,0);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("#e6d4b7");environment.environment.ambient_light_energy=.8;world.add_child(environment)
	var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-38,-28,0);key.light_energy=1.4;world.add_child(key)
	var camera=Camera3D.new();camera.current=true;camera.position=Vector3(.40,.31,.48);camera.look_at_from_position(camera.position,Vector3(0,.11,0));camera.fov=35.;world.add_child(camera)
	var surface=TextureRect.new();surface.texture=viewport.get_texture();surface.size=Vector2(600,600);surface.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;root.add_child(surface)
	var output=ProjectSettings.globalize_path("res://hearth20/refreshments/thumbs");DirAccess.make_dir_recursive_absolute(output)
	for id in Hearth20RefreshmentCatalog.FOODS.keys()+Hearth20RefreshmentCatalog.DRINKS.keys():
		var packed=await Hearth20RefreshmentModels.prepare(id,self)
		if packed==null:errors.append("Cannot load "+id);continue
		var model=Hearth20RefreshmentModels.make(id,packed)
		if model==null:errors.append("Missing model "+id);continue
		world.add_child(model);var bounds: AABB=model.get_meta("bounds")
		if absf(bounds.get_center().x)>.002 or absf(bounds.get_center().z)>.002 or absf(bounds.position.y)>.002 or bounds.size.y<.01 or bounds.size.length()>1.:errors.append("Incorrect normalized bounds for "+id+": "+str(bounds))
		for _warm in 5:await process_frame
		await RenderingServer.frame_post_draw;viewport.get_texture().get_image().save_png(output.path_join(id+".png"));model.queue_free();await process_frame
	print("Refreshment models: 21 colored assets, ",errors.size()," failures: ",errors)
	viewport.queue_free();surface.queue_free();Hearth20RefreshmentModels.cache.clear();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)

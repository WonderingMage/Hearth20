extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1200,900);var surface=SubViewportContainer.new();surface.stretch=true;surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.material=Hearth20FxPost.material();root.add_child(surface)
	var viewport=SubViewport.new();viewport.own_world_3d=true;viewport.transparent_bg=false;viewport.msaa_3d=Viewport.MSAA_4X;surface.add_child(viewport)
	var world=Node3D.new();viewport.add_child(world);var environment=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("#080c13");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("#e2d3b6");env.ambient_light_energy=.6;environment.environment=env;world.add_child(environment)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);light.light_color=Color("#ffe0a5");light.light_energy=1.8;world.add_child(light)
	var camera=Camera3D.new();camera.current=true;camera.position=Vector3(0,.5,2.7);camera.fov=40;world.add_child(camera);camera.look_at(Vector3.ZERO)
	var die=Hearth20CasinoDie.new();world.add_child(die);die.target_scale=.70;die.setup(8,7,"soul");die.place(Vector3.ZERO,camera,true)
	for i in 240:
		await process_frame
		if i in [20,90,180]:
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join("soul-die-"+str(i)+".png"))
	root.remove_child(surface);surface.queue_free();await process_frame;await process_frame;print("Soul die visual study complete.");quit()

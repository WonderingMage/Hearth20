extends SceneTree
var output=""
var shell: Hearth20SeatedShell
var checks=0
var errors=[]
func _initialize() -> void:output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func run() -> void:
	root.size=Vector2i(1600,1000);shell=Hearth20SeatedShell.new();root.add_child(shell)
	while not shell.ready_to_show:await process_frame
	shell.set_process(false);var tray=shell.refreshments;tray.set_process(false)
	var camera=shell.table.camera;var initial_basis=camera.global_basis
	for id in Hearth20RefreshmentCatalog.DRINKS:
		var packed=await Hearth20RefreshmentModels.prepare(id,self);expect(packed!=null,"drink loads: "+id)
		var model=Hearth20RefreshmentModels.make(id,packed);tray.serving.add_child(model)
		var lip: Vector3=model.get_meta("drink_lip");var bounds: AABB=model.get_meta("bounds")
		expect(lip.y>bounds.position.y+bounds.size.y*.85,"contact anchor is near the lip: "+id)
		for degrees in [-90.,0.,90.]:
			camera.global_basis=Basis(Vector3.UP,deg_to_rad(degrees))*initial_basis
			for sip in 3:
				tray.value={"drink_sips":sip};model.scale=Vector3.ONE
				tray._drink_pose(model,0.);expect(model.position.distance_to(tray.drink_at)<.00001,"sip begins on side table: "+id)
				var previous=model.position
				for frame in 121:
					var t=float(frame)/120.;tray._drink_pose(model,t)
					expect(model.position.is_finite() and model.position.distance_to(previous)<.13,"continuous finite sip path: "+id);previous=model.position
					if t>.43 and t<.64:
						var mouth=camera.to_global(Vector3(.08,-.15,-.28));var actual=model.to_global(lip)
						expect(actual.distance_to(mouth)<.0001,"lip stays at the mouth while tilted: "+id)
						var base=camera.to_local(model.global_position);var contact=camera.to_local(actual)
						expect(base.z<contact.z-.08,"container base tilts away from camera: "+id)
						for corner in 8:expect(camera.to_local(model.to_global(bounds.get_endpoint(corner))).z<-.06,"container clears camera near plane: "+id)
				expect(model.scale.is_equal_approx(Vector3.ONE),"sip does not squash the container: "+id)
				expect(model.position.distance_to(tray.drink_at)<.00001,"sip returns to exact serving position: "+id)
				tray._drink_pose(model,.52)
				if sip==0 and degrees==-90.:
					await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(id+"-sip.png"))
		model.queue_free();await process_frame
	camera.global_basis=initial_basis
	shell.queue_free();shell=null;await create_timer(.8).timeout;Hearth20RefreshmentModels.cache.clear()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"\t"))
	print("Drinking animation: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)

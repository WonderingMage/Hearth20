extends SceneTree
var checks:=0
var errors: Array=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool, note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error("FAIL: "+note)
func capture(window: Window, name_value: String) -> void:
	await create_timer(.15).timeout;await RenderingServer.frame_post_draw;window.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join(name_value+".png"))
func run() -> void:
	var app: Hearth20App=load("res://hearth20_main.tscn").instantiate();root.add_child(app);await process_frame
	var board:=Hearth20BoardCanvas.new();root.add_child(board);board.set_role("player");var arrived_usec:=Time.get_ticks_usec()-1500000
	board.set_player_snapshot({"edition":Hearth20Identity.EDITION,"scene":{"id":"age-study","width_cells":8,"height_cells":8,"cell_pixels":48},"fx":[{"id":"late-arrival","preset":"tabletop-fx-v1","effect":"explode","material":"Fire","start":Vector2(4,4),"end":Vector2(4,4),"center":Vector2(4,4),"elapsed_msec":1500,"original_travel_msec":600,"delay_to_arrival_msec":0,"impact_duration_msec":4000}]})
	expect(board.active_fx.events.size()==1 and absi(int(board.active_fx.events[0].started_usec)-arrived_usec)<100000 and board.active_fx.events[0].travel_usec==600000,"late player FX packet preserves animation age and original travel")
	board.queue_free();await process_frame
	var studio:=app.open_fx_studio();expect(studio!=null,"effects atelier opens from the real app")
	var hashes: Array=[]
	for i in studio.PRESETS.size():
		studio._preset(i);studio.playing=false;studio.age=1.0 if i!=0 else 1.9;await process_frame;await process_frame;await capture(studio,"atelier-%02d-%s"%[i,str(studio.PRESETS[i][0]).to_lower().replace(" ","-")])
		var image:=studio.viewport.get_texture().get_image();hashes.append(Hearth20Contracts.sha256(image.get_data()))
		expect(studio.actor.cloud.multimesh.instance_count==512,"cinematic density for "+str(studio.PRESETS[i][0]))
		if studio.actor.element!="Smoke":expect(not studio.actor.ribbons.is_empty(),"swept3D tube geometry for "+studio.actor.element)
		if studio.actor.element in ["Blood","Water"]:expect(studio.actor.crown!=null and studio.actor.crown.mesh.get_surface_count()==1,"deforming liquid crown for "+studio.actor.element)
		studio.age+=.35;await process_frame;await RenderingServer.frame_post_draw;expect(hashes.back()!=Hearth20Contracts.sha256(studio.viewport.get_texture().get_image().get_data()),"material and geometry animate over time: "+studio.actor.element)
	expect(hashes.all(func(value):return hashes.count(value)==1),"all eleven curated render studies differ")
	expect(studio.surface.material is ShaderMaterial,"isolated multiscale FX bloom is active")
	studio._preset(10);studio.playing=true;var times: Array=[]
	for i in 90:
		var start:=Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw
		if i>15:times.append((Time.get_ticks_usec()-start)/1000.)
	times.sort();var median: float=times[times.size()/2];var p95: float=times[floori(times.size()*.95)]
	FileAccess.open(OS.get_environment("H20_QA_EVIDENCE").path_join("fx-performance.json"),FileAccess.WRITE).store_string(JSON.stringify({"median_frame_ms":median,"p95_frame_ms":p95,"frames":times.size(),"renderer":RenderingServer.get_video_adapter_name(),"scenario":"one512-particle pyre +64-step self-shadowed volume + plume + swept tubes + isolated bloom + lit floor"},"\t"));print("FX atelier frame timing: median ",median," ms; p95 ",p95," ms")
	expect(median<60,"single cinematic effect remains interactive on the native test GPU")
	studio.queue_free();app.queue_free();await process_frame;await process_frame
	print("FX artistry: %d assertions, %d failures."%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

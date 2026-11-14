extends SceneTree
## Native visual/performance probe for the imported static room and props.
var shell: Hearth20SeatedShell
var output=""
var checks=0
var errors=[]
var results=[]
func _initialize() -> void:output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func until(predicate: Callable,message: String) -> void:
	var end=Time.get_ticks_msec()+30000
	while not predicate.call() and Time.get_ticks_msec()<end:await process_frame
	expect(predicate.call(),message)
func mean(values: Array) -> float:
	var sum=0.
	for value in values:sum+=float(value)
	return sum/maxi(1,values.size())
func measure(label: String,action=Callable()) -> void:
	await create_timer(2.).timeout
	var frames=[];var draws=[];var primitives=[];var previous=Time.get_ticks_usec();var start=previous
	while Time.get_ticks_usec()-start<8000000:
		if action.is_valid():action.call(float(Time.get_ticks_usec()-start)/1000000.)
		await process_frame;var now=Time.get_ticks_usec();frames.append(float(now-previous)/1000.);previous=now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var sorted=frames.duplicate();sorted.sort();var tail=sorted.slice(sorted.size()-maxi(1,ceili(sorted.size()*.01)))
	var result={"scene":label,"fps_cap":Engine.max_fps,"frames":frames.size(),"seconds":float(previous-start)/1000000.,"average_fps":1000./mean(frames),"one_percent_low_fps":1000./mean(tail),"p99_ms":sorted[mini(sorted.size()-1,floori(sorted.size()*.99))],"draw_calls":mean(draws),"primitives":mean(primitives),"video_memory_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.,"texture_memory_mb":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.}
	expect(Engine.max_fps==0,"uncapped measurement stays independent of background focus: "+label)
	results.append(result);print(JSON.stringify(result))
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_jpg(output.path_join(label+".jpg"),.93)
	FileAccess.open(output.path_join("performance.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
func run() -> void:
	root.title="Hearth20 · Imported asset check · closes automatically";root.size=Vector2i(1920,1080)
	OS.set_environment("H20_PERFORMANCE_OUTPUT",output)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var started=Time.get_ticks_msec();shell=Hearth20SeatedShell.new();root.add_child(shell)
	await until(func():return shell.ready_to_show,"imported assets finish loading")
	var load_ms=Time.get_ticks_msec()-started
	# OS focus notifications must not throttle the isolated measurement window.
	for pair in [["focus_entered","_focus_entered"],["focus_exited","_focus_exited"]]:
		var callback=Callable(shell,pair[1])
		if root.is_connected(pair[0],callback):root.disconnect(pair[0],callback)
	Engine.max_fps=0
	shell.app._load_sample_map("lantern-larch-inn",false)
	await measure("imported-table-front")
	shell.looking=true;shell.look.x=PI;await measure("imported-room-rear")
	await measure("imported-room-turn",func(t):shell.look.x=t*.55)
	shell.looking=false;shell.look=Vector2.ZERO;shell.focus_map();await process_frame
	expect(shell.table.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"focused map disables the 3D room pass")
	await measure("focused-map");shell.leave_focus()
	# Inspect changed static props without running unrelated casino transactions
	# or soul-die animations. Real mode transitions are covered by seated_visual.
	shell.map_items.hide();shell.table.casino_active=true
	shell.looking=true;shell.look=Vector2.ZERO
	var state={"game":"gambit_of_ord","id":"static-cups","phase":"betting","round":1,"stage":1,"pot":25,"revealed":false,"seats":[{"name":"Guest","mine":true,"dice":[],"dice_count":0,"folded":false,"flight":[]},{"name":"Other seat","dice_count":3,"folded":false,"flight":[]}]}
	shell.table.present(state,0);await until(func():return not shell.table.game_view.preparing,"new cup and chip props ready")
	expect(shell.table.game_view.dynamic_root.get_children().filter(func(n):return n.get_meta("generated_model","")=="dice_cup").size()==3,"hidden dice use three supplied cups")
	expect(not shell.table.game_view.dynamic_root.find_children("Generated_wood_coin*","Node3D",true,false).is_empty(),"pot uses supplied coin mesh")
	await measure("imported-cups-and-coins")
	state={"game":"run_of_luck","id":"static-race","phase":"betting","round":1,"stage":0,"pot":20,"race_rolls":[],"positions":[0,0,0,0,0],"seats":[]}
	shell.table.present(state,-1);await until(func():return not shell.table.game_view.preparing,"raceboard and existing animated lizard load")
	expect(shell.table.game_view.world_root.has_node("Generated_lizard_table"),"race keeps the supplied board")
	await measure("imported-race-board")
	shell.table.game_view.clear();shell.looking=false;shell.table.casino_active=false;shell.map_items.show()
	shell.refreshments.glance();await create_timer(.8).timeout
	expect(shell.refreshments.stool.has_node("Generated_side_table"),"supplied snack table present")
	expect(shell.refreshments.menu_model.get_children().filter(func(n):return n.get_meta("generated_model","")=="menu").size()==1,"supplied physical menu present")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_jpg(output.path_join("imported-side-table.jpg"),.93)
	var result={"checks":checks,"errors":errors,"resolution":[1920,1080],"vsync":false,"fps_cap":0,"load_ms":load_ms,"hardware":"i7-11700F / RTX 3070 Ti; not GTX 1060 / i5-8500 certification","build":"source debug","performance":results}
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	shell.queue_free();await create_timer(1.).timeout
	print("Generated scene: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)

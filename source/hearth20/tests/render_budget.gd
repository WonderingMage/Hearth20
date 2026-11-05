extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	root.size=Vector2i(1280,720)
	var stage=Hearth20FxStage3D.new();root.add_child(stage)
	expect(not stage.visible and stage.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"empty FX pass starts disabled")
	var event={"id":"budget-fx","preset":"tabletop-fx-v1","effect":"glow","material":"Holy","color":"#ffee99","density":16,"source":Vector2(2,2),"destination":Vector2(2,2),"started_usec":0,"travel_usec":0,"impact_duration_usec":8000000,"seed":12}
	stage.refresh_hz=30.
	expect(stage.update_events([event],32.,Vector2.ZERO,1000000,Vector2(640,480)),"on-screen effect schedules a frame")
	expect(stage.visible and stage.actors.size()==1,"on-screen 3D effect is retained")
	expect(not stage.update_events([event],32.,Vector2.ZERO,1010000,Vector2(640,480)),"miniature skips redundant frame inside 30 Hz budget")
	expect(stage.update_events([event],32.,Vector2.ZERO,1040000,Vector2(640,480)),"next animation frame reaches budget")
	stage.update_events([event],32.,Vector2(8000,8000),1040001,Vector2(640,480))
	expect(not stage.visible and stage.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"panning beyond FX pauses its render pass immediately")
	expect(not stage.actors["budget-fx"].visible,"off-camera actor is hidden")
	stage.update_events([event],32.,Vector2.ZERO,1040002,Vector2(640,480))
	expect(stage.visible and stage.actors["budget-fx"].visible,"panning back resumes the same actor")
	stage.update_events([],32.,Vector2.ZERO,1040003,Vector2(640,480))
	expect(stage.actors.is_empty() and not stage.visible,"expired effects release their actors")
	stage.queue_free();await process_frame
	var shell=Hearth20SeatedShell.new();root.add_child(shell)
	while not shell.ready_to_show:await process_frame
	shell.app._load_sample_map("sunspire-sanctum",false);await create_timer(.5).timeout
	expect(not shell.table.casino_active,"map mode marks casino inactive")
	expect(shell.table.card_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and shell.table.soul_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"map mode does not render hidden card or soul layers")
	shell.focus_map();await create_timer(.2).timeout
	expect(shell.table.process_mode==Node.PROCESS_MODE_DISABLED,"focused board stops all hidden tavern processing")
	for viewport in [shell.table.viewport,shell.table.card_viewport,shell.table.soul_viewport]:expect(viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"hidden table viewport remains disabled across frames")
	expect(shell.app.board.soft_light.refresh_hz==60.,"focused lighting has full animation cadence")
	shell.leave_focus();await create_timer(.2).timeout
	expect(shell.table.can_process() and shell.table.visible,"returning to seat resumes tavern")
	expect(shell.app.board.soft_light.refresh_hz==10.,"idle map miniature uses ten lighting updates per second")
	shell.app.session.set_table_mode("casino")
	while shell.current_mode!="casino" or shell.switching:await process_frame
	var portal=shell.app.casino_portal;portal.phase="visual-proof"
	shell.table.present({"game":"gambit_of_ord","id":"render-probe","phase":"betting","stage":3,"round":1,"pot":3,"revealed":true,"seats":[{"name":"One","mine":true,"dice":[8,6,4],"dice_count":3,"flight":[],"folded":false}]},0)
	while shell.table.game_view.preparing:await process_frame
	await create_timer(.4).timeout
	expect(shell.table.card_surface.visible and shell.table.game_view.dice.size()==3,"visible dice keep their overlay and full geometry")
	var die=shell.table.game_view.dice.values()[0];var age=die.age
	shell.looking=true;shell.look.x=PI;await create_timer(1).timeout
	expect(not die.render_active and die.age>age,"off-camera die stops rendering calculations while its timeline advances")
	var tick=die.soul_tick;await create_timer(.2).timeout
	expect(die.soul_tick==tick,"off-camera soul uniforms do not upload")
	shell.looking=false;shell.look=Vector2.ZERO;await create_timer(1).timeout
	expect(die.render_active and die.soul_tick>tick,"returning view resumes current soul animation")
	shell.table.book.open_book();await create_timer(1).timeout
	expect(shell.table.card_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and not die.render_active,"reading rules pauses hidden dice passes")
	shell.table.book.close_book();await create_timer(1).timeout
	shell.app.session.set_table_mode("map")
	while shell.current_mode!="map" or shell.switching:await process_frame
	await create_timer(.2).timeout
	expect(not shell.table.casino_active and shell.table.soul_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"leaving a live game cannot reactivate its soul layer")
	shell.app.session.set_scene_lighting(false);await create_timer(.2).timeout
	expect(not shell.app.board.soft_light.active and shell.app.board.soft_light.output.render_target_update_mode==SubViewport.UPDATE_DISABLED,"lighting toggle keeps its offscreen pass disabled")
	shell.queue_free();await create_timer(.3).timeout
	print("Render budgets: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)

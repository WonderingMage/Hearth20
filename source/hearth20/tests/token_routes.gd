extends SceneTree
const Saved=preload("campaign_saves.gd")
var checks=0
var errors=[]
var sequence=0
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func mouse(board: Hearth20BoardCanvas,point: Vector2,button: int,pressed: bool) -> void:
	var event=InputEventMouseButton.new();event.position=board._world_to_screen(point,64.);event.button_index=button;event.pressed=pressed;board._gui_input(event)
func motion(board: Hearth20BoardCanvas,point: Vector2) -> void:
	var event=InputEventMouseMotion.new();event.position=board._world_to_screen(point,64.);event.button_mask=MOUSE_BUTTON_MASK_LEFT;board._gui_input(event)
func move(session: Hearth20Session,path: Variant,player="player-a",revision=-1) -> Dictionary:
	sequence+=1;session.request_rates.clear()
	return session._apply_board_action({"action":"move_path","actor_id":"route-token","points":path,"expected_revision":session.campaign.revision if revision<0 else revision,"request_id":"route-test-"+str(sequence)},player)
func run() -> void:
	create_timer(20).timeout.connect(func():push_error("Token route watchdog");quit(1))
	root.size=Vector2i(1280,800)
	var app=Saved.AppFixture.new();root.add_child(app);app.board.size=Vector2(1000,650);app.board.focus_mode=Control.FOCUS_ALL
	for frame in 5:await process_frame
	var board=app.board;var scene=board.current_scene();var session=app.session
	scene.annotations=[];scene.walls=[];scene.doors=[];scene.cell_pixels=64.
	var actor=Hearth20TokenInventory.new_actor("Route adventurer",true,scene,Vector2(1.5,1.5));actor.id="route-token";actor.owner_player_id="player-a";app.campaign.actors.append(actor)
	board.activate_tool("select");board.camera_pan=Vector2.ZERO;board.camera_zoom=1.;board.fit_pending=false
	var revision=app.campaign.revision
	mouse(board,actor.position,MOUSE_BUTTON_LEFT,true);motion(board,Vector2(4.1,1.9))
	expect(board.dragging_actor and board.drag_points==[Vector2(1.5,1.5),Vector2(4.5,1.5)],"movement preview snaps to square centers")
	expect(board._get_drag_data(Vector2(100,100))==null and board.dragging_actor,"dragging inside the board preserves the route preview")
	mouse(board,Vector2(4.1,1.9),MOUSE_BUTTON_RIGHT,true);mouse(board,Vector2(4.1,1.9),MOUSE_BUTTON_RIGHT,false)
	expect(board.drag_points.size()==3 and board.drag_points[1]==Vector2(4.5,1.5),"right-click pins a center-snapped waypoint during a left drag")
	motion(board,Vector2(4.9,5.1));expect(is_equal_approx(Hearth20BoardTools.distance({"points":board.drag_points},5.),35.),"preview distance sums every route segment")
	mouse(board,Vector2(4.9,5.1),MOUSE_BUTTON_LEFT,false)
	expect(actor.position==Vector2(4.5,5.5) and app.campaign.revision==revision+1,"normal DM release applies the centered route once")
	expect(not board.dragging_actor and board.drag_points.is_empty(),"release clears all temporary movement points")
	mouse(board,actor.position,MOUSE_BUTTON_LEFT,true);motion(board,Vector2(6.1,5.1))
	var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;board._gui_input(escape)
	expect(not board.dragging_actor and board.drag_points.is_empty() and actor.position==Vector2(4.5,5.5),"Escape cancels route planning without moving the token")
	scene.snap_to_grid=false;mouse(board,actor.position,MOUSE_BUTTON_LEFT,true);motion(board,Vector2(6.2,5.8))
	expect(board.drag_points.back().distance_to(Vector2(6.2,5.8))<.001,"free-placement scenes preserve unsnapped previews")
	board.activate_tool("select");scene.snap_to_grid=true
	actor.position=Vector2(1.5,1.5);actor.movement_policy=Hearth20Contracts.default_movement_policy("grant",["player-a"]);actor.movement_policy.remaining_feet=50.
	session.remote_players={"player-a":{"nickname":"A"},"player-b":{"nickname":"B"}}
	scene.walls=[{"a":{"x":3.,"y":0.},"b":{"x":3.,"y":4.}}]
	var route=[Vector2(1.5,1.5),Vector2(1.5,4.5),Vector2(4.5,4.5),Vector2(4.5,1.5)]
	var before=var_to_bytes(app.campaign);var blocked=move(session,[actor.position,Vector2(4.5,1.5)])
	expect(not blocked.ok and before==var_to_bytes(app.campaign),"a straight move through a wall is rejected atomically")
	var accepted=move(session,route)
	expect(accepted.ok and actor.position==route.back() and actor.movement_policy.remaining_feet==5.,"a routed move around the wall charges the full 45 feet")
	actor.position=route.front();actor.movement_policy.remaining_feet=40.;before=var_to_bytes(app.campaign)
	expect(not move(session,route).ok and before==var_to_bytes(app.campaign),"insufficient route allowance cannot leave a partial move")
	for path in [null,{},[],[actor.position],[null,route.back()],[{},route.back()],[Vector2(NAN,1),route.back()],[actor.position,Vector2(INF,1)],[actor.position,Vector2(-1,1)],[actor.position,Vector2(9999,1)],Array(range(65))]:
		before=var_to_bytes(app.campaign)
		expect(not move(session,path).ok and before==var_to_bytes(app.campaign),"malformed route is rejected without table changes "+str(path).left(35))
	actor.movement_policy.remaining_feet=50.;before=var_to_bytes(app.campaign)
	expect(not move(session,route,"player-b").ok and before==var_to_bytes(app.campaign),"another player cannot route this character")
	expect(not move(session,route,"player-a",app.campaign.revision+1).ok and before==var_to_bytes(app.campaign),"stale table revisions reject route submission")
	actor.in_inventory=true;before=var_to_bytes(app.campaign)
	expect(not move(session,route).ok and before==var_to_bytes(app.campaign),"stowed tokens cannot be routed onto the board")
	app.queue_free();await process_frame;await process_frame
	print("Token routes: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

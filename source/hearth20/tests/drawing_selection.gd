extends SceneTree
var output=""
var checks=0
var errors=[]
var serial=0
var app: Hearth20App
var board: Hearth20BoardCanvas
var session: Hearth20Session
var scene: Dictionary
func _initialize() -> void:output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func mouse(point: Vector2,pressed: bool) -> void:
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=board._world_to_screen(point,float(scene.cell_pixels));board._gui_input(event)
func motion(point: Vector2) -> void:
	var event=InputEventMouseMotion.new();event.position=board._world_to_screen(point,float(scene.cell_pixels));event.button_mask=MOUSE_BUTTON_MASK_LEFT;board._gui_input(event)
func key(code: Key,control=false) -> void:
	var event=InputEventKey.new();event.keycode=code;event.pressed=true;event.ctrl_pressed=control;board._gui_input(event)
func action(command: Dictionary,player="dm-local") -> Dictionary:
	serial+=1;command.request_id="selection-test-"+str(serial);session.request_rates.clear();return session._apply_board_action(command,player)
func add(kind: String,a: Vector2,b: Vector2,player="dm-local",layer="tokens") -> String:
	var result=action({"action":"add","object":{"kind":kind,"layer":layer,"points":[a,b],"color":"#22d5fa","width":3.,"fill":"#00000000","text":"Test"}},player)
	expect(result.ok,"create "+kind+" fixture");return str(scene.annotations.back().id)
func settle() -> void:
	for i in 4:await process_frame
func run() -> void:
	root.size=Vector2i(1280,800);root.gui_embed_subwindows=true;Hearth20Preferences.values.startup_updates=false
	app=load("res://hearth20_main.tscn").instantiate();root.add_child(app);await process_frame
	board=app.board;session=app.session;scene=app.campaign.scenes[0];scene.grid_visible=false
	session.remote_players={"player-a":{"nickname":"A"},"player-b":{"nickname":"B"}}
	for player in ["player-a","player-b"]:
		var hero=Hearth20TokenInventory.new_actor(player,true,scene,Vector2(1.5,1.5));hero.owner_player_id=player;app.campaign.actors.append(hero)
	app.toolbox.open("draw",false);board.tool_settings.kind="freehand";board.tool_settings.color="#22d5fa";await settle()
	mouse(Vector2(3,3),true);motion(Vector2(4,4));motion(Vector2(5,3));await settle()
	expect(not board.draft.is_empty() and not board.drawing_is_selected(board.draft),"unfinished stroke is not a selected object when both IDs are empty")
	expect(not board.selecting_drawings and board.selected_object_ids.is_empty(),"drawing never starts a selection box")
	await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image();picture.save_png(output.path_join("drawing-preview.png"));var corner=board.get_global_position()+board._world_to_screen(Vector2(3,3),float(scene.cell_pixels))-Vector2(5,5);var extent=Vector2(2,1)*float(scene.cell_pixels)*board.camera_zoom+Vector2(10,10)
	var gold=0
	for x in range(roundi(corner.x),roundi(corner.x+extent.x)):
		for y in [roundi(corner.y),roundi(corner.y+extent.y)]:
			if x<0 or y<0 or x>=picture.get_width() or y>=picture.get_height():continue
			var p=picture.get_pixel(x,y);gold+=int(p.r>.7 and p.g>.45 and p.b<.6)
	expect(gold<4,"native frame contains no gold bounding outline around the live stroke")
	mouse(Vector2(5,3),false);expect(scene.annotations.size()==1,"stroke still commits normally")
	var first=str(scene.annotations[0].id);var second=add("line",Vector2(5,4),Vector2(6,5));var outside=add("rectangle",Vector2(8,8),Vector2(9,9))
	var order=scene.annotations.map(func(object):return object.id);var old_pan=board.camera_pan;app.toolbox.open("select",false)
	mouse(Vector2(2,2),true);motion(Vector2(6.5,5.5));expect(board.selecting_drawings,"dragging empty space in Select begins a marquee");mouse(Vector2(6.5,5.5),false)
	expect(board.selected_object_ids.size()==2 and first in board.selected_object_ids and second in board.selected_object_ids,"marquee selects only touched drawings")
	expect(board.camera_pan==old_pan and not board.panning,"selection drag does not also pan the map")
	await settle();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("box-selected-drawings.png"))
	var revision=int(app.campaign.revision);board.grab_focus();var backspace=InputEventKey.new();backspace.keycode=KEY_BACKSPACE;backspace.pressed=true;root.push_input(backspace);await settle()
	expect(scene.annotations.size()==1 and scene.annotations[0].id==outside,"focused Backspace deletes the selected group and preserves outside objects")
	expect(app.campaign.revision==revision+1,"group deletion is one revision, not many queued requests")
	key(KEY_Z,true);expect(scene.annotations.map(func(object):return object.id)==order,"one Ctrl+Z restores the whole group in original drawing order")
	mouse(Vector2(6.5,5.5),true);motion(Vector2(2,2));mouse(Vector2(2,2),false);expect(board.selected_object_ids.size()==2,"reverse-direction marquee works")
	key(KEY_ESCAPE);expect(board.selected_object_ids.is_empty() and not board.selecting_drawings,"Escape clears selection without deleting drawings")
	mouse(Vector2(10,10),true);mouse(Vector2(10,10),false);expect(board.selected_object_ids.is_empty(),"empty click clears selection")
	mouse(Vector2(2,2),true);motion(Vector2(6,5));key(KEY_ESCAPE);expect(not board.selecting_drawings,"Escape cancels an unfinished marquee")
	board.space_pan=true;mouse(Vector2(2,2),true);motion(Vector2(2.5,2.5));mouse(Vector2(2.5,2.5),false);board.space_pan=false;expect(not board.selecting_drawings,"Space-drag remains map panning")
	board.clear_drawing_selection();board.activate_tool("select");mouse(Vector2(3.5,3.5),true);mouse(Vector2(3.5,3.5),false);expect(board.selected_object_id==first,"single drawing selection remains available")
	board.activate_tool("draw");expect(board.selected_object_ids.is_empty() and not board.drawing_is_selected({"id":first}),"switching to Draw hides all selection frames")
	var own_a=add("line",Vector2(3,3),Vector2(4,4),"player-a");var own_b=add("text",Vector2(5,4),Vector2(6,5),"player-a");var other=add("ellipse",Vector2(4,4),Vector2(5,5),"player-b");var hidden=add("line",Vector2(3,4),Vector2(5,4),"dm-local","gm")
	var count=scene.annotations.size();var undo_count=session.board_undo.get("player-a",[]).size()
	for bad in [[own_a,other],[own_a,hidden],[own_a,"missing-drawing"],[own_a,own_a],[],[{}],"not-an-array"]:
		expect(not action({"action":"delete_many","ids":bad},"player-a").ok and scene.annotations.size()==count,"host rejects invalid/foreign group atomically")
	expect(session.board_undo.get("player-a",[]).size()==undo_count,"rejected group edits do not consume undo history")
	var original_order=scene.annotations.map(func(object):return object.id);expect(action({"action":"delete_many","ids":[own_a,own_b]},"player-a").ok,"host accepts owner group deletion")
	expect(action({"action":"undo"},"player-a").ok and scene.annotations.map(func(object):return object.id)==original_order,"owner can undo group deletion")
	board.selected_object_id=own_b;board.selected_object_ids.assign([own_b]);app.toolbox.open("text",false)
	expect(board.selected_object_id==own_b and board.selected_object().kind=="text" and not board.drawing_is_selected(board.selected_object()),"editing an existing text box keeps its target without showing a drawing outline")
	# Pure client-UI projection fixture, not a connected peer; mine flags carry ownership.
	var view=session._project_for("player-a");session.local_role="player";session.local_player_id="";session.client_snapshot=view;board.set_role("player");board.set_player_snapshot(view);board.activate_tool("select");await settle()
	mouse(Vector2(2,2),true);motion(Vector2(6.5,5.5));mouse(Vector2(6.5,5.5),false)
	expect(board.selected_object_ids.size()==2 and own_a in board.selected_object_ids and own_b in board.selected_object_ids,"player box excludes other players and GM-layer drawings")
	var diagonal={"kind":"line","points":[Vector2(1,1),Vector2(9,9)]};expect(not Hearth20DrawingSelection.touches(diagonal,Rect2(1,7,1,1)),"freehand/line selection checks actual segments, not empty bounding-box space")
	board.set_player_snapshot(Hearth20PlayerMap.waiting(app.campaign,"player-a"));expect(board.selected_object_ids.is_empty() and not board.selecting_drawings,"map/view changes clear selection")
	app.queue_free();await process_frame;await process_frame
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"  "));print("Drawing selection: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)

extends SceneTree
class AppFixture extends Node:
	func _accent_button(_button: Button) -> void:pass
	func _selected_sheet_actor() -> Dictionary:return {}
class SessionFixture extends Hearth20Session:
	var submitted=[]
	func submit_dice(_actor: String,expression: String,visibility: String,proficiency: bool,mode: String="normal") -> Dictionary:
		var id="fixture-roll-"+str(submitted.size())
		submitted.append({"action":"roll","request_id":id,"expression":expression,"visibility":visibility,"proficiency":proficiency,"mode":mode})
		return {"ok":true,"pending":true,"request_id":id}
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func run() -> void:
	var session=SessionFixture.new();root.add_child(session)
	var app=AppFixture.new();root.add_child(app)
	var dock=Hearth20ToolDock.new();root.add_child(dock);dock.app=app;dock.session=session;dock.current="dice"
	dock.content=VBoxContainer.new();dock.add_child(dock.content);dock.action_area=VBoxContainer.new();dock.add_child(dock.action_area)
	dock.note=Label.new();dock.add_child(dock.note);dock.dice_count=3;dock.dice_sides=6;dock.dice_bonus=202;dock.dice_visibility="self"
	session.table_request_finished.connect(dock._dice_request_finished);dock._dice_ui()
	dock.fields.dice_mode.select(1);dock.fields.dice_mode.item_selected.emit(1)
	expect(dock.dice_mode=="advantage" and dock.dice_count==1 and dock.dice_sides==20,"choosing advantage normalizes a previous 3d6 setup to one base d20")
	expect(dock.fields.quantity.value==2 and not dock.fields.quantity.editable,"quantity shows the two actual advantage dice and cannot create an invalid request")
	expect(not dock.fields.sides.editable and dock.die_buttons.filter(func(b):return b.get_meta("dice_sides")!=20).all(func(b):return b.disabled),"other die sizes are unavailable until Normal is chosen")
	expect("2d20" in dock.formula_label.text and "highest" in dock.formula_label.text,"advantage preview explains which of the two dice is kept")
	dock.dice_roll_button.pressed.emit()
	expect(session.submitted.size()==1 and session.submitted[0].expression=="1d20+202" and session.submitted[0].visibility=="self" and session.submitted[0].mode=="advantage","valid request preserves the private audience and bonus")
	expect("Waiting" in dock.roll_result.text and dock.dice_roll_button.disabled,"a sent request waits for acknowledgement instead of claiming it was recorded")
	dock._roll();expect(session.submitted.size()==1,"pending roll cannot be duplicated by repeated clicks")
	session.table_request_finished.emit({"action":"chat","request_id":"other"},{"ok":true})
	expect(not dock.pending_dice_request.is_empty(),"an unrelated chat acknowledgement cannot confirm this roll")
	session.table_request_finished.emit(session.submitted[0],{"ok":false,"error":"The GM rejected this fixture roll."})
	expect("rejected" in dock.roll_result.text and not dock.dice_roll_button.disabled,"a server rejection is shown next to the roll button and permits retry")
	dock.fields.dice_mode.select(2);dock.fields.dice_mode.item_selected.emit(2);dock.dice_roll_button.pressed.emit()
	expect("lowest" in dock.formula_label.text and session.submitted[1].mode=="disadvantage","disadvantage previews and sends the lower-of-two mode")
	session.table_request_finished.emit(session.submitted[1],{"ok":true})
	expect(dock.roll_result.text=="Roll confirmed." and not dock.dice_roll_button.disabled,"only the matching accepted request confirms the roll")
	dock.fields.dice_mode.select(0);dock.fields.dice_mode.item_selected.emit(0)
	expect(dock.fields.quantity.editable and dock.fields.sides.editable and dock.die_buttons.all(func(b):return not b.disabled),"Normal restores arbitrary dice and quantity controls")
	for button in dock.die_buttons:
		if button.get_meta("dice_sides")==6:button.pressed.emit()
	dock.fields.quantity.value=2;dock.dice_roll_button.pressed.emit()
	expect(session.submitted[2].expression=="2d6+202" and session.submitted[2].mode=="normal" and session.submitted[2].visibility=="self","normal multi-d6 rolls remain private and unchanged")
	session.pending_table_commands.append(session.submitted[2]);session._clear_client_view()
	expect(dock.pending_dice_request.is_empty() and "disconnected" in dock.roll_result.text and not dock.dice_roll_button.disabled,"disconnect releases the outstanding roll and explains why it was not confirmed")
	dock.dice_mode="advantage";dock.dice_count=1;dock.dice_sides=6;dock._roll()
	expect(session.submitted.size()==3 and "d20" in dock.roll_result.text,"an invalid restored d6 advantage state is rejected before sending")
	dock.queue_free();session.queue_free();app.queue_free();await process_frame;await process_frame
	print("Dice controls: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

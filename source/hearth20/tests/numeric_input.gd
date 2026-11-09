extends SceneTree
const Dice=preload("dice_controls.gd")
const Currency=preload("currency_input.gd")
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func type_number(input: SpinBox,text: String) -> void:
	input.get_line_edit().text=text
	input.get_line_edit().text_changed.emit(text)
func run() -> void:
	create_timer(15).timeout.connect(func():push_error("Numeric input watchdog");quit(1))
	var app=Dice.AppFixture.new();root.add_child(app)
	var session=Dice.SessionFixture.new();root.add_child(session)
	var dock=Hearth20ToolDock.new();root.add_child(dock);dock.app=app;dock.session=session;dock.current="dice"
	dock.content=VBoxContainer.new();dock.add_child(dock.content);dock.action_area=VBoxContainer.new();dock.add_child(dock.action_area)
	dock.note=Label.new();dock.add_child(dock.note);dock.dice_count=3;dock.dice_sides=6;dock.dice_bonus=202;dock._dice_ui()
	var bonus: SpinBox
	for input in dock.find_children("*","SpinBox",true,false):
		if input.value==202:bonus=input
	type_number(dock.fields.quantity,"04");type_number(bonus,"0203")
	dock.dice_roll_button.pressed.emit()
	expect(session.submitted.size()==1 and session.submitted[0].expression=="4d6+203","roll button commits typed quantity and bonus before reading them")
	dock.pending_dice_request=""
	type_number(dock.fields.quantity,"2+3");type_number(bonus,"-20")
	dock.dice_roll_button.pressed.emit()
	expect(session.submitted.size()==2 and session.submitted[1].expression=="5d6-20","existing arithmetic and signed modifiers remain supported")
	for text in ["","NaN","INF","1/0","0/0","1e999","0","51","2.5","not_a_number()","2".repeat(2048)]:
		dock.pending_dice_request="";type_number(dock.fields.quantity,text)
		var before=session.submitted.size();dock.dice_roll_button.pressed.emit()
		expect(session.submitted.size()==before and "Enter" in dock.roll_result.text,"invalid quantity blocks stale roll "+text.left(24))
	for text in ["2.5","51"]:
		type_number(dock.fields.quantity,text);dock.fields.quantity.apply()
		var before=session.submitted.size();dock.dice_roll_button.pressed.emit()
		expect(session.submitted.size()==before and "Enter" in dock.roll_result.text,"native focus-loss rounding cannot bypass rejection "+text)
	var casino_app=Currency.AppFixture.new();root.add_child(casino_app)
	var portal=Currency.PortalFixture.new();root.add_child(portal);portal.app=casino_app
	portal.status=Label.new();portal.add_child(portal.status)
	var controls=VBoxContainer.new();portal.add_child(controls);Hearth20CasinoGamesUI.reserve(portal,controls)
	var amount=controls.find_children("*","SpinBox",true,false)[0]
	var submit=controls.find_children("*","Button",true,false)[0]
	type_number(amount,"Total 01001 gp");submit.pressed.emit()
	expect(portal.sent.size()==1 and portal.sent[0].values.amount_cp==100100,"reserve button commits padded decimal and preserves individual gold pieces")
	for text in ["-1","1e999","oops","1.5"]:
		type_number(amount,text);var before=portal.sent.size();submit.pressed.emit()
		expect(portal.sent.size()==before and "Enter" in portal.status.text,"bad reserve never submits a stale amount "+text)
	var exits=[];var leave=portal._button(controls,"Leave",func():exits.append(true));leave.pressed.emit()
	expect(exits.size()==1,"invalid numeric draft cannot trap a player in the casino")
	dock.queue_free();session.queue_free();app.queue_free();portal.queue_free();casino_app.queue_free()
	await process_frame;await process_frame
	print("Numeric input: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

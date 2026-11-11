extends VBoxContainer
class_name Hearth20ToolDock
## Focused tool inspector. The map keeps its space; every tool has one home.
var app: Node
var board: Hearth20BoardCanvas
var session: Hearth20Session
var content: VBoxContainer
var action_area: VBoxContainer
var scroller: ScrollContainer
var fields: Dictionary = {}
var rail_buttons: Dictionary = {}
var tool_rail: VBoxContainer
var rail_hint: Label
var current := "draw"
var title: Label
var note: Label
var selection_note: Label
var roll_result: Label
var roll_history: VBoxContainer
var dice_visibility := "public"
var dice_count := 1
var dice_sides := 20
var dice_bonus := 0
var use_proficiency := false
var dice_mode := "normal"
var formula_label: Label
var syncing := false
var selected: Dictionary = {}
var dm_controls: Array[Control] = []
var section_body: VBoxContainer
var active_tool_name: Label
var die_buttons: Array[Button] = []
var dice_mode_help: Label
var dice_roll_button: Button
var pending_dice_request=""
var dice_status_text=""

func setup(owner_app: Node, rail: VBoxContainer) -> void:
	tool_rail=rail
	app = owner_app
	board = app.board
	session = app.session
	name = "Tools"
	scroller=ScrollContainer.new()
	scroller.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(scroller)
	action_area=VBoxContainer.new()
	action_area.add_theme_constant_override("separation",6)
	add_child(action_area)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in rail.get_children(): child.hide()
	rail.custom_minimum_size.x = 46
	rail.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for tool in [["select","↖","Select","V"],["tokens","","Tokens · add, edit and grant control","K"],["draw","✎","Draw","D"],["text","T","Text","T"],["measure","⌁","Measure","M"],["dice","◇","Dice","R"],["fx","✦","Effects","X"],["casino","","Tavern casino · Games",""],["beacon","◎","Beacon","B"],["mask","▧","Mask","H"],["lighting","☼","Lighting","L"],["layers","▱","Layers",""]]:
		var button := Button.new()
		button.text = ""
		button.icon=Hearth20Design.icon(str(tool[0]),22)
		button.add_theme_constant_override("icon_max_width",22)
		button.theme_type_variation="RailButton"
		button.custom_minimum_size = Vector2(44,38)
		button.add_theme_font_size_override("font_size",12)
		button.tooltip_text = str(tool[2])+(" · "+str(tool[3]) if not str(tool[3]).is_empty() else "")
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(func(): open(str(tool[0])))
		if tool[0]=="beacon":
			var divider:=HSeparator.new()
			rail.add_child(divider)
		rail.add_child(button)
		rail_buttons[str(tool[0])] = button
		if tool[0] in ["tokens","casino","beacon","mask","lighting","layers"]: dm_controls.append(button)
	rail_buttons.select.button_pressed = true
	var hint := Label.new()
	rail_hint=hint
	hint.text="F  fit"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",10)
	hint.add_theme_color_override("font_color",Color("#93a4ac"))
	rail.add_child(hint)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",14)
	scroller.add_child(content)
	board.object_selected.connect(_object_selected)
	session.timeline_changed.connect(func(_entries):
		if current == "dice": _refresh_rolls())
	session.table_request_finished.connect(_dice_request_finished)
	open("draw", false)
	board.activate_tool("select")
	rail_buttons.select.button_pressed=true

func refresh_role() -> void:
	for control in dm_controls: control.visible = session.local_role == "dm"
	if session.local_role == "player" and current in ["tokens","casino","beacon","mask","lighting","layers"]: open("draw",false)
	if session.local_role == "player": board.active_layer = "tokens"

func clear_content() -> void:
	die_buttons.clear()
	section_body=null
	fields.clear()
	for child in action_area.get_children():
		action_area.remove_child(child)
		child.queue_free()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func open(tool: String, show_panel: bool = true) -> void:
	if tool=="casino":
		if session.local_role=="dm":app.open_casino()
		return
	if tool in ["tokens","casino","beacon","mask","lighting","layers"] and session.local_role != "dm": return
	current = tool
	clear_content()
	scroller.scroll_vertical=0
	var eyebrow := label("TABLETOP  /  "+("DM TOOLS" if tool in ["beacon","mask","lighting","layers"] else "SHARED TOOLS"),11,Color("#8b9fa8"))
	_target().add_child(eyebrow)
	title = label({"select":"Selection", "draw":"Draw on the table", "text":"Text & labels", "measure":"Measure & plan", "dice":"Dice roller", "fx":"Bring it to life", "beacon":"Guide the party", "mask":"Hide / reveal map", "lighting":"Light & vision", "layers":"Map layers"}.get(tool,tool),24,Color("#f3ead8"))
	title.add_theme_font_override("font",Hearth20Design.font(true))
	title.add_theme_font_size_override("font_size",27)
	_target().add_child(title)
	note = label("",13,Color("#9cadb5"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target().add_child(note)
	if tool=="tokens":
		board.active_layer="tokens"
		board.activate_tool("select")
		title.text="Tokens & control"
		note.text="Create, place and edit tokens here. The DM controls every token until a player is explicitly assigned."
	elif tool != "dice" and tool != "layers": board.activate_tool(tool)
	if rail_buttons.has(tool): rail_buttons[tool].button_pressed = true
	match tool:
		"select": _selection_ui()
		"tokens":
			var panel:=Hearth20TokenPanel.new(); _target().add_child(panel); panel.setup(app)
		"draw": _draw_ui()
		"text": _text_ui()
		"measure": _measure_ui()
		"dice": _dice_ui()
		"fx": _fx_ui()
		"beacon": _beacon_ui()
		"mask": _mask_ui()
		"lighting": _lighting_ui()
		"layers": _layers_ui()
	if tool in ["draw","text"]:
		section("ACTIVE LAYER")
		var layer_note := label(board.active_layer.capitalize()+"  ·  "+("Only the DM sees this" if board.active_layer == "gm" else "Visible to the table"),13,Color("#76e0ca"))
		_target().add_child(layer_note)
		if session.local_role == "dm": button("Change layer…",func(): open("layers"))
	if show_panel: app._show_sidebar_page(self)

func label(text_value: String, font_size: int = 14, color: Color = Color("#d9e2e6")) -> Label:
	var result := Label.new()
	result.text = text_value
	result.clip_text=true
	result.tooltip_text=text_value
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",Hearth20Regal.resolve(color))
	return result

func _target() -> VBoxContainer:
	return section_body if section_body!=null else content

func section(text_value: String) -> void:
	var card:=PanelContainer.new()
	card.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#192130"),11,12,Color("#30394c")))
	content.add_child(card)
	section_body=VBoxContainer.new()
	section_body.add_theme_constant_override("separation",10)
	card.add_child(section_body)
	section_body.add_child(label(text_value,10,Hearth20Design.GOLD))

func button(text_value: String, callback: Callable, accent: bool = false, parent: Node = null) -> Button:
	var result := Button.new()
	result.text = text_value
	result.clip_text=true
	result.tooltip_text=text_value
	result.custom_minimum_size.y = 36
	result.add_theme_font_size_override("font_size",13)
	result.pressed.connect(callback)
	(parent if parent else _target()).add_child(result)
	if accent: app._accent_button(result)
	return result

func options(caption: String, values: Array, selected_value: String, callback: Callable) -> OptionButton:
	_target().add_child(label(caption,13))
	var result := OptionButton.new()
	result.fit_to_longest_item=false
	result.custom_minimum_size.y = 36
	for value in values:
		result.add_item(str(value).replace("_"," ").capitalize())
		result.set_item_metadata(result.item_count-1,str(value))
		if str(value) == selected_value: result.select(result.item_count-1)
	result.item_selected.connect(func(index): callback.call(str(result.get_item_metadata(index))))
	_target().add_child(result)
	return result

func choices(values: Array, selected_value: String, callback: Callable, columns: int = 3) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	_target().add_child(grid)
	var group := ButtonGroup.new()
	for value in values:
		var key := str(value[0]) if value is Array else str(value)
		var text_value := str(value[1]) if value is Array else key.capitalize()
		var result := button(text_value,func(): callback.call(key),false,grid)
		result.theme_type_variation="ChoiceButton"
		if key in ["freehand","line","rectangle","ellipse","square","circle","cone","beam"]:
			result.icon=Hearth20Design.icon(key,17)
			result.add_theme_constant_override("icon_max_width",17)
			result.text=key.capitalize()
		result.toggle_mode = true
		result.button_group = group
		result.button_pressed = key == selected_value
		result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if current=="dice" and key.is_valid_int():
			result.clip_text=false
			result.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
			result.alignment=HORIZONTAL_ALIGNMENT_CENTER
			result.set_meta("dice_sides",int(key))
			result.icon=Hearth20Design.icon("die"+key,28)
			result.add_theme_constant_override("icon_max_width",28)
			result.expand_icon=true
			result.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
			result.custom_minimum_size.y=64
			result.add_theme_font_size_override("font_size",12)
			die_buttons.append(result)
		if current=="fx" and Hearth20BoardTools.COLORS.has(key):
			result.icon=Hearth20Design.icon("circle",11)
			result.add_theme_constant_override("icon_max_width",11)
			result.add_theme_color_override("icon_normal_color",Color(Hearth20BoardTools.COLORS[key]))
			result.add_theme_color_override("icon_hover_color",Color(Hearth20BoardTools.COLORS[key]))
			result.add_theme_color_override("icon_pressed_color",Color(Hearth20BoardTools.COLORS[key]))
	return grid

func refresh_density(compact: bool) -> void:
	if is_instance_valid(tool_rail):tool_rail.add_theme_constant_override("separation",1 if compact else 4)
	if is_instance_valid(rail_hint):rail_hint.visible=not compact
	if current=="dice":
		if note!=null: note.visible=not compact
		for item in die_buttons:
			if is_instance_valid(item): item.custom_minimum_size.y=52 if compact else 64

func number(caption: String, value: float, low: float, high: float, callback: Callable, suffix: String = "") -> SpinBox:
	var row := HBoxContainer.new()
	_target().add_child(row)
	var text_label := label(caption,13)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_label)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.value = value
	spin.suffix = suffix
	spin.custom_minimum_size = Vector2(112,34)
	spin.value_changed.connect(callback)
	row.add_child(spin)
	Hearth20Design.track_number(spin)
	return spin

func toggle(caption: String, value: bool, callback: Callable) -> CheckButton:
	var result := CheckButton.new()
	result.text = caption
	result.button_pressed = value
	result.toggled.connect(callback)
	_target().add_child(result)
	return result

func color_field(caption: String, field: String) -> void:
	var row := HBoxContainer.new()
	_target().add_child(row)
	var text_label := label(caption,13)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_label)
	var picker := ColorPickerButton.new()
	text_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size.x=120
	picker.color = Color(board.tool_settings.get(field,"#76e0ca"))
	picker.custom_minimum_size = Vector2(72,32)
	picker.color_changed.connect(func(color): board.tool_settings[field] = "#"+color.to_html(); _refresh_text_preview())
	row.add_child(picker)
	fields[field] = picker

func _draw_ui() -> void:
	if board.tool_settings.kind not in ["freehand","line","rectangle","ellipse"]: board.tool_settings.kind="freehand"
	note.text = "Drag to draw. Switch to Select to move a drawing or press Delete to remove it. Ctrl+Z undoes your last edit."
	choices([["freehand","✎ Freehand"],["line","╱ Line"],["rectangle","□ Rectangle"],["ellipse","○ Ellipse"]],str(board.tool_settings.kind),func(v): board.tool_settings.kind = v,2)
	section("APPEARANCE")
	color_field("Stroke", "color")
	number("Stroke width",float(board.tool_settings.width),1,24,func(v): board.tool_settings.width = v,"px")
	color_field("Fill · transparent for border only", "fill")
	number("Opacity",float(board.tool_settings.opacity)*100,10,100,func(v): board.tool_settings.opacity = v/100.0,"%")
	button("Undo last drawing edit",func(): _report(session.board_action({"action":"undo"})))

func _text_ui() -> void:
	note.text = "Write your label, style it, then click or drag a text box on the map. Select an existing label to edit it."
	var edit := TextEdit.new()
	edit.placeholder_text = "The northern gate…"
	edit.text = str(board.tool_settings.text)
	edit.custom_minimum_size.y = 94
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text_changed.connect(func(): board.tool_settings.text = edit.text.left(2000); _refresh_text_preview())
	_target().add_child(edit)
	fields.text = edit
	options("Typeface",["Sans","Serif","Mono"],str(board.tool_settings.font),func(v): board.tool_settings.font=v; _refresh_text_preview())
	number("Font size",float(board.tool_settings.font_size),8,144,func(v): board.tool_settings.font_size=v; _refresh_text_preview(),"px")
	var row := HBoxContainer.new()
	_target().add_child(row)
	for item in [["bold","B  Bold"],["italic","I  Italic"]]:
		var key := str(item[0])
		var result := button(str(item[1]),func(): pass,false,row)
		result.toggle_mode=true
		result.button_pressed=bool(board.tool_settings[key])
		result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		result.toggled.connect(func(value): board.tool_settings[key]=value; _refresh_text_preview())
	color_field("Text color","color")
	color_field("Background","fill")
	toggle("Show border",bool(board.tool_settings.border),func(value): board.tool_settings.border=value)
	color_field("Border color","border_color")
	section("LIVE PREVIEW")
	var preview := Label.new()
	preview.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	preview.custom_minimum_size.y=68
	_target().add_child(preview)
	fields.preview=preview
	_refresh_text_preview()
	button("Apply style & text to selected",_apply_selected,true,action_area)

func _refresh_text_preview() -> void:
	if not fields.has("preview"): return
	var preview: Label=fields.preview
	preview.text=str(board.tool_settings.text) if not str(board.tool_settings.text).is_empty() else "The northern gate"
	preview.add_theme_font_override("font",board._object_font(board.tool_settings))
	preview.add_theme_font_size_override("font_size",int(board.tool_settings.font_size))
	preview.add_theme_color_override("font_color",Color(board.tool_settings.color))
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(board.tool_settings.fill)
	style.border_color=Color(board.tool_settings.border_color)
	style.set_border_width_all(1 if board.tool_settings.border else 0)
	style.set_content_margin_all(8)
	preview.add_theme_stylebox_override("normal",style)

func _measure_ui() -> void:
	note.text="Drag to measure. While holding left, right-click or press Q to add a waypoint. Your measurement is shared live."
	choices(["line","square","circle","cone","beam"],str(board.ruler_settings.shape),func(v): board.ruler_settings.shape=v; open("measure"),3)
	section("PLACEMENT")
	options("Grid snapping",["center","corner","none"],str(board.ruler_settings.snap),func(v): board.ruler_settings.snap=v)
	if board.ruler_settings.shape in ["square","circle"]:
		var origins: Array=["center","edge","corner"] if board.ruler_settings.shape == "square" else ["center","edge"]
		if not origins.has(board.ruler_settings.origin): board.ruler_settings.origin="center"
		choices(origins,str(board.ruler_settings.origin),func(v): board.ruler_settings.origin=v)
	if board.ruler_settings.shape == "cone":
		choices([["45","45°"],["60","60°"],["90","90°"]],str(board.ruler_settings.angle),func(v): board.ruler_settings.angle=int(v))
		choices([["round","Rounded end"],["flat","Flat end"]],"round" if board.ruler_settings.round else "flat",func(v): board.ruler_settings.round=v=="round",2)
	if board.ruler_settings.shape == "beam": choices([["5","5 ft"],["10","10 ft"],["15","15 ft"]],str(board.ruler_settings.beam_width),func(v): board.ruler_settings.beam_width=int(v))
	section("AFTER RELEASE")
	choices([["instant","Disappear"],["linger","Linger"]],"linger" if board.ruler_settings.linger else "instant",func(v): board.ruler_settings.linger=v=="linger",2)
	_target().add_child(label("Linger stays until your next click on the board.",12,Color("#9cadb5")))
	options("Distance rule",["grid","euclidean","alternating","manhattan"],str(board.ruler_settings.distance),func(v): board.ruler_settings.distance=v)
	var info:=label("Grid: diagonals cost one square. Alternating: every second diagonal costs two. Shape dimensions use the map's scale.",12,Color("#9cadb5"))
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_target().add_child(info)

func _dice_ui() -> void:
	note.text="Choose your dice. Make your moment."
	button("◇  3D dice collection · choose or preview",func():
		for child in app.get_children():
			if child is Hearth20DiceSetsWindow and not child.is_queued_for_deletion():Hearth20Design.popup_window(child);return
		var picker:=Hearth20DiceSetsWindow.new(); app.add_child(picker); picker.setup(session))
	choices([["self","Only me"],["public","Everyone"],["secret","GM only"]],dice_visibility,func(v): dice_visibility=v)
	section("CHOOSE YOUR DICE")
	choices([["4","d4"],["6","d6"],["8","d8"],["10","d10"],["12","d12"],["20","d20"],["100","d100"]],str(dice_sides),func(v): dice_sides=int(v); fields.sides.remove_meta("number_draft");fields.sides.value=dice_sides; _formula(),4)
	var basic:=HBoxContainer.new()
	basic.add_theme_constant_override("separation",10)
	_target().add_child(basic)
	for item in [["Quantity",dice_count,1,50],["Modifier",dice_bonus,-1000,1000]]:
		var box:=VBoxContainer.new()
		box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation",5)
		basic.add_child(box)
		box.add_child(label(str(item[0]),12,Hearth20Design.MUTED))
		var value:=SpinBox.new()
		value.min_value=float(item[2]); value.max_value=float(item[3]); value.value=float(item[1])
		value.custom_minimum_size.y=34
		value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var is_count: bool=item[0]=="Quantity"
		value.value_changed.connect(func(v):
			if is_count: dice_count=int(v)
			else: dice_bonus=int(v)
			_formula())
		box.add_child(value)
		Hearth20Design.track_number(value)
		if is_count:fields.quantity=value
		else:fields.bonus=value
	section("ROLL OPTIONS")
	fields.sides=number("Sides · custom die",dice_sides,2,1000,func(v): dice_sides=int(v); _formula())
	_target().add_child(label("Include your D&D Beyond modifier in the manual bonus.",12))
	fields.dice_mode=options("Roll mode",["normal","advantage","disadvantage"],dice_mode,_set_dice_mode)
	dice_mode_help=label("",12,Hearth20Design.MUTED);dice_mode_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_target().add_child(dice_mode_help)
	formula_label=label("",24,Color("#f0c674"))
	formula_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	formula_label.add_theme_font_override("font",Hearth20Design.font(true))
	action_area.add_child(formula_label)
	_formula()
	dice_roll_button=button("Roll dice",_roll,true,action_area)
	dice_roll_button.disabled=not pending_dice_request.is_empty()
	roll_result=label(dice_status_text,16,Color("#76e0ca"))
	roll_result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	action_area.add_child(roll_result)
	section("RECENT ROLLS")
	roll_history=VBoxContainer.new()
	roll_history.add_theme_constant_override("separation",8)
	_target().add_child(roll_history)
	_refresh_rolls()
	_sync_dice_mode()

func _set_dice_mode(value: String) -> void:
	dice_mode=value
	if value!="normal":dice_count=1;dice_sides=20
	_sync_dice_mode();_formula()

func _sync_dice_mode() -> void:
	var special=dice_mode!="normal"
	if fields.has("quantity"):
		fields.quantity.remove_meta("number_draft")
		fields.quantity.set_value_no_signal(2 if special else dice_count);fields.quantity.editable=not special
	if fields.has("sides"):
		fields.sides.remove_meta("number_draft")
		fields.sides.set_value_no_signal(dice_sides);fields.sides.editable=not special
	for die in die_buttons:
		die.disabled=special and int(die.get_meta("dice_sides",0))!=20
		die.set_pressed_no_signal(int(die.get_meta("dice_sides",0))==dice_sides)
	if is_instance_valid(dice_mode_help):dice_mode_help.text="Roll two d20s; keep the higher result." if dice_mode=="advantage" else "Roll two d20s; keep the lower result." if dice_mode=="disadvantage" else "Normal rolls support any quantity and die. Advantage/disadvantage use two d20s."

func _formula() -> void:
	if not is_instance_valid(formula_label): return
	formula_label.text="%dd%d" % [dice_count,dice_sides]+("%+d" % dice_bonus if dice_bonus else "")+(" + proficiency" if use_proficiency else "")
	if dice_mode!="normal":formula_label.text="2d20 · keep "+("highest" if dice_mode=="advantage" else "lowest")+("%+d"%dice_bonus if dice_bonus else "")

func _roll() -> void:
	if not pending_dice_request.is_empty():return
	var committed=Hearth20Design.commit_numbers([fields.quantity,fields.sides,fields.bonus])
	if not committed.ok:
		dice_status_text=committed.error;roll_result.text=dice_status_text;return
	if dice_mode!="normal" and (dice_count!=1 or dice_sides!=20):
		dice_status_text="Advantage/disadvantage use two d20s. Choose d20 with quantity 1, or Normal for this die.";roll_result.text=dice_status_text;return
	var actor: Dictionary=app._selected_sheet_actor()
	var expression:="%dd%d" % [dice_count,dice_sides]+("%+d" % dice_bonus if dice_bonus else "")
	var result: Dictionary=session.submit_dice(str(actor.get("id","")) if use_proficiency else "",expression,dice_visibility,use_proficiency,dice_mode)
	if not result.get("ok",false):dice_status_text=str(result.get("error","The roll could not be sent."))
	elif result.get("pending",false):
		pending_dice_request=str(result.get("request_id",""));dice_status_text="Waiting for the GM to confirm the roll…";dice_roll_button.disabled=true
	else:dice_status_text="Roll confirmed. Only the GM sees the result." if dice_visibility=="secret" else "Roll confirmed."
	roll_result.text=dice_status_text
	_refresh_rolls()

func _dice_request_finished(command: Dictionary,result: Dictionary) -> void:
	if pending_dice_request.is_empty() or command.get("action","")!="roll" or command.get("request_id","")!=pending_dice_request:return
	pending_dice_request=""
	dice_status_text=("Roll confirmed. Only the GM sees the result." if command.get("visibility","")=="secret" else "Roll confirmed.") if result.get("ok",false) else str(result.get("error","The GM could not accept this roll."))
	if current=="dice" and is_instance_valid(roll_result):roll_result.text=dice_status_text
	if current=="dice" and is_instance_valid(dice_roll_button):dice_roll_button.disabled=false

func _refresh_rolls() -> void:
	if not is_instance_valid(roll_history): return
	for child in roll_history.get_children():
		roll_history.remove_child(child)
		child.queue_free()
	var rolls: Array=session.timeline_for_local().filter(func(e): return e.get("type","")=="roll")
	rolls.reverse()
	for entry in rolls.slice(0,10):
		var card:=PanelContainer.new()
		card.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#111a28"),9,10,Color("#354157")))
		roll_history.add_child(card)
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		card.add_child(row)
		var total:=label(str(entry.total),25,Hearth20Design.GOLD)
		total.custom_minimum_size.x=42
		total.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(total)
		var text_label:=label("%s\n%s · %s" % [entry.formula,entry.sender,{"public":"Everyone","self":"Only me","secret":"GM only","gm":"Roller + GM"}.get(str(entry.visibility),"")],12)
		text_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		text_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		row.add_child(text_label)
		var reroll:=button("",func():
			var result: Dictionary=session.submit_dice("",str(entry.formula),dice_visibility,false,str(entry.get("mode","normal")))
			_report(result),false,row)
		reroll.icon=Hearth20Design.icon("undo",17)
		reroll.add_theme_constant_override("icon_max_width",17)
		reroll.theme_type_variation="QuietButton"
		reroll.tooltip_text="Reroll "+str(entry.formula)
	if rolls.is_empty(): roll_history.add_child(label("Your rolls will appear here.",13,Color("#8b9fa8")))

func _fx_ui() -> void:
	button("✦  Open effects atelier · F7",func():app.open_fx_studio())
	note.text="Cinematic 3D effects: cast from source to target, or release an instant effect at the cursor. Fire, holy and arcane energy cast light; death and smoke absorb it. Blood, liquid and crystals have distinct physical motion."
	var presets: Dictionary = session.client_snapshot.get("fx_presets",{}) if session.local_role=="player" else session.campaign.get("fx_presets",{})
	if not presets.is_empty(): options("Saved table effects",presets.keys(),"",func(v): board.fx_settings=presets[v].duplicate(true); open("fx"))
	options("Effect",Hearth20BoardTools.EFFECTS,str(board.fx_settings.effect),func(v): board.fx_settings.effect=v)
	section("LIVE PREVIEW · LOCAL ONLY")
	var effect_preview:=Hearth20FxPreview.new()
	effect_preview.board=board; effect_preview.settings=board.fx_settings
	_target().add_child(effect_preview)
	section("MATERIAL & COLOR")
	var values: Array=[]
	for name_value in Hearth20BoardTools.COLORS: values.append([name_value,name_value])
	choices(values,Hearth20BoardTools.fx_material(board.fx_settings),func(v): board.fx_settings.material=v; board.fx_settings.color=Hearth20BoardTools.COLORS[v],3)
	var picker:=ColorPickerButton.new()
	picker.color=Color(board.fx_settings.color)
	picker.custom_minimum_size.y=34
	picker.color_changed.connect(func(v): board.fx_settings.color="#"+v.to_html())
	_target().add_child(picker)
	section("CUSTOMIZE")
	number("Scale",float(board.fx_settings.size)*100,25,400,func(v): board.fx_settings.size=v/100,"%")
	number("Duration",float(board.fx_settings.duration)*1000,300,8000,func(v): board.fx_settings.duration=v/1000,"ms")
	number("Particle count",float(board.fx_settings.density),8,128,func(v): board.fx_settings.density=int(v))
	toggle("Reduce motion on this device",false,func(v): board.active_fx.reduced_motion=v)
	button("Preview here",func():
		var settings: Dictionary=board.fx_settings.duplicate(true)
		var center:=board._screen_to_world(board.size*0.5)
		board.active_fx.add_authorized_event(session.make_effect(settings,center-Vector2(2,0),center+Vector2(2,0))))
	if session.local_role=="dm":
		var name_edit:=LineEdit.new()
		name_edit.placeholder_text="Name this custom effect…"
		name_edit.max_length=48
		_target().add_child(name_edit)
		button("Save as table preset",func(): _report(session.board_action({"action":"save_fx_preset","name":name_edit.text,"settings":board.fx_settings})))

func _beacon_ui() -> void:
	note.text="Click the board to place a lasting waypoint for everyone. Beacons never reveal map artwork. Use Select to move or remove one."
	var edit:=LineEdit.new()
	edit.placeholder_text="Waypoint label"
	edit.text=str(board.tool_settings.get("text","Waypoint"))
	edit.text_changed.connect(func(v): board.tool_settings.text=v.left(96))
	_target().add_child(edit)
	color_field("Beacon color","color")
	board.active_layer="tokens"

func _mask_ui() -> void:
	note.text="Hide the full page, then carve out rooms as the party explores. The mask always takes priority over lighting."
	choices([["hide","Hide area"],["reveal","Reveal area"]],"reveal" if board.mask_reveal else "hide",func(v): board.mask_reveal=v=="reveal",2)
	choices([["rect","Rectangle"],["poly","Polygon"]],"poly" if board.mask_polygon else "rect",func(v): board.mask_polygon=v=="poly"; board.polygon_points.clear(),2)
	var help:=label("Rectangle: click and drag. Polygon: click corners, then right-click to finish.",13,Color("#9cadb5"))
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_target().add_child(help)
	section("FULL PAGE")
	button("Hide full page",func(): _report(session.board_action({"action":"mask_all","reveal":false})))
	button("Reveal full page",func(): _report(session.board_action({"action":"mask_all","reveal":true})))
	section("DM VIEW")
	number("Mask opacity",board.gm_mask_opacity*100,10,100,func(v): board.gm_mask_opacity=v/100,"%")

func _lighting_ui() -> void:
	note.text="Walls stop sight and light. Windows pass light but block movement. Place a light at a window for natural light entering a dark room."
	var scene: Dictionary=board.current_scene()
	toggle("Dynamic lighting",bool(scene.get("dynamic_lighting",false)),func(v): _report(session.set_scene_lighting(v,str(board.current_scene().get("ambient_light","bright")))))
	options("Ambient light",["bright","dim","dark"],str(scene.get("ambient_light","bright")),func(v): _report(session.set_scene_lighting(bool(board.current_scene().get("dynamic_lighting",false)),v)))
	Hearth20LightingPanel.build(self)
	section("PLACE ON THE MAP")
	if board.tool_settings.kind not in ["wall","window","door","light"]: board.tool_settings.kind="wall"
	choices(["wall","window","door","light"],str(board.tool_settings.kind),func(v): board.tool_settings.kind=v; board.active_layer="light",2)
	board.active_layer="light"
	color_field("Editor color","color")
	number("Bright light",float(board.tool_settings.bright),0,1000,func(v): board.tool_settings.bright=v,"ft")
	number("Additional dim light",float(board.tool_settings.dim),0,1000,func(v): board.tool_settings.dim=v,"ft")
	options("Light source",Hearth20Lighting.SOURCE_TYPES,str(board.tool_settings.get("source_type","torch")),func(v):
		board.tool_settings.source_type=v
		board.tool_settings.spread_degrees=70.0 if v in ["window","sunlight","moonlight"] else 360.0
		board.tool_settings.light_color="#b5d2ed" if v in ["moonlight","crystal"] else "#ffdc9a"
		open("lighting",false))
	color_field("Light color","light_color")
	number("Direction",float(board.tool_settings.get("angle_degrees",0)),-360,360,func(v): board.tool_settings.angle_degrees=v,"°")
	number("Spread",float(board.tool_settings.get("spread_degrees",360)),1,360,func(v): board.tool_settings.spread_degrees=v,"°")
	number("God rays",float(board.tool_settings.get("ray_strength",0.55))*100,0,100,func(v): board.tool_settings.ray_strength=v/100.0,"%")
	toggle("Preview lighting & god rays",board.lighting_preview,func(v): board.lighting_preview=v; board.queue_redraw())
	toggle("Door open",bool(board.tool_settings.open),func(v): board.tool_settings.open=v)
	button("Edit selected light / barrier",func(): board.activate_tool("select"); _selection_ui_reopen())
	section("SHARED TABLE LIGHTING")
	var info=label("Everyone sees this environmental lighting. Walls shape the light; explicit map masks keep rooms private. Character senses stay on D&D Beyond.",13)
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_target().add_child(info)

func _layers_ui() -> void:
	note.text="Choose the layer you want to edit. Drawings and tokens on other layers stay protected from accidental selection."
	for item in [["tokens","Tokens","Characters and shared drawings"],["gm","DM layer","Private notes and hidden pieces"],["map","Map","Static scenery, below tokens"],["foreground","Foreground","Roofs and objects above tokens"],["light","Light","Walls, windows, doors and emitters"]]:
		var key:=str(item[0])
		var result:=button(str(item[1]),func(): board.active_layer=key; board.activate_tool("select"); open("layers"))
		result.icon=Hearth20Design.icon(key,20)
		result.add_theme_constant_override("icon_max_width",20)
		result.add_theme_constant_override("h_separation",12)
		result.alignment=HORIZONTAL_ALIGNMENT_LEFT
		result.custom_minimum_size.y=44
		if board.active_layer==key: result.add_theme_stylebox_override("normal",Hearth20Design.panel(Color("#343025"),9,10,Color("#a38958")))
		result.tooltip_text=str(item[2])
		var detail:=label(str(item[2]),12,Color("#91a6ad"))
		_target().add_child(detail)
	section("MOVE SELECTION")
	options("Destination",Hearth20BoardTools.LAYERS,board.active_layer,func(v): fields.destination=v)
	fields.destination=board.active_layer
	button("Move selected object / token",func():
		var layer:=str(fields.destination)
		var object:=board.selected_object().duplicate(true)
		if not object.is_empty():
			object.layer=layer
			_report(session.board_action({"action":"update","object":object}))
		else: _report(session.board_action({"action":"actor_layer","id":board.selected_actor_id,"layer":layer})),true)
	button("Draw on this layer",func(): open("lighting" if board.active_layer=="light" else "draw"))

func _selection_ui_reopen() -> void:
	open("select")

func _selection_ui() -> void:
	note.text="Click an object on the active layer to select it. Drag to move. Delete removes it; Ctrl+Z restores your last drawing edit."
	selected=board.selected_object().duplicate(true)
	selection_note=label("No drawing selected" if selected.is_empty() else str(selected.kind).capitalize()+" · "+str(selected.get("layer","tokens")).capitalize(),16,Color("#76e0ca"))
	_target().add_child(selection_note)
	if not selected.is_empty():
		if selected.kind=="text": button("Edit text & appearance",func():
			for key in board.tool_settings:
				if selected.has(key): board.tool_settings[key]=selected[key]
			open("text"))
		if selected.kind in ["door","light"]:
			toggle("Door open" if selected.kind=="door" else "Light enabled",bool(selected.get("open",false)) if selected.kind=="door" else bool(selected.get("enabled",true)),func(v):
				selected["open" if selected.kind=="door" else "enabled"]=v
				_report(session.board_action({"action":"update","object":selected})))
		if selected.kind=="light":
			var tint:=ColorPickerButton.new()
			tint.color=Color(str(selected.get("light_color",selected.get("color","#ffcd8e"))))
			tint.custom_minimum_size.y=32
			tint.color_changed.connect(func(v): selected.light_color=v.to_html())
			_target().add_child(label("Light color",12))
			_target().add_child(tint)
			number("Bright light",float(selected.get("bright",20)),0,1000,func(v): selected.bright=v,"ft")
			number("Additional dim",float(selected.get("dim",20)),0,1000,func(v): selected.dim=v,"ft")
			options("Light source",Hearth20Lighting.SOURCE_TYPES,str(selected.get("source_type","torch")),func(v): selected.source_type=v)
			if selected.get("source_type","")=="window":
				_target().add_child(label("Nearby window openings set the width.\nThe fallback applies to unlinked lights.",11))
				number("Fallback width",float(selected.get("portal_width",6)),0.1,100,func(v): selected.portal_width=v,"ft")
				number("Window height",float(selected.get("window_height",7)),0.1,100,func(v): selected.window_height=v,"ft")
				number("Sill above floor",float(selected.get("sill_height",3)),0.1,100,func(v): selected.sill_height=v,"ft")
			number("Direction",float(selected.get("angle_degrees",0)),-360,360,func(v): selected.angle_degrees=v,"°")
			number("Spread",float(selected.get("spread_degrees",360)),1,360,func(v): selected.spread_degrees=v,"°")
			number("God rays",float(selected.get("ray_strength",0.55))*100,0,100,func(v): selected.ray_strength=v/100.0,"%")
			button("Apply light settings",func(): _report(session.board_action({"action":"update","object":selected})),true)
		button("Delete selected drawing",func(): _report(session.board_action({"action":"delete","id":board.selected_object_id})); board.selected_object_id=""; open("select"))
	button("Undo last drawing edit",func(): _report(session.board_action({"action":"undo"})))
	if session.local_role=="dm": button("Layers & object placement",func(): open("layers"))

func _object_selected(object: Dictionary) -> void:
	selected=object.duplicate(true)
	if current=="select": open("select",false)
	elif object.get("kind","")=="text":
		for key in board.tool_settings:
			if object.has(key): board.tool_settings[key]=object[key]

func _apply_selected() -> void:
	var object:=board.selected_object().duplicate(true)
	if object.is_empty():
		app._on_status("Use Select to choose a text box first.")
		return
	for key in board.tool_settings:
		if key not in ["kind","layer"]: object[key]=board.tool_settings[key]
	_report(session.board_action({"action":"update","object":object}))

func _report(result: Dictionary) -> void:
	app._on_status(str(result.get("error","Table updated.")))

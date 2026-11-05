extends Control
class_name Hearth20Shell
## Native application chrome and searchable command palette; actions call existing UI.
var app: Node
var scene_label: Label
var scene_detail: Label
var campaign_label: Label
var session_badge: Label
var layer_button: Button
var zoom_value: Label
var map_detail: Label
var palette: Control
var palette_card: PanelContainer
var search: LineEdit
var command_rows: VBoxContainer
var command_buttons: Array[Button] = []
var commands: Array = []
var selection := 0
var update_elapsed := 0.0
var search_button: Button
var map_library_button: Button
var welcome_card: PanelContainer
var welcome_title: Label
var welcome_copy: Label
var welcome_import: Button
var welcome_open: Button

func setup(owner_app: Node, toolbar: HBoxContainer, board_panel: PanelContainer, footer: PanelContainer) -> void:
	app=owner_app
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=Hearth20Design.theme()
	for child in toolbar.get_children():
		toolbar.remove_child(child)
		if child not in [app.save_button,app.load_button,app.inspector_toggle,app.chat_shortcut_button,app.cover_map_button,app.inventory_drop_button]: child.queue_free()
	toolbar.custom_minimum_size.y=62
	toolbar.add_theme_constant_override("separation",12)
	var mark:=TextureRect.new()
	mark.texture=Hearth20Design.icon("crest",32)
	mark.modulate=Hearth20Design.GOLD
	mark.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size=Vector2(38,42)
	toolbar.add_child(mark)
	var brand:=VBoxContainer.new()
	brand.add_theme_constant_override("separation",0)
	brand.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	brand.custom_minimum_size.x=164
	toolbar.add_child(brand)
	brand.add_child(text_label("H E A R T H 2 0",16,Hearth20Design.INK))
	brand.add_child(text_label("THE ADVENTURE AT YOUR TABLE",9,Hearth20Design.GOLD))
	var divider:=VSeparator.new()
	divider.custom_minimum_size=Vector2(1,30)
	divider.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	toolbar.add_child(divider)
	var title_box:=VBoxContainer.new()
	title_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title_box.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	title_box.add_theme_constant_override("separation",2)
	toolbar.add_child(title_box)
	campaign_label=text_label("",14,Hearth20Design.INK)
	campaign_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	campaign_label.custom_minimum_size.x=90
	title_box.add_child(campaign_label)
	session_badge=text_label("",10,Hearth20Design.MUTED)
	title_box.add_child(session_badge)
	map_library_button=make_button("map","Maps",func(): app._open_map_library())
	map_library_button.tooltip_text="Browse 15 sample maps and campaign scenes"
	toolbar.add_child(map_library_button)
	for item in [app.cover_map_button,app.inventory_drop_button]:
		item.custom_minimum_size.y=36;item.size_flags_vertical=Control.SIZE_SHRINK_CENTER;toolbar.add_child(item)
	var appearance:=Hearth20Regal.ThemeMedallion.new()
	appearance.name="AppearanceMedallion"
	toolbar.add_child(appearance)
	var preferences_button=make_button("gear","⚙",func():app.open_preferences());preferences_button.tooltip_text="Settings · Display, audio and updates";preferences_button.custom_minimum_size=Vector2(40,36);toolbar.add_child(preferences_button)
	search_button=make_button("search","Find a tool   Ctrl K",toggle_palette)
	search_button.custom_minimum_size.x=160
	toolbar.add_child(search_button)
	app.chat_shortcut_button.theme_type_variation="QuietButton"
	app.chat_shortcut_button.icon=Hearth20Design.icon("chat",18)
	app.chat_shortcut_button.add_theme_constant_override("icon_max_width",18)
	app.chat_shortcut_button.custom_minimum_size.y=36
	toolbar.add_child(app.chat_shortcut_button)
	app.save_button.text="Save"
	app.save_button.icon=Hearth20Design.icon("save",17)
	app.save_button.add_theme_constant_override("icon_max_width",17)
	app.save_button.custom_minimum_size.y=36
	app.save_button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	toolbar.add_child(app.save_button)
	for item in [[app.load_button,"open","Open a saved table"],[app.inspector_toggle,"panel","Show or hide the inspector"]]:
		var button: Button=item[0]
		button.text=""
		button.icon=Hearth20Design.icon(str(item[1]),19)
		button.add_theme_constant_override("icon_max_width",19)
		button.custom_minimum_size=Vector2(36,36)
		button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		button.theme_type_variation="QuietButton"
		button.tooltip_text=str(item[2])
		toolbar.add_child(button)
	var overlay:=Control.new()
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_panel.add_child(overlay)
	_build_map_controls(overlay)
	app.board.rich_empty_state=true
	footer.add_theme_stylebox_override("panel",Hearth20Design.panel(Color(0,0,0,0),0,2,Color(0,0,0,0)))
	footer.custom_minimum_size.y=22
	app.status_label.add_theme_font_size_override("font_size",11)
	app.status_label.add_theme_color_override("font_color",Hearth20Design.MUTED)
	_build_palette()
	resized.connect(_layout_palette)
	resized.connect(_update_labels)
	_update_labels()
	Hearth20Regal.sync(app)

func text_label(value: String, pixels: int, color: Color) -> Label:
	var result:=Label.new()
	result.text=value
	result.add_theme_font_size_override("font_size",pixels)
	result.add_theme_color_override("font_color",Hearth20Regal.resolve(color))
	return result

func make_button(icon_name: String, caption: String, callback: Callable) -> Button:
	var result:=Button.new()
	result.text=caption
	result.icon=Hearth20Design.icon(icon_name,18)
	result.add_theme_constant_override("icon_max_width",18)
	result.add_theme_constant_override("h_separation",8)
	result.custom_minimum_size.y=34
	result.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	result.theme_type_variation="QuietButton"
	result.pressed.connect(callback)
	return result

func _build_map_controls(overlay: Control) -> void:
	var top:=HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left=16; top.offset_top=14; top.offset_right=-16; top.offset_bottom=58
	top.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.add_child(top)
	var scene_card:=PanelContainer.new()
	scene_card.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#141c29ed"),10,10,Color("#354257"),true))
	scene_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	top.add_child(scene_card)
	var scene_row:=HBoxContainer.new()
	scene_row.add_theme_constant_override("separation",10)
	scene_row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scene_card.add_child(scene_row)
	var map_icon:=TextureRect.new()
	map_icon.texture=Hearth20Design.icon("map",20)
	map_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	map_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_icon.custom_minimum_size=Vector2(22,24)
	map_icon.modulate=Hearth20Design.GOLD
	map_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scene_row.add_child(map_icon)
	var scene_text:=VBoxContainer.new()
	scene_text.add_theme_constant_override("separation",0)
	scene_text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scene_row.add_child(scene_text)
	scene_label=text_label("",13,Hearth20Design.INK)
	scene_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scene_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	scene_text.add_child(scene_label)
	scene_detail=text_label("",10,Hearth20Design.MUTED)
	scene_detail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scene_text.add_child(scene_detail)
	var spacer:=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	layer_button=make_button("layers","Tokens",func():
		if app.session.local_role=="dm": app.toolbox.open("layers"))
	layer_button.tooltip_text="Active editing layer"
	top.add_child(layer_button)
	var zoom_panel:=PanelContainer.new()
	zoom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	zoom_panel.offset_left=-221; zoom_panel.offset_right=-16; zoom_panel.offset_top=-56; zoom_panel.offset_bottom=-16
	zoom_panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#151d2bed"),10,4,Color("#354257"),true))
	overlay.add_child(zoom_panel)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",3)
	zoom_panel.add_child(row)
	row.add_child(make_button("minus","",func(): app.board._zoom_at(app.board.size*0.5,1.0/1.15)))
	zoom_value=text_label("100%",12,Hearth20Design.INK)
	zoom_value.custom_minimum_size.x=44
	zoom_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(zoom_value)
	row.add_child(make_button("plus","",func(): app.board._zoom_at(app.board.size*0.5,1.15)))
	row.add_child(make_button("fit","Fit",func(): app.board.fit_map()))
	map_detail=text_label("",11,Hearth20Design.MUTED)
	map_detail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	map_detail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	map_detail.offset_left=18; map_detail.offset_right=250; map_detail.offset_top=-38; map_detail.offset_bottom=-18
	overlay.add_child(map_detail)
	welcome_card=PanelContainer.new()
	welcome_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	welcome_card.offset_left=-218; welcome_card.offset_right=218; welcome_card.offset_top=-155; welcome_card.offset_bottom=155
	welcome_card.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#171f2ff5"),18,28,Color("#65573f"),true))
	overlay.add_child(welcome_card)
	var welcome:=VBoxContainer.new()
	welcome.add_theme_constant_override("separation",15)
	welcome_card.add_child(welcome)
	var crest:=TextureRect.new()
	crest.texture=Hearth20Design.icon("crest",36)
	crest.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.custom_minimum_size=Vector2(40,40)
	crest.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	crest.modulate=Hearth20Design.GOLD
	welcome.add_child(crest)
	welcome.add_child(text_label("A PLACE FOR YOUR NEXT ADVENTURE",10,Hearth20Design.GOLD))
	welcome_title=text_label("Set the scene.",30,Hearth20Design.INK)
	welcome_title.add_theme_font_override("font",Hearth20Design.font(true))
	welcome.add_child(welcome_title)
	welcome_copy=text_label("Bring your battle map, gather your party, and make the table your own.",14,Hearth20Design.MUTED)
	welcome_copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	welcome.add_child(welcome_copy)
	var actions:=HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	welcome.add_child(actions)
	welcome_import=make_button("map","Import a map",func():
		if app.session.local_role=="dm": app._open_map_dialog()
		else: app._show_sidebar_page(app.session_page))
	Hearth20Design.primary(welcome_import)
	welcome_import.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions.add_child(welcome_import)
	welcome_open=make_button("open","Open last table",func(): app._load_campaign())
	welcome_open.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions.add_child(welcome_open)

func _process(delta: float) -> void:
	update_elapsed+=delta
	if update_elapsed<0.15: return
	update_elapsed=0
	_update_labels()

func _update_labels() -> void:
	if app==null or app.board==null or app.session==null: return
	var scene: Dictionary=app.board.current_scene()
	var is_player: bool=app.session.local_role=="player"
	map_library_button.visible=not is_player
	campaign_label.text="Your adventure" if is_player else str(app.campaign.get("title","New table"))
	var connected: bool=not (app.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	session_badge.text=("PLAYER" if is_player else "GAME MASTER")+"  /  "+("CONNECTED" if connected else "LOCAL TABLE")
	session_badge.add_theme_color_override("font_color",Hearth20Design.TEAL if connected else Hearth20Design.MUTED)
	scene_label.text=str(scene.get("title","Awaiting a scene")).left(30)
	scene_detail.text="%s ft per square   ·   %s × %s" % [str(scene.get("feet_per_cell",5)).trim_suffix(".0"),str(scene.get("width_cells",24)),str(scene.get("height_cells",16))]
	layer_button.text={"tokens":"Tokens","gm":"DM layer","map":"Map","foreground":"Foreground","light":"Light"}.get(app.board.active_layer,"Tokens")
	zoom_value.text="%d%%" % roundi(app.board.camera_zoom*100)
	map_detail.text="%d tokens  ·  %s" % [app.board.current_actors().size(),"Snap on" if scene.get("snap_to_grid",true) else "Free placement"]
	app.inspector_toggle.text=""
	app.inspector_toggle.button_pressed=app.inspector_tabs.visible
	app.chat_shortcut_button.text="Chat"+(" · %d"%app.unread_chat_count if app.unread_chat_count>0 else "")
	search_button.text="Find a tool   Ctrl K" if size.x>=1150 else "Ctrl K"
	search_button.custom_minimum_size.x=160 if size.x>=1150 else 74
	app.toolbox.refresh_density(size.y<720)
	var waiting: bool=is_player and (scene.is_empty() or scene.get("id","")=="disconnected")
	var empty: bool=not is_player and str(scene.get("map_asset","")).is_empty() and app.board.current_actors().is_empty()
	for collection in ["annotations","walls","doors","props","fog_rects"]:
		if not scene.get(collection,[]).is_empty(): empty=false
	welcome_card.visible=waiting or empty
	welcome_title.text="Your seat is ready." if waiting else "Set the scene."
	welcome_copy.text="Connect to your GM's table to receive your character and the scene." if waiting else "Bring your battle map, gather your party, and make the table your own."
	welcome_import.text="Connect to a table" if waiting else "Import a map"
	welcome_open.visible=not is_player
	var board_width: float=app.board.size.x
	welcome_card.offset_left=-minf(218,board_width*0.5-24)
	welcome_card.offset_right=minf(218,board_width*0.5-24)
	if palette.visible and is_player and commands.any(func(c): return bool(c.get("dm",false))): close_palette()

func _build_palette() -> void:
	palette=Control.new()
	palette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	palette.mouse_filter=Control.MOUSE_FILTER_STOP
	palette.visible=false
	palette.z_index=50
	add_child(palette)
	var dim:=ColorRect.new()
	dim.color=Color("#050811d9")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed: close_palette())
	palette.add_child(dim)
	palette_card=PanelContainer.new()
	palette_card.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#192131"),16,18,Color("#716044"),true))
	palette.add_child(palette_card)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	palette_card.add_child(column)
	column.add_child(text_label("JUMP TO A TOOL OR WORKSPACE",10,Hearth20Design.GOLD))
	search=LineEdit.new()
	search.placeholder_text="Search tools, dice, lighting…"
	search.custom_minimum_size.y=44
	search.text_changed.connect(_filter_commands)
	search.text_submitted.connect(func(_value): _run_command(selection))
	search.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed:
			if event.keycode==KEY_ESCAPE: close_palette(); search.accept_event()
			elif event.keycode in [KEY_DOWN,KEY_UP]:
				selection=clampi(selection+(1 if event.keycode==KEY_DOWN else -1),0,maxi(0,command_buttons.size()-1))
				_update_command_focus(); search.accept_event())
	column.add_child(search)
	command_rows=VBoxContainer.new()
	command_rows.add_theme_constant_override("separation",4)
	column.add_child(command_rows)
	column.add_child(text_label("↑ ↓ to navigate     Enter to open     Esc to close",11,Hearth20Design.MUTED))

func toggle_palette() -> void:
	if palette.visible: close_palette(); return
	commands=[]
	if Hearth20MultiplayerLab.enabled() and app.session.local_role=="dm":commands.append({"label":"Multiplayer Lab · DM + 2 Players","icon":"tokens","key":"F8","dm":true,"run":func():app.multiplayer_lab.open_panel()})
	for item in [["select","Select objects","V"],["tokens","Tokens · add, edit & grant control","K"],["draw","Drawing tools","D"],["text","Text & labels","T"],["measure","Measure & templates","M"],["dice","Dice roller","R"],["fx","Visual effects","X"],["casino","Tavern casino · Games",""],["beacon","Party beacon","B"],["mask","Hide / reveal map","H"],["lighting","Light & vision","L"],["layers","Map layers",""]]:
		var dm_only: bool=item[0] in ["tokens","casino","beacon","mask","lighting","layers"]
		if dm_only and app.session.local_role!="dm": continue
		var tool: String=item[0]
		commands.append({"label":item[1],"icon":tool,"key":item[2],"dm":dm_only,"run":func(): app.toolbox.open(tool)})
	for item in [["sheet","Character sheet",app.sheet_page],["chat","Table chat",app.chat_page],["journal","Journal & handouts",app.journal_page],["connect","Connection",app.session_page]]:
		var page: Control=item[2]
		commands.append({"label":item[1],"icon":item[0],"key":"","dm":false,"run":func(): app._show_sidebar_page(page)})
	search.text=""
	_filter_commands("")
	palette.show()
	_layout_palette()
	search.grab_focus()

func close_palette() -> void:
	palette.hide()
	app.board.grab_focus()

func _layout_palette() -> void:
	if palette_card==null: return
	var width:=minf(540,size.x-48)
	palette_card.position=Vector2((size.x-width)*0.5,maxf(40,size.y*0.12))
	palette_card.size=Vector2(width,0)

func _filter_commands(query: String) -> void:
	for child in command_rows.get_children():
		command_rows.remove_child(child); child.queue_free()
	command_buttons.clear()
	var filtered:=commands.filter(func(c): return query.strip_edges().to_lower() in str(c.label).to_lower()).slice(0,7)
	for command in filtered:
		var index:=command_buttons.size()
		var button:=make_button(str(command.icon),str(command.label),func(): _run_command(index))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y=39
		button.set_meta("command",command)
		command_rows.add_child(button)
		command_buttons.append(button)
	if filtered.is_empty(): command_rows.add_child(text_label("No matching tool. Try “dice” or “lighting”.",13,Hearth20Design.MUTED))
	selection=0
	_update_command_focus()
	_layout_palette()

func _update_command_focus() -> void:
	for i in command_buttons.size():
		command_buttons[i].add_theme_stylebox_override("normal",Hearth20Design.panel(Color("#333126") if i==selection else Color(0,0,0,0),8,9,Color("#786746") if i==selection else Color(0,0,0,0)))

func _run_command(index: int) -> void:
	if index<0 or index>=command_buttons.size(): return
	var command: Dictionary=command_buttons[index].get_meta("command")
	close_palette()
	command.run.call()

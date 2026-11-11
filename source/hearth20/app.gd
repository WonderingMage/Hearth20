extends Control
class_name Hearth20App
## Hearth20-only dispatch and workbench UI. project.godot remains inert until reviewed.

const SESSION_SCRIPT := preload("res://hearth20/session.gd")
const BOARD_SCRIPT := preload("res://hearth20/board_canvas.gd")
const LITE_BRIDGE_SCRIPT := preload("res://hearth20/lite_rules_bridge.gd")
const LITE_ADAPTER_SCRIPT := preload("res://hearth20/lite_world_adapter.gd")

var seated_shell: Node
var campaign: Dictionary
var session: Node
var board: Control
var lite_bridge: RefCounted
var lite_adapter: RefCounted
var status_label: Label
var selected_label: Label
var player_picker: OptionButton
var movement_mode: OptionButton
var movement_distance: SpinBox
var recipe_prompt: TextEdit
var recipe_json: TextEdit
var recipe_unresolved: Label
var log_view: RichTextLabel
var host_port: SpinBox
var join_address: LineEdit
var join_secret: LineEdit
var player_name: LineEdit
var map_dialog: FileDialog
var token_dialog: FileDialog
var recipe_current: Dictionary = {}
var remote_players: Dictionary = {}
var empty_state_label: Label
var mode_select: Button
var mode_fog: Button
var mode_doors: Button
var token_name_edit: LineEdit
var token_size_edit: SpinBox
var token_preview: TextureRect
var token_visibility_button: Button
var grid_cells_edit: SpinBox
var grid_anchor_edit: OptionButton
var grid_scale_edit: SpinBox
var zoom_label: Label
var token_x_edit: SpinBox
var token_y_edit: SpinBox
var restore_scene_button: Button
var recipe_acknowledge: CheckButton
var scene_recovery: Dictionary = {}
var save_button: Button
var load_button: Button
var host_button: Button
var dm_rail: VBoxContainer
var scene_page: ScrollContainer
var token_page: ScrollContainer
var session_page: ScrollContainer
var author_page: ScrollContainer
var network_controls: VBoxContainer
var player_session_note: Label
var leave_session_button: Button
var inspector_tabs: TabContainer
var inspector_toggle: Button
var mode_rocket: Button
var map_import_button: Button
var grid_snap_button: Button
var grid_display_button: Button
var grid_state_label: Label
var sheet_page: ScrollContainer
var chat_page: ScrollContainer
var journal_page: ScrollContainer
var help_page: ScrollContainer
var sheet_summary: Label
var sheet_actions: VBoxContainer
var chat_feed: RichTextLabel
var chat_composer: LineEdit
var chat_visibility: OptionButton
var roll_advantage: OptionButton
var sidebar_toggle: Button
var chat_privacy: OptionButton
var sheet_actor_picker: OptionButton
var selected_sheet_actor_id := ""
var join_character_window: Hearth20JoinPawnWindow
var current_save_path=""
var campaign_progress: Hearth20CampaignProgress
var beyond_sheet: Hearth20BeyondSheet
var cover_map_button: Button
var inventory_drop_button: Button
var casino_portal: Hearth20CasinoPortal
var dm_sheet_editor: VBoxContainer
var dm_sheet_fields: Dictionary = {}
var dm_save_profs: Array[CheckBox] = []
var dm_skill_profs: Dictionary = {}
var workspace_tabs: TabContainer
var chat_shortcut_button: Button
var unread_chat_count := 0
var handout_title: LineEdit
var handout_body: TextEdit
var handout_public: CheckButton
var handout_list: OptionButton
var handout_save_button: Button
var dm_notes_editor: TextEdit
var dm_notes_save_button: Button
var blackout_toggle: CheckButton
var dynamic_lighting_toggle: CheckButton
var ambient_picker: OptionButton
var darkvision_field: SpinBox
var bright_light_field: SpinBox
var dim_light_field: SpinBox
var vision_enabled_toggle: CheckButton
var measure_active := false
var last_timeline_id := ""
var sheet_render_signature := ""
var vision_render_signature := ""
var toolbox: Hearth20ToolDock
var shell: Hearth20Shell
var character_card: Hearth20CharacterCard
var inventory_window: Hearth20TokenInventoryWindow
var multiplayer_lab: Hearth20MultiplayerLab
var dice_stage: Hearth20DiceStage
var connection_window: Window
var connection_signature=""

func open_token_inventory() -> Hearth20TokenInventoryWindow:
	if session.local_role!="dm": return null
	if is_instance_valid(inventory_window) and not inventory_window.is_queued_for_deletion(): Hearth20Design.popup_window(inventory_window); return inventory_window
	inventory_window=Hearth20TokenInventoryWindow.new(); add_child(inventory_window); inventory_window.setup(self); return inventory_window

func _ready() -> void:
	Hearth20Regal.load_preference()
	var updates=get_node_or_null("/root/Updates")
	if updates!=null:updates.app=self;updates.startup_check.call_deferred()
	add_to_group("hearth20_themed")
	var project_name := str(ProjectSettings.get_setting("application/config/name", ""))
	var edition := str(ProjectSettings.get_setting("application/config/edition", ""))
	var dispatch := Hearth20Identity.validate_project_dispatch(project_name, edition)
	if not dispatch.ok:
		push_error(str(dispatch.error))
		return
	campaign = Hearth20Identity.new_campaign()
	lite_adapter = LITE_ADAPTER_SCRIPT.new(campaign)
	lite_bridge = LITE_BRIDGE_SCRIPT.new()
	var rules_result: Dictionary = lite_bridge.attach(lite_adapter)
	if not rules_result.ok:
		push_error("Hearth20 could not attach Lite rules module: " + str(rules_result.get("error", "unknown error")))
		return
	session = SESSION_SCRIPT.new()
	session.name = "Hearth20Session"
	add_child(session)
	session.configure(campaign)
	var steam=get_node_or_null("/root/SteamLink")
	if steam!=null:
		steam.attach(session);steam.invite_received.connect(_on_steam_invite);steam.changed.connect(_steam_connection_changed)
	session.status_changed.connect(_on_status)
	session.snapshot_received.connect(_on_snapshot)
	session.state_changed.connect(_on_host_state)
	_build_ui()
	dice_stage=Hearth20DiceStage.new(); dice_stage.z_index=100; add_child(dice_stage); dice_stage.setup(session)
	casino_portal=Hearth20CasinoPortal.new();add_child(casino_portal);casino_portal.setup(self)
	multiplayer_lab=Hearth20MultiplayerLab.new();add_child(multiplayer_lab);multiplayer_lab.setup(self)
	board.set_campaign(campaign, session, "dm")
	_update_grid_state()
	_update_session_ui()
	call_deferred("_select_initial_scene_tab")
	_on_status("Hearth20 %s · Ready. Import a map or open a saved table." % Hearth20Identity.VERSION)

func _select_initial_scene_tab() -> void:
	if session != null and session.local_role != "player" and inspector_tabs != null:
		_show_sidebar_page(workspace_tabs)
		workspace_tabs.current_tab = workspace_tabs.get_tab_idx_from_control(scene_page)

func _process(_delta: float) -> void:
	if not scene_recovery.is_empty() and int(campaign.get("revision", -1)) != int(scene_recovery.get("revision", -2)):
		scene_recovery.clear()
		if restore_scene_button and is_instance_valid(restore_scene_button):
			restore_scene_button.disabled = true

func _build_ui() -> void:
	theme=Hearth20Design.theme()
	var background := ColorRect.new()
	background.color = Hearth20Design.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.offset_left=12
	root.offset_top=4
	root.offset_right=-12
	root.offset_bottom=-6
	root.theme = _build_theme()
	add_child(root)
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size.y = 54
	toolbar.add_theme_constant_override("separation", 10)
	root.add_child(toolbar)
	var brand := Label.new()
	brand.text = "HEARTH20  /  TABLE"
	brand.custom_minimum_size.x = 190
	brand.add_theme_font_size_override("font_size", 20)
	brand.add_theme_color_override("font_color", Color("#f0e6d3"))
	toolbar.add_child(brand)
	save_button = _add_button(toolbar, "Save table", _save_campaign)
	load_button = _add_button(toolbar, "Open table", _load_campaign)
	_accent_button(save_button)
	inspector_toggle = _add_button(toolbar, "Hide panel", _toggle_inspector)
	_add_button(toolbar, "Sheet  S", func(): _show_sidebar_page(sheet_page))
	chat_shortcut_button = _add_button(toolbar, "Chat  C", func(): _show_sidebar_page(chat_page))
	_add_button(toolbar, "Ruler  M", _toggle_measure)
	cover_map_button=Button.new();cover_map_button.text="◇ Cover map";cover_map_button.toggle_mode=true;cover_map_button.tooltip_text="Cover the entire map for players. Click again to reveal it.";cover_map_button.toggled.connect(func(value):
		var result=session.set_blackout(value)
		if not result.ok:_on_status(str(result.get("error","Map cover could not be changed."))))
	toolbar.add_child(cover_map_button)
	inventory_drop_button=Button.new();inventory_drop_button.text="✧ Token vault";inventory_drop_button.tooltip_text="Open token inventory · drag a map token here to stow it";inventory_drop_button.pressed.connect(open_token_inventory);toolbar.add_child(inventory_drop_button)
	inventory_drop_button.set_drag_forwarding(Callable(),func(_p,data):return Hearth20TokenDrag.accepts(session,data),func(_p,data):
		var result=session.store_inventory_token(str(data.actor_id));_on_status("Token stowed in the campaign vault." if result.ok else str(result.get("error","Unable to stow token.")));board.dragging_actor=false;board.queue_redraw())
	status_label = Label.new()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	dm_rail = VBoxContainer.new()
	dm_rail.custom_minimum_size.x = 66
	dm_rail.add_theme_constant_override("separation", 6)
	var rail_frame:=PanelContainer.new()
	rail_frame.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#121925"),12,5,Hearth20Design.BORDER,true))
	rail_frame.add_child(dm_rail)
	body.add_child(rail_frame)
	mode_select = _add_button(dm_rail, "↖\nSelect", _select_mode)
	mode_select.toggle_mode = true
	mode_select.button_pressed = true
	mode_fog = _add_button(dm_rail, "▧\nFog", _toggle_fog)
	mode_fog.toggle_mode = true
	mode_doors = _add_button(dm_rail, "▤\nDoors", _toggle_door)
	mode_doors.toggle_mode = true
	mode_rocket = _add_button(dm_rail, "✦\nRocket", _begin_rocket)
	mode_rocket.toggle_mode = true
	var keyboard_note := Label.new()
	keyboard_note.text = "F fit\nSpace pan\nEsc cancel"
	keyboard_note.add_theme_font_size_override("font_size", 11)
	keyboard_note.add_theme_color_override("font_color", Color("#91a09f"))
	dm_rail.add_child(keyboard_note)
	var board_panel := PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#0e1420"),14,0,Hearth20Design.BORDER,true))
	board = BOARD_SCRIPT.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.selection_changed.connect(_on_selection)
	board.hint_changed.connect(_on_status)
	board_panel.add_child(board)
	body.add_child(board_panel)
	inspector_tabs = TabContainer.new()
	inspector_tabs.custom_minimum_size.x = 352
	inspector_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_tabs.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Design.SURFACE,14,14,Hearth20Design.BORDER,true))
	body.add_child(inspector_tabs)
	scene_page = ScrollContainer.new()
	scene_page.name = "Scene"
	scene_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_tabs.add_child(scene_page)
	var scene_sections := VBoxContainer.new()
	scene_sections.custom_minimum_size.x = 250
	scene_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_sections.add_theme_constant_override("separation", 10)
	scene_page.add_child(scene_sections)
	_build_scene_section(scene_sections)
	token_page = ScrollContainer.new()
	token_page.name = "Token"
	token_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_tabs.add_child(token_page)
	var token_sections := VBoxContainer.new()
	token_sections.custom_minimum_size.x = 250
	token_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	token_sections.add_theme_constant_override("separation", 10)
	token_page.add_child(token_sections)
	_build_token_section(token_sections)
	session_page = ScrollContainer.new()
	session_page.name = "Session"
	session_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_tabs.add_child(session_page)
	var session_sections := VBoxContainer.new()
	session_sections.custom_minimum_size.x = 250
	session_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	session_sections.add_theme_constant_override("separation", 10)
	session_page.add_child(session_sections)
	_build_network_section(session_sections)
	_add_button(session_sections, "Preview selected player", _preview_selected_player)
	player_session_note = Label.new()
	player_session_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_session_note.visible = false
	session_sections.add_child(player_session_note)
	leave_session_button = _add_button(session_sections, "Leave table", _leave_table)
	leave_session_button.visible = false
	author_page = ScrollContainer.new()
	author_page.name = "Recipe"
	author_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_tabs.add_child(author_page)
	var author_sections := VBoxContainer.new()
	author_sections.custom_minimum_size.x = 250
	author_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	author_sections.add_theme_constant_override("separation", 10)
	author_page.add_child(author_sections)
	_build_recipe_section(author_sections)
	# The board stays central while table actions live in one predictable sidebar.
	inspector_tabs.get_tab_bar().custom_minimum_size.y = 34
	scene_page.name = "Scene"
	token_page.name = "Token"
	session_page.name = "Connect"
	author_page.name = "Build"
	_build_player_pages()
	toolbox = Hearth20ToolDock.new()
	inspector_tabs.add_child(toolbox)
	toolbox.setup(self, dm_rail)
	inspector_tabs.set_tab_title(inspector_tabs.get_tab_idx_from_control(workspace_tabs),"Table")
	if session.has_signal("timeline_changed"):
		session.timeline_changed.connect(_on_timeline_changed)
	inspector_tabs.current_tab = 0
	_update_grid_state()
	var footer := PanelContainer.new()
	footer.custom_minimum_size.y = 26
	footer.add_theme_stylebox_override("panel", _panel_style("#20282d"))
	root.add_child(footer)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.add_theme_color_override("font_color", Color("#aeb9b8"))
	footer.add_child(status_label)
	var files := FileDialog.new()
	files.access = FileDialog.ACCESS_FILESYSTEM
	files.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	files.add_filter("*.png, *.jpg, *.jpeg", "Battle map image")
	files.file_selected.connect(_on_map_selected)
	files.title="Choose a battlemap · Cancel returns to your table"
	files.use_native_dialog=OS.get_name()=="Windows"
	files.canceled.connect(_cancel_map_dialog);files.close_requested.connect(_cancel_map_dialog)
	(seated_shell if seated_shell!=null else self).add_child(files)
	map_dialog = files
	var token_files := FileDialog.new()
	token_files.access = FileDialog.ACCESS_FILESYSTEM
	token_files.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	token_files.add_filter("*.png", "PNG token image")
	token_files.file_selected.connect(_on_token_selected)
	add_child(token_files)
	token_dialog = token_files
	shell=Hearth20Shell.new()
	add_child(shell)
	shell.setup(self,toolbar,board_panel,footer)

func _build_player_pages() -> void:
	sheet_page = ScrollContainer.new()
	sheet_page.name = "Sheet"
	sheet_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_tabs.add_child(sheet_page)
	var sheet := VBoxContainer.new()
	sheet.custom_minimum_size.x = 310
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_theme_constant_override("separation", 9)
	sheet_page.add_child(sheet)
	beyond_sheet=Hearth20BeyondSheet.new();sheet.add_child(beyond_sheet);beyond_sheet.setup(self)
	chat_page = ScrollContainer.new()
	chat_page.name = "Chat"
	chat_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_tabs.add_child(chat_page)
	var chat_column := VBoxContainer.new()
	chat_column.custom_minimum_size.x = 310
	chat_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_page.add_child(chat_column)
	_add_header(chat_column, "TABLE CHAT & ROLLS")
	chat_feed = RichTextLabel.new()
	chat_feed.bbcode_enabled = false
	chat_feed.custom_minimum_size.y = 330
	chat_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_feed.scroll_following = true
	chat_feed.selection_enabled = true
	chat_column.add_child(chat_feed)
	var chat_row := HBoxContainer.new()
	chat_privacy = OptionButton.new()
	chat_privacy.add_item("Table")
	chat_privacy.add_item("Only me + DM")
	chat_row.add_child(chat_privacy)
	chat_composer = LineEdit.new()
	chat_composer.placeholder_text = "Message the table…"
	chat_composer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_composer.text_submitted.connect(_send_chat)
	chat_row.add_child(chat_composer)
	var send_button := _add_button(chat_row, "Send", func(): _send_chat(chat_composer.text))
	send_button.custom_minimum_size.x = 66
	chat_column.add_child(chat_row)
	journal_page = ScrollContainer.new()
	journal_page.name = "Journal"
	inspector_tabs.add_child(journal_page)
	var journal := VBoxContainer.new()
	journal.custom_minimum_size.x = 310
	journal_page.add_child(journal)
	_add_header(journal, "TABLE JOURNAL")
	var journal_note := Label.new()
	journal_note.text = "Campaign notes and scene journals will appear here. DM notes stay in the host campaign; player journals will be shared deliberately by the DM."
	journal_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal.add_child(journal_note)
	dm_notes_editor = TextEdit.new()
	dm_notes_editor.placeholder_text = "Private DM session notes…"
	dm_notes_editor.custom_minimum_size.y = 150
	dm_notes_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dm_notes_editor.text = str(campaign.get("dm_notes", ""))
	journal.add_child(dm_notes_editor)
	dm_notes_save_button = _add_button(journal, "Save DM notes", func():
		if session.local_role == "dm":
			campaign.dm_notes = dm_notes_editor.text.left(100000)
			_on_status("DM notes saved with this campaign.")
		else:
			_on_status("Player journals are not shared yet.")
	)
	_add_header(journal, "SHARED HANDOUTS")
	handout_list = OptionButton.new()
	handout_list.item_selected.connect(_select_handout)
	journal.add_child(handout_list)
	handout_title = LineEdit.new()
	handout_title.placeholder_text = "Handout title"
	journal.add_child(handout_title)
	handout_body = TextEdit.new()
	handout_body.placeholder_text = "Notes to share with players…"
	handout_body.custom_minimum_size.y = 140
	journal.add_child(handout_body)
	handout_public = CheckButton.new()
	handout_public.text = "Visible to players"
	handout_public.button_pressed = true
	journal.add_child(handout_public)
	_add_button(journal, "New handout", _new_handout)
	handout_save_button = _add_button(journal, "Save handout", _save_handout)
	_refresh_handouts()
	help_page = ScrollContainer.new()
	help_page.name = "Help"
	inspector_tabs.add_child(help_page)
	var help := VBoxContainer.new()
	help.custom_minimum_size.x = 310
	help_page.add_child(help)
	_add_header(help, "QUICK CONTROLS")
	var help_text := Label.new()
	help_text.text = "Use Sheet for D&D Beyond. Use Dice for a manual dice expression and modifier; choose the roll audience there. S opens Sheet, C opens Chat, J opens Journal, M toggles the ruler, 1–4 pick map tools, F fits the map, Shift-click pings, Space + drag pans, and Esc cancels the current action."
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_child(help_text)
	_add_header(help, "VISION")
	var vision_note := Label.new()
	vision_note.text = "Everyone shares the DM’s environmental lighting. Character senses stay on D&D Beyond. The DM can cover the map or mask specific areas to keep them private."
	vision_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_child(vision_note)
	workspace_tabs = TabContainer.new()
	workspace_tabs.name = "Workspace"
	for page in [scene_page, token_page, session_page, author_page, help_page]:
		inspector_tabs.remove_child(page)
		workspace_tabs.add_child(page)
	inspector_tabs.add_child(workspace_tabs)
	workspace_tabs.current_tab = workspace_tabs.get_tab_idx_from_control(scene_page)
	inspector_tabs.current_tab = inspector_tabs.get_tab_idx_from_control(sheet_page)
	_refresh_sheet()
	_refresh_chat()

func _refresh_sheet() -> void:
	pass

func _display_number(value: Variant) -> String:
	if value is float and is_finite(value) and is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return str(value)

func _add_sheet_detail(parent: VBoxContainer, title: String, value: Variant) -> void:
	var detail_body := Label.new()
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.visible = false
	if value is String:
		detail_body.text = value
	else:
		detail_body.text = JSON.stringify(value, "  ")
	var toggle: Button = _add_button(parent, title + "  ▸", func():
		detail_body.visible = not detail_body.visible
	)
	toggle.pressed.connect(func():
		toggle.text = title + ("  ▾" if detail_body.visible else "  ▸")
	)
	parent.add_child(detail_body)

func _selected_sheet_actor() -> Dictionary:
	if session.local_role == "dm":
		return Hearth20Contracts.find_actor(campaign, board.selected_actor_id) if board != null and not board.selected_actor_id.is_empty() else {}
	if not session.client_snapshot is Dictionary:
		return {}
	for actor in session.client_snapshot.get("sheets", []):
		if actor is Dictionary and str(actor.get("id", "")) == selected_sheet_actor_id:
			return actor
	return {}

func _refresh_sheet_choices() -> void:
	if sheet_actor_picker == null:
		return
	sheet_actor_picker.visible = session.local_role == "player"
	if session.local_role == "dm":
		return
	var sheets: Array = session.client_snapshot.get("sheets", []) if session.client_snapshot is Dictionary else []
	var current_id := selected_sheet_actor_id if not selected_sheet_actor_id.is_empty() else str(session.client_snapshot.get("view_actor_id",""))
	sheet_actor_picker.clear()
	var matched := false
	for actor in sheets:
		if actor is Dictionary:
			sheet_actor_picker.add_item(str(actor.get("name", "Hero")))
			sheet_actor_picker.set_item_metadata(sheet_actor_picker.item_count - 1, str(actor.get("id", "")))
			if str(actor.get("id", "")) == current_id:
				sheet_actor_picker.select(sheet_actor_picker.item_count - 1)
				selected_sheet_actor_id = current_id
				matched = true
	if sheet_actor_picker.item_count > 0 and not matched:
		sheet_actor_picker.select(0)
		selected_sheet_actor_id = str(sheet_actor_picker.get_item_metadata(0))

func _select_sheet_actor(index: int) -> void:
	if index >= 0 and index < sheet_actor_picker.item_count:
		selected_sheet_actor_id = str(sheet_actor_picker.get_item_metadata(index))
		if session.local_role=="player":session.set_view_actor(selected_sheet_actor_id)
		_refresh_sheet()

func _refresh_dm_sheet_editor(actor: Dictionary) -> void:
	if dm_sheet_editor == null:
		return
	dm_sheet_editor.visible = session.local_role == "dm"
	for child in dm_sheet_editor.get_children():
		child.queue_free()
	dm_sheet_fields.clear()
	dm_save_profs.clear()
	dm_skill_profs.clear()
	if session.local_role != "dm":
		return
	_add_header(dm_sheet_editor, "DM · EDIT CHARACTER BASICS")
	var abilities: Variant = actor.get("abilities", {})
	var keys := ["str", "dex", "con", "int", "wis", "cha"]
	var ability_row := GridContainer.new()
	ability_row.columns = 3
	for index in range(keys.size()):
		var key: String = keys[index]
		var field := SpinBox.new()
		field.min_value = 1
		field.max_value = 30
		field.step = 1
		field.prefix = key.to_upper() + " "
		field.custom_minimum_size.x = 94
		field.value = float(abilities.get(key, 10)) if abilities is Dictionary else float(abilities[index]) if abilities is Array and abilities.size() > index else 10.0
		dm_sheet_fields[key] = field
		ability_row.add_child(field)
	dm_sheet_editor.add_child(ability_row)
	var stats_row := GridContainer.new()
	stats_row.columns = 2
	for field_spec in [["hp", "HP", 0, 9999], ["max_hp", "Max", 1, 9999], ["temp", "Temp", 0, 9999], ["ac", "AC", 0, 100], ["speed", "Speed", 0, 1000], ["level", "Level", 1, 20], ["prof_bonus", "Prof", 0, 20]]:
		var field := SpinBox.new()
		field.min_value = float(field_spec[2])
		field.max_value = float(field_spec[3])
		field.step = 1
		field.prefix = str(field_spec[1]) + " "
		field.custom_minimum_size.x = 145
		field.value = float(actor.get(str(field_spec[0]), 0 if field_spec[0] in ["hp", "temp"] else 10 if field_spec[0] == "ac" else 30 if field_spec[0] == "speed" else 1))
		dm_sheet_fields[str(field_spec[0])] = field
		stats_row.add_child(field)
	dm_sheet_editor.add_child(stats_row)
	_add_header(dm_sheet_editor, "SAVE PROFICIENCIES")
	var saves_row := GridContainer.new()
	saves_row.columns = 3
	var save_labels := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
	var saved_indices: Array = actor.get("save_profs", [])
	for index in range(6):
		var proficiency := CheckBox.new()
		proficiency.text = save_labels[index]
		proficiency.button_pressed = saved_indices.has(index)
		proficiency.custom_minimum_size.x = 90
		dm_save_profs.append(proficiency)
		saves_row.add_child(proficiency)
	dm_sheet_editor.add_child(saves_row)
	_add_header(dm_sheet_editor, "SKILL PROFICIENCIES")
	var skill_grid := GridContainer.new()
	skill_grid.columns = 2
	var skill_names := ["Acrobatics", "Animal Handling", "Arcana", "Athletics", "Deception", "History", "Insight", "Intimidation", "Investigation", "Medicine", "Nature", "Perception", "Performance", "Persuasion", "Religion", "Sleight of Hand", "Stealth", "Survival"]
	var skill_values: Dictionary = actor.get("skills", {}) if actor.get("skills", {}) is Dictionary else {}
	for skill_name in skill_names:
		var skill_row := HBoxContainer.new()
		var skill_label := Label.new()
		skill_label.text = skill_name
		skill_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_row.add_child(skill_label)
		var proficiency := OptionButton.new()
		proficiency.add_item("None")
		proficiency.add_item("Proficient")
		proficiency.add_item("Expertise")
		proficiency.select(clampi(int(skill_values.get(skill_name, 0)), 0, 2))
		proficiency.tooltip_text = "Enable proficiency bonus for this skill."
		skill_row.add_child(proficiency)
		dm_skill_profs[skill_name] = proficiency
		skill_grid.add_child(skill_row)
	dm_sheet_editor.add_child(skill_grid)
	_add_button(dm_sheet_editor, "Save character stats", _save_sheet_changes)

func _save_sheet_changes() -> void:
	if board.selected_actor_id.is_empty():
		return
	var ability_scores: Array[int] = []
	for key in ["str", "dex", "con", "int", "wis", "cha"]:
		ability_scores.append(int(dm_sheet_fields[key].value))
	var save_proficiencies: Array[int] = []
	for index in range(dm_save_profs.size()):
		if dm_save_profs[index].button_pressed:
			save_proficiencies.append(index)
	var skill_proficiencies := {}
	for skill_name in dm_skill_profs:
		skill_proficiencies[skill_name] = dm_skill_profs[skill_name].selected
	var patch := {"abilities": ability_scores, "save_profs": save_proficiencies, "skills": skill_proficiencies}
	for key in ["hp", "max_hp", "temp", "ac", "speed", "level", "prof_bonus"]:
		patch[key] = int(dm_sheet_fields[key].value)
	var result: Dictionary = session.update_sheet(board.selected_actor_id, patch)
	if not result.get("ok", false):
		_on_status(str(result.get("error", "Hero stats could not be saved.")))
	else:
		_on_status("Hero stats saved to the host sheet.")
		_refresh_sheet()

func _submit_roll(kind: String, key: String, expression: String = "") -> void:
	var actor := _selected_sheet_actor()
	if actor.is_empty() and kind != "dice":
		_on_status("Select your assigned hero before rolling.")
		return
	var mode: String = ["normal", "advantage", "disadvantage"][roll_advantage.selected]
	var visibility: String = "public" if chat_visibility.selected == 0 else "gm"
	var result: Dictionary = session.submit_roll(str(actor.get("id", "")), kind, key, mode, visibility, expression if not expression.is_empty() else "1d20")
	if not result.get("ok", false):
		_on_status(str(result.get("error", "Roll could not be submitted.")))
	else:
		inspector_tabs.current_tab = inspector_tabs.get_tab_idx_from_control(chat_page)

func _send_chat(message: String) -> void:
	var clean := message.strip_edges()
	if clean.is_empty():
		return
	var result: Dictionary = session.send_chat(clean, "public" if chat_privacy.selected == 0 else "gm")
	if not result.get("ok", false):
		_on_status(str(result.get("error", "Message could not be sent.")))
	else:
		chat_composer.clear()

func _save_handout() -> void:
	if session.local_role != "dm":
		_on_status("Only the DM can edit handouts.")
		return
	var handout_id := ""
	if handout_list.selected >= 0:
		handout_id = str(handout_list.get_item_metadata(handout_list.selected))
	var result: Dictionary = session.share_handout(handout_title.text, handout_body.text, handout_public.button_pressed, handout_id)
	if not result.get("ok", false):
		_on_status(str(result.get("error", "Handout could not be saved.")))
	else:
		_refresh_handouts()
		for index in range(handout_list.item_count):
			if str(handout_list.get_item_metadata(index)) == str(result.get("id", handout_id)):
				handout_list.select(index)
				_select_handout(index)
				break
		_on_status("Handout saved.")

func _new_handout() -> void:
	if session.local_role != "dm":
		return
	handout_list.select(-1)
	handout_title.clear()
	handout_body.clear()
	handout_public.button_pressed = true
	handout_title.grab_focus()

func _refresh_handouts() -> void:
	if handout_list == null:
		return
	var handouts: Array = campaign.get("handouts", []) if session.local_role == "dm" else session.client_snapshot.get("handouts", [])
	var selected_id := str(handout_list.get_item_metadata(handout_list.selected)) if handout_list.selected >= 0 else ""
	handout_list.clear()
	var selection_index := -1
	for handout in handouts:
		if handout is Dictionary:
			handout_list.add_item(str(handout.get("title", "Untitled handout")))
			handout_list.set_item_metadata(handout_list.item_count - 1, str(handout.get("id", "")))
			if str(handout.get("id", "")) == selected_id:
				selection_index = handout_list.item_count - 1
	if selection_index >= 0:
		handout_list.select(selection_index)
	elif session.local_role == "player" and handout_list.item_count > 0:
		selection_index = 0
		handout_list.select(selection_index)
	if session.local_role == "player" and selection_index >= 0:
		# Public handout text can change between snapshots or role switches; reload the selected record.
		_select_handout(selection_index)
	elif session.local_role == "player":
		handout_title.clear()
		handout_body.clear()
	elif session.local_role == "dm" and not selected_id.is_empty() and selection_index < 0:
		# Keep an unsaved DM draft when a refresh does not contain its current selection.
		pass
	handout_title.editable = session.local_role == "dm"
	handout_body.editable = session.local_role == "dm"
	handout_public.visible = session.local_role == "dm"
	handout_save_button.visible = session.local_role == "dm"

func _select_handout(index: int) -> void:
	var handouts: Array = campaign.get("handouts", []) if session.local_role == "dm" else session.client_snapshot.get("handouts", [])
	if index < 0 or index >= handout_list.item_count:
		return
	var handout_id := str(handout_list.get_item_metadata(index))
	for handout in handouts:
		if handout is Dictionary and str(handout.get("id", "")) == handout_id:
			handout_title.text = str(handout.get("title", ""))
			handout_body.text = str(handout.get("body", ""))
			handout_public.button_pressed = bool(handout.get("public", session.local_role == "player"))
			return

func _vision_spin(prefix: String, initial: float) -> SpinBox:
	var field := SpinBox.new()
	field.min_value = 0
	field.max_value = 1000
	field.step = 5
	field.prefix = prefix + " "
	field.suffix = " ft"
	field.value = initial
	field.custom_minimum_size.x = 96
	return field

func _refresh_vision_controls() -> void:
	if dynamic_lighting_toggle == null or board == null:
		return
	var scene: Dictionary = board.current_scene()
	var actor := Hearth20Contracts.find_actor(campaign, board.selected_actor_id) if session.local_role == "dm" and not board.selected_actor_id.is_empty() else {}
	var vision: Dictionary = actor.get("vision", {}) if actor.get("vision", {}) is Dictionary else {}
	vision = vision.duplicate(true)
	vision.darkvision_feet = 0.0
	var signature := "%s|%s|%s|%s" % [session.local_role, board.selected_actor_id if session.local_role == "dm" else "", JSON.stringify(vision), JSON.stringify({"dynamic_lighting": scene.get("dynamic_lighting", false), "ambient_light": scene.get("ambient_light", "bright"), "blackout": scene.get("blackout", false)})]
	if signature == vision_render_signature:
		return
	vision_render_signature = signature
	dynamic_lighting_toggle.set_pressed_no_signal(bool(scene.get("dynamic_lighting", false)))
	var ambient_names := ["bright", "dim", "dark"]
	var ambient_index := ambient_names.find(str(scene.get("ambient_light", "bright")))
	ambient_picker.select(maxi(0, ambient_index))
	blackout_toggle.set_pressed_no_signal(bool(scene.get("blackout", false)))
	cover_map_button.visible=session.local_role=="dm"
	inventory_drop_button.visible=session.local_role=="dm"
	cover_map_button.set_pressed_no_signal(bool(scene.get("blackout",false)))
	cover_map_button.text="◆ Reveal map" if scene.get("blackout",false) else "◇ Cover map"
	vision_enabled_toggle.set_pressed_no_signal(bool(vision.get("enabled", true)))
	darkvision_field.set_value_no_signal(float(vision.get("darkvision_feet", 60.0)))
	bright_light_field.set_value_no_signal(float(vision.get("bright_light_feet", 0.0)))
	dim_light_field.set_value_no_signal(float(vision.get("dim_light_feet", 0.0)))
	var dm_controls: bool = session.local_role == "dm"
	for control in [dynamic_lighting_toggle, ambient_picker, blackout_toggle, vision_enabled_toggle]:
		control.disabled = not dm_controls
	for field in [darkvision_field, bright_light_field, dim_light_field]:
		field.editable = dm_controls

func _toggle_measure() -> void:
	if toolbox != null:
		toolbox.open("measure")
		return
	measure_active = not bool(board.measure_tool)
	board.set_measure_tool(measure_active)
	_on_status("Ruler active. Drag between two points to measure." if measure_active else "Ruler closed.")

func _preview_selected_player() -> void:
	if session.local_role != "dm" or player_picker.selected < 0 or player_picker.selected >= player_picker.item_count:
		_on_status("Assign a hero to a connected player first.")
		return
	var player_id := str(player_picker.get_item_metadata(player_picker.selected))
	if not session.remote_players.has(player_id):
		_on_status("Assign a hero to a connected player first.")
		return
	var has_assigned_hero := false
	for actor in campaign.get("actors", []):
		if actor is Dictionary and bool(actor.get("is_hero", false)) and str(actor.get("owner_player_id", "")) == player_id:
			has_assigned_hero = true
			break
	if not has_assigned_hero:
		_on_status("Assign a hero to this player before previewing their view.")
		return
	var projected: Dictionary = session._project_for(player_id)
	if projected.is_empty():
		_on_status("This player has no projected board view yet.")
		return
	var nickname := str(session.remote_players[player_id].get("nickname", "Player"))
	var preview_window := Window.new()
	preview_window.title = "%s · PLAYER VIEW · READ ONLY" % nickname
	preview_window.size = Vector2i(1120, 760)
	preview_window.unresizable = false
	preview_window.close_requested.connect(func(): preview_window.queue_free())
	var preview_panel := PanelContainer.new()
	preview_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_panel.add_theme_stylebox_override("panel", _panel_style("#111519"))
	var preview_board: Control = BOARD_SCRIPT.new()
	preview_board.read_only_preview = true
	preview_panel.add_child(preview_board)
	preview_window.add_child(preview_panel)
	add_child(preview_window)
	preview_board.set_campaign(campaign, session, "player")
	preview_board.set_player_snapshot(projected)
	preview_window.popup_centered()

func _on_timeline_changed(entries: Array) -> void:
	_track_unread(entries)
	_refresh_chat()

func _track_unread(entries: Array) -> void:
	if entries.is_empty():
		last_timeline_id = ""
		return
	var newest: String = str(entries.back().get("id", "")) if entries.back() is Dictionary else ""
	if newest == last_timeline_id:
		return
	if not last_timeline_id.is_empty():
		var previous_index := -1
		for index in range(entries.size()):
			if entries[index] is Dictionary and str(entries[index].get("id", "")) == last_timeline_id:
				previous_index = index
				break
		var arrived := entries.size() - previous_index - 1 if previous_index >= 0 else 1
		if inspector_tabs.current_tab != inspector_tabs.get_tab_idx_from_control(chat_page):
			unread_chat_count += maxi(1, arrived)
	last_timeline_id = newest

func _refresh_chat() -> void:
	if chat_feed == null or session == null or not session.has_method("timeline_for_local"):
		return
	chat_feed.clear()
	var entries: Array = session.timeline_for_local()
	for entry in entries:
		if not entry is Dictionary:
			continue
		var raw_stamp := str(entry.get("time", ""))
		var stamp := raw_stamp.substr(11, 8) if raw_stamp.length() >= 19 else raw_stamp
		var sender := str(entry.get("sender", "Table"))
		var visibility_mark: String = {"gm":" · Roller + GM", "self":" · Only me", "secret":" · GM only"}.get(str(entry.get("visibility", "public")), "")
		chat_feed.push_color(Color("#91a0aa"))
		chat_feed.push_font_size(12)
		chat_feed.add_text("%s  " % stamp)
		chat_feed.pop()
		chat_feed.push_color(Color("#e5e9eb"))
		chat_feed.push_font_size(14)
		chat_feed.add_text("%s%s\n" % [sender, visibility_mark])
		chat_feed.pop()
		chat_feed.pop()
		if str(entry.get("type", "")) == "chat":
			chat_feed.push_color(Color("#d3d9dd"))
			chat_feed.push_font_size(14)
			chat_feed.add_text("  %s\n\n" % str(entry.get("text", "")))
			chat_feed.pop()
			chat_feed.pop()
		else:
			var actor_name := str(entry.get("actor_name", ""))
			var label := str(entry.get("label", "Roll"))
			var formula := str(entry.get("formula", "1d20"))
			var dice: Array = entry.get("dice", [])
			var dice_text := " [%s]" % ", ".join(dice.map(func(value): return str(value))) if not dice.is_empty() else ""
			var mode := " · %s" % str(entry.get("mode", "")) if str(entry.get("mode", "normal")) != "normal" else ""
			chat_feed.push_color(Color("#aab5bc"))
			chat_feed.push_font_size(12)
			chat_feed.add_text("  %s · %s: %s%s%s\n" % [actor_name, label, formula, dice_text, mode])
			chat_feed.pop()
			chat_feed.push_color(Color("#f0c674"))
			chat_feed.push_font_size(22)
			chat_feed.add_text("  %s\n\n" % str(entry.get("total", "—")))
			chat_feed.pop()
			chat_feed.pop()
	last_timeline_id = str(entries.back().get("id", "")) if not entries.is_empty() and entries.back() is Dictionary else ""
	if chat_shortcut_button != null and unread_chat_count > 0:
		chat_shortcut_button.text = "Chat  C · %d" % unread_chat_count

func _panel_style(fill: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _build_theme() -> Theme:
	return Hearth20Design.theme()

func _control_style(fill: String, border: String, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(border)
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _accent_button(button: Button) -> void:
	Hearth20Design.primary(button)

func _toggle_inspector() -> void:
	inspector_tabs.visible = not inspector_tabs.visible
	inspector_toggle.text = "Hide panel" if inspector_tabs.visible else "Show panel"

func _show_sidebar_page(page: Control) -> void:
	if not inspector_tabs.visible:
		inspector_tabs.visible = true
		inspector_toggle.text = "Hide panel"
	if page.get_parent() == workspace_tabs:
		inspector_tabs.current_tab = inspector_tabs.get_tab_idx_from_control(workspace_tabs)
		workspace_tabs.current_tab = workspace_tabs.get_tab_idx_from_control(page)
	else:
		inspector_tabs.current_tab = inspector_tabs.get_tab_idx_from_control(page)
	if page == chat_page:
		unread_chat_count = 0
		chat_shortcut_button.text = "Chat  C"

func _set_dynamic_lighting(enabled: bool) -> void:
	if session.local_role != "dm":
		_on_status("Only the DM can change scene lighting.")
		return
	var ambient: String = ["bright", "dim", "dark"][ambient_picker.selected] if ambient_picker != null else "dark"
	var result: Dictionary = session.set_scene_lighting(enabled, ambient)
	if not result.get("ok", false):
		_on_status(str(result.get("error", "Lighting could not be updated.")))

func _unhandled_key_input(event: InputEvent) -> void:
	if casino_portal!=null and casino_portal.phase!="closed":
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			var table=casino_portal.scene
			if is_instance_valid(table) and table.book.opened and not table.book.busy:table.book.close_book()
			elif is_instance_valid(table) and table.peeking:table.toggle_peek()
			elif casino_portal.current().is_empty():casino_portal.close_local()
		return
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode==KEY_K and event.ctrl_pressed and shell!=null:
		shell.toggle_palette()
		get_viewport().set_input_as_handled()
		return
	if shell!=null and shell.palette.visible and event.keycode==KEY_ESCAPE:
		shell.close_palette()
		get_viewport().set_input_as_handled()
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit: return
	if event.keycode==KEY_F7:
		open_fx_studio();get_viewport().set_input_as_handled();return
	if toolbox != null and not event.ctrl_pressed and not event.alt_pressed:
		var shortcuts := {KEY_V:"select",KEY_K:"tokens",KEY_D:"draw",KEY_T:"text",KEY_M:"measure",KEY_R:"dice",KEY_X:"fx",KEY_B:"beacon",KEY_H:"mask",KEY_L:"lighting"}
		if shortcuts.has(event.keycode):
			toolbox.open(shortcuts[event.keycode])
			get_viewport().set_input_as_handled()
			return
	if event.keycode == KEY_ESCAPE:
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			return
		# Forward Escape because tool buttons can own focus while the board owns the active tool.
		board._gui_input(event)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_TAB:
		if inspector_tabs.visible:
			inspector_tabs.current_tab = (inspector_tabs.current_tab + 1) % inspector_tabs.get_tab_count()
		else:
			_show_sidebar_page(sheet_page)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_S:
		_show_sidebar_page(sheet_page)
	elif event.keycode == KEY_C:
		_show_sidebar_page(chat_page)
	elif event.keycode == KEY_J:
		_show_sidebar_page(journal_page)
	elif event.keycode == KEY_1:
		_select_mode()
	elif event.keycode == KEY_2:
		_toggle_fog()
	elif event.keycode == KEY_3:
		_toggle_door()
	elif event.keycode == KEY_4:
		_begin_rocket()

func _build_scene_section(parent: VBoxContainer) -> void:
	_add_header(parent, "MAP SETUP")
	var intro := Label.new()
	intro.text = "Bring in your own battle map, then align its 5-foot grid. The artwork stays separate from walls, doors, fog and tokens."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(intro)
	map_import_button = _add_button(parent, "Import PNG / JPEG…", _open_map_dialog)
	_accent_button(map_import_button)
	var library_button:=_add_button(parent,"Browse 15 sample maps…",_open_map_library)
	library_button.icon=Hearth20Design.icon("map",18)
	library_button.add_theme_constant_override("icon_max_width",18)
	_add_button(parent, "Calibrate grid…", _calibrate_prompt)
	_add_button(parent, "Fit map  ·  F", func(): board.fit_map())
	grid_state_label = Label.new()
	grid_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(grid_state_label)
	grid_display_button = _add_button(parent, "Hide square grid", _toggle_grid_display)
	grid_snap_button = _add_button(parent, "Turn snapping off", _toggle_grid_snap)
	var grid_controls:=Hearth20GridControls.new(); parent.add_child(grid_controls); grid_controls.setup(self)
	grid_cells_edit = SpinBox.new()
	grid_cells_edit.min_value = 1
	grid_cells_edit.max_value = 256
	grid_cells_edit.value = 24
	grid_cells_edit.suffix = " cells across map"
	parent.add_child(grid_cells_edit)
	grid_scale_edit = SpinBox.new()
	grid_scale_edit.min_value = 80
	grid_scale_edit.max_value = 120
	grid_scale_edit.step = 0.5
	grid_scale_edit.value = 100
	grid_scale_edit.suffix = "% scale"
	parent.add_child(grid_scale_edit)
	_add_button(parent, "Apply grid scale", _apply_grid_calibration)
	var calibration_note := Label.new()
	calibration_note.text = "Width calibration assumes the grid begins at the image's top-left. Border and offset anchor calibration is pending."
	calibration_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(calibration_note)
	restore_scene_button = _add_button(parent, "Restore previous scene", _restore_previous_scene)
	restore_scene_button.disabled = true
	_add_header(parent, "SCENE CONTENT")
	_add_button(parent, "Add hero token", _add_hero)
	_add_button(parent, "Add NPC token", _add_token)
	_add_button(parent, "Clear fog", _clear_fog)
	_add_button(parent, "Clear cosmetic effects", _clear_fx)
	_add_header(parent, "DYNAMIC VISION")
	var lighting_row := HBoxContainer.new()
	dynamic_lighting_toggle = CheckButton.new()
	dynamic_lighting_toggle.text = "Lighting"
	dynamic_lighting_toggle.toggled.connect(_set_dynamic_lighting)
	lighting_row.add_child(dynamic_lighting_toggle)
	ambient_picker = OptionButton.new()
	ambient_picker.add_item("Bright")
	ambient_picker.add_item("Dim")
	ambient_picker.add_item("Dark")
	ambient_picker.item_selected.connect(func(index: int):
		if dynamic_lighting_toggle.button_pressed and session.local_role == "dm":
			session.set_scene_lighting(true, ["bright", "dim", "dark"][index])
	)
	lighting_row.add_child(ambient_picker)
	parent.add_child(lighting_row)
	blackout_toggle = CheckButton.new()
	blackout_toggle.text = "Blackout table"
	blackout_toggle.toggled.connect(func(enabled: bool): session.set_blackout(enabled))
	parent.add_child(blackout_toggle)
	vision_enabled_toggle = CheckButton.new()
	vision_enabled_toggle.text = "Carried light enabled"
	vision_enabled_toggle.button_pressed = true
	parent.add_child(vision_enabled_toggle)
	var vision_range_row := GridContainer.new()
	vision_range_row.columns = 2
	darkvision_field = _vision_spin("Dark", 60)
	bright_light_field = _vision_spin("Bright", 0)
	dim_light_field = _vision_spin("Dim", 0)
	vision_range_row.add_child(darkvision_field);darkvision_field.hide()
	vision_range_row.add_child(bright_light_field)
	vision_range_row.add_child(dim_light_field)
	parent.add_child(vision_range_row)
	var torch_preset := _add_button(parent, "Torch · 20 ft bright + 20 ft dim", func():
		bright_light_field.value = 20
		dim_light_field.value = 20
	)
	torch_preset.tooltip_text = "Set the selected hero’s carried light source to 20 feet bright and another 20 feet dim."
	_add_button(parent, "Apply carried light", func():
		if board.selected_actor_id.is_empty():
			_on_status("Select a hero to set its vision.")
			return
		var actor := Hearth20Contracts.find_actor(campaign, board.selected_actor_id)
		if not actor.is_empty() and bool(actor.get("is_hero", false)):
			var result: Dictionary = session.set_actor_vision(board.selected_actor_id, true, 0.0, bright_light_field.value, dim_light_field.value)
			if not result.get("ok", false):
				_on_status(str(result.get("error", "Vision could not be updated.")))
		else:
			_on_status("Select a hero token before changing vision.")
	)
	var template_shape := OptionButton.new()
	for shape in ["Circle", "Rectangle", "Line", "Cone"]:
		template_shape.add_item(shape)
	_add_button(parent, "Place area template", func():
		if board.role != "dm":
			_on_status("Only the DM places templates.")
			return
		board.set_template_tool(["circle", "rectangle", "line", "cone"][template_shape.selected])
	)
	parent.add_child(template_shape)
	_add_header(parent, "VIEW")
	var view_help := Label.new()
	view_help.text = "Wheel zooms at the pointer. Hold Space and drag, or use the middle mouse button, to pan. Arrow keys nudge the view."
	view_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(view_help)

func _build_token_section(parent: VBoxContainer) -> void:
	_add_button(parent,"Campaign token inventory",open_token_inventory)
	_add_header(parent, "SELECTED TOKEN")
	selected_label = Label.new()
	selected_label.text = "Select a token on the map."
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(selected_label)
	token_preview = TextureRect.new()
	token_preview.custom_minimum_size = Vector2(96, 96)
	token_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	token_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	token_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(token_preview)
	token_visibility_button = _add_button(parent, "Reveal to players", _toggle_selected_visibility)
	token_name_edit = LineEdit.new()
	token_name_edit.placeholder_text = "Choose a token on the map"
	token_name_edit.text_submitted.connect(_rename_selected_token)
	parent.add_child(token_name_edit)
	token_size_edit = SpinBox.new()
	token_size_edit.min_value = 0.25
	token_size_edit.max_value = 2.0
	token_size_edit.step = 0.05
	token_size_edit.value = 1.0
	token_size_edit.suffix = " token scale"
	token_size_edit.value_changed.connect(_resize_selected_token)
	parent.add_child(token_size_edit)
	var position_row := HBoxContainer.new()
	token_x_edit = SpinBox.new()
	token_x_edit.min_value = 0
	token_x_edit.max_value = 128
	token_x_edit.step = 0.1
	token_x_edit.prefix = "X "
	position_row.add_child(token_x_edit)
	token_y_edit = SpinBox.new()
	token_y_edit.min_value = 0
	token_y_edit.max_value = 128
	token_y_edit.step = 0.1
	token_y_edit.prefix = "Y "
	position_row.add_child(token_y_edit)
	parent.add_child(position_row)
	_add_button(parent, "Apply token position", _apply_token_position)
	_add_button(parent, "Choose PNG appearance…", _open_token_dialog)
	_add_header(parent, "DM CONTROL")
	var note := Label.new()
	note.text = "PNG is cosmetic and stored in this campaign."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)
	_add_header(parent, "ASSIGNMENT / MOVEMENT")
	player_picker = OptionButton.new()
	parent.add_child(player_picker)
	_add_button(parent, "Assign this hero", _assign_hero)
	movement_mode = OptionButton.new()
	for item in ["Blocked", "Turn allowance", "Distance grant", "Free until revoked"]:
		movement_mode.add_item(item)
	parent.add_child(movement_mode)
	movement_distance = SpinBox.new()
	movement_distance.min_value = 0
	movement_distance.max_value = 10000
	movement_distance.step = 5
	movement_distance.value = 25
	movement_distance.suffix = " ft"
	parent.add_child(movement_distance)
	_add_button(parent, "Apply movement policy", _apply_movement)

func _apply_grid_calibration() -> void:
	var previous_revision := int(campaign.get("revision", 0))
	var outcome: Dictionary = board.calibrate_map_width(int(grid_cells_edit.value))
	if not outcome.get("ok", false):
		_on_status(str(outcome.get("error", "Grid calibration failed.")))
		return
	var scene: Dictionary = board.current_scene()
	var factor := float(grid_scale_edit.value) / 100.0
	scene.cell_pixels = float(scene.cell_pixels) * factor
	scene.width_cells = maxi(1, ceili(float(scene.get("map_width", 0)) / float(scene.cell_pixels)))
	scene.height_cells = maxi(1, ceili(float(scene.get("map_height", 0)) / float(scene.cell_pixels)))
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_mark_scene_recovery_revision(previous_revision)
	board.fit_map()
	board.queue_redraw()
	if session and session.local_role == "dm":
		session._broadcast_snapshots()
	grid_scale_edit.value = 100.0
	_update_grid_state()
	_on_status("Grid scale applied. Fine tune between 80% and 120%, then apply again.")

func _capture_scene_recovery() -> void:
	var scene: Dictionary = board.current_scene()
	if scene.is_empty() or board.role != "dm":
		scene_recovery.clear()
		return
	scene_recovery = {"scene_id": str(scene.get("id", "")), "scene": scene.duplicate(true), "assets": campaign.get("assets", {}).duplicate(true), "revision": int(campaign.get("revision", 0))}
	restore_scene_button.disabled = true

func _mark_scene_recovery_revision(previous_revision: int) -> void:
	if scene_recovery.is_empty() or int(scene_recovery.get("revision", -1)) != previous_revision:
		scene_recovery.clear()
		restore_scene_button.disabled = true
		return
	scene_recovery.revision = int(campaign.get("revision", 0))
	restore_scene_button.disabled = false

func _restore_previous_scene() -> void:
	if scene_recovery.is_empty() or int(campaign.get("revision", -1)) != int(scene_recovery.get("revision", -2)):
		_on_status("Recovery expired because campaign state changed. Import or apply a recipe to create a new recovery point.")
		scene_recovery.clear()
		restore_scene_button.disabled = true
		return
	if not session.remote_players.is_empty() or not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_on_status("Previous-scene recovery is available only while the table is offline.")
		return
	var scene := Hearth20Contracts.find_scene(campaign, str(scene_recovery.scene_id))
	if scene.is_empty():
		_on_status("The prior scene is no longer available.")
		return
	var prior_scene: Dictionary = scene_recovery.scene
	scene.clear()
	scene.merge(prior_scene, true)
	campaign.assets = scene_recovery.assets.duplicate(true)
	campaign.revision = int(campaign.get("revision", 0)) + 1
	board.actor_image_cache.clear()
	board.fit_map()
	board.queue_redraw()
	scene_recovery.clear()
	restore_scene_button.disabled = true
	_on_status("Previous scene and its asset records restored. Actor and movement state was left as is.")

func _select_mode() -> void:
	board.activate_tool("select")
	board.set_fog_tool(false)
	board.set_door_tool(false)
	board.fx_target_mode = false
	mode_select.set_pressed_no_signal(true)
	mode_fog.set_pressed_no_signal(false)
	mode_doors.set_pressed_no_signal(false)
	mode_rocket.set_pressed_no_signal(false)
	_on_status("Select and move tokens. Hold Space while dragging to pan.")

func _rename_selected_token(value: String) -> void:
	if board.role != "dm" or board.selected_actor_id.is_empty():
		return
	var actor := Hearth20Contracts.find_actor(campaign, board.selected_actor_id)
	if actor.is_empty():
		return
	actor.name = value.strip_edges().left(64)
	campaign.revision = int(campaign.get("revision", 0)) + 1
	board.queue_redraw()
	if session and session.local_role == "dm":
		session._broadcast_snapshots()

func _resize_selected_token(value: float) -> void:
	if not is_inside_tree() or board == null or board.role != "dm" or board.selected_actor_id.is_empty():
		return
	var actor := Hearth20Contracts.find_actor(campaign, board.selected_actor_id)
	if actor.is_empty():
		return
	actor.token_size = clampf(value, 0.25, 2.0)
	campaign.revision = int(campaign.get("revision", 0)) + 1
	board.queue_redraw()
	if session and session.local_role == "dm":
		session._broadcast_snapshots()

func _apply_token_position() -> void:
	if board.role != "dm" or board.selected_actor_id.is_empty():
		return
	var actor := Hearth20Contracts.find_actor(campaign, board.selected_actor_id)
	var scene: Dictionary = board.current_scene()
	if actor.is_empty() or actor.get("in_inventory",false) or scene.is_empty():
		return
	actor.position = Hearth20TokenInventory.snap_position(scene,Vector2(clampf(token_x_edit.value, 0.0, float(scene.width_cells)), clampf(token_y_edit.value, 0.0, float(scene.height_cells))))
	campaign.revision = int(campaign.get("revision", 0)) + 1
	board.queue_redraw()
	if session and session.local_role == "dm":
		session._broadcast_snapshots()

func _build_network_section(parent: VBoxContainer) -> void:
	var party=_add_button(parent,"✦ Gather party · Steam & Direct IP",func():open_connections())
	party.custom_minimum_size.y=44
	_add_header(parent, "HOSTED TABLE")
	network_controls = VBoxContainer.new()
	network_controls.add_theme_constant_override("separation", 8)
	parent.add_child(network_controls)
	var host_row := HBoxContainer.new()
	host_port = SpinBox.new()
	host_port.min_value = 1024
	host_port.max_value = 65535
	host_port.value = 28930
	host_row.add_child(host_port)
	host_button = _add_button(host_row, "Host table", _host_table)
	network_controls.add_child(host_row)
	join_address = LineEdit.new()
	join_address.placeholder_text = "Host address"
	network_controls.add_child(join_address)
	join_secret = LineEdit.new()
	join_secret.placeholder_text = "DM invite code"
	network_controls.add_child(join_secret)
	player_name = LineEdit.new()
	player_name.name="PlayerDisplayName"
	player_name.placeholder_text = "Your display name"
	player_name.max_length=40
	var remembered:=Hearth20PlayerProfile.preferences()
	player_name.text=remembered.display_name
	join_address.text=remembered.address
	host_port.value=remembered.port
	var name_label:=Label.new(); name_label.text="DISPLAY NAME"; network_controls.add_child(name_label)
	network_controls.add_child(player_name)
	var remembered_note:=Label.new(); remembered_note.text="Your name and identity are remembered on this device. A saved campaign restores the tokens the DM granted you."; remembered_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; network_controls.add_child(remembered_note)
	var join_button := _add_button(network_controls, "Join as player", _join_table)
	_accent_button(join_button)
	var session_note := Label.new()
	session_note.text = "Players can select and move an assigned hero within the DM's current movement permission. The host checks each request. First-time players import a character sheet and optional token PNG; the DM receives the character in inventory."
	session_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(session_note)

func _build_selection_section(parent: VBoxContainer) -> void:
	_add_header(parent, "TOKEN PERMISSION")
	selected_label = Label.new()
	selected_label.text = "Select a token on the map."
	parent.add_child(selected_label)
	var row := HBoxContainer.new()
	movement_mode = OptionButton.new()
	for item in ["Blocked", "Turn allowance", "Distance grant", "Free until revoked"]:
		movement_mode.add_item(item)
	row.add_child(movement_mode)
	movement_distance = SpinBox.new()
	movement_distance.min_value = 0
	movement_distance.max_value = 10000
	movement_distance.step = 5
	movement_distance.value = 25
	movement_distance.suffix = " ft"
	row.add_child(movement_distance)
	parent.add_child(row)
	_add_button(parent, "Apply DM movement policy", _apply_movement)
	var movement_help := Label.new()
	movement_help.text = "Player moves are checked by the host against assigned ownership, calibrated scene bounds, walls, closed doors, and remaining distance. Distance uses measured straight-line world feet."
	movement_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(movement_help)

func _build_recipe_section(parent: VBoxContainer) -> void:
	_add_header(parent, "OFFLINE SCENE AUTHORING")
	var intro := Label.new()
	intro.text = "Describe a place and review Hearth20's bounded draft. Every result remains editable data for the DM."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(intro)
	recipe_prompt = TextEdit.new()
	recipe_prompt.custom_minimum_size.y = 76
	recipe_prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	recipe_prompt.placeholder_text = "Describe a scene, e.g. an overgrown forest camp with four connected rooms, a campfire, two tents and a secret cache."
	parent.add_child(recipe_prompt)
	_add_button(parent, "Draft bounded recipe", _draft_recipe)
	recipe_unresolved = Label.new()
	recipe_unresolved.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(recipe_unresolved)
	var advanced := CheckButton.new()
	advanced.text = "Advanced: edit recipe data"
	parent.add_child(advanced)
	recipe_json = TextEdit.new()
	recipe_json.custom_minimum_size.y = 180
	recipe_json.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	recipe_json.placeholder_text = "Versioned recipe JSON is editable before applying. Unsupported wording remains visible above."
	recipe_json.add_theme_font_size_override("font_size", 11)
	recipe_json.visible = false
	parent.add_child(recipe_json)
	advanced.toggled.connect(func(enabled: bool): recipe_json.visible = enabled)
	recipe_acknowledge = CheckButton.new()
	recipe_acknowledge.text = "Unresolved items reviewed"
	recipe_acknowledge.visible = false
	parent.add_child(recipe_acknowledge)
	var review_button := _add_button(parent, "Review and apply draft", _apply_recipe)
	_accent_button(review_button)
	var limitation := Label.new()
	limitation.text = "Offline limited vocabulary; no AI service. Recipe JSON is optional advanced editing. Review unresolved requests before applying."
	limitation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(limitation)
	_add_header(parent, "TABLE LOG")
	log_view = RichTextLabel.new()
	log_view.custom_minimum_size.y = 140
	log_view.fit_content = true
	log_view.scroll_following = true
	parent.add_child(log_view)

func _add_header(parent: Node, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color("#91d6ca")
	parent.add_child(label)

func _add_button(parent: Node, text_value: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 34 if not text_value.contains("\n") else 54
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = text_value.replace("\n", " ")
	button.pressed.connect(callable)
	parent.add_child(button)
	return button

func _add_hero() -> void:
	if board.role != "dm":
		return
	board.add_token("Hero %d" % (campaign.actors.size() + 1), true, Vector2(4, 4))

func _add_token() -> void:
	if board.role != "dm":
		return
	board.add_token("Token %d" % (campaign.actors.size() + 1), false, Vector2(7, 5))

func _open_map_dialog() -> void:
	if board.role == "dm":
		if seated_shell!=null and seated_shell.focus_state=="table":seated_shell.focus_map()
		map_dialog.popup_centered_ratio(0.78)
func _cancel_map_dialog() -> void:
	if is_instance_valid(map_dialog):map_dialog.hide()
	_on_status("Map import cancelled. Your current table is unchanged.")
func open_preferences() -> void:
	Hearth20SettingsWindow.open(seated_shell if seated_shell!=null else self,self)

func _open_map_library() -> Hearth20MapLibraryWindow:
	if session.local_role!="dm": return null
	for child in get_children():
		if child is Hearth20MapLibraryWindow and not child.is_queued_for_deletion():Hearth20Design.popup_window(child);return child
	var window:=Hearth20MapLibraryWindow.new()
	add_child(window)
	window.setup(self)
	Hearth20Design.popup_window(window)
	return window

func _load_sample_map(map_id: String, move_party: bool=true) -> Dictionary:
	var result: Dictionary=session.load_sample_map(map_id,move_party)
	if result.get("ok",false): _finish_library_scene_change(str(result.get("title","Sample map")))
	return result

func _switch_library_scene(scene_id: String, move_party: bool=true) -> Dictionary:
	var result: Dictionary=session.switch_library_scene(scene_id,move_party)
	if result.get("ok",false): _finish_library_scene_change(str(result.get("title","Scene")))
	return result

func _finish_library_scene_change(title_value: String) -> void:
	if board.active_fx!=null: board.active_fx.clear_all()
	board.map_texture_cache=null
	board.map_texture_cache_key=""
	board.lighting_cache_key=""
	board.selected_actor_id=""
	board.selected_object_id=""
	board.activate_tool("select",true)
	board.fit_map()
	scene_recovery.clear()
	grid_cells_edit.value=int(board.current_scene().get("width_cells",24))
	grid_scale_edit.value=100
	_update_grid_state()
	_on_selection("")
	_on_status("%s · Scene ready with calibrated grid, editable lights, walls and doors."%title_value)

func _on_map_selected(path: String) -> void:
	var previous_revision := int(campaign.get("revision", 0))
	_capture_scene_recovery()
	var result: Dictionary = board.import_map(path)
	if not result.get("ok", false):
		scene_recovery.clear()
		restore_scene_button.disabled = true
		_on_status("Map import failed: %s" % result.get("error", "unknown error"))
		return
	_mark_scene_recovery_revision(previous_revision)
	if result.get("auto_calibrated",false):
		grid_cells_edit.value=int(result.calibration_width_cells)
		_on_status("Map ready · %d × %d cells · %s ft per cell. Grid scale read from the image."%[int(result.calibration_width_cells),int(result.height_cells),str(result.feet_per_cell)])
		_update_grid_state()
		return
	_on_status("Map imported (%d × %d px). Set its grid scale to finish setup." % [int(result.width), int(result.height)])
	_update_grid_state()
	_calibrate_prompt()

func _calibrate_prompt() -> AcceptDialog:
	var dialog_owner: Node = seated_shell if is_instance_valid(seated_shell) else self
	var existing := dialog_owner.get_node_or_null("GridCalibration") as AcceptDialog
	if is_instance_valid(existing) and not existing.is_queued_for_deletion():
		Hearth20Design.popup_window(existing)
		return existing
	var dialog := ConfirmationDialog.new()
	dialog.name = "GridCalibration"
	dialog.title = "Grid calibration"
	dialog.theme = Hearth20Design.theme()
	dialog.dialog_hide_on_ok = false
	dialog.ok_button_text = "Apply grid"
	dialog.cancel_button_text = "Keep current grid"
	# A wrapped label with no initial width can report one word per line and
	# expand an AcceptDialog beyond the screen before its first layout pass.
	# Bound the content with a scroll region; the native action footer stays out.
	var available := get_tree().root.size - Vector2i(48, 96)
	var content_width := clampi(available.x - 40, 240, 440)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(content_width, mini(172, maxi(80, available.y - 100)))
	dialog.add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.custom_minimum_size.x = content_width
	form.add_theme_constant_override("separation", 12)
	scroll.add_child(form)
	var description := Label.new()
	description.text = "Set how many 5-foot cells span the imported map's width. Height follows the image aspect ratio."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(description)
	var cells := SpinBox.new()
	cells.name = "WidthCells"
	cells.min_value = 1
	cells.max_value = 256
	cells.step = 1
	cells.value = int(board.current_scene().get("calibration_width_cells", board.current_scene().get("width_cells", 24)))
	grid_cells_edit.value = cells.value
	form.add_child(cells)
	Hearth20Design.track_number(cells)
	var error_label := Label.new()
	error_label.name = "ValidationError"
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.add_theme_color_override("font_color", Color("#ffb896"))
	form.add_child(error_label)
	dialog.confirmed.connect(func():
		var valid := Hearth20Design.commit_numbers([cells])
		if not valid.ok:
			error_label.text = str(valid.error)
			cells.get_line_edit().grab_focus()
			return
		var previous_revision := int(campaign.get("revision", 0))
		var outcome: Dictionary = board.calibrate_map_width(int(cells.value))
		_on_status(outcome.get("error", "Map calibration saved at %.2f px per cell." % float(outcome.get("cell_pixels", 0.0))))
		if outcome.get("ok", false):
			_mark_scene_recovery_revision(previous_revision)
			_update_grid_state()
			dialog.queue_free()
		else:
			error_label.text = str(outcome.get("error", "Could not calibrate this map."))
	)
	var keep_current := func():
		_on_status("Map imported with its current grid. You can adjust the grid from the map toolbar.")
		dialog.queue_free()
	dialog.canceled.connect(keep_current)
	dialog.close_requested.connect(keep_current)
	dialog_owner.add_child(dialog)
	dialog.size = Vector2i(content_width + 40, mini(280, maxi(180, available.y)))
	Hearth20Design.popup_window(dialog)
	cells.get_line_edit().grab_focus.call_deferred()
	return dialog

func _toggle_grid_snap() -> void:
	var enabled: bool = board.toggle_snap_to_grid()
	_update_grid_state()
	_on_status("Grid snap %s; placements %s." % ["enabled" if enabled else "disabled", "snap to calibrated cells" if enabled else "free within the board"])

func _toggle_grid_display() -> void:
	if board.role != "dm":
		return
	var scene: Dictionary = board.current_scene()
	scene.grid_visible = not bool(scene.get("grid_visible", true))
	campaign.revision = int(campaign.get("revision", 0)) + 1
	board.queue_redraw()
	if session and session.local_role == "dm":
		session._broadcast_snapshots()
	_update_grid_state()

func _update_grid_state() -> void:
	if grid_state_label == null or board == null or not is_instance_valid(board):
		return
	var scene: Dictionary = board.current_scene()
	if scene.is_empty():
		grid_state_label.text = "No active scene"
		return
	var grid_visible := bool(scene.get("grid_visible", true))
	var snapping := bool(scene.get("snap_to_grid", true))
	grid_state_label.text = "%s grid · %s placement" % ["Square" if grid_visible else "Hidden", "snapped" if snapping else "free"]
	grid_display_button.text = "Hide square grid" if grid_visible else "Show square grid"
	grid_snap_button.text = "Turn snapping off" if snapping else "Turn snapping on"

func _open_token_dialog() -> void:
	if board.role == "dm":
		token_dialog.popup_centered_ratio(0.7)

func _on_token_selected(path: String) -> void:
	var result: Dictionary = board.attach_token_png(path)
	_refresh_token_inspector()
	_on_status("PNG override saved: %s" % result.get("sha256", result.get("error", "failed")))

func _toggle_fog() -> void:
	board.set_fog_tool(not board.fog_tool)
	mode_fog.set_pressed_no_signal(board.fog_tool)
	mode_doors.set_pressed_no_signal(false)
	mode_rocket.set_pressed_no_signal(false)
	mode_select.set_pressed_no_signal(not board.fog_tool)
	mode_rocket.set_pressed_no_signal(false)
	_on_status("Drag a rectangle on the map to conceal its pixels and content." if board.fog_tool else "Fog tool disabled.")

func _clear_fog() -> void:
	board.clear_fog()
	_on_status("Fog cleared.")

func _toggle_door() -> void:
	board.set_door_tool(not board.door_tool)
	mode_doors.set_pressed_no_signal(board.door_tool)
	mode_fog.set_pressed_no_signal(false)
	mode_rocket.set_pressed_no_signal(false)
	mode_select.set_pressed_no_signal(not board.door_tool)
	mode_rocket.set_pressed_no_signal(false)
	_on_status("Door tool is DM-only: click a door to open or close it." if board.door_tool else "Door tool disabled.")

func _begin_rocket() -> void:
	if board.fx_target_mode:
		board.fx_target_mode = false
		board.queue_redraw()
		mode_rocket.set_pressed_no_signal(false)
		mode_select.set_pressed_no_signal(true)
		_on_status("Rocket targeting cancelled.")
		return
	board.begin_fire_rocket_target()
	mode_select.set_pressed_no_signal(false)
	mode_fog.set_pressed_no_signal(false)
	mode_doors.set_pressed_no_signal(false)
	mode_rocket.set_pressed_no_signal(board.fx_target_mode)

func _clear_fx() -> void:
	if board.role == "dm":
		board.active_fx.clear_all()
		var scene: Dictionary = board.current_scene()
		scene.fx = []
		campaign.revision = int(campaign.get("revision", 0)) + 1
		session._broadcast_snapshots()
		_on_status("Cosmetic effects cleared.")

func _host_table() -> void:
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_on_status("Leave the active table before starting another host session.")
		return
	var result: Dictionary = session.start_host(int(host_port.value))
	if result.ok:
		_update_session_ui()
		_on_status("Host ready. Share invite code %s with players." % result.invite_secret)
	else:
		_on_status(result.error)

func _join_table() -> void:
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_on_status("Leave the active table before joining another host.")
		return
	var result: Dictionary = session.join_host(join_address.text, int(host_port.value), join_secret.text, player_name.text)
	if result.ok:
		board.set_role("player")
		_update_session_ui()
		_on_status("Connecting to the Hearth20 host…")
	else:
		_on_status(result.error)

func _assign_hero() -> void:
	if player_picker.selected < 0 or player_picker.selected >= player_picker.item_count:
		return
	var player_id := str(player_picker.get_item_metadata(player_picker.selected))
	var result: Dictionary = session.assign_hero(board.selected_actor_id, player_id)
	_on_status("Hero assigned." if result.ok else result.get("error", "Could not assign hero."))

func _apply_movement() -> void:
	var modes := ["blocked", "turn_allowance", "grant", "free_until_revoked"]
	var result: Dictionary = board.update_movement_policy(modes[movement_mode.selected], float(movement_distance.value))
	_on_status("Movement permission updated." if result.get("ok", false) else result.get("error", result.get("reason", "Could not set movement permission.")))

func _draft_recipe() -> void:
	var result: Dictionary = Hearth20Recipes.author(recipe_prompt.text, int(Time.get_unix_time_from_system()))
	if not result.ok:
		_on_status(result.error)
		return
	recipe_current = result.recipe
	recipe_json.text = JSON.stringify(recipe_current, "  ")
	_update_unresolved(recipe_current.get("unresolved_requests", []))
	recipe_acknowledge.visible = not recipe_current.get("unresolved_requests", []).is_empty()
	recipe_acknowledge.button_pressed = false
	_on_status("Review the draft and unresolved requests, then apply.")

func _apply_recipe() -> void:
	if board.role != "dm":
		_on_status("Only the DM can edit the scene.")
		return
	var parsed := Hearth20Recipes.parse_bounded_json(recipe_json.text)
	if not parsed.ok:
		_on_status("Recipe rejected: " + "; ".join(parsed.errors))
		return
	var recipe: Dictionary = parsed.recipe
	if not recipe.get("unresolved_requests", []).is_empty() and not recipe_acknowledge.button_pressed:
		_on_status("Review the unresolved request list and check its acknowledgement before applying.")
		return
	var scene: Dictionary = board.current_scene()
	var previous_revision := int(campaign.get("revision", 0))
	_capture_scene_recovery()
	var applied := Hearth20Recipes.apply_to_scene(recipe, scene)
	if not applied.ok:
		scene_recovery.clear()
		restore_scene_button.disabled = true
		_on_status("Recipe rejected: " + "; ".join(applied.errors))
		return
	recipe_current = recipe
	_update_unresolved(applied.unresolved_requests)
	recipe_acknowledge.visible = not applied.unresolved_requests.is_empty()
	recipe_acknowledge.button_pressed = false
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_mark_scene_recovery_revision(previous_revision)
	board.fit_pending = true
	board.queue_redraw()
	session._broadcast_snapshots()
	_on_status("Editable scene recipe applied. Unknown requests remain listed for the DM.")

func _update_unresolved(items: Array) -> void:
	if items.is_empty():
		recipe_unresolved.text = "Unresolved requests: none"
	else:
		recipe_unresolved.text = "Unresolved requests (not applied):\n• " + "\n• ".join(PackedStringArray(items))

func _save_campaign() -> void:
	if board.role != "dm":
		_on_status("Only the DM can save the campaign.")
		return
	Hearth20CampaignVault.open(seated_shell if seated_shell!=null else self,self,"save")

func begin_campaign_save(path: String,title_value: String) -> Hearth20CampaignProgress:
	if is_instance_valid(campaign_progress) and campaign_progress.active:return campaign_progress
	campaign_progress=Hearth20CampaignProgress.open(self,"save",path,title_value)
	return campaign_progress

func _load_campaign() -> void:
	if board.role != "dm":
		_on_status("Only the DM can load the campaign.")
		return
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) or not session.remote_players.is_empty():
		_on_status("Disconnect the active table before loading another campaign.")
		return
	Hearth20CampaignVault.open(seated_shell if seated_shell!=null else self,self,"open")

func install_loaded_campaign(loaded_campaign: Dictionary,source_path="") -> Dictionary:
	if session.local_role!="dm" or not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):return {"ok":false,"error":"Leave the active table before loading another campaign."}
	var candidate_adapter=LITE_ADAPTER_SCRIPT.new(loaded_campaign)
	var candidate_bridge=LITE_BRIDGE_SCRIPT.new()
	var rules_result: Dictionary = candidate_bridge.attach(candidate_adapter)
	if not rules_result.ok:
		_on_status("Campaign loaded, but rules bridge could not attach: " + str(rules_result.get("error", "unknown error")))
		return rules_result
	lite_bridge.detach();campaign=loaded_campaign;lite_adapter=candidate_adapter;lite_bridge=candidate_bridge;current_save_path=source_path
	dm_notes_editor.text = str(campaign.get("dm_notes", ""))
	sheet_render_signature = ""
	vision_render_signature = ""
	session.configure(campaign)
	board.set_campaign(campaign, session, "dm")
	_update_session_ui()
	_on_status("Hearth20 campaign loaded from the separate Hearth20 save root.")
	return {"ok":true}

func _on_selection(actor_id: String) -> void:
	if actor_id.is_empty():
		selected_label.text = "Select a token on the map."
		_refresh_token_inspector()
		_refresh_sheet()
		_refresh_vision_controls()
		return
	var actor := Hearth20Contracts.find_actor(campaign, actor_id) if board.role == "dm" else {}
	if board.role == "player":
		for visible_actor in board.current_actors():
			if str(visible_actor.get("id", "")) == actor_id:
				if session.client_snapshot.get("sheets",[]).any(func(sheet):return str(sheet.id)==actor_id):
					selected_sheet_actor_id=actor_id
				var movement: Dictionary = visible_actor.get("movement", {})
				var mode := str(movement.get("mode", "blocked"))
				selected_label.text = "Your hero · %s%s" % [mode.replace("_", " "), " · %.1f ft remaining" % float(movement.get("remaining_feet", 0.0)) if movement.has("remaining_feet") else ""]
				_refresh_token_inspector()
				_refresh_sheet()
				_refresh_vision_controls()
				return
	var visibility_note := " · CONCEALED" if bool(actor.get("hidden", false)) else " · visible to players"
	selected_label.text = "%s · %s%s" % [str(actor.get("name", actor_id)), str(actor.get("movement_policy", {}).get("mode", "blocked")), visibility_note]
	_refresh_token_inspector()
	_refresh_sheet()
	_refresh_vision_controls()

func _refresh_token_inspector() -> void:
	if token_name_edit == null:
		return
	var actor := Hearth20Contracts.find_actor(campaign, board.selected_actor_id) if board.role == "dm" else {}
	if actor.is_empty() and board.role == "player":
		for visible_actor in board.current_actors():
			if str(visible_actor.get("id", "")) == board.selected_actor_id:
				actor = visible_actor
				break
	if actor.is_empty():
		token_visibility_button.visible = board.role == "dm"
		token_visibility_button.disabled = true
		token_visibility_button.text = "Reveal to players"
		token_name_edit.text = ""
		token_name_edit.placeholder_text = "Choose a token on the map"
		token_name_edit.editable = false
		token_size_edit.editable = false
		token_x_edit.editable = false
		token_y_edit.editable = false
		token_preview.texture = null
		return
	token_name_edit.editable = board.role == "dm"
	token_visibility_button.visible = board.role == "dm"
	token_visibility_button.disabled = board.role != "dm"
	token_visibility_button.text = "Reveal to players" if bool(actor.get("hidden", false)) else "Conceal from players"
	token_name_edit.placeholder_text = str(actor.get("name", "Token"))
	token_name_edit.text = str(actor.get("name", "Token"))
	token_size_edit.editable = board.role == "dm"
	token_size_edit.set_value_no_signal(float(actor.get("token_size", 0.82)))
	var scene: Dictionary = board.current_scene()
	token_x_edit.max_value = maxf(0.0, float(scene.get("width_cells", 128)))
	token_y_edit.max_value = maxf(0.0, float(scene.get("height_cells", 128)))
	token_x_edit.editable = board.role == "dm"
	token_y_edit.editable = board.role == "dm"
	var position: Variant = actor.get("position", Vector2.ZERO)
	if position is Vector2:
		token_x_edit.set_value_no_signal(position.x)
		token_y_edit.set_value_no_signal(position.y)
	var asset_id := str(actor.get("png_asset_id", actor.get("asset_id", "")))
	token_preview.texture = board._actor_texture(asset_id) if not asset_id.is_empty() else null

func _toggle_selected_visibility() -> void:
	if board == null or board.role != "dm" or board.selected_actor_id.is_empty():
		return
	var actor := Hearth20Contracts.find_actor(campaign, board.selected_actor_id)
	if actor.is_empty():
		return
	actor.hidden = not bool(actor.get("hidden", false))
	campaign.revision = int(campaign.get("revision", 0)) + 1
	board.queue_redraw()
	_on_selection(board.selected_actor_id)
	if session and session.local_role == "dm":
		session._broadcast_snapshots()
	_on_status("Token concealed from players." if actor.hidden else "Token revealed to players.")

func _on_snapshot(value: Dictionary) -> void:
	board.set_player_snapshot(value)
	if session.local_role=="player" and not value.get("connection_closed",false):
		if value.get("character_required",false) and not is_instance_valid(join_character_window) and not (multiplayer_lab!=null and multiplayer_lab.auto_character()):
			open_join_character()
		elif not value.get("character_required",false) and is_instance_valid(join_character_window):
			join_character_window.cancelled=true;join_character_window._close()
	if bool(value.get("connection_closed", false)):
		if is_instance_valid(join_character_window):join_character_window.cancelled=true;join_character_window._close()
		selected_sheet_actor_id = ""
		last_timeline_id = ""
		unread_chat_count = 0
		if chat_feed != null:
			chat_feed.clear()
		if chat_shortcut_button != null:
			chat_shortcut_button.text = "Chat  C"
		if handout_list != null:
			handout_list.clear()
		if handout_title != null:
			handout_title.clear()
		if handout_body != null:
			handout_body.clear()
		if sheet_render_signature != "":
			sheet_render_signature = ""
		_refresh_sheet()
		_refresh_handouts()
		_refresh_token_inspector()
		_refresh_vision_controls()
		player_session_note.text = "Disconnected from the table. Your local view has been cleared."
		_on_status("Disconnected from the table. Join a host to load an authorized view.")
		return
	_track_unread(value.get("timeline", []))
	player_session_note.text = "Your character is saved in the DM’s token inventory. The DM will place it and grant movement." if value.get("character_in_inventory",false) else "Connected to the table. Choose your assigned character in Sheet; rolls are validated by the host."
	_refresh_token_inspector()
	_refresh_sheet()
	_refresh_chat()
	_refresh_handouts()
	_refresh_vision_controls()
	_on_status("Connected. Your authorized scene, character sheet and table rolls are ready.")

func _on_host_state(value: Dictionary) -> void:
	remote_players = value.get("players", {})
	player_picker.clear()
	for player_id in remote_players:
		player_picker.add_item(str(remote_players[player_id].get("nickname", "Player")))
		player_picker.set_item_metadata(player_picker.item_count - 1, str(player_id))
	_update_session_ui()
	_refresh_sheet()
	_refresh_handouts()
	_refresh_vision_controls()

func _update_session_ui() -> void:
	var previous_tab: int = inspector_tabs.current_tab
	var player_mode: bool = session.local_role == "player"
	var session_active: bool = not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	dm_rail.visible = true
	if toolbox != null: toolbox.refresh_role()
	for page in [scene_page, token_page, author_page]:
		var page_index: int = workspace_tabs.get_tab_idx_from_control(page)
		if page_index >= 0:
			workspace_tabs.set_tab_hidden(page_index, player_mode)
	if player_mode:
		var active_workspace_page: int = workspace_tabs.current_tab
		if active_workspace_page >= 0 and workspace_tabs.is_tab_hidden(active_workspace_page):
			workspace_tabs.current_tab = workspace_tabs.get_tab_idx_from_control(session_page)
	save_button.visible = not player_mode
	load_button.visible = not player_mode
	load_button.disabled = session_active
	host_button.disabled = session_active
	network_controls.visible = not player_mode and not session_active
	player_session_note.visible = player_mode or session_active
	leave_session_button.visible = session_active
	if sheet_page != null:
		sheet_page.visible = true
		chat_page.visible = true
		journal_page.visible = true
		help_page.visible = true
	if player_mode:
		player_session_note.text = "Connecting as a player. The DM controls the scene, vision and outcomes."
		leave_session_button.text = "Leave table"
	elif session_active:
		player_session_note.text = "Hosting Hearth20. The DM retains scene authority. Campaign loading and another session are disabled until hosting ends."
		leave_session_button.text = "End hosted table"
	if player_mode:
		inspector_tabs.current_tab = inspector_tabs.get_tab_idx_from_control(sheet_page)
	else:
		inspector_tabs.current_tab = previous_tab
	if dm_notes_editor != null:
		dm_notes_editor.visible = not player_mode
		dm_notes_save_button.visible = not player_mode
		handout_public.visible = not player_mode
	_refresh_sheet()
	_refresh_chat()
	_refresh_handouts()
	_refresh_vision_controls()

func _leave_table() -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	session.stop_session()
	session.configure(campaign)
	board.set_role("dm")
	_update_session_ui()
	_on_status("Left the table. DM workspace restored.")

func _on_status(message: String) -> void:
	if message == "Active map action cancelled." and mode_select != null:
		mode_select.set_pressed_no_signal(true)
		mode_fog.set_pressed_no_signal(false)
		mode_doors.set_pressed_no_signal(false)
		mode_rocket.set_pressed_no_signal(false)
	elif board != null and mode_select != null:
		mode_fog.set_pressed_no_signal(board.fog_tool)
		mode_doors.set_pressed_no_signal(board.door_tool)
		mode_rocket.set_pressed_no_signal(board.fx_target_mode)
		mode_select.set_pressed_no_signal(not board.fog_tool and not board.door_tool and not board.fx_target_mode)
	if status_label:
		status_label.text = message
	if log_view:
		log_view.append_text("%s\n" % message.replace("[", "\\["))

func open_character_import(_actor_id: String="") -> void:
	open_beyond_sheet()

func open_character_folio() -> void:
	open_beyond_sheet()
func open_beyond_sheet() -> void:
	if seated_shell!=null:seated_shell.focus_sheet();return
	_show_sidebar_page(sheet_page)
	if is_instance_valid(casino_portal) and casino_portal.phase!="closed":
		OS.shell_open(beyond_sheet.requested)
	elif not is_instance_valid(beyond_sheet.expanded):beyond_sheet.toggle_expanded()

func open_fx_studio() -> Hearth20FxStudioWindow:
	for child in get_children():
		if child is Hearth20FxStudioWindow and not child.is_queued_for_deletion():Hearth20Design.popup_window(child);return child
	var studio:=Hearth20FxStudioWindow.new();add_child(studio);studio.setup(self);return studio

func open_casino() -> void:
	if session.local_role=="dm" and casino_portal!=null:casino_portal.open()

func open_connections(action="") -> Window:
	return Hearth20ConnectionWindow.open(self,action)
func open_join_character() -> Hearth20JoinPawnWindow:
	if is_instance_valid(join_character_window):return join_character_window
	join_character_window=Hearth20JoinPawnWindow.new()
	# The map is a texture-backed nested viewport. Modal input belongs to the player's screen.
	(seated_shell if seated_shell!=null else self).add_child(join_character_window)
	join_character_window.setup(self)
	return join_character_window
func _on_steam_invite() -> void:
	open_connections("join").accept_invitation()
func _steam_connection_changed() -> void:
	if not is_instance_valid(host_button):return
	var link=get_node("/root/SteamLink")
	var signature=str(session.local_role)+"|"+str(session.transport)+"|"+str(session.multiplayer.multiplayer_peer.get_connection_status())+"|"+str(link.busy())
	if signature==connection_signature:return
	connection_signature=signature;board.set_role(session.local_role);_update_session_ui()

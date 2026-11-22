extends Window
class_name Hearth20OwnedTokenEditor

const REPLY_TIMEOUT_SECONDS := 45.0

var app: Hearth20App
var actor_id: String
var original_name: String
var can_rename: bool
var original_portrait: Texture2D
var name_field: LineEdit
var preview: TextureRect
var status: Label
var choose_button: Button
var save_button: Button
var cancel_button: Button
var files: FileDialog
var reply_timeout: Timer
var png := PackedByteArray()
var submitting := false

func setup(owner_app: Hearth20App, actor: Dictionary) -> void:
	app = owner_app
	actor_id = str(actor.id)
	can_rename = not actor.has("masked_name_length")
	original_name = str(actor.get("name", "")) if can_rename else ""
	title = "Hearth20 · Edit your token"
	size = Vector2i(440, 350)
	min_size = Vector2i(350, 300)
	theme = Hearth20Design.theme()
	transient = true
	exclusive = true
	close_requested.connect(_close)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Hearth20Design.panel(Hearth20Regal.swatch(Hearth20Regal.BG), 6, 18, Hearth20Regal.swatch(Hearth20Regal.GOLD)))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var name_label := Label.new()
	name_label.text = "Name on the map"
	name_label.visible = can_rename
	column.add_child(name_label)
	name_field = LineEdit.new()
	name_field.max_length = 64
	name_field.text = original_name
	name_field.visible = can_rename
	name_field.text_changed.connect(func(_text): _update_actions())
	name_field.text_submitted.connect(func(_text): _save())
	column.add_child(name_field)

	preview = TextureRect.new()
	preview.custom_minimum_size.y = 80
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	original_portrait = app.board._actor_texture(str(actor.get("asset_id", "")))
	preview.texture = original_portrait
	column.add_child(preview)
	status = Label.new()
	status.text = "Your party sees this name and portrait." if can_rename else "Choose a new portrait for your token."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)

	files = FileDialog.new()
	files.title = "Hearth20 · Choose your token image"
	files.access = FileDialog.ACCESS_FILESYSTEM
	files.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	files.add_filter("*.png, *.gif", "PNG and GIF token images")
	files.use_native_dialog = OS.get_name() == "Windows"
	files.file_selected.connect(_choose_png)
	files.canceled.connect(Hearth20Design.dismiss_file_picker.bind(files))
	files.close_requested.connect(Hearth20Design.dismiss_file_picker.bind(files))
	add_child(files)
	choose_button = Button.new()
	choose_button.text = "Choose image…"
	choose_button.pressed.connect(func(): Hearth20Design.open_file_picker(files, 0.8))
	column.add_child(choose_button)

	var actions := HBoxContainer.new()
	column.add_child(actions)
	cancel_button = Button.new()
	cancel_button.pressed.connect(_close)
	actions.add_child(cancel_button)
	save_button = Button.new()
	save_button.text = "Save token"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(_save)
	actions.add_child(save_button)
	Hearth20Design.primary(save_button)

	reply_timeout = Timer.new()
	reply_timeout.one_shot = true
	reply_timeout.timeout.connect(_check_reply)
	add_child(reply_timeout)
	app.session.character_edit_result.connect(_on_result)
	app.session.snapshot_received.connect(func(snapshot):
		if snapshot.get("connection_closed", false): _close())
	_update_actions()
	Hearth20Design.popup_window(self)
	if can_rename:name_field.grab_focus()
	else:choose_button.grab_focus()

func _choose_png(path: String) -> void:
	Hearth20Design.dismiss_file_picker(files)
	var inspected := Hearth20Assets.inspect_token_art(path)
	if not inspected.ok:
		png.clear()
		preview.texture = original_portrait
		status.text = str(inspected.error)
		_update_actions()
		return
	png = inspected.bytes
	preview.texture = ImageTexture.create_from_image(inspected.image)
	status.text = "Portrait ready."
	_update_actions()

func _update_actions() -> void:
	var proposed := name_field.text.strip_edges()
	var changed := (not png.is_empty() or proposed!=original_name) and not proposed.is_empty() if can_rename else not png.is_empty()
	save_button.disabled = submitting or not changed
	name_field.editable = can_rename and not submitting
	choose_button.disabled = submitting
	cancel_button.text = "Close" if submitting else "Cancel"

func _save() -> void:
	if save_button.disabled:
		return
	var result: Dictionary = app.session.edit_owned_character(actor_id, name_field.text.strip_edges(), png)
	if not result.get("ok", false):
		status.text = str(result.get("error", "Unable to save your token."))
		return
	if not result.get("pending", false):
		_finish(true, "Your token was updated.")
		return
	submitting = true
	status.text = "Saving your token…"
	_update_actions()
	reply_timeout.start(REPLY_TIMEOUT_SECONDS)

func _on_result(result: Dictionary) -> void:
	if submitting and str(result.get("id", "")) == actor_id:
		var saved := bool(result.get("ok", false))
		_finish(saved, str(result.get("error", "Your token was updated." if saved else "Unable to save your token.")))

func _check_reply() -> void:
	var upload: Dictionary = app.session.steam_outgoing.get(1, {})
	if upload.get("kind", "") == "character":
		var elapsed := (Time.get_ticks_msec() - int(upload.get("active", {}).get("last_sent", 0))) / 1000.0
		if elapsed < REPLY_TIMEOUT_SECONDS:
			reply_timeout.start(REPLY_TIMEOUT_SECONDS - elapsed)
			return
	_finish(false, "The DM hasn't confirmed your edit. You can try again.")

func _finish(saved: bool, message: String) -> void:
	reply_timeout.stop()
	submitting = false
	if saved:
		app._on_status(message)
		_close()
	else:
		status.text = message
		_update_actions()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not files.visible:
		set_input_as_handled()
		_close()

func _close() -> void:
	Hearth20Design.dismiss_file_picker(files)
	hide()
	exclusive = false
	queue_free()

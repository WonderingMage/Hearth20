extends Window
class_name Hearth20JoinPawnWindow
var app: Hearth20App
var cancelled=false
var name_field: LineEdit
var status: Label
var preview: TextureRect
var png=PackedByteArray()
var send_button: Button
func setup(owner_app: Hearth20App) -> void:
	app=owner_app;title="Hearth20 Beyond · Bring your character";size=Vector2i(600,560);min_size=size;theme=Hearth20Design.theme();transient=true;exclusive=true;close_requested.connect(_close)
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#18120c"),3,28,Color("#ba9247")));add_child(panel)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",16);panel.add_child(box)
	var heading=Label.new();heading.text="YOUR PLACE AT THE TABLE";heading.add_theme_font_size_override("font_size",26);box.add_child(heading)
	status=Label.new();status.text="Give your character a name and choose a PNG token. Your sheet stays on D&D Beyond. The DM receives your token in the campaign inventory and can grant movement.";status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status)
	name_field=LineEdit.new();name_field.max_length=64;name_field.placeholder_text="Character name";box.add_child(name_field)
	preview=TextureRect.new();preview.custom_minimum_size=Vector2(150,150);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;box.add_child(preview)
	var files=FileDialog.new();files.access=FileDialog.ACCESS_FILESYSTEM;files.file_mode=FileDialog.FILE_MODE_OPEN_FILE;files.filters=PackedStringArray(["*.png ; Character token PNG"]);files.file_selected.connect(func(path):
		var result=Hearth20Assets.inspect_token_png(path)
		if not result.ok:status.text=str(result.error);return
		png=result.bytes;var image=Image.new();image.load_png_from_buffer(png);preview.texture=ImageTexture.create_from_image(image);status.text="Token selected · one grid square. Your DM controls when it enters the map.")
	add_child(files)
	var choose=Button.new();choose.text="Choose token PNG…";choose.pressed.connect(func():files.popup_centered_ratio(.8));box.add_child(choose)
	send_button=Button.new();send_button.text="Send character to DM inventory";send_button.custom_minimum_size.y=44;box.add_child(send_button);send_button.pressed.connect(func():
		if name_field.text.strip_edges().is_empty() or png.is_empty():status.text="Choose a character name and a PNG first.";return
		var result=app.session.submit_join_character({"name":name_field.text.strip_edges()},png)
		if result.ok:send_button.disabled=true;status.text="Sending your character…"
		else:status.text=str(result.get("error","Unable to send character.")))
	app.session.character_submission_result.connect(func(result):
		if result.ok:cancelled=true;_close()
		else:status.text=str(result.get("error","Unable to accept character."));send_button.disabled=false)
	popup_centered()
func _close() -> void:
	if not cancelled and app.session.local_role=="player":app.session.stop_session()
	queue_free()

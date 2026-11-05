extends SceneTree
## Exercise real root-viewport input routing through the seated app's nested viewport.
class AppFixture extends Hearth20App:
	func _ready() -> void:
		session=Hearth20Session.new();session.name="Hearth20Session";add_child(session)
		session.configure(Hearth20Identity.new_campaign("Onboarding input fixture"));session.local_role="player";session.local_player_id=""
class ShellFixture extends Hearth20SeatedShell:
	func _ready() -> void:
		name="SeatedTable";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func click_at(point: Vector2) -> void:
	var event=InputEventMouseMotion.new();event.position=point;event.global_position=point;root.push_input(event)
	var press=InputEventMouseButton.new();press.position=point;press.global_position=point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press)
	var release=press.duplicate();release.pressed=false;root.push_input(release)
	await process_frame;await process_frame
func run() -> void:
	root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
	var shell=ShellFixture.new();root.add_child(shell)
	var surface=SubViewportContainer.new();surface.stretch=true;surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shell.add_child(surface)
	var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.gui_embed_subwindows=true;surface.add_child(viewport)
	var app=AppFixture.new();app.seated_shell=shell;app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);viewport.add_child(app);shell.app=app
	await process_frame;await process_frame
	var window=app.open_join_character()
	expect(window.get_parent()==shell and window.get_parent().get_viewport()==root,"seated onboarding belongs to the player's screen, outside the map viewport")
	await process_frame;await process_frame
	var point=Vector2(window.position)+window.name_field.get_global_rect().get_center()
	await click_at(point)
	expect(window.name_field.has_focus(),"root-window click reaches the character-name field")
	var letter=InputEventKey.new();letter.pressed=true;letter.keycode=KEY_T;letter.unicode=84;root.push_input(letter);await process_frame
	expect(window.name_field.text=="T","typing reaches the selected character-name field")
	var choose: Button
	for node in window.find_children("*","Button",true,false):
		if node.text=="Choose token PNG…":choose=node
	expect(is_instance_valid(choose),"PNG selection control exists")
	if is_instance_valid(choose):await click_at(Vector2(window.position)+choose.get_global_rect().get_center())
	var files: FileDialog
	for node in window.get_children():
		if node is FileDialog:files=node
	expect(is_instance_valid(files) and files.visible,"root-window click opens the PNG chooser")
	if is_instance_valid(files):
		var image=Image.create(48,48,false,Image.FORMAT_RGBA8);image.fill(Color.CORAL)
		var path=OS.get_cmdline_user_args()[0].path_join("input-test-pawn.png");image.save_png(path);files.current_dir=path.get_base_dir();files.get_line_edit().text=""
		await create_timer(.2).timeout
		await click_at(Vector2(files.position)+files.get_line_edit().get_global_rect().get_center())
		for character in path.get_file():
			var input=InputEventKey.new();input.pressed=true;input.unicode=character.unicode_at(0);root.push_input(input)
		await process_frame;await process_frame
		var enter=InputEventKey.new();enter.pressed=true;enter.keycode=KEY_ENTER;root.push_input(enter)
		await process_frame;await process_frame
		expect(not files.visible and not window.png.is_empty(),"PNG file acceptance receives root input and loads the preview")
		files.hide()
	await click_at(Vector2(window.position)+window.send_button.get_global_rect().get_center())
	expect("Connect to the DM first" in window.status.text,"submit click reaches the session boundary without a network connection")
	window.cancelled=true;window.queue_free();shell.queue_free();await process_frame;await process_frame
	print("Onboarding input: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

extends VBoxContainer
class_name Hearth20BeyondSheet
const HOME="https://www.dndbeyond.com/my-characters"
var app: Hearth20App
var address: LineEdit
var status: Label
var surface: Panel
var pid=-1
var channel=""
var nonce=""
var sequence=0
var elapsed=0.0
var browser_ready=false
var requested=HOME
var action=""
var expanded: Control
var original_parent: Node
var original_index=0
var expanded_button: Button
var last_message=""
var command_number=0
var native_commands: Array=[]
var reparenting=false
var host_mode="native"
var stopping=false
var backend: OptionButton
var quitting=false
func setup(owner_app: Hearth20App) -> void:
	app=owner_app;name="BeyondSheetBrowser";add_theme_constant_override("separation",8);size_flags_vertical=Control.SIZE_EXPAND_FILL
	var profile=ConfigFile.new()
	if profile.load("user://beyond-sheet.cfg")==OK:
		var saved=str(profile.get_value("sheet","url",HOME))
		if valid_url(saved):requested=saved
		var saved_mode=str(profile.get_value("sheet","browser","native"))
		if saved_mode in ["native","embedded"]:host_mode=saved_mode
	var heading=Label.new();heading.text="D&D BEYOND · YOUR SHEET";heading.add_theme_font_override("font",Hearth20Design.font(true));heading.add_theme_font_size_override("font_size",18);add_child(heading)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",6);add_child(row)
	backend=OptionButton.new();backend.add_item("My Windows browser");backend.add_item("Built-in browser");backend.select(0 if host_mode=="native" else 1);backend.item_selected.connect(func(index):_change_backend("native" if index==0 else "embedded"));row.add_child(backend)
	_button(row,"‹",func():action="back");_button(row,"›",func():action="forward");_button(row,"↻",func():action="reload")
	expanded_button=_button(row,"Expand sheet",toggle_expanded)
	address=LineEdit.new();address.placeholder_text="D&D Beyond character URL or search…";address.size_flags_horizontal=Control.SIZE_EXPAND_FILL;address.text_submitted.connect(_go);add_child(address)
	var go=HFlowContainer.new();add_child(go);_button(go,"My characters",func():navigate(HOME));_button(go,"Go / Search",func():_go(address.text));_button(go,"Browser ↗",func():OS.shell_open(requested));_button(go,"Choose browser window",func():action="choose_browser");_button(go,"Return browser to desktop",func():action="release_browser")
	status=Label.new();status.text="Sign in on D&D Beyond. Your sheet stays on that website; map controls and casino coins stay in Hearth20.";status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",12);add_child(status)
	surface=Panel.new();surface.name="NativeWebsiteSurface";surface.custom_minimum_size=Vector2(280,440);surface.size_flags_vertical=Control.SIZE_EXPAND_FILL;surface.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#18120c"),2,10,Color("#9b783d")));add_child(surface)
	address.text=requested
func _change_backend(value: String) -> void:
	if value==host_mode or stopping:return
	if not await release_for_shutdown():backend.select(0 if host_mode=="native" else 1);return
	host_mode=value;browser_ready=false;native_commands.clear();channel="";_save_profile()
func _save_profile() -> void:
	var profile=ConfigFile.new();profile.set_value("sheet","url",requested);profile.set_value("sheet","browser",host_mode);profile.save("user://beyond-sheet.cfg")
static func valid_url(value: String) -> bool:
	if value.length()>2048 or "@" in value or "\n" in value or "\r" in value or "\\" in value:return false
	return value.begins_with("https://www.dndbeyond.com/") or value.begins_with("https://dndbeyond.com/")
func _button(parent: Node, text: String, pressed: Callable) -> Button:
	var b=Button.new();b.text=text;b.custom_minimum_size.y=34;b.pressed.connect(pressed);parent.add_child(b);return b
func _go(text: String) -> void:
	var value=text.strip_edges()
	if value.is_empty():navigate(HOME)
	elif valid_url(value):navigate(value)
	elif value.contains("://"):status.text="Enter a D&D Beyond URL, or words to search on D&D Beyond."
	else:navigate("https://www.dndbeyond.com/search?q="+value.uri_encode())
func navigate(url: String) -> void:
	if not valid_url(url):return
	requested=url;action="navigate";address.text=url
	_save_profile()
func toggle_expanded() -> void:
	if app.seated_shell!=null and not app.seated_shell.changing_focus:
		if app.seated_shell.focus_state=="sheet":app.seated_shell.leave_focus()
		else:app.seated_shell.focus_sheet()
		return
	if is_instance_valid(expanded):
		_move_surface(original_parent);original_parent.move_child(self,original_index);expanded.queue_free();expanded=null;expanded_button.text="Expand sheet";return
	original_parent=get_parent();original_index=get_index()
	expanded=PanelContainer.new();expanded.name="ExpandedBeyondSheet";expanded.z_index=300;expanded.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);expanded.offset_left=24;expanded.offset_top=24;expanded.offset_right=-24;expanded.offset_bottom=-24;expanded.theme=Hearth20Design.theme();expanded.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#110e09"),3,16,Color("#b68b40")));app.add_child(expanded);_move_surface(expanded);expanded_button.text="Back to the table" if app.seated_shell!=null else "Return to map"
func _move_surface(parent: Node) -> void:
	# Reparenting emits exit_tree too; it is a layout change, not browser shutdown.
	reparenting=true;reparent(parent);reparenting=false
func _process(delta: float) -> void:
	if app==null or stopping:return
	elapsed+=delta
	if elapsed<.12:return
	elapsed=0
	var shown=is_visible_in_tree() and app.get_window().mode!=Window.MODE_MINIMIZED
	if app.seated_shell!=null and app.seated_shell.focus_state!="sheet":shown=false
	if app.seated_shell!=null and app.seated_shell.has_modal():shown=false
	if not is_instance_valid(expanded):shown=shown and app.inspector_tabs.current_tab==app.inspector_tabs.get_tab_idx_from_control(app.sheet_page)
	if is_instance_valid(app.casino_portal) and app.casino_portal.phase!="closed":shown=false
	if is_instance_valid(app.shell) and is_instance_valid(app.shell.palette) and app.shell.palette.visible:shown=false
	# Native websites must not cover Godot dialogs or settlement notices.
	if is_instance_valid(app.casino_portal.balance_notice) and app.casino_portal.balance_notice.veil.visible:shown=false
	for child in app.get_children():
		if child is Window and child.visible:shown=false
	if pid>=0 and not OS.is_process_running(pid):pid=-1;browser_ready=false;native_commands.clear()
	if not shown and pid<0:return
	if pid<0:
		_start()
		if pid<0:return
	_read_status()
	var rect=surface.get_global_rect().intersection(Rect2(Vector2.ZERO,app.get_viewport_rect().size))
	if not is_instance_valid(expanded):rect=rect.intersection(app.sheet_page.get_global_rect())
	var scale=Vector2(DisplayServer.window_get_size())/app.get_viewport_rect().size
	var command={"visible":shown and rect.size.x>50 and rect.size.y>50,"x":roundi(rect.position.x*scale.x),"y":roundi(rect.position.y*scale.y),"width":roundi(rect.size.x*scale.x),"height":roundi(rect.size.y*scale.y),"action":action if browser_ready else "","url":requested}
	_write(command)
	if browser_ready:action=""
func _start() -> void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://hearth20/browser/bundle.json"))
	if not manifest is Dictionary:status.text="Embedded browser files are missing. Use Open in browser.";set_process(false);return
	var root=ProjectSettings.globalize_path("user://native-browser/"+str(manifest.version));DirAccess.make_dir_recursive_absolute(root)
	for name_value in manifest.files:
		var data=FileAccess.get_file_as_bytes("res://hearth20/browser/"+str(name_value));var hash=Hearth20Contracts.sha256(data)
		if hash!=str(manifest.files[name_value]):status.text="Browser files failed their integrity check. Use Open in browser.";set_process(false);return
		var dest=root.path_join(str(name_value))
		if not FileAccess.file_exists(dest) or FileAccess.get_sha256(dest)!=hash:
			var f=FileAccess.open(dest,FileAccess.WRITE)
			if f==null:status.text="Unable to prepare embedded browser. Use Open in browser.";set_process(false);return
			f.store_buffer(data);f.close()
	nonce=Crypto.new().generate_random_bytes(24).hex_encode();channel=ProjectSettings.globalize_path("user://beyond-browser/session-"+nonce);DirAccess.make_dir_recursive_absolute(channel)
	_write({"visible":false,"x":0,"y":0,"width":1,"height":1})
	var hwnd=DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE,get_window().get_window_id())
	var arguments=PackedStringArray([str(hwnd),str(OS.get_process_id()),nonce,channel])
	if host_mode=="native":arguments.append("native")
	pid=OS.create_process(root.path_join("BeyondBrowserHost.exe"),arguments)
	var window=get_tree().root
	window.auto_accept_quit=false
	if not window.close_requested.is_connected(_quit_with_browser):window.close_requested.connect(_quit_with_browser)
	if pid<0:status.text="Embedded browser could not start. Use Open in browser.";set_process(false)
	action="navigate"
func release_for_shutdown() -> bool:
	if stopping:return false
	if pid<0 or not OS.is_process_running(pid):pid=-1;return true
	stopping=true;_write({"action":"exit","visible":false})
	var deadline=Time.get_ticks_msec()+4000
	while OS.is_process_running(pid) and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	stopping=false
	if OS.is_process_running(pid):status.text="The browser is still attached. Choose another browser window or close the sheet browser before leaving Hearth20.";return false
	pid=-1;browser_ready=false;channel="";native_commands.clear();return true
func _quit_with_browser() -> void:
	if quitting:return
	quitting=true
	if await release_for_shutdown():get_tree().quit()
	else:quitting=false
func _write(command: Dictionary) -> void:
	if channel.is_empty():return
	if not str(command.get("action","")).is_empty() and command.action!="exit":
		command_number+=1;var instruction={"command_id":command_number,"action":str(command.action)}
		for key in ["url","qa"]:
			if command.has(key):instruction[key]=command[key]
		native_commands.append(instruction)
	if not native_commands.is_empty() and command.get("action","")!="exit":command.merge(native_commands[0],true)
	sequence+=1;command.nonce=nonce;command.sequence=sequence
	var f=FileAccess.open(channel.path_join("control.json"),FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify(command));f.close()
func _read_status() -> void:
	var path=channel.path_join("status.json")
	if not FileAccess.file_exists(path):return
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:return
	var result=parser.data
	if not result is Dictionary or result.get("nonce","")!=nonce:return
	while not native_commands.is_empty() and int(native_commands[0].command_id)<=int(result.get("last_command_id",0)):native_commands.pop_front()
	var was_ready=browser_ready;browser_ready=bool(result.get("ready",false))
	if browser_ready and not was_ready:action="navigate"
	last_message=str(result.get("message",""));status.text=last_message+" · Website balances are updated manually."
func _exit_tree() -> void:
	if not reparenting:_write({"action":"exit","visible":false})
func suspend_native() -> void:
	_write({"visible":false,"x":0,"y":0,"width":1,"height":1})
func capture_sheet_preview() -> void:
	# Local personal folio only. Never stored as a campaign asset or sent over RPC.
	_write({"action":"capture_sheet","visible":true})

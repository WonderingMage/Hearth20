extends Node
class_name Hearth20MultiplayerLab
## Debug-only real-process local play. Controls never cross the game network.
const ENV_ROOT="H20_LOCAL_LAB_ROOT"
const ENV_TOKEN="H20_LOCAL_LAB_TOKEN"
const SLOTS=["dm","player1","player2"]
static var start_on_table=false
var app: Hearth20App
var slot="dm"
var root_path=""
var token=""
var config={}
var pids={}
var placed={}
var elapsed=0.
var last_command=""
var last_submit=-10000
var active=false
var stopping=false
var overlay: CanvasLayer
var strip: PanelContainer
var panel: Window
var note: Label
var status_rows={}
var names=[]
var samples: CheckBox
var placement: CheckBox
var fresh_profiles: CheckBox
var switches={}
var last_focus_ack=""
static func enabled() -> bool:return bool(ProjectSettings.get_setting_with_override("application/config/hearth20_debug")) and OS.has_feature("debug")
static func child_slot() -> String:
	if not enabled():return ""
	for arg in OS.get_cmdline_user_args():
		if arg in ["--h20-local-player=1","--h20-local-player=2"]:return "player"+arg.right(1)
	return ""
static func read_record(path: String) -> Dictionary:
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>16384:return {}
	var parser=JSON.new();var result=parser.parse(file.get_as_text());file.close()
	return parser.data if result==OK and parser.data is Dictionary else {}
func write_record(name_value: String, value: Dictionary) -> bool:
	if root_path.is_empty() or name_value not in ["launch.json","dm.json","player1.json","player2.json","cmd-dm.json","cmd-player1.json","cmd-player2.json"]:return false
	var path=root_path.path_join(name_value);var temporary=path+"."+slot+".writing";var file=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(value));file.close()
	return DirAccess.rename_absolute(temporary,path)==OK
func setup(owner_app: Hearth20App) -> void:
	app=owner_app
	if not enabled():set_process(false);return
	overlay=CanvasLayer.new();overlay.layer=150;app.add_child(overlay)
	var entry=Button.new();entry.name="MultiplayerLabButton";entry.text="Multiplayer Lab · F8";entry.tooltip_text="One DM and two independent local player windows";entry.custom_minimum_size=Vector2(0,38);entry.theme=Hearth20Design.theme();entry.pressed.connect(open_panel);app.network_controls.add_child(entry)
	_build_strip()
	var child=child_slot()
	if not child.is_empty():
		entry.hide();slot=child;call_deferred("_join_child")
	elif start_on_table:start_on_table=false;call_deferred("start",true)
func _button(parent: Node, caption: String, action: Callable) -> Button:
	var b=Button.new();b.text=caption;b.custom_minimum_size.y=38;b.pressed.connect(action);parent.add_child(b);return b
func _label(parent: Node, text: String, size_value=15) -> Label:
	var label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",size_value);parent.add_child(label);return label
func _build_strip() -> void:
	var anchor=Control.new();anchor.mouse_filter=Control.MOUSE_FILTER_IGNORE;anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(anchor)
	strip=PanelContainer.new();strip.name="LocalWindowSwitcher";strip.theme=Hearth20Design.theme();strip.anchor_left=.5;strip.anchor_right=.5;strip.anchor_top=1;strip.anchor_bottom=1;strip.offset_left=-330;strip.offset_right=330;strip.offset_top=-62;strip.offset_bottom=-12;strip.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#19130c"),3,9,Color("#b38c43")));anchor.add_child(strip)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);strip.add_child(row);_label(row,"LOCAL TABLE",12)
	for id in SLOTS:
		var target=id;switches[id]=_button(row,"DM" if id=="dm" else "Player "+id.right(1),func():focus_view(target));switches[id].tooltip_text="Bring this window to the front · Alt+"+str(SLOTS.find(id)+1)
	_button(row,"Options",open_panel);strip.hide()
func open_panel() -> void:
	if not enabled():return
	if is_instance_valid(panel):panel.popup_centered();return
	panel=Window.new();panel.title="Hearth20 · Multiplayer Lab";panel.size=Vector2i(730,650);panel.min_size=Vector2i(650,560);panel.theme=Hearth20Design.theme();panel.close_requested.connect(panel.hide);app.add_child(panel)
	panel.add_theme_stylebox_override("embedded_border",Hearth20Design.panel(Color("#18130b"),3,8,Color("#a17c3c")));panel.add_theme_stylebox_override("embedded_unfocused_border",Hearth20Design.panel(Color("#18130b"),3,8,Color("#796038")));panel.add_theme_color_override("title_color",Color("#e2c58e"))
	var background=PanelContainer.new();background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#17130d"),3,0,Color("#8d6d36")));panel.add_child(background)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	panel.add_child(margin);var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;margin.add_child(scroll);var col=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;col.add_theme_constant_override("separation",13);scroll.add_child(col)
	_label(col,"ONE TABLE · THREE WINDOWS",25);_label(col,"Your DM window and two real local players. Each player has a separate saved identity and receives only their authorized view.")
	for i in 2:
		var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);col.add_child(row);_label(row,"Player "+str(i+1),16);var name_input=LineEdit.new();name_input.max_length=40;name_input.text=["Player 1 · Liora","Player 2 · Bram"][i];name_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(name_input);names.append(name_input)
	samples=CheckBox.new();samples.text="Use sample named PNG characters";samples.button_pressed=true;col.add_child(samples)
	placement=CheckBox.new();placement.text="Place sample tokens and allow their players to move them";placement.button_pressed=true;col.add_child(placement)
	fresh_profiles=CheckBox.new();fresh_profiles.text="Fresh player identities for this run (keeps existing profiles)";col.add_child(fresh_profiles)
	_label(col,"Players declare casino gold at each table. Turn samples off to test choosing a character name and PNG. D&D Beyond handles character sheets.",13)
	var launch=_button(col,"Launch two player windows",func():start(samples.button_pressed));launch.name="LaunchTwoPlayers";launch.disabled=slot!="dm"
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);col.add_child(row)
	for id in SLOTS:
		var target=id;_button(row,"Show DM" if id=="dm" else "Show Player "+id.right(1),func():focus_view(target))
	_button(col,"Arrange all three windows",arrange);var stop=_button(col,"Close the two test players",stop_players);stop.disabled=slot!="dm"
	for id in SLOTS:status_rows[id]=_label(col,"",14)
	note=_label(col,"Choose Launch to host locally and join both players automatically. The normal host and invitation controls still work for other computers.",14);panel.popup_centered();_update_labels()
func start(use_samples=true) -> Dictionary:
	if not enabled() or slot!="dm" or app.session.local_role!="dm":return {"ok":false,"error":"Start local players from the debug DM window."}
	if active:
		if _alive("player1") or _alive("player2"):
			if stopping:return _error("The test players are closing. Launch again once both say not open.")
			for id in ["player1","player2"]:
				if not _alive(id):_launch(id)
			return {"ok":true}
		active=false;pids.clear()
	var session: Hearth20Session=app.session
	if session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		var hosted=false
		for port in range(28930,28962):
			if session.start_host(port).ok:hosted=true;break
		if not hosted:return _error("No local test port is available. Close another host and try again.")
	if session.listening_port<=0:return _error("Leave the current connection and start a DM host first.")
	token=Crypto.new().generate_random_bytes(16).hex_encode();root_path=ProjectSettings.globalize_path("user://hearth20/local_labs/lab-"+token);DirAccess.make_dir_recursive_absolute(root_path)
	var player_names=[]
	for i in 2:player_names.append(names[i].text.strip_edges() if names.size()==2 and not names[i].text.strip_edges().is_empty() else ["Player 1 · Liora","Player 2 · Bram"][i])
	config={"token":token,"parent_pid":OS.get_process_id(),"port":session.listening_port,"invite":session.invite_secret,"names":player_names,"samples":bool(use_samples),"place":placement.button_pressed if is_instance_valid(placement) else true,"fresh":fresh_profiles.button_pressed if is_instance_valid(fresh_profiles) else false,"created":Time.get_unix_time_from_system()}
	if not write_record("launch.json",config):return _error("The local test folder could not be written.")
	active=true;stopping=false;placed.clear();app.host_port.value=session.listening_port;app._update_session_ui();get_window().title="Hearth20 · DM · Local Multiplayer Lab";strip.show();_heartbeat()
	for id in ["player1","player2"]:_launch(id)
	if is_instance_valid(panel):panel.hide()
	return {"ok":true,"root":root_path}
func _launch(id: String) -> void:
	if id not in ["player1","player2"] or _alive(id):return
	var profile=root_path.path_join("profiles/"+id) if config.get("fresh",false) else ProjectSettings.globalize_path("user://hearth20/local_player_profiles/"+id)
	for part in ["Roaming","Local"]:DirAccess.make_dir_recursive_absolute(profile.path_join(part))
	for file in [id+".json","cmd-"+id+".json"]:
		if FileAccess.file_exists(root_path.path_join(file)):DirAccess.remove_absolute(root_path.path_join(file))
	var env={"APPDATA":profile.path_join("Roaming"),"LOCALAPPDATA":profile.path_join("Local"),ENV_ROOT:root_path,ENV_TOKEN:token};var previous={}
	for key in env:previous[key]={"exists":OS.has_environment(key),"value":OS.get_environment(key)};OS.set_environment(key,env[key])
	var args=PackedStringArray()
	if OS.has_feature("editor"):args.append_array(["--path",ProjectSettings.globalize_path("res://")])
	args.append_array(["--log-file",root_path.path_join(id+".log"),"--","--h20-local-player="+id.right(1)])
	var pid=OS.create_instance(args)
	for key in previous:
		if previous[key].exists:OS.set_environment(key,previous[key].value)
		else:OS.unset_environment(key)
	pids[id]=pid
	if pid<=0:_error("Could not open "+id+". Try Launch again.")
func _join_child() -> void:
	root_path=OS.get_environment(ENV_ROOT);token=OS.get_environment(ENV_TOKEN)
	if token.length()!=32 or not token.is_valid_hex_number(false) or not root_path.is_absolute_path() or root_path.length()>1024 or root_path.get_file()!="lab-"+token:get_tree().quit();return
	config=read_record(root_path.path_join("launch.json"))
	if config.get("token","")!=token or not config.get("parent_pid") is float and not config.get("parent_pid") is int or int(config.get("parent_pid",0))<=0:get_tree().quit();return
	if not config.get("names") is Array or config.names.size()!=2 or not config.get("port") is float and not config.get("port") is int or str(config.get("invite","")).length()>128:get_tree().quit();return
	active=true;strip.show();get_window().title="Hearth20 · Player "+slot.right(1)+" · Local Multiplayer Lab";var index=int(slot.right(1))-1
	app.join_address.text="127.0.0.1";app.host_port.value=int(config.port);app.join_secret.text=str(config.invite);app.player_name.text=str(config.names[index]).left(40);app._join_table();_heartbeat()
func auto_character() -> bool:return enabled() and active and slot!="dm" and bool(config.get("samples",false))
func demo_sheet(index: int) -> Dictionary:
	return {"name":"Lab · Liora" if index==0 else "Lab · Bram"}
func demo_png(index: int) -> PackedByteArray:
	var image=Image.create(96,96,false,Image.FORMAT_RGBA8);image.fill(Color("#c3a458") if index==0 else Color("#a47757"));return image.save_png_to_buffer()
func _prepare_samples() -> void:
	if not config.get("samples",false) or not config.get("place",false):return
	var scene=Hearth20Contracts.find_scene(app.campaign,app.campaign.active_scene)
	for i in 2:
		var status=_status("player"+str(i+1));var principal=str(status.get("principal",""))
		if principal.is_empty():continue
		var actor=Hearth20JoinCharacter.current(app.campaign,principal)
		if actor.is_empty() or not str(actor.get("name","")).begins_with("Lab · ") or placed.has(actor.id):continue
		placed[actor.id]=true
		if not actor.get("in_inventory",false):continue
		var at=Vector2(floor(float(scene.width_cells)/2.)+i*2+.5,floor(float(scene.height_cells)/2.)+.5);app.session.place_inventory_token(actor.id,at);app.session.grant_token_control(actor.id,principal,true)
func _status(id: String) -> Dictionary:
	if not active or id not in SLOTS:return {}
	var s=read_record(root_path.path_join(id+".json"))
	if s.get("token","")!=token or Time.get_unix_time_from_system()-float(s.get("time",0))>(30 if id=="dm" else 6) or int(s.get("pid",0))<=0 or s.get("closed",false):return {}
	return s
func _alive(id: String) -> bool:
	if not _status(id).is_empty():return true
	return int(pids.get(id,-1))>0 and OS.is_process_running(int(pids[id]))
func _heartbeat() -> void:
	var snapshot=app.session.client_snapshot;var principal=str(app.session.local_player_id)
	write_record(slot+".json",{"token":token,"pid":OS.get_process_id(),"time":Time.get_unix_time_from_system(),"role":slot,"principal":principal,"user_path":ProjectSettings.globalize_path("user://"),"connected":slot=="dm" or not principal.is_empty(),"character":str(snapshot.get("join_character_id","")),"character_required":bool(snapshot.get("character_required",false)),"own_token_visible":snapshot.get("actors",[]).any(func(a):return a.id==snapshot.get("join_character_id","")),"focus_ack":last_focus_ack,"table_mode":app.seated_shell.current_mode if app.seated_shell!=null else "map","table_ready":app.seated_shell.ready_to_show and not app.seated_shell.switching if app.seated_shell!=null else true})
func focus_view(id: String) -> void:
	if not active or id not in SLOTS:return
	var status=_status(id)
	if status.is_empty():
		if slot=="dm" and id!="dm":_launch(id)
		return
	if int(status.pid)!=OS.get_process_id() and DisplayServer.get_name()!="headless":DisplayServer.enable_for_stealing_focus(int(status.pid))
	_command(id,"focus")
func _command(id: String, action: String, extra: Dictionary={}) -> void:
	var cmd={"token":token,"id":Crypto.new().generate_random_bytes(8).hex_encode(),"action":action};cmd.merge(extra);write_record("cmd-"+id+".json",cmd)
func arrange() -> void:
	if not active:return
	var area=DisplayServer.screen_get_usable_rect(get_window().current_screen);var large=area.size.x>=2500 and area.size.y>=1300
	for i in 3:
		var bounds=Rect2i(area.position+Vector2i(32+i*44,38+i*38),Vector2i(mini(1400,area.size.x-140),mini(900,area.size.y-150)))
		if large:bounds=Rect2i(area.position+Vector2i(0 if i==0 else area.size.x/2,0 if i<2 else area.size.y/2),Vector2i(area.size.x/2,area.size.y if i==0 else area.size.y/2))
		_command(SLOTS[i],"arrange",{"x":bounds.position.x,"y":bounds.position.y,"w":bounds.size.x,"h":bounds.size.y})
func stop_players() -> void:
	if not active or slot!="dm":return
	stopping=true
	for id in ["player1","player2"]:_command(id,"close")
	if is_instance_valid(note):note.text="The two test players are closing. Your DM table stays open. Launch reopens the same saved player identities."
func _error(text: String) -> Dictionary:
	app._on_status(text)
	if is_instance_valid(note):note.text=text
	return {"ok":false,"error":text}
func _update_labels() -> void:
	for id in status_rows:
		var s=_status(id);status_rows[id].text=("DM" if id=="dm" else "Player "+id.right(1))+" · "+("not open" if s.is_empty() else "hosting" if id=="dm" else "import character" if s.character_required else "connected" if s.connected else "connecting…")
	for id in switches:switches[id].button_pressed=id==slot
func _process(delta: float) -> void:
	if not enabled() or not active:return
	elapsed+=delta
	if elapsed<.2:return
	elapsed=0.
	Engine.max_fps=60 if get_window().has_focus() else 20
	if slot!="dm" and _status("dm").is_empty():_close_child();return
	var cmd=read_record(root_path.path_join("cmd-"+slot+".json"))
	if cmd.get("token","")==token and cmd.get("id","")!=last_command:
		last_command=str(cmd.id)
		if cmd.get("action","")=="close" and slot!="dm":_close_child();return
		if cmd.get("action","")=="focus":
			last_focus_ack=last_command
			if DisplayServer.get_name()!="headless":get_window().mode=Window.MODE_WINDOWED if get_window().mode==Window.MODE_MINIMIZED else get_window().mode;get_window().grab_focus()
		elif cmd.get("action","")=="arrange" and DisplayServer.get_name()!="headless":get_window().mode=Window.MODE_WINDOWED;get_window().size=Vector2i(clampi(int(cmd.get("w",1280)),900,8000),clampi(int(cmd.get("h",800)),620,8000));get_window().position=Vector2i(int(cmd.get("x",0)),int(cmd.get("y",0)))
		elif cmd.get("action","")=="capture" and not OS.get_environment("H20_QA_EVIDENCE").is_empty():_capture_qa()
	if slot=="dm":_prepare_samples()
	elif auto_character() and app.session.client_snapshot.get("character_required",false) and not app.session.local_player_id.is_empty() and Time.get_ticks_msec()-last_submit>2000:last_submit=Time.get_ticks_msec();app.session.submit_join_character(demo_sheet(int(slot.right(1))-1),demo_png(int(slot.right(1))-1))
	_heartbeat();_update_labels()
func _close_child() -> void:
	if stopping:return
	stopping=true
	if is_instance_valid(app.beyond_sheet) and not await app.beyond_sheet.release_for_shutdown():stopping=false;return
	app.session.stop_session();get_tree().quit()
func _input(event: InputEvent) -> void:
	if not enabled() or not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_F8:open_panel();get_viewport().set_input_as_handled()
	elif event.alt_pressed and event.keycode in [KEY_1,KEY_2,KEY_3] and active:focus_view(SLOTS[int(event.keycode)-KEY_1]);get_viewport().set_input_as_handled()
func _exit_tree() -> void:
	if active:
		if slot=="dm":stop_players()
		write_record(slot+".json",{"token":token,"pid":OS.get_process_id(),"time":Time.get_unix_time_from_system(),"closed":true})
func _capture_qa() -> void:
	await RenderingServer.frame_post_draw
	if is_inside_tree():get_window().get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join("lab-"+slot+".png"))

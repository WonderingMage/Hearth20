extends Window
class_name Hearth20ConnectionWindow
var app: Hearth20App
var link: Hearth20SteamLink
var tabs: TabContainer
var nickname: LineEdit
var steam_status: Label
var connection_detail: Label
var steam_progress: ProgressBar
var connect_button: Button
var steam_host: Button
var steam_join: Button
var invite_field: LineEdit
var invite_button: Button
var friend_list: ItemList
var friend_invite: Button
var friend_refresh: Button
var copy_button: Button
var cancel_button: Button
var end_button: Button
var friends_loaded=false
var direct_status: Label
var direct_port: SpinBox
var direct_address: LineEdit
var direct_code: LineEdit
var direct_host: Button
var direct_join: Button
var intent=""
static func open(owner_app: Hearth20App,action="") -> Hearth20ConnectionWindow:
	if is_instance_valid(owner_app.connection_window):
		owner_app.connection_window.popup_centered();return owner_app.connection_window
	var window=Hearth20ConnectionWindow.new();owner_app.connection_window=window
	(owner_app.seated_shell if owner_app.seated_shell!=null else owner_app).add_child(window)
	window.setup(owner_app,action);return window
func setup(owner_app: Hearth20App,action: String) -> void:
	app=owner_app;link=app.get_node("/root/SteamLink");intent=action
	title="Hearth20 · Gather your party";size=Vector2i(880,740);min_size=Vector2i(740,650);theme=Hearth20Design.theme();transient=true;close_requested.connect(_close)
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Regal.swatch(Hearth20Regal.BG),3,24,Hearth20Regal.swatch(Hearth20Regal.GOLD)));add_child(panel)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);panel.add_child(column)
	var heading=_label(column,"✦  GATHER YOUR PARTY  ✦",28);heading.add_theme_font_override("font",Hearth20Design.font(true));heading.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.GOLD))
	_label(column,"A private table for friends, wherever the adventure finds you.",14)
	var name_row=HBoxContainer.new();column.add_child(name_row);_label(name_row,"YOUR DISPLAY NAME",12)
	nickname=LineEdit.new();nickname.placeholder_text="What should the party call you?";nickname.max_length=40;nickname.size_flags_horizontal=Control.SIZE_EXPAND_FILL;nickname.text=Hearth20PlayerProfile.preferences().display_name;name_row.add_child(nickname)
	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tabs)
	_build_steam();_build_direct()
	var footer=HBoxContainer.new();column.add_child(footer)
	cancel_button=_button(footer,"Cancel connection",func():link.cancel());end_button=_button(footer,"Leave table",func():app._leave_table();refresh())
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(spacer);_button(footer,"Return to the table",_close)
	link.changed.connect(refresh);app.session.status_changed.connect(_session_status);nickname.text_changed.connect(func(_text):refresh())
	if link.pending_invite>0:invite_field.text=str(link.pending_invite);intent="join"
	refresh();popup_centered()
func _label(parent: Node,text: String,points=14) -> Label:
	var label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",points);parent.add_child(label);return label
func _button(parent: Node,text: String,action: Callable) -> Button:
	var button=Button.new();button.text=text;button.custom_minimum_size.y=39;button.pressed.connect(action);parent.add_child(button);return button
func _page(name_value: String) -> VBoxContainer:
	var scroll=ScrollContainer.new();scroll.name=name_value;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var margin=MarginContainer.new();margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(margin)
	for side in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",12);box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;margin.add_child(box);return box
func _build_steam() -> void:
	var page=_page("Steam")
	_label(page,"PRIVATE STEAM TABLE",20)
	_label(page,"No address or router setup. Open Hearth20 on both PCs, connect Steam here, then send an invitation.",14)
	steam_status=_label(page,"",15);steam_status.custom_minimum_size.y=42
	connection_detail=_label(page,"",12)
	steam_progress=ProgressBar.new();steam_progress.show_percentage=true;steam_progress.custom_minimum_size.y=15;page.add_child(steam_progress)
	var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",12);page.add_child(actions)
	connect_button=_button(actions,"Connect Steam",func():
		_result(link.initialize())
		if nickname.text.is_empty():nickname.text=link.display_name)
	steam_host=_button(actions,"Host private table",func():_result(link.host()))
	invite_button=_button(actions,"Steam invite overlay",func():_result(link.invite_friends()))
	var join_row=HBoxContainer.new();page.add_child(join_row)
	invite_field=LineEdit.new();invite_field.placeholder_text="Paste an invitation link or lobby number";invite_field.max_length=180;invite_field.size_flags_horizontal=Control.SIZE_EXPAND_FILL;join_row.add_child(invite_field)
	steam_join=_button(join_row,"Join invitation",func():_result(link.join(invite_field.text,nickname.text)))
	copy_button=_button(page,"Copy this table's invitation",func():DisplayServer.clipboard_set(link.invite_link());steam_status.text="Invitation copied. Your friend needs Hearth20 open and connected to Steam.")
	var friend_heading=HBoxContainer.new();page.add_child(friend_heading);_label(friend_heading,"INVITE A STEAM FRIEND",12)
	friend_refresh=_button(friend_heading,"Refresh friends",_load_friends)
	friend_list=ItemList.new();friend_list.custom_minimum_size.y=110;friend_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;page.add_child(friend_list)
	friend_list.item_selected.connect(func(_index):refresh())
	friend_invite=_button(page,"Send invitation to selected friend",func():
		var selected=friend_list.get_selected_items()
		if not selected.is_empty():_result(link.invite_friend(int(friend_list.get_item_metadata(selected[0])))))
	_label(page,"Spacewar test mode · Steam may show you as playing Spacewar. Each PC needs a different signed-in Steam account. The friend list works even when the overlay is unavailable.",11)
func _build_direct() -> void:
	var page=_page("Direct IP")
	_label(page,"DIRECT CONNECTION",20)
	_label(page,"For local play, the multiplayer lab, or an existing network setup.",14)
	direct_status=_label(page,"",13);direct_status.custom_minimum_size.y=58
	var host_row=HBoxContainer.new();page.add_child(host_row);_label(host_row,"Port",13)
	direct_port=SpinBox.new();direct_port.min_value=1024;direct_port.max_value=65535;direct_port.value=app.host_port.value;host_row.add_child(direct_port)
	direct_host=_button(host_row,"Host by Direct IP",func():app.host_port.value=direct_port.value;app._host_table();refresh())
	_button(page,"Copy local connection details",func():DisplayServer.clipboard_set(_direct_details()))
	direct_address=LineEdit.new();direct_address.placeholder_text="DM's host address";direct_address.text=Hearth20PlayerProfile.preferences().address;page.add_child(direct_address)
	direct_code=LineEdit.new();direct_code.placeholder_text="DM invite code";direct_code.max_length=128;page.add_child(direct_code)
	direct_join=_button(page,"Join by Direct IP",func():
		app.join_address.text=direct_address.text;app.join_secret.text=direct_code.text;app.player_name.text=nickname.text;app.host_port.value=direct_port.value;app._join_table();refresh())
	_label(page,"Same computer: 127.0.0.1. Same Wi-Fi/LAN: use the DM's local IPv4 address. Internet play through Direct IP needs the DM's public address and UDP port forwarding. Steam mode handles connections through Steam instead.",12)
func _direct_details() -> String:
	var addresses=[]
	for address in IP.get_local_addresses():
		if ":" not in address and not address.begins_with("127.") and not address.begins_with("169.254.") and address!="0.0.0.0":addresses.append(address)
	return "Local host addresses: "+(", ".join(addresses) if not addresses.is_empty() else "not found")+"\nPort: "+str(app.session.listening_port if app.session.listening_port>0 else int(direct_port.value))+" UDP"+("\nInvite code: "+app.session.invite_secret if app.session.transport=="direct" and app.session.listening_port>0 else "\nStart hosting to generate an invite code.")
func _load_friends() -> void:
	friend_list.clear();friends_loaded=true
	for friend in link.friends():var index=friend_list.add_item(str(friend.name));friend_list.set_item_metadata(index,friend.id)
	refresh()
func refresh() -> void:
	if not is_instance_valid(steam_status):return
	var online=not app.session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	steam_status.text=link.message;connection_detail.text=link.transfer_message if not link.transfer_message.is_empty() else ("Private lobby · "+str(link.lobby_id) if link.lobby_id>0 else "Your campaign, token permissions and private sheet stay under the same local profile.")
	steam_progress.visible=not link.transfer_message.is_empty();steam_progress.value=link.progress*100.
	connect_button.disabled=link.initialized;steam_host.disabled=online or link.busy()
	steam_join.disabled=online or link.busy() or nickname.text.strip_edges().is_empty()
	invite_button.disabled=link.state!="hosting" or not link.initialized or not link.api.isOverlayEnabled()
	copy_button.disabled=link.state!="hosting";friend_refresh.disabled=link.state!="hosting"
	friend_invite.disabled=link.state!="hosting" or friend_list.get_selected_items().is_empty()
	cancel_button.visible=link.busy();end_button.visible=online;direct_host.disabled=online or link.busy();direct_join.disabled=online or link.busy()
	direct_status.text="Connected through Steam. Leave this table before starting a Direct IP session." if app.session.transport=="steam" else _direct_details()
	if link.state=="hosting" and not friends_loaded:call_deferred("_load_friends")
	if intent=="join" and link.state=="joined" and not app.session.client_snapshot.is_empty():intent="";hide()
func _session_status(_note: String) -> void:refresh()
func _result(result: Dictionary) -> void:
	refresh()
	if not result.get("ok",false):steam_status.text=str(result.get("error","Unable to connect."))
func _close() -> void:
	if link.busy():link.cancel()
	queue_free()

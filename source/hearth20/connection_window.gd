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
var journey: Hearth20PartyGuide.RouteDiagram
var role_button: Button
var join_row: HBoxContainer
var host_tools: VBoxContainer
var paste_button: Button
var open_steam_button: Button
var steam_instructions: Label
var step_title: Label
var step_description: Label
var ready_panel: VBoxContainer
var ready_note: Label
var advanced_button: Button
var auto_host_pending=false
var invitation_sent=false
var invited_name=""
var retry_until=0
var retry_tick=0.
var friends_lobby_id=0
var display_name_row: HBoxContainer
var steam_actions: HBoxContainer
var steam_footnote: Label
var friend_search: LineEdit
var friend_records: Array=[]
static func open(owner_app: Hearth20App,action="") -> Hearth20ConnectionWindow:
	if is_instance_valid(owner_app.connection_window) and not owner_app.connection_window.is_queued_for_deletion():
		if action in ["host","join"]:owner_app.connection_window._set_intent(action)
		Hearth20Design.popup_window(owner_app.connection_window);return owner_app.connection_window
	var window=Hearth20ConnectionWindow.new();owner_app.connection_window=window
	(owner_app.seated_shell if owner_app.seated_shell!=null else owner_app).add_child(window)
	window.setup(owner_app,action);return window
func setup(owner_app: Hearth20App,action: String) -> void:
	app=owner_app;link=app.get_node("/root/SteamLink");intent=action
	auto_host_pending=action=="host"
	if auto_host_pending:link.pending_invite=0
	title="Hearth20 · Gather your party";size=Vector2i(880,740);min_size=Vector2i(740,650);theme=Hearth20Design.theme();transient=true;close_requested.connect(_close)
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Regal.swatch(Hearth20Regal.BG),3,24,Hearth20Regal.swatch(Hearth20Regal.GOLD)));add_child(panel)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);panel.add_child(column)
	var heading=_label(column,"✦  GATHER YOUR PARTY  ✦",28);heading.add_theme_font_override("font",Hearth20Design.font(true));heading.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.GOLD))
	var help_row=HBoxContainer.new();column.add_child(help_row)
	var guidance=_label(help_row,"We’ll guide you through connecting your party.",13);guidance.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;guidance.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	role_button=_button(help_row,"Host instead" if intent=="join" else "Join instead",func():_set_intent("host" if intent=="join" else "join"))
	_button(help_row,"Illustrated guide",func():Hearth20PartyGuide.open(self,"direct" if tabs.current_tab==1 else intent))
	var name_row=HBoxContainer.new();column.add_child(name_row);_label(name_row,"YOUR DISPLAY NAME",12)
	display_name_row=name_row
	nickname=LineEdit.new();nickname.placeholder_text="What should the party call you?";nickname.max_length=40;nickname.size_flags_horizontal=Control.SIZE_EXPAND_FILL;nickname.text=Hearth20PlayerProfile.preferences().display_name;name_row.add_child(nickname)
	nickname.focus_exited.connect(_remember_name)
	tabs=TabContainer.new();tabs.tabs_visible=false;tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tabs)
	_build_steam();_build_direct()
	var footer=HBoxContainer.new();column.add_child(footer)
	advanced_button=_button(footer,"Advanced connection",_toggle_advanced)
	cancel_button=_button(footer,"Cancel connection",func():link.cancel());end_button=_button(footer,"Leave table",func():app._leave_table();refresh())
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(spacer);_button(footer,"Return to the table",_close)
	link.changed.connect(refresh);app.session.status_changed.connect(_session_status);nickname.text_changed.connect(func(_text):refresh())
	if link.pending_invite>0:invite_field.text=str(link.pending_invite);intent="join"
	refresh();Hearth20Design.popup_window(self)
	if intent in ["host","join"]:call_deferred("_prepare_steam")
func _label(parent: Node,text: String,points=14) -> Label:
	var label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",points);parent.add_child(label);return label
func _button(parent: Node,text: String,action: Callable) -> Button:
	var button=Button.new();button.text=text;button.custom_minimum_size.y=39;button.pressed.connect(action);parent.add_child(button);return button
func _page(name_value: String) -> VBoxContainer:
	var scroll=ScrollContainer.new();scroll.name=name_value;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var margin=MarginContainer.new();margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(margin)
	for side in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",8);box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;margin.add_child(box);return box
func _build_steam() -> void:
	var page=_page("Steam")
	journey=Hearth20PartyGuide.RouteDiagram.new();journey.role="join" if intent=="join" else "host";journey.compact=true;page.add_child(journey)
	step_title=_label(page,"",23)
	step_description=_label(page,"",15)
	steam_instructions=_label(page,"Open Steam on each PC with a different account. Host a private table, then invite your friends.",14)
	steam_status=_label(page,"",15);steam_status.custom_minimum_size.y=30
	connection_detail=_label(page,"",12)
	steam_progress=ProgressBar.new();steam_progress.show_percentage=true;steam_progress.custom_minimum_size.y=15;page.add_child(steam_progress)
	var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",12);page.add_child(actions)
	steam_actions=actions
	connect_button=_button(actions,"Connect Steam",_prepare_steam)
	steam_host=_button(actions,"Host private table",_host_steam)
	open_steam_button=_button(actions,"Open Steam & continue",_open_steam)
	invite_button=_button(actions,"Quick invite…",quick_invite)
	join_row=HBoxContainer.new();page.add_child(join_row)
	invite_field=LineEdit.new();invite_field.placeholder_text="Paste an invitation link or lobby number";invite_field.max_length=180;invite_field.size_flags_horizontal=Control.SIZE_EXPAND_FILL;join_row.add_child(invite_field)
	steam_join=_button(join_row,"Join invitation",_join_steam)
	paste_button=_button(join_row,"Paste & join",func():invite_field.text=DisplayServer.clipboard_get().strip_edges();_join_steam())
	invite_field.text_submitted.connect(func(_text):_join_steam())
	host_tools=VBoxContainer.new();host_tools.add_theme_constant_override("separation",8);page.add_child(host_tools)
	var friend_heading=HBoxContainer.new();friend_heading.add_theme_constant_override("separation",10);host_tools.add_child(friend_heading);var caption=_label(friend_heading,"INVITE A STEAM FRIEND",12);caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	copy_button=_button(friend_heading,"Copy invitation",func():DisplayServer.clipboard_set(link.invite_link());steam_status.text="Invitation copied. Send your Steam friend an invite first, then share this link.")
	friend_refresh=_button(friend_heading,"Refresh friends",_load_friends)
	friend_search=LineEdit.new();friend_search.placeholder_text="Find a Steam friend by name…";friend_search.max_length=64;host_tools.add_child(friend_search)
	friend_search.text_changed.connect(func(_text):_filter_friends())
	friend_search.text_submitted.connect(func(_text):
		if friend_list.item_count==1:friend_list.select(0);_invite_selected())
	friend_list=ItemList.new();friend_list.custom_minimum_size.y=80;friend_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;host_tools.add_child(friend_list)
	friend_list.item_selected.connect(func(_index):refresh())
	friend_invite=_button(host_tools,"Invite selected friend",_invite_selected)
	_button(host_tools,"Start preparing my table",_close)
	ready_panel=VBoxContainer.new();ready_panel.add_theme_constant_override("separation",12);page.add_child(ready_panel)
	ready_note=_label(ready_panel,"",15)
	var enter=_button(ready_panel,"Enter my table",_close);enter.custom_minimum_size.y=48
	_button(ready_panel,"Invite another friend",func():invitation_sent=false;refresh())
	steam_footnote=_label(page,"Steam test mode may appear as Spacewar. Each PC uses a different signed-in Steam account.",11)
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
	friends_loaded=true;friend_records=link.friends();_filter_friends()
	refresh()
func _filter_friends() -> void:
	friend_list.clear()
	var query:=friend_search.text.strip_edges().to_lower()
	for friend in friend_records:
		if not query.is_empty() and query not in str(friend.name).to_lower():continue
		var index:=friend_list.add_item(str(friend.name));friend_list.set_item_metadata(index,friend.id)
	refresh()
func quick_invite() -> void:
	if link.state!="hosting":_result({"ok":false,"error":"Host a Steam table first."});return
	if link.api.isOverlayEnabled():_result(link.invite_friends());return
	invitation_sent=false;refresh()
	friend_search.grab_focus.call_deferred()
	steam_status.text="Type your friend's name below. Press Enter when one result remains, or choose a result and Invite."
	steam_status.show()
func _set_intent(value: String) -> void:
	intent=value
	if value=="host":link.pending_invite=0
	auto_host_pending=value=="host" and app.session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	journey.role="join" if value=="join" else "host"
	role_button.text="Host instead" if value=="join" else "Join instead"
	refresh()
	if auto_host_pending:call_deferred("_prepare_steam")
func _toggle_advanced() -> void:
	auto_host_pending=false
	retry_until=0
	if link.busy():link.cancel()
	tabs.current_tab=1 if tabs.current_tab==0 else 0
	advanced_button.text="Back to guided setup" if tabs.current_tab==1 else "Advanced connection"
func _open_steam() -> void:
	var error=OS.shell_open("steam://open/main")
	if error!=OK:
		steam_status.text="Open Steam from your Start menu and sign in, then try again."
		return
	retry_until=Time.get_ticks_msec()+90000
	steam_status.text="Sign in to Steam. Hearth20 will continue automatically when it is ready."
func _process(delta: float) -> void:
	if retry_until<=0:return
	if Time.get_ticks_msec()>=retry_until:
		retry_until=0
		steam_status.text="Finish signing in to Steam, then press Connect Steam to continue."
		return
	retry_tick+=delta
	if retry_tick<1.:return
	retry_tick=0.
	_prepare_steam()
func _invite_selected() -> void:
	if invitation_sent:return
	var selected=friend_list.get_selected_items()
	if selected.is_empty():return
	var index=selected[0]
	var result=link.invite_friend(int(friend_list.get_item_metadata(index)))
	if result.ok:
		invited_name=friend_list.get_item_text(index)
		invitation_sent=true
	_result(result)
func _prepare_steam() -> void:
	if tabs.current_tab!=0 or link.busy():return
	if not app.session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer:return
	var result=link.initialize()
	if result.ok and nickname.text.strip_edges().is_empty():nickname.text=link.display_name
	_result(result)
	if not result.ok:return
	retry_until=0
	if link.pending_invite>0:accept_invitation()
	elif auto_host_pending:_host_steam()
func _remember_name() -> void:
	var saved=Hearth20PlayerProfile.preferences()
	Hearth20PlayerProfile.remember(nickname.text,saved.address,saved.port)
func _host_steam() -> void:
	if not nickname.text.strip_edges().is_empty():_remember_name()
	auto_host_pending=false
	var result=link.host()
	if result.ok:
		if nickname.text.strip_edges().is_empty():nickname.text=link.display_name
		_remember_name();intent="host";journey.role="host"
	elif app.session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and not link.busy():
		auto_host_pending=true
	_result(result)
func _join_steam() -> void:
	if not link.initialized:
		var connected=link.initialize()
		if not connected.ok:_result(connected);return
	if nickname.text.strip_edges().is_empty():nickname.text=link.display_name
	var result=link.join(invite_field.text,nickname.text)
	if result.ok:_remember_name();intent="join";journey.role="join"
	_result(result)
func accept_invitation() -> void:
	auto_host_pending=false
	intent="join";tabs.current_tab=0;invite_field.text=str(link.pending_invite);journey.role="join"
	if app.session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and not link.busy():_join_steam()
func refresh() -> void:
	if not is_instance_valid(steam_status):return
	var online=not app.session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	var hosting=link.state=="hosting"
	if hosting and friends_lobby_id!=link.lobby_id:
		friends_lobby_id=link.lobby_id
		friends_loaded=false
		invitation_sent=false
		invited_name=""
	join_row.visible=intent=="join" and link.initialized and not online and not link.busy()
	host_tools.visible=hosting and not invitation_sent
	ready_panel.visible=hosting and invitation_sent
	display_name_row.visible=not hosting or tabs.current_tab==1
	steam_status.visible=not hosting or link.state=="error"
	connection_detail.visible=link.busy() and not link.transfer_message.is_empty()
	steam_footnote.visible=not link.initialized
	connect_button.visible=not link.initialized;open_steam_button.visible=not link.initialized;steam_instructions.visible=not link.initialized
	steam_instructions.hide()
	steam_host.visible=intent!="join" and not hosting and not link.busy();invite_button.visible=hosting
	steam_actions.visible=not link.initialized or steam_host.visible or invite_button.visible
	role_button.disabled=online or link.busy();paste_button.disabled=online or link.busy();invite_field.editable=not online and not link.busy()
	steam_status.text=link.message;connection_detail.text=link.transfer_message if not link.transfer_message.is_empty() else ("Private lobby · "+str(link.lobby_id) if link.lobby_id>0 else "Your campaign, token permissions and private sheet stay under the same local profile.")
	steam_progress.visible=link.busy() or not link.transfer_message.is_empty();steam_progress.indeterminate=link.busy() and link.transfer_message.is_empty();steam_progress.value=link.progress*100.
	connect_button.disabled=link.initialized;steam_host.disabled=online or link.busy()
	steam_join.disabled=online or link.busy()
	journey.current_step=2 if link.state=="joined" or ready_panel.visible else 1 if hosting or link.busy() or (intent=="join" and link.initialized) else 0
	journey.queue_redraw()
	_update_guidance(hosting)
	invite_button.disabled=link.state!="hosting" or not link.initialized
	copy_button.disabled=link.state!="hosting";friend_refresh.disabled=link.state!="hosting"
	friend_invite.disabled=link.state!="hosting" or friend_list.get_selected_items().is_empty()
	cancel_button.visible=link.busy();end_button.visible=online;direct_host.disabled=online or link.busy();direct_join.disabled=online or link.busy()
	direct_status.text="Connected through Steam. Leave this table before starting a Direct IP session." if app.session.transport=="steam" else _direct_details()
	if hosting and not friends_loaded:
		friends_loaded=true
		call_deferred("_load_friends")
	if intent=="join" and link.state=="joined" and not app.session.client_snapshot.is_empty():intent="";hide()
func _update_guidance(hosting: bool) -> void:
	if hosting:
		step_title.text="3 · Your table is open" if invitation_sent else "2 · Invite your friends"
		step_description.text="Your friends can join while you prepare the adventure. Quick invite stays available for the next player." if invitation_sent else "Press Quick invite, or find a Steam friend by name below. They accept the invitation while Hearth20 is open on their PC."
		var guests=app.session.remote_players.values().map(func(player):return str(player.get("nickname","Player")))
		ready_note.text=("Invitation sent to "+invited_name+".\n" if not invited_name.is_empty() else "")+("Waiting for players to arrive." if guests.is_empty() else "At your table · "+", ".join(guests))+"\nNew characters arrive in Tokens. Place their pawns and grant movement when you are ready."
	elif link.busy():
		step_title.text="2 · Preparing your table" if intent!="join" else "2 · Joining the adventure"
		step_description.text="Hearth20 is setting up the connection. The map and character setup will open automatically when ready."
	elif link.initialized and intent=="join":
		step_title.text="2 · Ready for your DM’s invitation"
		step_description.text="Ask your DM to invite your Steam account, "+link.display_name+". Accept that invitation and Hearth20 will join automatically. You can also paste a link below."
	else:
		step_title.text="1 · Connect your Steam account"
		step_description.text="Open Steam and sign in on this PC. We’ll prepare the connection and fill in your name. Each player uses their own Steam account."
func _session_status(_note: String) -> void:refresh()
func _result(result: Dictionary) -> void:
	refresh()
	if not result.get("ok",false):
		steam_status.text=str(result.get("error","Unable to connect."))
		steam_status.show()
func _close() -> void:
	retry_until=0
	auto_host_pending=false
	if not nickname.text.strip_edges().is_empty():_remember_name()
	if link.busy():link.cancel()
	queue_free()

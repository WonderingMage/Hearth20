extends SceneTree
const Fakes=preload("steam_fakes.gd")
class AppFixture extends Hearth20App:
	func _ready() -> void:
		session=Hearth20Session.new();add_child(session);session.configure(Hearth20Identity.new_campaign("Connection screen fixture"))
		get_node("/root/SteamLink").attach(session)
		host_port=SpinBox.new();host_port.value=28930;add_child(host_port)
		join_address=LineEdit.new();join_secret=LineEdit.new();player_name=LineEdit.new()
		for field in [join_address,join_secret,player_name]:add_child(field)
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func run() -> void:
	root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
	var app=AppFixture.new();root.add_child(app);await process_frame;await process_frame
	var link=root.get_node("SteamLink")
	expect(not link.initialized and not Engine.has_singleton("Steam"),"ordinary app startup remains independent of Steam")
	var window=app.open_connections("host");await process_frame;await process_frame
	expect(window.tabs.get_tab_count()==2,"Steam and Direct IP both have a clear home")
	expect(window.nickname.max_length==40 and window.steam_host.text=="Host private table","name and host controls are explicit")
	expect(window.invite_button.disabled,"invitation overlay starts unavailable")
	window.connect_button.pressed.emit();await process_frame
	expect(not link.initialized and "background" in window.steam_status.text,"background test cannot initialize the real Steam client")
	var api=Fakes.Api.new();root.add_child(api);link.api=api;link.fake_backend=true;link.peer_factory=func():return Fakes.Peer.new()
	window.connect_button.pressed.emit();await process_frame
	expect(link.initialized and window.nickname.text=="Fixture Adventurer","Connect fills an empty display name from Steam")
	window.steam_host.pressed.emit();api.lobby_created.emit(1,109775240000000001);await process_frame;await process_frame
	expect(not window.copy_button.disabled and window.friend_list.item_count==2,"host gets copyable invitation and a friend list")
	expect(window.invite_button.disabled,"missing overlay keeps its button disabled")
	window.friend_list.select(0);window.friend_list.item_selected.emit(0);window.friend_invite.pressed.emit()
	expect(api.calls.any(func(value):return value[0]=="invite"),"friend-list fallback sends an invite without invoking overlay")
	expect(window.direct_host.disabled and window.direct_join.disabled,"active Steam table cannot be silently replaced by Direct IP")
	link.transfer_update(.4,"Receiving the battlemap and campaign…");await process_frame
	expect(window.steam_progress.visible and window.steam_progress.value==40.,"chunk transfer progress is visible")
	for dimensions in [Vector2i(740,650),Vector2i(880,740)]:
		window.size=dimensions;await process_frame;await process_frame
		print("LAYOUT ",dimensions," tabs=",window.tabs.size," window=",window.size)
		expect(window.tabs.size.x>600 and window.tabs.size.y>300,"connection layout retains usable space at "+str(dimensions))
	window._close();await process_frame
	expect(link.state=="hosting","returning to table keeps the host running")
	var reopened=app.open_connections("host");await process_frame
	expect(reopened!=null and not reopened.copy_button.disabled,"host can reopen the invitation controls")
	link.disconnect_table();await process_frame
	expect(app.session.local_role=="dm" and not reopened.direct_host.disabled,"leaving Steam restores Direct IP controls")
	reopened.queue_free();app.queue_free();link._steam_shutdown();api.queue_free();await process_frame;await process_frame
	expect(not Engine.has_singleton("Steam"),"UI checks never load the real Steam component")
	print("Steam UI: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

extends SceneTree
const Fakes=preload("steam_fakes.gd")
const Party=preload("party_onboarding.gd")
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func settle() -> void:
	for frame in 4:await process_frame
func run() -> void:
	root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
	var app=Party.AppFixture.new();root.add_child(app);await settle()
	var link=root.get_node("SteamLink");var api=Fakes.Api.new();root.add_child(api)
	link.api=api;link.fake_backend=true;link.peer_factory=func():return Fakes.Peer.new()
	api.running=false
	var window=app.open_connections("host");await settle()
	expect(not link.initialized and window.open_steam_button.visible,"missing Steam gives an actionable first step")
	expect("1" in window.step_title.text and not api.calls.any(func(v):return v[0]=="create"),"setup waits safely for Steam sign-in")
	api.running=true;window.retry_until=Time.get_ticks_msec()+90000;window._process(1.1)
	expect(link.state=="creating" and window.retry_until==0,"opening/signing into Steam continues hosting automatically")
	window._prepare_steam();window.steam_host.pressed.emit()
	expect(api.calls.filter(func(v):return v[0]=="create").size()==1,"repeated host actions cannot create duplicate lobbies")
	window.cancel_button.pressed.emit()
	expect(not link.busy() and link.lobby_id==0,"cancel while creating leaves no active lobby")
	api.lobby_created.emit(1,109775240000000001)
	expect(link.lobby_id==0 and api.calls.any(func(v):return v[0]=="leave"),"late lobby creation after cancellation is discarded")
	window._host_steam();api.lobby_created.emit(1,109775240000000002);await settle()
	expect(window.host_tools.visible and not window.ready_panel.visible,"successful hosting advances to the invitation step")
	expect(not window.tabs.tabs_visible,"connection choices are behind the Advanced connection action")
	window._invite_selected()
	expect(not api.calls.any(func(v):return v[0]=="invite"),"an empty selection cannot send an invitation")
	window.friend_list.select(0);window.friend_list.set_item_metadata(0,999)
	window._invite_selected()
	expect(not window.invitation_sent and window.steam_status.visible,"stale/non-friend entries show a recoverable error")
	window._load_friends();window.friend_list.select(0);window._invite_selected();window._invite_selected()
	expect(api.calls.filter(func(v):return v[0]=="invite").size()==1,"double clicking an invitation sends once")
	expect(window.ready_panel.visible and "3" in window.step_title.text,"sending an invitation advances to the final guided step")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("host-ready.png"))
	link.disconnect_table();window._set_intent("host");await settle();api.lobby_created.emit(1,109775240000000003);await settle()
	expect(not window.invitation_sent and window.host_tools.visible,"a new hosted table resets the invitation step and list")
	api.steam_shutdown.emit();await settle()
	expect(not link.initialized and link.lobby_id==0 and window.open_steam_button.visible,"Steam shutdown during setup releases the table and offers recovery")
	window.retry_until=Time.get_ticks_msec()-1;window._process(1.1)
	expect(window.retry_until==0 and "signing in" in window.steam_status.text,"automatic retry expires with a clear next action")
	window._set_intent("host");window._toggle_advanced();await settle()
	expect(window.tabs.current_tab==1 and not link.busy() and not window.auto_host_pending,"Advanced connection cancels queued automatic hosting")
	window._close();await settle();link._steam_shutdown();app.queue_free();api.queue_free();await settle()
	expect(not Engine.has_singleton("Steam"),"edge checks never contact a real Steam account")
	print("Connection edges: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

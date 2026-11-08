extends SceneTree
const Fakes=preload("steam_fakes.gd")
class AppFixture extends Hearth20App:
	func _ready() -> void:
		campaign=Hearth20Identity.new_campaign("Party guide fixture");session=Hearth20Session.new();add_child(session);session.configure(campaign);get_node("/root/SteamLink").attach(session)
		host_port=SpinBox.new();host_port.value=28930;add_child(host_port)
		join_address=LineEdit.new();join_secret=LineEdit.new();player_name=LineEdit.new()
		for field in [join_address,join_secret,player_name]:add_child(field)
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func settle() -> void:
	for frame in 4:await process_frame
func screenshot(name_value: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var output=OS.get_cmdline_user_args()[0];root.get_texture().get_image().save_png(output.path_join(name_value+".png"))
func run() -> void:
	root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
	var app=AppFixture.new();root.add_child(app);await settle()
	var guide=Hearth20PartyGuide.open(app,"host");await settle()
	expect(guide.role_tabs.get_tab_count()==3 and guide.role_tabs.current_tab==0,"field guide covers Steam host, Steam join and Direct IP")
	expect(guide.get_parent()==root,"field guide opens above the map and native sheet")
	await screenshot("host-guide")
	var again=Hearth20PartyGuide.open(app,"join");await settle()
	expect(again==guide and guide.role_tabs.current_tab==1,"reopening selects the requested role without duplicating the guide")
	await screenshot("join-guide")
	for dimensions in [Vector2i(740,560),Vector2i(880,640)]:
		guide.size=dimensions;await settle()
		expect(guide.role_tabs.size.x>650 and guide.role_tabs.size.y>300,"guide remains readable at "+str(dimensions))
	guide.queue_free();await settle()
	var link=root.get_node("SteamLink");var api=Fakes.Api.new();root.add_child(api);link.api=api;link.fake_backend=true;link.peer_factory=func():return Fakes.Peer.new()
	var window=app.open_connections("host");await settle()
	expect(link.initialized and link.state=="creating","Host a game prepares the private lobby automatically")
	expect(window.nickname.text=="Fixture Adventurer","a missing display name is supplied by Steam")
	expect(api.calls.filter(func(value):return value[0]=="create").size()==1,"one Host action creates one private table")
	window.nickname.text="The Brasskeeper";window.steam_host.pressed.emit();api.lobby_created.emit(1,109775240000000001);await settle()
	expect(api.calls.filter(func(value):return value[0]=="init").size()==1,"one-click hosting reuses Steam initialization")
	expect(link.state=="hosting" and window.friend_list.item_count==2,"hosting automatically loads the invitation list")
	expect(Hearth20PlayerProfile.preferences().display_name=="The Brasskeeper","the chosen display name survives the next launch")
	expect(window.journey.current_step==1,"host illustration advances to inviting friends")
	await screenshot("host-connection")
	window._close();link.disconnect_table();await settle();link._steam_shutdown()
	var lobby=109775240000000002;link.pending_invite=lobby
	window=app.open_connections("join");await settle()
	expect(link.state=="joining" and link.expected_lobby==lobby,"accepted invitations initialize Steam and join automatically")
	expect(window.nickname.text=="The Brasskeeper","automatic joining preserves the player's chosen display name")
	window.accept_invitation();window._prepare_steam()
	expect(api.calls.filter(func(value):return value[0]=="join").size()==1,"duplicate invitation events cannot start duplicate joins")
	window._close();await settle()
	expect(not link.busy() and link.pending_invite==0,"cancelling clears the invitation to prevent an unwanted retry")
	window=app.open_connections("join");await settle();window.invite_field.text="invalid invitation";window._join_steam()
	expect("invitation" in window.steam_status.text and not link.busy(),"invalid pasted invitations give a visible error")
	window.nickname.text="";window.invite_field.text=str(lobby);window._join_steam()
	expect(link.state=="joining" and window.nickname.text=="Fixture Adventurer","manual Join fills an empty name before connecting")
	window._close();link._steam_shutdown();app.queue_free();api.queue_free();await settle()
	expect(not Engine.has_singleton("Steam"),"onboarding checks never load the real Steam client")
	print("Party onboarding: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

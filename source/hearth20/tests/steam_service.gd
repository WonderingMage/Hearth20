extends SceneTree
const Fakes=preload("steam_fakes.gd")
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func run() -> void:
	expect(not Engine.has_singleton("Steam"),"opening Hearth20 does not load or initialize Steam")
	var original=get_root().get_node("SteamLink")
	expect(not original.initialized and not original.is_processing(),"the normal startup link is dormant")
	original.fake_backend=true
	expect(not original.initialize().ok and not Engine.has_singleton("Steam"),"a missing fake backend cannot fall through to real Steam during background checks")
	original.fake_backend=false
	for invalid in ["", "abc", "-1", "+1", "00123", "steam://joinlobby/999/123/456", "9223372036854775808"]:expect(Hearth20SteamLink.parse_lobby(invalid)==0,"reject invalid invitation: "+invalid)
	expect(Hearth20SteamLink.parse_lobby("steam://joinlobby/480/109775240000000001/76561198000000001")==109775240000000001,"Steam invitation link parses without opening a browser")
	var valid=Hearth20SteamLink.metadata("a".repeat(32));expect(Hearth20SteamLink.valid_metadata(valid),"Hearth20 Steam metadata matches this edition and wire format")
	for key in Hearth20SteamLink.META_KEYS:
		var changed=valid.duplicate();changed[key]="another game"
		expect(not Hearth20SteamLink.valid_metadata(changed),"foreign lobby rejected for "+key)
	var session=Hearth20Session.new();root.add_child(session);session.configure(Hearth20Identity.new_campaign("Steam fixture campaign"))
	var link=Hearth20SteamLink.new();root.add_child(link);var api=Fakes.Api.new();root.add_child(api);link.api=api;link.fake_backend=true
	link.peer_factory=func():var peer=Fakes.Peer.new();peer.ids[1]=api.lobby_owner;return peer
	link.attach(session)
	expect(api.calls.is_empty(),"attaching an application never starts Steam")
	api.running=false;expect(not link.initialize().ok and api.calls.is_empty(),"missing Steam gives a friendly error without initializing or launching it")
	api.running=true;api.init_status=2;expect(not link.initialize().ok and not link.initialized,"Steam initialization failure is recoverable")
	api.init_status=0;api.online=false;expect(not link.initialize().ok and not link.initialized,"offline accounts cannot create a table")
	api.online=true;expect(link.initialize().ok and link.initialized,"explicit Connect initializes the fake Steam API")
	expect(api.calls.any(func(call):return call==["init",480,false]),"shared AppID 480 is explicit and embedded render callbacks stay off")
	expect(link.host().ok and link.state=="creating","hosting waits for Steam's asynchronous callback")
	expect(api.calls.any(func(call):return call==["create",0,9]),"lobbies are private and bounded to DM plus eight players")
	api.lobby_created.emit(1,109775240000000001)
	expect(link.state=="hosting" and session.transport=="steam" and session.local_role=="dm","created lobby adopts the real session authority boundary")
	expect(session.invite_secret.length()==32 and Hearth20SteamLink.valid_metadata(api.data),"Steam session has a random invitation gate and edition metadata")
	expect(not session.multiplayer.multiplayer_peer.relay,"Steam peer-to-peer client relay remains disabled")
	expect(link.allows_peer(44),"only actual lobby members can reach the signing handshake")
	session.multiplayer.multiplayer_peer.ids[77]=76561198000000077
	expect(not link.allows_peer(77),"another Spacewar user cannot reach campaign data")
	expect(link.can_send(44),"low Steam send queue permits image chunks")
	api.pending=200000;expect(not link.can_send(44),"large send queue pauses image chunks before overflow");api.pending=0
	api.unacknowledged=600000;expect(not link.can_send(44),"unacknowledged data applies backpressure");api.unacknowledged=0
	api.send_rate=16777216;api.pending=200000
	expect(link.can_send(44),"a fast measured link receives a larger short send window")
	api.pending=1000000;expect(link.can_send(44),"a fast link can keep one RTT of transfer data in flight")
	api.pending=2000000;expect(not link.can_send(44),"a fast link still has bounded queue latency")
	api.pending=0;api.send_rate=262144
	expect(api.calls.has(["network-config",11,268435456]),"bulk transfers use the SDK maximum instead of an application bandwidth cap")
	expect(api.calls.has(["network-config",9,8388608]),"native send buffer accommodates adaptive high-throughput windows")
	expect(link.friends()[0].name=="Aurelia","friend list is sorted and independent of the overlay")
	expect(link.invite_friend(76561198000000002).ok and api.calls.any(func(call):return call[0]=="invite"),"in-game friend invitation calls Steam's lobby invite API")
	expect(not link.invite_friend(123).ok,"arbitrary IDs cannot bypass the friend picker")
	expect(link.invite_link().begins_with("steam://joinlobby/480/"),"copyable invite uses the correct shared AppID")
	link.disconnect_table();expect(session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and link.lobby_id==0,"leaving closes the peer and lobby")
	expect(not session.campaign.is_empty() and session.campaign.title=="Steam fixture campaign","DM campaign remains intact on disconnect")
	link.host();link.cancel();api.lobby_created.emit(1,109775240000000002)
	expect(link.state=="ready" and api.calls.has(["leave",109775240000000002]),"late create callback after Cancel leaves its orphan lobby")
	link.host();link.deadline=Time.get_ticks_msec()-1;link._process(.1)
	expect(not link.busy() and link.state=="error" and session.transport=="direct","timeout cancels without trapping the player")
	api.lobby_owner=76561198000000002;api.data={"h20_product":"other-spacewar-game"}
	expect(link.join("109775240000000003","Aurelia").ok,"valid link begins a join")
	api.lobby_joined.emit(109775240000000003,0,false,1)
	expect(link.state=="error" and session.transport=="direct" and link.lobby_id==0,"another game's lobby is left before creating a campaign connection")
	api.data=valid.duplicate();link.join("109775240000000004","Aurelia");api.lobby_joined.emit(109775240000000004,0,false,1)
	expect(link.state=="connecting" and session.local_role=="player" and session.transport=="steam","approved lobby joins the DM using a Steam ID")
	expect(link.allows_peer(1),"client accepts only its pinned lobby owner")
	session.local_player_id="verified-fixture";link.deadline=Time.get_ticks_msec()+1000;link._process(.01)
	expect(link.deadline>0,"verified identity still has a timeout until the first complete map arrives")
	link.transfer_update(.5,"Receiving map")
	expect(link.deadline>Time.get_ticks_msec()+44000,"active large-image progress refreshes the join timeout")
	api.lobby_owner=76561198000000003;expect(not link.allows_peer(1),"lobby owner substitution cannot silently replace the DM")
	api.lobby_chat_update.emit(109775240000000004,api.lobby_owner,api.lobby_owner,1)
	expect(not link.active() and session.client_snapshot.is_empty() and session.local_role=="dm","owner departure clears private player view and restores the local workspace")
	session.configure(Hearth20Identity.new_campaign("Preserved direct campaign"));api.lobby_owner=api.user
	link.host();api.lobby_created.emit(1,109775240000000005);api.steam_shutdown.emit()
	expect(not link.initialized and not link.active() and session.transport=="direct","Steam shutdown leaves the application usable")
	expect(session.campaign.title=="Preserved direct campaign","Steam shutdown preserves the local campaign")
	link.queue_free();session.queue_free();api.queue_free();await process_frame;await process_frame
	expect(not Engine.has_singleton("Steam"),"fake tests never load or contact the Steam client")
	print("Steam service: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

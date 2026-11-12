extends Node
class_name Hearth20SteamLink
## The Steam client is contacted only after a user chooses Steam mode.
signal changed
signal invite_received
const APP_ID=480
const VIRTUAL_PORT=28931
const WIRE="hearth20-steam-rpc-v1"
const TIMEOUT_MSEC=30000
const META_KEYS=["h20_product","h20_edition","h20_protocol","h20_schema","h20_wire","h20_gate"]
var api: Object
var peer_factory: Callable
var session: Node
var initialized=false
var state="idle"
var message="Open Steam and sign in, then connect here. Everyone should open Hearth20 before accepting an invitation."
var lobby_id=0
var host_id=0
var own_id=0
var display_name=""
var pending_invite=0
var deadline=0
var progress=0.
var transfer_message=""
var callbacks_tick=0.
var health_tick=0.
var expected_lobby=0
var expected_host=0
var wired=false
var fake_backend=false
var closing=false
var network_config_results={}
func _ready() -> void:
	set_process(false)
	var args=Array(OS.get_cmdline_args())+Array(OS.get_cmdline_user_args())
	var index=args.find("+connect_lobby")
	if index>=0 and index+1<args.size():pending_invite=parse_lobby(str(args[index+1]))
func attach(value: Node) -> void:
	if session==value:return
	if is_instance_valid(session) and session.steam_link==self:
		if session.snapshot_received.is_connected(_snapshot_arrived):session.snapshot_received.disconnect(_snapshot_arrived)
		session.steam_link=null
	session=value;session.steam_link=self
	session.snapshot_received.connect(_snapshot_arrived)
func busy() -> bool:return state in ["creating","joining","metadata","connecting"]
func active() -> bool:return lobby_id>0 and state in ["hosting","joined","connecting","metadata"]
func initialize() -> Dictionary:
	if initialized:return {"ok":true}
	if DisplayServer.get_name()=="headless" and (not fake_backend or not api is Node):return _fail("Steam sign-in is disabled in background checks. Open Hearth20 normally when you are ready to play.")
	if api==null:
		var native=Hearth20SteamRuntime.load_native()
		if not native.ok:return _fail(native.error)
		api=Engine.get_singleton("Steam")
	if not api.isSteamRunning():return _fail("Steam is not running. Open Steam and sign in, then press Connect Steam.")
	var result=api.steamInitEx(APP_ID,false)
	if not result is Dictionary or int(result.get("status",-1))!=0:return _fail("Steam could not connect. Check that you are signed in and try again.")
	if not api.loggedOn():api.steamShutdown();return _fail("Steam is offline. Sign in to Steam before hosting or joining.")
	initialized=true;own_id=int(api.getSteamID());display_name=str(api.getPersonaName()).left(40)
	if own_id<=0:initialized=false;api.steamShutdown();return _fail("Steam did not provide a player identity. Restart Steam and try again.")
	_wire();api.initRelayNetworkAccess();set_process(true)
	# Let Steam adapt to the link instead of inheriting its low bulk-transfer ceiling.
	network_config_results.minimum_rate=api.setGlobalConfigValueInt32(10,65536)
	# Use the SDK's supported maximum; congestion control chooses the actual rate.
	# Zero is clamped to a tiny rate by some SDK versions, so it is not "unlimited".
	network_config_results.adaptive_maximum=api.setGlobalConfigValueInt32(11,268435456)
	network_config_results.send_buffer=api.setGlobalConfigValueInt32(9,8388608)
	_set_status("ready","Connected to Steam as "+display_name+". Host a private table or accept a friend's invitation.")
	return {"ok":true}
func _wire() -> void:
	if wired:return
	for pair in [["lobby_created",_lobby_created],["lobby_joined",_lobby_joined],["lobby_data_update",_lobby_data_update],["lobby_chat_update",_lobby_chat_update],["join_requested",_join_requested],["steam_shutdown",_steam_shutdown],["steam_server_disconnected",_steam_offline]]:
		if api.has_signal(pair[0]):api.connect(pair[0],pair[1])
	wired=true
func _offline_session() -> bool:return is_instance_valid(session) and session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
func host() -> Dictionary:
	if not _offline_session():return _fail("Leave the active table before hosting another one.",false)
	if busy():return {"ok":false,"error":"A Steam connection is already in progress."}
	var result=initialize()
	if not result.ok:return result
	_leave_lobby();expected_lobby=0;deadline=Time.get_ticks_msec()+TIMEOUT_MSEC
	_set_status("creating","Preparing your private Steam table…");api.createLobby(0,Hearth20Session.MAX_CLIENTS+1)
	return {"ok":true,"pending":true}
func join(value: String,nickname: String) -> Dictionary:
	var id=parse_lobby(value)
	if id==0:return _fail("Paste a Hearth20 Steam invitation or lobby number.",false)
	if nickname.strip_edges().is_empty():return _fail("Enter your display name before joining.",false)
	if not _offline_session():return _fail("Leave the active table before accepting another invitation.",false)
	if busy():return {"ok":false,"error":"A Steam connection is already in progress."}
	var result=initialize()
	if not result.ok:return result
	_leave_lobby();session.pending_nickname=nickname.strip_edges().left(40);expected_lobby=id;deadline=Time.get_ticks_msec()+TIMEOUT_MSEC
	_set_status("joining","Opening the invited Steam table…");api.joinLobby(id)
	return {"ok":true,"pending":true}
static func parse_lobby(value: String) -> int:
	var text=value.strip_edges()
	if text.begins_with("steam://joinlobby/480/"):
		var pieces=text.trim_prefix("steam://joinlobby/480/").split("/");text=pieces[0]
	if text.is_empty() or text.length()>19 or not text.is_valid_int() or text.begins_with("+") or text.begins_with("-"):return 0
	var number=int(text)
	return number if number>0 and str(number)==text else 0
static func metadata(secret: String) -> Dictionary:
	return {"h20_product":Hearth20Identity.PRODUCT_ID,"h20_edition":Hearth20Identity.EDITION,"h20_protocol":str(Hearth20Identity.NETWORK_PROTOCOL),"h20_schema":str(Hearth20Identity.SCHEMA_VERSION),"h20_wire":WIRE,"h20_gate":secret}
static func valid_metadata(values: Dictionary) -> bool:
	var expected=metadata("")
	for key in META_KEYS:
		if not values.get(key) is String or (key!="h20_gate" and values[key]!=expected[key]):return false
	return values.h20_gate.length()==32 and values.h20_gate.is_valid_hex_number(false)
func _lobby_created(result: int,id: int) -> void:
	if state!="creating":
		if result==1 and id>0 and id!=lobby_id:api.leaveLobby(id)
		return
	if result!=1 or id<=0:_fail("Steam could not create a private table. Try again.");return
	lobby_id=id;host_id=own_id;expected_host=own_id
	var gate=Crypto.new().generate_random_bytes(16).hex_encode()
	for key in metadata(gate):
		if not api.setLobbyData(id,key,metadata(gate)[key]):_abort("Steam could not publish the table's connection details.");return
	api.setLobbyMemberLimit(id,Hearth20Session.MAX_CLIENTS+1);api.setLobbyJoinable(id,true)
	var peer=_make_peer()
	if peer==null or peer.create_host(VIRTUAL_PORT)!=OK:
		if peer!=null:peer.close()
		_abort("Steam could not open this table. Close another Hearth20 Steam window and try again.");return
	peer.set_server_relay(false)
	var applied=session.adopt_steam_peer(peer,true,gate,"")
	if not applied.ok:peer.close();_abort(applied.error);return
	deadline=0;_set_status("hosting","Your private Steam table is open. Invite your friends to join.")
func _lobby_joined(id: int,_permissions: int,_locked: bool,response: int) -> void:
	if state=="hosting" and id==lobby_id:return
	if state=="creating":
		if response==1 and int(api.getLobbyOwner(id))!=own_id:api.leaveLobby(id)
		return
	if state!="joining" or id!=expected_lobby:
		if response==1 and id!=lobby_id:api.leaveLobby(id)
		return
	if response!=1:
		pending_invite=0;expected_lobby=0;deadline=0
		_fail("Steam could not join that invitation. Ask the DM for a new invite and make sure the table is still open.");return
	lobby_id=id;host_id=int(api.getLobbyOwner(id));expected_host=host_id
	if host_id<=0 or host_id==own_id:_abort("This invitation does not point to another DM's table.");return
	_set_status("metadata","Checking the Hearth20 table…");api.requestLobbyData(id);_try_connect()
func _lobby_data_update(success: int,id: int,_member: int) -> void:
	if id!=lobby_id:return
	if success!=1 and state=="metadata":_abort("Steam could not read this invitation. Ask the DM to resend it.");return
	if state=="metadata":_try_connect()
	elif active() and int(api.getLobbyOwner(id))!=expected_host:_abort("The DM left this Steam table. Your local campaign is preserved.")
func _try_connect() -> void:
	if state!="metadata":return
	var values={}
	for key in META_KEYS:values[key]=str(api.getLobbyData(lobby_id,key))
	if values.h20_product.is_empty():return
	if not valid_metadata(values):_abort("This is another game or an incompatible Hearth20 build. Ask the DM to use the same Steam build.");return
	var peer=_make_peer()
	if peer==null or peer.create_client(host_id,VIRTUAL_PORT)!=OK:
		if peer!=null:peer.close()
		_abort("Steam could not connect to the DM. Check that each PC uses a different Steam account.");return
	peer.set_server_relay(false)
	var adopted=session.adopt_steam_peer(peer,false,values.h20_gate,session.pending_nickname)
	if not adopted.ok:peer.close();_abort(adopted.error);return
	pending_invite=0;deadline=Time.get_ticks_msec()+TIMEOUT_MSEC;_set_status("connecting","Connecting to the DM through Steam…")
func _make_peer():
	return peer_factory.call() if peer_factory.is_valid() else ClassDB.instantiate("SteamMultiplayerPeer")
func allows_peer(peer_id: int) -> bool:
	if not initialized or lobby_id<=0 or not is_instance_valid(session):return false
	var peer=session.multiplayer.multiplayer_peer
	if not peer.has_method("get_steam_id_for_peer_id"):return false
	var id=int(peer.get_steam_id_for_peer_id(peer_id))
	if id<=0:return false
	if session.local_role=="player":return peer_id==1 and id==expected_host and int(api.getLobbyOwner(lobby_id))==expected_host
	var members=int(api.getNumLobbyMembers(lobby_id))
	if members<1 or members>Hearth20Session.MAX_CLIENTS+1:return false
	for i in members:
		if int(api.getLobbyMemberByIndex(lobby_id,i))==id:return true
	return false
func can_send(peer_id: int) -> bool:
	if not allows_peer(peer_id):return false
	var peer=session.multiplayer.multiplayer_peer.get_peer(peer_id)
	if peer==null:return false
	var status=api.getConnectionRealTimeStatus(int(peer.get_connection_handle()),0,true)
	if int(status.get("response",0))!=1:return false
	var details: Dictionary=status.get("connection_status",{})
	var rate=maxi(65536,int(details.get("send_rate",262144)))
	# A 25 ms-only window starves long-distance links between callbacks. Allow
	# roughly one RTT of useful work while retaining a bounded native queue.
	var pending_limit=clampi(int(float(rate)*(.025+float(details.get("ping",50))/1000.))+65536,131072,4194304)
	var unacknowledged_limit=clampi(int(float(rate)*(.1+2.*float(details.get("ping",50))/1000.)),524288,8388608)
	return int(details.get("pending_reliable",99999999))<pending_limit and int(details.get("sent_unacknowledged_reliable",99999999))<unacknowledged_limit
func invite_friends() -> Dictionary:
	if state!="hosting" or lobby_id<=0:return {"ok":false,"error":"Host a Steam table first."}
	api.activateGameOverlayInviteDialog(lobby_id)
	return {"ok":true}
func friends() -> Array:
	var result=[]
	if not initialized:return result
	for i in mini(500,int(api.getFriendCount(4))):
		var id=int(api.getFriendByIndex(i,4));var name_value=str(api.getFriendPersonaName(id)).left(64)
		result.append({"id":id,"name":name_value})
	result.sort_custom(func(a,b):return a.name.naturalnocasecmp_to(b.name)<0)
	return result
func invite_friend(id: int) -> Dictionary:
	if state!="hosting" or lobby_id<=0:return {"ok":false,"error":"Host a Steam table first."}
	if not friends().any(func(friend):return friend.id==id):return {"ok":false,"error":"Choose one of your Steam friends."}
	if not api.inviteUserToLobby(lobby_id,id):return _fail("Steam could not send that invitation. Try again.",false)
	message="Steam invitation sent. Your friend should open Hearth20 before accepting.";changed.emit();return {"ok":true}
func invite_link() -> String:
	return "steam://joinlobby/480/%d/%d"%[lobby_id,host_id] if state=="hosting" else ""
func _join_requested(id: int,_friend: int) -> void:
	if id<=0:return
	if id==lobby_id and active():return
	pending_invite=id;invite_received.emit();changed.emit()
func _lobby_chat_update(id: int,_changed: int,_making: int,_state: int) -> void:
	if id==lobby_id and expected_host>0 and int(api.getLobbyOwner(id))!=expected_host:_abort("The DM left this Steam table. Your local campaign is preserved.")
	elif id==lobby_id and state=="hosting" and is_instance_valid(session):
		for peer_id in session.multiplayer.get_peers():
			if not allows_peer(peer_id):session.multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		changed.emit()
func _snapshot_arrived(snapshot: Dictionary) -> void:
	if snapshot.get("connection_closed",false):return
	if state=="connecting" and is_instance_valid(session) and session.transport=="steam":
		deadline=0;progress=1.;transfer_message="";_set_status("joined","You are connected to the Hearth20 Steam table.")
func transfer_update(value: float,note: String) -> void:
	progress=value;transfer_message=note
	if state=="connecting":deadline=Time.get_ticks_msec()+45000
	changed.emit()
func connection_lost() -> void:
	if not closing and lobby_id>0:_abort("The Steam connection ended. Ask the DM to keep the table open and join again.")
func disconnect_table() -> void:
	closing=true
	if is_instance_valid(session) and session.transport=="steam":session.stop_session()
	if is_instance_valid(session) and session.local_role=="player" and session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer:session.configure(session.campaign)
	_leave_lobby();expected_lobby=0;expected_host=0;deadline=0;progress=0.;transfer_message="";closing=false
	_set_status("ready" if initialized else "idle","Steam table closed. Your local campaign and character identity are preserved.")
func cancel() -> void:
	if busy():pending_invite=0;disconnect_table()
func _leave_lobby() -> void:
	if initialized and lobby_id>0:api.leaveLobby(lobby_id)
	lobby_id=0;host_id=0
func _abort(note: String) -> void:
	pending_invite=0
	disconnect_table();_fail(note)
func _steam_shutdown() -> void:
	disconnect_table();initialized=false;set_process(false);_set_status("error","Steam has closed. Open Steam and reconnect when you are ready.")
func _steam_offline(_reason: int) -> void:
	message="Steam is offline. Existing play may continue; new invitations need Steam to reconnect.";changed.emit()
func _process(delta: float) -> void:
	callbacks_tick+=delta;health_tick+=delta
	if initialized and callbacks_tick>=1./30.:callbacks_tick=0.;api.run_callbacks()
	if busy() and deadline>0 and Time.get_ticks_msec()>deadline:_abort("Steam took too long to connect. Cancelled safely; ask the DM to resend the invite.")
	if state=="metadata" and health_tick>.5:health_tick=0.;_try_connect()
func _set_status(next: String,note: String) -> void:state=next;message=note;changed.emit()
func _fail(note: String,change_state=true) -> Dictionary:
	message=note
	if change_state:state="error"
	changed.emit();return {"ok":false,"error":note}
func _exit_tree() -> void:
	closing=true
	if initialized:
		if is_instance_valid(session) and session.transport=="steam":session.multiplayer.multiplayer_peer.close()
		_leave_lobby();api.steamShutdown();initialized=false

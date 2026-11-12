extends Node
class_name Hearth20Session
## Small ENet host boundary for Hearth20. The host creates every public view.

signal status_changed(message: String)
signal state_changed(state: Dictionary)
signal snapshot_received(snapshot: Dictionary)
signal map_transfer_progress(state: Dictionary)
signal fx_received(event: Dictionary)
signal timeline_changed(entries: Array)
signal dice_rolled(entry: Dictionary)
signal table_request_finished(command: Dictionary, result: Dictionary)
signal ping_received(event: Dictionary)
signal tool_preview_received(event: Dictionary)
signal character_submission_result(result: Dictionary)
signal casino_action_result(result: Dictionary)
signal refreshment_event(event: Dictionary)
signal refreshment_action_result(result: Dictionary)

const MAX_CLIENTS := 8
const MAX_PORT := 65535
const MAX_SECRET_LENGTH := 128

var campaign: Dictionary = {}
var client_snapshot: Dictionary = {}
var local_role := "dm"
var local_player_id := "dm-local"
var invite_secret := ""
var listening_port := 0
var pending_nickname := "Player"
var remote_players: Dictionary = {}
var peer_to_player: Dictionary = {}
var token_owner: Dictionary = {}
var current_turn_id := "turn-0"
var dice_rng := RandomNumberGenerator.new()
var recent_requests: Dictionary = {}
var request_rates: Dictionary = {}
var template_undo: Array = []
var projection_cache: Dictionary = {}
var peer_asset_state: Dictionary = {}
var board_undo: Dictionary = {}
var preview_state: Dictionary = {}
var sight_cache: Dictionary = {}
var pending_proofs: Dictionary = {}
var token_drag_scope=""
var refreshment_tick=0.
var transport="direct"
var steam_link: Node
var steam_chunks=Hearth20SteamChunks.new()
var steam_outgoing={}
var steam_transfer_tick=0.
var pending_table_commands: Array = []
var steam_images=Hearth20SteamImages.new()
var peer_steam_images={}
var steam_peer_cursor=0
var map_transfer_state: Dictionary={"active":false,"progress":0.0,"received":0,"total":0,"phase":""}

func _ready() -> void:
	dice_rng.randomize()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(func():
		_clear_client_view()
		status_changed.emit("The Hearth20 host disconnected. Private table data cleared.")
		if transport=="steam" and is_instance_valid(steam_link):steam_link.connection_lost.call_deferred()
	)
	multiplayer.connection_failed.connect(func():
		_clear_client_view()
		status_changed.emit("Could not connect to the Hearth20 host. Private table data cleared.")
		if transport=="steam" and is_instance_valid(steam_link):steam_link.connection_lost.call_deferred()
	)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func configure(campaign_data: Dictionary) -> void:
	campaign = campaign_data
	Hearth20MapLibrary.discard_empty_starter(campaign,str(campaign.get("active_scene","")))
	if not campaign.has("map_covered"):
		campaign.map_covered=bool(Hearth20Contracts.find_scene(campaign,str(campaign.get("active_scene",""))).get("blackout",false))
	_sync_map_cover()
	token_drag_scope=Crypto.new().generate_random_bytes(16).hex_encode()
	projection_cache.clear()
	peer_asset_state.clear()
	template_undo.clear()
	board_undo.clear()
	preview_state.clear()
	sight_cache.clear()
	pending_proofs.clear()
	peer_steam_images.clear()
	local_role = "dm"
	local_player_id = "dm-local"
	if not Hearth20Contracts.valid_identifier(campaign.get("refreshment_scope","")):campaign.refreshment_scope="snacks-"+Crypto.new().generate_random_bytes(12).hex_encode()
	_load_refreshment_ledger()

func start_host(port: int) -> Dictionary:
	if not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:return {"ok":false,"error":"Leave the active table before hosting another game."}
	if is_instance_valid(steam_link) and steam_link.busy():return {"ok":false,"error":"Cancel the Steam connection before hosting by Direct IP."}
	if port < 1024 or port > MAX_PORT:
		return {"ok": false, "error": "Choose a port from 1024 to 65535."}
	var api:=multiplayer as SceneMultiplayer
	if api!=null: api.server_relay=false
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		return {"ok": false, "error": "Could not host the Hearth20 table (error %d)." % error}
	local_role="dm"
	local_player_id="dm-local"
	multiplayer.multiplayer_peer = peer
	transport="direct"
	listening_port=port
	invite_secret = _new_invite_secret()
	remote_players.clear()
	peer_to_player.clear()
	peer_asset_state.clear()
	peer_steam_images.clear()
	status_changed.emit("Hosting Hearth20 on port %d. Invite code: %s" % [port, invite_secret])
	return {"ok": true, "invite_secret": invite_secret}

func join_host(address: String, port: int, secret: String, nickname: String) -> Dictionary:
	if not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:return {"ok":false,"error":"Leave the active table before joining another game."}
	if is_instance_valid(steam_link) and steam_link.busy():return {"ok":false,"error":"Cancel the Steam connection before joining by Direct IP."}
	var clean_address := address.strip_edges()
	var clean_name := nickname.strip_edges().left(40)
	if clean_address.is_empty() or clean_name.is_empty() or port < 1024 or port > MAX_PORT or secret.is_empty() or secret.length() > MAX_SECRET_LENGTH:
		return {"ok": false, "error": "Enter a host, port, invite code, and player name."}
	if clean_address.length()>255 or clean_address.contains("/") or clean_address.contains("\\") or clean_address.contains(" ") or clean_address.contains("\t") or clean_address.contains("\n") or clean_address.contains("\r"):
		return {"ok":false,"error":"Enter the DM’s IP address or host name. Put the port in the separate port box."}
	if Hearth20PlayerProfile.key()==null: return {"ok":false,"error":"Could not open your saved player identity. Your existing identity file was preserved."}
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(clean_address, port)
	if error != OK:
		peer.close()
		return {"ok": false, "error": "Could not connect to the Hearth20 host (error %d)." % error}
	Hearth20PlayerProfile.remember(clean_name,clean_address,port)
	local_role="player"
	_clear_client_view()
	multiplayer.multiplayer_peer = peer
	transport="direct"
	local_role = "player"
	local_player_id = ""
	invite_secret = secret
	pending_nickname = clean_name
	return {"ok": true}

func adopt_steam_peer(peer: MultiplayerPeer,hosting: bool,secret: String,nickname: String) -> Dictionary:
	if not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:return {"ok":false,"error":"Leave the active table before connecting through Steam."}
	if not is_instance_valid(steam_link) or not steam_link.initialized:return {"ok":false,"error":"Connect to Steam first."}
	if secret.length()!=32 or not secret.is_valid_hex_number(false):return {"ok":false,"error":"The Steam invitation is invalid."}
	if not hosting and (nickname.strip_edges().is_empty() or Hearth20PlayerProfile.key()==null):return {"ok":false,"error":"Choose a display name and make sure your local player profile can be saved."}
	var api=multiplayer as SceneMultiplayer
	if api!=null:api.server_relay=false
	transport="steam";listening_port=0;invite_secret=secret;local_role="dm" if hosting else "player"
	remote_players.clear();peer_to_player.clear();peer_asset_state.clear();peer_steam_images.clear();pending_proofs.clear();steam_chunks.clear();steam_outgoing.clear()
	if hosting:local_player_id="dm-local"
	else:
		_clear_client_view();pending_nickname=nickname.strip_edges().left(40)
		var remembered=Hearth20PlayerProfile.preferences();Hearth20PlayerProfile.remember(pending_nickname,remembered.address,remembered.port)
	multiplayer.multiplayer_peer=peer
	status_changed.emit("Steam table ready. Invite friends to your private lobby." if hosting else "Connecting to the DM through Steam…")
	return {"ok":true}

func stop_session() -> void:
	var was_steam=transport=="steam"
	if multiplayer.multiplayer_peer!=null:multiplayer.multiplayer_peer.close()
	transport="direct";steam_chunks.clear();steam_outgoing.clear();peer_steam_images.clear()
	listening_port=0
	_clear_client_view()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	remote_players.clear()
	peer_to_player.clear()
	token_owner.clear()
	recent_requests.clear()
	request_rates.clear()
	projection_cache.clear()
	peer_asset_state.clear()
	pending_proofs.clear()
	status_changed.emit("Table disconnected.")
	if was_steam and is_instance_valid(steam_link) and not steam_link.closing:steam_link.disconnect_table()

func _clear_client_view() -> void:
	_finish_map_download()
	steam_images.clear()
	var interrupted=pending_table_commands.duplicate();pending_table_commands.clear()
	for command in interrupted:table_request_finished.emit(command,{"ok":false,"error":"The table disconnected before confirming this request."})
	client_snapshot.clear()
	local_player_id = "" if local_role == "player" else "dm-local"
	if local_role != "player":
		return
	var empty := Hearth20Identity.network_identity()
	empty.merge({"revision": 0, "connection_closed": true, "scene": {"id": "disconnected", "title": "No active table", "width_cells": 24, "height_cells": 16, "cell_pixels": 64.0, "feet_per_cell": 5.0, "grid_visible": false, "walls": [], "doors": [], "props": []}, "actors": [], "sheets": [], "timeline": [], "handouts": [], "assets": {}, "fx": [], "map_png": PackedByteArray(), "map_sha256": Hearth20Contracts.sha256(PackedByteArray()), "vision_mask": {}}, true)
	timeline_changed.emit([])
	snapshot_received.emit(empty)

@rpc("any_peer", "call_remote", "reliable")
func send_handshake(identity: Dictionary, secret: String, nickname: String, public_pem: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if transport=="steam" and (not is_instance_valid(steam_link) or not steam_link.allows_peer(peer_id) or peer_to_player.size()>=MAX_CLIENTS and not peer_to_player.has(peer_id)):
		_reject_peer(peer_id);return
	if not Hearth20Identity.validate_network_identity(identity) or secret != invite_secret or nickname.strip_edges().is_empty() or nickname.length() > 40 or not Hearth20PlayerProfile.valid_public(public_pem):
		_reject_peer(peer_id)
		return
	if peer_to_player.has(peer_id):
		_send_peer_snapshot(peer_id, str(peer_to_player[peer_id]))
		return
	if pending_proofs.has(peer_id): return
	var nonce:=Crypto.new().generate_random_bytes(32)
	var features: Array=identity.get("steam_features",[]) if identity.get("steam_features",[]) is Array else []
	var image_version:=2 if "image-cache-v2" in features else 1 if transport=="steam" and "image-cache-v1" in features else 0
	pending_proofs[peer_id]={"nonce":nonce,"public_key":public_pem,"nickname":nickname.strip_edges(),"expires":Time.get_ticks_msec()+15000,"image_cache":image_version}
	player_challenge.rpc_id(peer_id,nonce)

@rpc("authority", "call_remote", "reliable")
func player_challenge(nonce: PackedByteArray) -> void:
	if local_role!="player" or multiplayer.get_remote_sender_id()!=1 or nonce.size()!=32: return
	prove_player.rpc_id(1,Hearth20PlayerProfile.sign(nonce))

@rpc("any_peer", "call_remote", "reliable")
func prove_player(signature: PackedByteArray) -> void:
	if local_role!="dm" or not multiplayer.is_server(): return
	var peer_id:=multiplayer.get_remote_sender_id()
	if transport=="steam" and (not is_instance_valid(steam_link) or not steam_link.allows_peer(peer_id) or peer_to_player.size()>=MAX_CLIENTS):
		_reject_peer(peer_id);return
	var pending: Dictionary=pending_proofs.get(peer_id,{})
	pending_proofs.erase(peer_id)
	if pending.is_empty() or Time.get_ticks_msec()>int(pending.expires) or not Hearth20PlayerProfile.verify(pending.nonce,pending.public_key,signature):
		_reject_peer(peer_id); return
	var player_id:=Hearth20PlayerProfile.principal(str(pending.public_key))
	if remote_players.has(player_id):
		_reject_peer(peer_id); return
	if not campaign.has("participants"): campaign.participants={}
	if not campaign.participants.has(player_id) and campaign.participants.size()>=256:
		_reject_peer(peer_id); return
	var nickname: String=pending.nickname
	var participant: Dictionary=campaign.participants.get(player_id,{}).duplicate(true)
	participant.merge({"public_key":pending.public_key,"display_name":nickname},true)
	campaign.participants[player_id]=participant
	campaign.revision=int(campaign.get("revision",0))+1
	peer_to_player[peer_id] = player_id
	if int(pending.get("image_cache",0))>0:
		peer_steam_images[peer_id]=Hearth20SteamImages.new();peer_steam_images[peer_id].protocol_version=int(pending.image_cache)
	remote_players[player_id] = {"peer_id": peer_id, "nickname": nickname.strip_edges(), "joined_at": Time.get_unix_time_from_system()}
	status_changed.emit("%s joined the table." % nickname.strip_edges())
	connected_player.rpc_id(peer_id, player_id)
	_send_peer_snapshot(peer_id, player_id)
	_broadcast_dm_state()

func _reject_peer(peer_id: int) -> void:
	pending_proofs.erase(peer_id)
	if peer_id not in multiplayer.get_peers(): return
	var api:=multiplayer as SceneMultiplayer
	if api!=null: api.disconnect_peer(peer_id)
	else: multiplayer.multiplayer_peer.disconnect_peer(peer_id,true)

@rpc("any_peer", "call_remote", "reliable")
func request_move(actor_id: String, from: Vector2, to: Vector2, expected_revision: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var player_id := str(peer_to_player.get(peer_id, ""))
	if player_id.is_empty() or is_spectating(player_id) or expected_revision != int(campaign.get("revision", -1)):
		_send_peer_snapshot(peer_id, player_id)
		return
	var actor := Hearth20Contracts.find_actor(campaign, actor_id)
	if actor.is_empty() or str(actor.get("owner_player_id", "")) != player_id:
		status_changed.emit("Rejected a move request that did not name the sender's assigned hero.")
		_send_peer_snapshot(peer_id, player_id)
		return
	var scene := Hearth20Contracts.find_scene(campaign, str(campaign.get("active_scene", "")))
	var cells := from.distance_to(to)
	var measured_feet := cells * float(scene.get("feet_per_cell", 5.0))
	var result := Hearth20Contracts.authorize_and_apply_move(campaign, player_id, "player", actor_id, from, to, measured_feet)
	if not result.ok:
		status_changed.emit("Move rejected: %s." % str(result.reason).replace("_", " "))
		_send_peer_snapshot(peer_id, player_id)
		return
	_broadcast_snapshots()

@rpc("authority", "call_remote", "reliable")
func receive_snapshot(snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var completed_transfer=""
	if snapshot.has("_h20_cancel"):
		if multiplayer.get_remote_sender_id()==1 and Hearth20Identity.validate_network_identity(snapshot) and (transport!="steam" or steam_link.allows_peer(1)) and snapshot._h20_cancel is String:
			steam_chunks.cancel(1,snapshot._h20_cancel);_finish_map_download(snapshot._h20_cancel)
		return
	if snapshot.has("_h20_transfer"):
		if multiplayer.get_remote_sender_id()!=1 or not Hearth20Identity.validate_network_identity(snapshot) or (transport=="steam" and not steam_link.allows_peer(1)):return
		var received=steam_chunks.accept(1,snapshot,"snapshot")
		if not received.ok:_steam_transfer_failed(1,received.error);return
		if received.get("replayed",false):return
		var fraction:=float(received.get("progress",0.))
		if transport=="steam":steam_link.transfer_update(fraction,"Receiving the battlemap and campaign…")
		map_transfer_state={"id":str(snapshot._h20_transfer.id),"active":true,"progress":fraction,"received":roundi(fraction*float(snapshot._h20_transfer.size)),"total":int(snapshot._h20_transfer.size),"phase":"Preparing map…" if received.complete else "Downloading map…"}
		map_transfer_progress.emit(map_transfer_state.duplicate())
		if not received.complete:return
		completed_transfer=str(snapshot._h20_transfer.id)
		if not received.value is Dictionary:_steam_transfer_failed(1,"The table transfer was invalid.");return
		snapshot=received.value
	if multiplayer.get_remote_sender_id() != 1 or not Hearth20Identity.validate_network_identity(snapshot) or not snapshot.get("revision", null) is int or int(snapshot.revision) < 0 or not snapshot.get("scene") is Dictionary or not snapshot.get("actors") is Array or not snapshot.get("assets") is Dictionary:
		return
	if int(snapshot.revision)<int(client_snapshot.get("revision",-1)):
		if not completed_transfer.is_empty():_finish_map_download(completed_transfer)
		return
	if snapshot.get("_h20_image_cache",false):
		var decoded=steam_images.decode(snapshot)
		if not decoded.ok:_steam_transfer_failed(1,decoded.error);return
		snapshot=decoded.snapshot
	if bool(snapshot.get("map_unchanged", false)):
		if str(client_snapshot.get("map_sha256", "")) != str(snapshot.get("map_sha256", "")):
			return
		snapshot.map_png = client_snapshot.get("map_png", PackedByteArray())
	if bool(snapshot.get("assets_unchanged", false)):
		if client_snapshot.is_empty():
			return
		snapshot.assets = client_snapshot.get("assets", {})
	if bool(snapshot.get("light_unchanged",false)):
		if client_snapshot.get("scene",{}).get("id","")!=snapshot.scene.get("id",""): return
		snapshot.scene.light_field=client_snapshot.get("scene",{}).get("light_field",{})
	snapshot.erase("map_unchanged")
	snapshot.erase("assets_unchanged")
	snapshot.erase("light_unchanged")
	steam_images.remember(snapshot)
	client_snapshot = snapshot
	timeline_changed.emit(timeline_for_local())
	snapshot_received.emit(client_snapshot.duplicate(true))
	if map_transfer_state.get("active",false):
		_finish_map_download.call_deferred(completed_transfer if not completed_transfer.is_empty() else str(map_transfer_state.get("id","")))

func _finish_map_download(expected_id: String="") -> void:
	if not expected_id.is_empty() and str(map_transfer_state.get("id",""))!=expected_id:return
	if not map_transfer_state.get("active",false):return
	map_transfer_state.active=false;map_transfer_progress.emit(map_transfer_state.duplicate())

@rpc("authority", "call_remote", "reliable")
func connected_player(player_id: String) -> void:
	if multiplayer.is_server() or not Hearth20Contracts.valid_identifier(player_id):
		return
	local_player_id = player_id
	status_changed.emit("Connected to Hearth20 as %s." % pending_nickname)

@rpc("authority", "call_remote", "reliable")
func receive_fx(event: Dictionary) -> void:
	if multiplayer.is_server() or multiplayer.get_remote_sender_id() != 1 or not Hearth20Identity.validate_network_identity(event):
		return
	fx_received.emit(event.duplicate(true))

func assign_hero(actor_id: String, player_id: String) -> Dictionary:
	if not bool(Hearth20Contracts.find_actor(campaign,actor_id).get("is_hero",false)): return {"ok":false,"error":"Choose an existing hero."}
	return grant_token_control(actor_id,player_id,false)

func create_inventory_token(name_value: String, hero: bool=false) -> Dictionary:
	if local_role!="dm": return {"ok":false,"error":"Only the DM manages campaign tokens."}
	if name_value.strip_edges().is_empty() or name_value.length()>64 or campaign.actors.size()>=Hearth20Contracts.MAX_ACTORS: return {"ok":false,"error":"Enter a token name (up to 64 characters), within the campaign token limit."}
	var actor:=Hearth20TokenInventory.new_actor(name_value,hero,Hearth20Contracts.find_scene(campaign,campaign.active_scene),Vector2(.5,.5))
	actor.in_inventory=true; campaign.actors.append(actor); _inventory_changed()
	return {"ok":true,"id":str(actor.id)}

func store_inventory_token(id: String) -> Dictionary:
	if local_role!="dm": return {"ok":false,"error":"Only the DM stores campaign tokens."}
	var actor:=Hearth20Contracts.find_actor(campaign,id)
	if actor.is_empty() or actor.get("decorative",false): return {"ok":false,"error":"Choose a campaign token."}
	actor.in_inventory=true; _inventory_changed(); return {"ok":true}

func place_inventory_token(id: String, point: Vector2) -> Dictionary:
	if local_role!="dm": return {"ok":false,"error":"Only the DM places campaign tokens."}
	var actor:=Hearth20Contracts.find_actor(campaign,id)
	var scene:=Hearth20Contracts.find_scene(campaign,campaign.active_scene)
	if actor.is_empty() or actor.get("decorative",false) or not Hearth20Contracts._point_inside_scene(point,scene): return {"ok":false,"error":"Choose a token and a position inside this map."}
	actor.scene_id=scene.id; actor.position=Hearth20TokenInventory.snap_position(scene,point); actor.in_inventory=false
	_inventory_changed(); return {"ok":true}

func duplicate_inventory_token(id: String) -> Dictionary:
	if local_role!="dm" or campaign.actors.size()>=Hearth20Contracts.MAX_ACTORS: return {"ok":false,"error":"Only the DM duplicates tokens within the campaign limit."}
	var source:=Hearth20Contracts.find_actor(campaign,id)
	if source.is_empty() or source.get("decorative",false): return {"ok":false,"error":"Choose a campaign token."}
	var actor:=source.duplicate(true)
	actor.id="actor-%d-%d"%[Time.get_ticks_usec(),randi()%100000]; actor.name=(str(actor.get("name","Token")).left(59)+" copy"); actor.in_inventory=true
	actor.owner_player_id=""; actor.movement_policy=Hearth20Contracts.default_movement_policy("blocked",[]); actor.erase("turn_allowance_turn_id")
	campaign.actors.append(actor); _inventory_changed(); return {"ok":true,"id":str(actor.id)}

func center_scene_tokens() -> Dictionary:
	if local_role!="dm": return {"ok":false,"error":"Only the DM aligns tokens."}
	var scene:=Hearth20Contracts.find_scene(campaign,campaign.active_scene)
	if not scene.get("snap_to_grid",true): return {"ok":false,"error":"Enable grid snapping before aligning map tokens."}
	for actor in Hearth20TokenInventory.entries(campaign):
		if not actor.get("in_inventory",false) and actor.scene_id==scene.id: actor.position=Hearth20TokenInventory.snap_position(scene,actor.position)
	_inventory_changed(); return {"ok":true}

func _inventory_changed() -> void:
	campaign.revision=int(campaign.get("revision",0))+1; projection_cache.clear(); sight_cache.clear(); _broadcast_snapshots()

func grant_token_control(actor_id: String, player_id: String, allow_move: bool=true) -> Dictionary:
	if local_role!="dm" or (not player_id.is_empty() and not remote_players.has(player_id) and not campaign.get("participants",{}).has(player_id)):
		return {"ok":false,"error":"Only the DM can choose a connected or saved player."}
	var actor := Hearth20Contracts.find_actor(campaign, actor_id)
	if actor.is_empty() or actor.get("decorative",false) or actor.get("layer","tokens")!="tokens":
		return {"ok":false,"error":"Choose a token on the token layer."}
	actor.owner_player_id = player_id
	token_owner[actor_id] = player_id
	var controllers: Array[String]=[]
	if not player_id.is_empty(): controllers.append(player_id)
	var policy := Hearth20Contracts.default_movement_policy("free_until_revoked" if allow_move and not player_id.is_empty() else "blocked", controllers)
	actor.movement_policy = policy
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_broadcast_snapshots()
	return {"ok": true}

func set_player_movement(actor_id: String, mode: String, distance_feet: float = 0.0, expiry: String = "campaign") -> Dictionary:
	if local_role != "dm":
		return {"ok": false, "error": "Only the DM changes movement permissions."}
	var actor := Hearth20Contracts.find_actor(campaign, actor_id)
	if actor.is_empty():
		return {"ok": false, "error": "Select a token."}
	var controllers: Array[String] = []
	if not str(actor.get("owner_player_id", "")).is_empty():
		controllers.append(str(actor.owner_player_id))
	var grant_id := "grant-%d" % Time.get_ticks_usec()
	var result := Hearth20Contracts.set_movement_policy(campaign, actor_id, mode, controllers, distance_feet, grant_id, expiry)
	if result.ok:
		_broadcast_snapshots()
	return result

func set_scene_fog(rects: Array) -> void:
	if local_role != "dm":
		return
	var scene := Hearth20Contracts.find_scene(campaign, str(campaign.get("active_scene", "")))
	if scene.is_empty():
		return
	scene.fog_rects = rects.duplicate(true)
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_broadcast_snapshots()

func play_fire_rocket(source: Vector2, destination: Vector2, target_actor_id: String = "") -> Dictionary:
	if local_role != "dm":
		return {"ok": false, "error": "Only the DM may synchronize an effect."}
	var scene := Hearth20Contracts.find_scene(campaign, str(campaign.get("active_scene", "")))
	if scene.is_empty():
		return {"ok": false, "error": "No active scene."}
	var effect := Hearth20FxRenderer.new()
	var result := effect.play_fire_rocket(source, destination)
	if not result.ok:
		return result
	var event: Dictionary = result.event
	event.target_actor_id = target_actor_id
	event.center = destination
	event.start = source
	event.end = destination
	event.preset = "fire-rocket-impact-v1"
	event.merge(Hearth20Identity.network_identity(), true)
	var target := Hearth20Contracts.find_actor(campaign, target_actor_id) if not target_actor_id.is_empty() else {}
	# The synchronized lifetime uses host monotonic microseconds only. Clients
	# receive a remaining delay and start their local visual timeline on receipt.
	event.public = (target.is_empty() or not bool(target.get("hidden", false))) \
		and Hearth20Contracts.point_is_visible(source, scene) \
		and Hearth20Contracts.point_is_visible(destination, scene) \
		and Hearth20Contracts.path_is_visible(source, destination, scene)
	scene.fx.append(event)
	if scene.fx.size() > Hearth20Contracts.MAX_FX_EVENTS:
		scene.fx.pop_front()
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_broadcast_snapshots()
	return {"ok": true, "event": event}

func _send_peer_snapshot(peer_id: int, player_id: String,map_override: Variant=null) -> void:
	if peer_id not in multiplayer.get_peers(): return
	var snapshot := _project_for(player_id,map_override)
	if not snapshot.is_empty():
		# Redacting a large map can outlast a peer's connection. ENet may have
		# closed its channels before SceneMultiplayer emits disconnection.
		if peer_id not in multiplayer.get_peers(): return
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
			var remote: ENetPacketPeer=multiplayer.multiplayer_peer.get_peer(peer_id)
			if remote==null or remote.get_state()!=ENetPacketPeer.STATE_CONNECTED or remote.get_channels()==0: return
		# Cached maps + cached lighting make reveal/movement small enough to send
		# directly, bypassing the bulk snapshot queue. Old peers keep their v1 path.
		if peer_steam_images.has(peer_id) and peer_steam_images[peer_id].protocol_version>=2:
			var compact: Dictionary=peer_steam_images[peer_id].encode(snapshot)
			if var_to_bytes(compact).size()<=65536:
				if steam_outgoing.has(peer_id):
					var active: Dictionary=steam_outgoing[peer_id].active
					if not active.is_empty():
						var cancel:=Hearth20Identity.network_identity();cancel._h20_cancel=active.id;rpc_id(peer_id,"receive_snapshot",cancel)
					steam_outgoing.erase(peer_id)
				if rpc_id(peer_id,"receive_snapshot",compact)==OK:peer_steam_images[peer_id].remember(snapshot,true)
				return
		if transport=="steam" or peer_steam_images.has(peer_id):
			if not steam_outgoing.has(peer_id):steam_outgoing[peer_id]={"active":{},"pending":{},"cache":{},"kind":"snapshot"}
			var slot: Dictionary=steam_outgoing[peer_id]
			if peer_steam_images.has(peer_id) and not slot.active.is_empty():
				var actors=snapshot.actors.map(func(actor):return str(actor.id))
				if slot.cache.get("map","")!=snapshot.get("map_sha256","") or slot.cache.get("actors",[]).any(func(id):return id not in actors):
					var cancel=Hearth20Identity.network_identity();cancel._h20_cancel=slot.active.id
					rpc_id(peer_id,"receive_snapshot",cancel);slot.active={};slot.cache={}
			# Keep only the latest waiting state. The in-flight state always finishes first.
			steam_outgoing[peer_id].pending=snapshot
			return
		var assets_hash := Hearth20Contracts.sha256(var_to_bytes(snapshot.assets))
		var previous: Dictionary = peer_asset_state.get(peer_id, {})
		var map_hash := str(snapshot.get("map_sha256", ""))
		var light_hash:=Hearth20Contracts.sha256(var_to_bytes(snapshot.scene.get("light_field",{})))
		if previous.get("map", "") == map_hash:
			snapshot.map_png = PackedByteArray()
			snapshot.map_unchanged = true
		if previous.get("assets", "") == assets_hash:
			snapshot.assets = {}
			snapshot.assets_unchanged = true
		if previous.get("light","")==light_hash and previous.get("scene","")==str(snapshot.scene.get("id","")):
			snapshot.scene.light_field={}; snapshot.light_unchanged=true
		peer_asset_state[peer_id] = {"map": map_hash, "assets": assets_hash,"light":light_hash,"scene":str(snapshot.scene.get("id",""))}
		receive_snapshot.rpc_id(peer_id, snapshot)

func _broadcast_snapshots() -> void:
	if local_role != "dm":
		return
	var scene=Hearth20Contracts.find_scene(campaign,str(campaign.get("active_scene","")))
	var shared_map=Hearth20Assets.read_asset(campaign,str(scene.get("map_asset","")),"map") if not peer_to_player.is_empty() and not bool(campaign.get("map_covered",false)) and not bool(scene.get("blackout",false)) else PackedByteArray()
	for peer_variant in peer_to_player:
		_send_peer_snapshot(int(peer_variant), str(peer_to_player[peer_variant]),shared_map)
	_broadcast_dm_state()

func _broadcast_dm_state() -> void:
	state_changed.emit({"campaign": campaign, "players": remote_players.duplicate(true)})
	timeline_changed.emit(timeline_for_local())

func _project_for(player_id: String,map_override: Variant=null) -> Dictionary:
	var scene := Hearth20Contracts.find_scene(campaign, str(campaign.get("active_scene", "")))
	if not scene.is_empty():
		var now := Time.get_ticks_usec()
		scene.fx = scene.get("fx", []).filter(func(event: Dictionary) -> bool: return int(event.get("started_usec", now)) + int(event.get("travel_usec", 0)) + int(event.get("impact_duration_usec", 950000)) >= now)
	# Chat/dice do not alter sight. Reuse the already redacted base instead of
	# ray-testing and re-encoding every map pixel for an unrelated message.
	var visual_key := Hearth20Contracts.sha256(var_to_bytes([scene, campaign.get("actors", []), campaign.get("turn_remaining_feet", {}),Hearth20Vision.view_actor_id(campaign,player_id,scene)]))
	var previous: Dictionary = projection_cache.get(player_id, {})
	var projected: Dictionary
	var covered: bool=bool(campaign.get("map_covered",false)) or bool(scene.get("blackout",false))
	if covered:
		projected=Hearth20Contracts.covered_projection(campaign,player_id)
	elif str(previous.get("key", "")) == visual_key and scene.get("fx", []).is_empty():
		projected = previous.snapshot.duplicate(true)
	else:
		var map_bytes: PackedByteArray=map_override if map_override is PackedByteArray else Hearth20Assets.read_asset(campaign,str(scene.get("map_asset","")),"map") if not scene.is_empty() else PackedByteArray()
		projected = Hearth20Contracts.project_for_player(campaign, player_id, map_bytes)
		if not projected.is_empty():
			projection_cache[player_id] = {"key": visual_key, "snapshot": projected.duplicate(true)}
	if not projected.is_empty():
		projected.revision = int(campaign.get("revision", 0))
		projected.timeline = _timeline_for(player_id)
		projected.handouts = _handouts_for(player_id)
		projected.fx_presets = campaign.get("fx_presets",{}).duplicate(true)
		projected.character_required = Hearth20JoinCharacter.current(campaign,player_id).is_empty()
		projected.character_in_inventory = bool(Hearth20JoinCharacter.current(campaign,player_id).get("in_inventory",false))
		projected.join_character_id = str(Hearth20JoinCharacter.current(campaign,player_id).get("id",""))
		projected.table_mode=str(campaign.get("table_mode","map"))
		projected.casino = Hearth20TavernGames.project(campaign,player_id)
		projected.casino_receipts = Hearth20CasinoWallet.pending(campaign,player_id)
		projected.refreshments=Hearth20Refreshments.view(campaign,player_id,Time.get_unix_time_from_system())
		# Include sheets/history in the aggregate bound, not just image assets.
		if var_to_bytes(projected).size() > Hearth20Contracts.MAX_PROJECTION_BYTES:
			return {}
	return projected

func _on_peer_disconnected(peer_id: int) -> void:
	steam_chunks.clear_peer(peer_id);steam_outgoing.erase(peer_id)
	peer_steam_images.erase(peer_id)
	pending_proofs.erase(peer_id)
	if local_role != "dm":
		return
	var player_id := str(peer_to_player.get(peer_id, ""))
	remote_players.erase(player_id)
	peer_to_player.erase(peer_id)
	peer_asset_state.erase(peer_id)
	projection_cache.erase(player_id)
	request_rates.erase(player_id)
	_broadcast_dm_state()

func timeline_for_local() -> Array:
	return client_snapshot.get("timeline", []).duplicate(true) if local_role == "player" else _timeline_for("dm-local")

func _timeline_for(player_id: String) -> Array:
	var output: Array = []
	for entry in campaign.get("table_timeline", []):
		if not entry is Dictionary:
			continue
		var recipients: Array = entry.get("recipients", []) if entry.get("recipients", []) is Array else []
		if str(entry.get("visibility", "")) == "self" and not recipients.has(player_id):
			continue
		if str(entry.get("visibility", "")) == "secret" and player_id != "dm-local":
			continue
		if player_id != "dm-local" and str(entry.get("visibility", "gm")) != "public" and not recipients.has(player_id):
			continue
		var clean := {}
		for field in ["id", "type", "sender", "actor_name", "label", "visibility", "total", "formula", "dice", "kept", "modifier", "mode", "dice_set", "text", "time"]:
			if entry.has(field):
				clean[field] = Hearth20TableData.safe_value(entry[field])
		output.append(clean)
	return output.slice(-200)

func _append_entry(entry: Dictionary, player_id: String) -> void:
	entry.id = "event-%d-%d" % [Time.get_ticks_usec(), dice_rng.randi_range(0, 1000000)]
	entry.time = Time.get_datetime_string_from_system(false, true)
	entry.sender = "DM" if player_id == "dm-local" else str(remote_players.get(player_id, {}).get("nickname", "Player")).left(40)
	entry.recipients = [player_id]
	if not campaign.get("table_timeline") is Array:
		campaign.table_timeline = []
	campaign.table_timeline.append(entry)
	while campaign.table_timeline.size() > 200:
		campaign.table_timeline.pop_front()
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_broadcast_snapshots()

func submit_roll(actor_id: String, kind: String, key: String = "", mode: String = "normal", visibility: String = "public", expression: String = "1d20") -> Dictionary:
	return _submit_table_request({"action": "roll", "actor_id": actor_id, "kind": kind, "key": key, "mode": mode, "visibility": visibility, "expression": expression})

func _publish_dice_animation(entry: Dictionary) -> void:
	if local_role!="dm" or entry.get("type","")!="roll": return
	var local:=_timeline_for("dm-local")
	if not local.is_empty() and local.back().id==entry.id: dice_rolled.emit(local.back().duplicate(true))
	for peer in peer_to_player:
		var authorized:=_timeline_for(str(peer_to_player[peer]))
		if not authorized.is_empty() and authorized.back().id==entry.id:
			var packet: Dictionary=authorized.back().duplicate(true); packet.merge(Hearth20Identity.network_identity())
			receive_dice_animation.rpc_id(int(peer),packet)

@rpc("any_peer", "call_remote", "reliable")
func receive_dice_animation(entry: Dictionary) -> void:
	if multiplayer.is_server() or multiplayer.get_remote_sender_id()!=1 or not Hearth20Identity.validate_network_identity(entry) or var_to_bytes(entry).size()>16384 or not Hearth20DiceStage.valid_entry(entry): return
	dice_rolled.emit(entry.duplicate(true))

func send_chat(message: String, visibility: String = "public") -> Dictionary:
	var clean := message.strip_edges()
	var parts := clean.split(" ", false, 1)
	if parts.size() == 2 and parts[0].to_lower() in ["/r", "/roll", "/gmroll"]:
		var expression := str(parts[1]).strip_edges()
		if expression.begins_with("d"):
			expression = "1" + expression
		return submit_roll("", "dice", "", "normal", "gm" if parts[0].to_lower() == "/gmroll" else visibility, expression)
	if clean.to_lower().begins_with("/w gm "):
		return _submit_table_request({"action": "chat", "text": clean.substr(6), "visibility": "gm"})
	return _submit_table_request({"action": "chat", "text": message, "visibility": visibility})

func _submit_table_request(command: Dictionary) -> Dictionary:
	if command.get("action","")=="roll": command.dice_set=Hearth20DiceSets.selected(local_role)
	command.request_id = "command-%d-%d" % [Time.get_ticks_usec(), randi()]
	if local_role == "dm":
		return _apply_table_request(command, "dm-local")
	if local_player_id.is_empty() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return {"ok": false, "error": "Join a table before sending a roll or message."}
	if pending_table_commands.size()>=32:return {"ok":false,"error":"Wait for the GM to confirm your pending requests."}
	# Reliable requests and their existing acknowledgements arrive in the same order.
	# Keep correlation local so older compatible hosts need no new RPC format.
	pending_table_commands.append(command.duplicate(true))
	var sent=rpc_id(1,"request_table_action",command)
	if sent!=OK:
		pending_table_commands.pop_back();return {"ok":false,"error":"The request could not be sent to the GM."}
	return {"ok": true, "pending": true,"request_id":str(command.request_id)}

@rpc("any_peer", "call_remote", "reliable")
func request_table_action(command: Dictionary) -> void:
	if not multiplayer.is_server() or local_role != "dm":
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var player_id := str(peer_to_player.get(peer_id, ""))
	if player_id.is_empty():
		return
	var result := _apply_table_request(command, player_id)
	table_action_result.rpc_id(peer_id, bool(result.get("ok", false)), str(result.get("error", "Recorded at the table.")))

@rpc("authority", "call_remote", "reliable")
func table_action_result(ok: bool, message: String) -> void:
	if not multiplayer.is_server() and multiplayer.get_remote_sender_id() == 1:
		if not pending_table_commands.is_empty():
			var command: Dictionary=pending_table_commands.pop_front()
			table_request_finished.emit(command,{"ok":ok,"message":message,"error":"" if ok else message})
		status_changed.emit(message if not ok else "Recorded at the table.")

func _apply_table_request(command: Dictionary, player_id: String) -> Dictionary:
	if is_spectating(player_id) and command.get("action","")!="chat":return {"ok":false,"error":"You are spectating during a blackout."}
	if player_id != "dm-local" and not remote_players.has(player_id):
		return {"ok": false, "error": "Only an admitted player may send table messages."}
	if command.size() > 12 or var_to_bytes(command).size() > 8192 or not Hearth20Contracts.valid_identifier(command.get("request_id", "")):
		return {"ok": false, "error": "Invalid table request."}
	var request_id := player_id + ":" + str(command.request_id)
	if recent_requests.has(request_id):
		return {"ok": false, "error": "That request was already recorded."}
	var now := Time.get_ticks_msec()
	var rate: Dictionary = request_rates.get(player_id, {"start": now, "count": 0})
	if now - int(rate.start) > 2000:
		rate = {"start": now, "count": 0}
	rate.count = int(rate.count) + 1
	request_rates[player_id] = rate
	if int(rate.count) > 12:
		return {"ok": false, "error": "Please wait a moment before sending more messages."}
	var visibility := str(command.get("visibility", "public"))
	if visibility not in ["public", "gm", "self", "secret"]:
		return {"ok": false, "error": "Choose Public or Only me + DM."}
	var entry := {"visibility": visibility}
	match str(command.get("action", "")):
		"chat":
			if not command.get("text") is String:
				return {"ok": false, "error": "Enter a message."}
			var message := str(command.text).strip_edges()
			if message.is_empty() or message.length() > 2000:
				return {"ok": false, "error": "Messages must contain 1 to 2,000 characters."}
			entry.type = "chat"
			entry.text = message
		"roll":
			if str(command.get("kind",""))!="dice" or bool(command.get("proficiency",false)):return {"ok":false,"error":"Use a dice expression with your manual modifier. Sheet abilities stay on D&D Beyond."}
			var chosen_set: Variant=command.get("dice_set","set-1")
			if not Hearth20DiceSets.valid(chosen_set,player_id!="dm-local"): return {"ok":false,"error":"Choose a bundled dice collection."}
			entry.dice_set="dm" if player_id=="dm-local" else chosen_set
			for field in ["actor_id", "kind", "key", "mode", "expression"]:
				if not command.get(field, "") is String or str(command.get(field, "")).length() > 96:
					return {"ok": false, "error": "Invalid roll request."}
			var actor := Hearth20Contracts.find_actor(campaign, str(command.get("actor_id", "")))
			var generic_dice := actor.is_empty() and str(command.get("kind", "")) == "dice" and str(command.get("actor_id", "")).is_empty()
			if player_id != "dm-local" and not generic_dice and (actor.is_empty() or not bool(actor.get("is_hero", false)) or str(actor.get("owner_player_id", "")) != player_id):
				return {"ok": false, "error": "Roll from your assigned character's sheet."}
			if actor.is_empty() and str(command.get("kind", "")) != "dice":
				return {"ok": false, "error": "Select a character sheet."}
			if not actor.is_empty() and bool(actor.get("hidden", false)) and not bool(actor.get("is_hero", false)) and visibility == "public":
				return {"ok": false, "error": "Use a private roll for a concealed creature."}
			var expression := str(command.get("expression", "1d20"))
			if bool(command.get("proficiency", false)):
				if actor.is_empty(): return {"ok": false, "error": "Select your character to add proficiency."}
				var prof := clampi(int(actor.get("prof_bonus", 2 + floori(float(clampi(int(actor.get("level", 1)), 1, 20) - 1) / 4.0))), 0, 20)
				var expression_parts := RegEx.new()
				expression_parts.compile("^([0-9]{1,2}d[0-9]{1,4})([+-][0-9]{1,4})?$")
				var parsed := expression_parts.search(expression)
				if parsed == null: return {"ok": false, "error": "Choose valid dice."}
				expression = parsed.get_string(1) + "%+d" % (int(parsed.get_string(2)) + prof)
			var rolled := Hearth20TableData.roll(actor, str(command.kind), str(command.get("key", "")), str(command.get("mode", "normal")), expression, dice_rng)
			if not rolled.ok:
				return rolled
			rolled.erase("ok")
			entry.merge(rolled)
			entry.actor_name = str(actor.get("name", "Dice")).left(96)
		_:
			return {"ok": false, "error": "Unknown table action."}
	recent_requests[request_id] = true
	while recent_requests.size() > 2048:
		recent_requests.erase(recent_requests.keys()[0])
	_append_entry(entry, player_id)
	_publish_dice_animation(entry)
	return {"ok": true}

func set_scene_lighting(enabled: bool, ambient: String = "dark") -> Dictionary:
	if local_role != "dm" or ambient not in ["bright", "dim", "dark"]:
		return {"ok": false, "error": "Only the DM configures scene lighting."}
	var scene := Hearth20Contracts.find_scene(campaign, str(campaign.get("active_scene", "")))
	if scene.is_empty():
		return {"ok": false, "error": "Open a scene first."}
	scene.dynamic_lighting = enabled
	scene.ambient_light = ambient
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_broadcast_snapshots()
	return {"ok": true}

func load_sample_map(map_id: String, move_party: bool = true) -> Dictionary:
	if local_role!="dm": return {"ok":false,"error":"Only the DM loads campaign maps."}
	var result:=Hearth20MapLibrary.add_to_campaign(campaign,map_id,move_party)
	if bool(result.get("ok",false)):
		_sync_map_cover()
		projection_cache.clear(); sight_cache.clear(); template_undo.clear(); board_undo.clear()
		_broadcast_snapshots()
	return result

func set_natural_lighting(value: Dictionary) -> Dictionary:
	if local_role!="dm" or not Hearth20NaturalLight.valid(value): return {"ok":false,"error":"Only the DM sets bounded natural light settings."}
	var scene:=Hearth20Contracts.find_scene(campaign,str(campaign.get("active_scene","")))
	if scene.is_empty(): return {"ok":false,"error":"Open a scene first."}
	scene.natural_light=value.duplicate(true)
	campaign.revision=int(campaign.get("revision",0))+1
	projection_cache.clear(); sight_cache.clear()
	_broadcast_snapshots()
	return {"ok":true}

func set_grid_style(opacity: float, thickness: float, color: String) -> Dictionary:
	if local_role!="dm" or not is_finite(opacity) or not is_finite(thickness) or opacity<0 or opacity>1 or thickness<0.5 or thickness>4 or not Color.html_is_valid(color): return {"ok":false,"error":"Only the DM changes grid appearance within its supported range."}
	var scene:=Hearth20Contracts.find_scene(campaign,str(campaign.get("active_scene","")))
	if scene.is_empty(): return {"ok":false,"error":"Open a scene first."}
	scene.grid_opacity=opacity; scene.grid_thickness=thickness; scene.grid_color=color
	campaign.revision=int(campaign.get("revision",0))+1
	projection_cache.clear()
	_broadcast_snapshots()
	return {"ok":true}

func switch_library_scene(scene_id: String, move_party: bool = true, include_stored: bool=false) -> Dictionary:
	if local_role!="dm": return {"ok":false,"error":"Only the DM switches campaign scenes."}
	var scene:=Hearth20Contracts.find_scene(campaign,scene_id)
	if scene.is_empty(): return {"ok":false,"error":"The selected campaign scene no longer exists."}
	if move_party:
		var entries: Array=[]
		for entry in scene.get("library_entry",[]):
			var p:=Hearth20Contracts._point_from_record(entry)
			if Hearth20Contracts._point_inside_scene(p,scene): entries.append(p)
		if entries.is_empty(): entries=[Vector2(minf(4.0,float(scene.width_cells)*0.5),minf(4.0,float(scene.height_cells)*0.5))]
		var heroes: Array=campaign.actors.filter(func(actor):return bool(actor.get("is_hero",false)) and (include_stored or not actor.get("in_inventory",false)))
		var places:=Hearth20TokenInventory.party_positions(scene,entries,heroes.size())
		if places.size()<heroes.size():return {"ok":false,"error":"This map does not have enough clear squares for the party."}
		var index:=0
		for actor in campaign.actors:
			if bool(actor.get("is_hero",false)) and (include_stored or not actor.get("in_inventory",false)):
				actor.scene_id=scene_id;actor.position=places[index];actor.in_inventory=false;index+=1
	campaign.active_scene=scene_id
	_sync_map_cover()
	campaign.revision=int(campaign.get("revision",0))+1
	projection_cache.clear(); sight_cache.clear(); template_undo.clear(); board_undo.clear()
	_broadcast_snapshots()
	return {"ok":true,"id":scene_id,"title":str(scene.get("title","Scene"))}

func set_blackout(enabled: bool) -> Dictionary:
	if local_role != "dm":
		return {"ok": false, "error": "Only the DM covers the table."}
	var scene := Hearth20Contracts.find_scene(campaign, str(campaign.get("active_scene", "")))
	if scene.is_empty():
		return {"ok": false, "error": "Open a scene first."}
	campaign.map_covered=enabled
	_sync_map_cover()
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_broadcast_snapshots()
	return {"ok": true}

func _sync_map_cover() -> void:
	for scene in campaign.get("scenes",[]):scene.blackout=bool(campaign.get("map_covered",false))

func import_map_package(path: String) -> Dictionary:
	if local_role!="dm":return {"ok":false,"error":"Only the DM imports campaign maps."}
	var result:=Hearth20MapPackage.import_into(campaign,path)
	if result.ok:
		_sync_map_cover();sight_cache.clear();template_undo.clear();board_undo.clear();_broadcast_snapshots()
	return result

func set_actor_vision(actor_id: String, enabled: bool, darkvision_feet: float = 0.0, bright_light_feet: float = 0.0, dim_light_feet: float = 0.0) -> Dictionary:
	if not is_zero_approx(darkvision_feet):return {"ok":false,"error":"Character senses stay on D&D Beyond. Set a carried light source instead."}
	var settings := {"enabled": enabled, "bright_light_feet": bright_light_feet, "dim_light_feet": dim_light_feet}
	if local_role != "dm" or not Hearth20Vision.valid_settings(settings):
		return {"ok": false, "error": "Only the DM sets vision/light ranges (0–1,000 ft)."}
	var actor := Hearth20Contracts.find_actor(campaign, actor_id)
	if actor.is_empty():
		return {"ok": false, "error": "Select a token first."}
	actor.vision = settings
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_broadcast_snapshots()
	return {"ok": true}

func update_sheet(actor_id: String, patch: Dictionary) -> Dictionary:
	if local_role != "dm" or patch.size() > 64 or var_to_bytes(patch).size() > 65536:
		return {"ok": false, "error": "Only the DM edits recorded sheet values."}
	var actor := Hearth20Contracts.find_actor(campaign, actor_id)
	if actor.is_empty():
		return {"ok": false, "error": "Select a character first."}
	var candidate := actor.duplicate(true)
	for field in patch:
		if field not in Hearth20TableData.SHEET_FIELDS:
			return {"ok": false, "error": "Unsupported sheet field."}
		candidate[field] = Hearth20TableData.safe_value(patch[field])
	var test_campaign := campaign.duplicate(true)
	var test_actor := Hearth20Contracts.find_actor(test_campaign, actor_id)
	test_actor.merge(candidate, true)
	var checked := Hearth20Contracts.validate_campaign(test_campaign)
	if not checked.ok:
		return {"ok": false, "error": "; ".join(checked.errors)}
	actor.merge(candidate, true)
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_broadcast_snapshots()
	return {"ok": true}

func share_handout(title: String, body: String, public: bool = true, handout_id: String = "") -> Dictionary:
	if local_role != "dm" or title.strip_edges().is_empty() or title.length() > 96 or body.length() > 12000:
		return {"ok": false, "error": "Only the DM edits handouts (title 96, body 12,000 characters)."}
	if not campaign.get("handouts") is Array:
		campaign.handouts = []
	var record := {}
	for handout in campaign.handouts:
		if handout is Dictionary and str(handout.get("id", "")) == handout_id:
			record = handout
			break
	if record.is_empty():
		if campaign.handouts.size() >= 128:
			return {"ok": false, "error": "This campaign already has 128 handouts."}
		record = {"id": "handout-%d" % Time.get_ticks_usec()}
		campaign.handouts.append(record)
	record.merge({"title": title.strip_edges(), "body": body, "public": public}, true)
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_broadcast_snapshots()
	return {"ok": true, "id": record.id}

func _handouts_for(_player_id: String) -> Array:
	var shared: Array = []
	for handout in campaign.get("handouts", []):
		if handout is Dictionary and bool(handout.get("public", false)):
			shared.append({"id": str(handout.get("id", "")), "title": str(handout.get("title", "")).left(96), "body": str(handout.get("body", "")).left(12000)})
	return shared

func place_template(shape: String, start: Vector2, end: Vector2) -> Dictionary:
	if local_role != "dm" or shape not in ["circle", "rectangle", "line", "cone"]:
		return {"ok": false, "error": "Only the DM places measured areas."}
	var scene := Hearth20Contracts.find_scene(campaign, str(campaign.get("active_scene", "")))
	if scene.is_empty() or not Hearth20Contracts.finite_point(start) or not Hearth20Contracts.finite_point(end) or not Hearth20Contracts._point_inside_scene(start, scene) or not Hearth20Contracts._point_inside_scene(end, scene) or start.distance_to(end) < 0.05:
		return {"ok": false, "error": "Drag a measured area inside the map."}
	if not scene.get("templates") is Array:
		scene.templates = []
	if scene.templates.size() >= 128:
		return {"ok": false, "error": "Remove an area before adding more (128 maximum)."}
	var record := {"id": "area-%d" % Time.get_ticks_usec(), "shape": shape, "start": start, "end": end}
	scene.templates.append(record)
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_broadcast_snapshots()
	return {"ok": true, "id": record.id}

func remove_template(template_id: String) -> Dictionary:
	if local_role != "dm":
		return {"ok": false, "error": "Only the DM removes measured areas."}
	var scene := Hearth20Contracts.find_scene(campaign, str(campaign.get("active_scene", "")))
	for index in scene.get("templates", []).size():
		if str(scene.templates[index].get("id", "")) == template_id:
			template_undo.append({"scene_id": scene.id, "template": scene.templates[index].duplicate(true), "index": index})
			if template_undo.size() > 20:
				template_undo.pop_front()
			scene.templates.remove_at(index)
			campaign.revision = int(campaign.get("revision", 0)) + 1
			_broadcast_snapshots()
			return {"ok": true}
	return {"ok": false, "error": "That measured area has already been removed."}

func undo_template_removal() -> Dictionary:
	if local_role != "dm" or template_undo.is_empty():
		return {"ok": false, "error": "No removed area to restore."}
	var last: Dictionary = template_undo.back()
	var scene := Hearth20Contracts.find_scene(campaign, str(last.scene_id))
	if scene.is_empty() or scene.get("templates", []).size() >= 128:
		return {"ok": false, "error": "The original scene is unavailable or full."}
	if not scene.get("templates") is Array:
		scene.templates = []
	scene.templates.insert(mini(int(last.index), scene.templates.size()), last.template)
	template_undo.pop_back()
	campaign.revision = int(campaign.get("revision", 0)) + 1
	_broadcast_snapshots()
	return {"ok": true}

func send_ping(point: Vector2) -> Dictionary:
	if local_role == "dm":
		return _send_ping_for(point, "dm-local")
	if local_player_id.is_empty():
		return {"ok": false, "error": "Join a table before pinging."}
	request_ping.rpc_id(1, point)
	return {"ok": true}

@rpc("any_peer", "call_remote", "reliable")
func request_ping(point: Vector2) -> void:
	if not multiplayer.is_server() or local_role != "dm":
		return
	var player_id := str(peer_to_player.get(multiplayer.get_remote_sender_id(), ""))
	if not player_id.is_empty():
		_send_ping_for(point, player_id)

func _send_ping_for(point: Vector2, player_id: String) -> Dictionary:
	if is_spectating(player_id):return {"ok":false,"error":"You are spectating during a blackout."}
	var scene := Hearth20Contracts.find_scene(campaign, str(campaign.get("active_scene", "")))
	if scene.is_empty() or not Hearth20Contracts.finite_point(point) or not Hearth20Contracts._point_inside_scene(point, scene):
		return {"ok": false, "error": "Ping inside the map."}
	var rate_key := "ping:" + player_id
	if Time.get_ticks_msec() - int(request_rates.get(rate_key, -1000)) < 750:
		return {"ok": false, "error": "Wait a moment before pinging again."}
	request_rates[rate_key] = Time.get_ticks_msec()
	if player_id != "dm-local" and not Hearth20Vision.visible(point, Hearth20Vision.build_view(campaign, player_id, scene)):
		return {"ok": false, "error": "Ping a point your character can see."}
	var event := {"point": point, "sender": "DM" if player_id == "dm-local" else str(remote_players.get(player_id, {}).get("nickname", "Player")).left(40)}
	ping_received.emit(event)
	for peer_id in peer_to_player:
		var recipient := str(peer_to_player[peer_id])
		if Hearth20Vision.visible(point, Hearth20Vision.build_view(campaign, recipient, scene)):
			receive_ping.rpc_id(int(peer_id), event)
	return {"ok": true}

@rpc("authority", "call_remote", "reliable")
func receive_ping(event: Dictionary) -> void:
	if local_role == "player" and multiplayer.get_remote_sender_id() == 1 and Hearth20Contracts.finite_point(event.get("point")):
		ping_received.emit({"point": event.point, "sender": str(event.get("sender", "Player")).left(40)})

func _new_invite_secret() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func submit_dice(actor_id: String, expression: String, visibility: String, proficiency: bool, mode: String = "normal") -> Dictionary:
	return _submit_table_request({"action":"roll", "actor_id":actor_id, "kind":"dice", "key":"", "mode":mode, "visibility":visibility, "expression":expression, "proficiency":proficiency})

func board_action(command: Dictionary) -> Dictionary:
	command = command.duplicate(true)
	command.request_id = "board-%d-%d" % [Time.get_ticks_usec(), randi()]
	if local_role == "dm": return _apply_board_action(command, "dm-local")
	if local_player_id.is_empty(): return {"ok":false, "error":"Join a table to use shared tools."}
	request_board_action.rpc_id(1, command)
	return {"ok":true, "pending":true}

@rpc("any_peer", "call_remote", "reliable")
func request_board_action(command: Dictionary) -> void:
	if local_role != "dm" or not multiplayer.is_server(): return
	var player := str(peer_to_player.get(multiplayer.get_remote_sender_id(), ""))
	if player.is_empty(): return
	var result := _apply_board_action(command, player)
	table_action_result.rpc_id(multiplayer.get_remote_sender_id(), bool(result.get("ok", false)), str(result.get("error", "Board updated.")))

func _apply_board_action(command: Dictionary, player: String) -> Dictionary:
	if is_spectating(player):return {"ok":false,"error":"You are spectating during a blackout."}
	if player != "dm-local" and not remote_players.has(player): return {"ok":false, "error":"Not admitted."}
	if command.size() > 8 or var_to_bytes(command).size() > 52000 or not Hearth20Contracts.valid_identifier(command.get("request_id", "")): return {"ok":false, "error":"Invalid board request."}
	var key := player + ":" + str(command.request_id)
	if recent_requests.has(key): return {"ok":false, "error":"Duplicate board request."}
	var rate_key := "board:" + player
	var now := Time.get_ticks_msec()
	var rate: Dictionary = request_rates.get(rate_key, {"start":now, "count":0})
	if now - int(rate.start) > 2000: rate = {"start":now, "count":0}
	rate.count = int(rate.count) + 1
	request_rates[rate_key] = rate
	if int(rate.count) > 24: return {"ok":false, "error":"Please pause before editing again."}
	var scene := Hearth20Contracts.find_scene(campaign, str(campaign.get("active_scene", "")))
	if scene.is_empty(): return {"ok":false, "error":"No active map."}
	var objects: Array = scene.get("annotations", [])
	var action := str(command.get("action", ""))
	var undo: Dictionary = {}
	match action:
		"move_path":
			if not Hearth20Contracts._integer_number(command.get("expected_revision")) or command.expected_revision!=campaign.get("revision",0):return {"ok":false,"error":"The table changed. Pick up the token again."}
			var actor=Hearth20Contracts.find_actor(campaign,str(command.get("actor_id","")))
			if actor.is_empty() or (player!="dm-local" and actor.get("owner_player_id","")!=player):return {"ok":false,"error":"Choose a token assigned to you."}
			var path=command.get("points")
			if not path is Array or path.size()<2 or path.size()>64:return {"ok":false,"error":"Use a movement route with 2 to 64 points."}
			for point in path:
				if not Hearth20BoardTools.point_ok(point,scene):return {"ok":false,"error":"Keep movement waypoints inside the map."}
			var moved=Hearth20Contracts.authorize_and_apply_move(campaign,player,"dm" if player=="dm-local" else "player",str(actor.id),path.front(),path.back(),0.,path)
			if not moved.ok:return {"ok":false,"error":"Move rejected · "+str(moved.reason).replace("_"," ")}
		"add", "update":
			var o: Variant = command.get("object", {})
			if not Hearth20BoardTools.valid_object(o, scene): return {"ok":false, "error":"The drawing contains invalid values or lies outside the map."}
			if player != "dm-local" and (o.get("layer", "tokens") != "tokens" or o.kind not in ["freehand", "line", "rectangle", "ellipse", "text"]): return {"ok":false, "error":"Players draw on the token layer."}
			var index := -1
			for i in objects.size():
				if str(objects[i].id) == str(o.get("id", "")): index = i
			if action == "update":
				if index < 0 or (player != "dm-local" and (objects[index].owner != player or objects[index].get("layer","tokens") != "tokens")): return {"ok":false, "error":"Select one of your own drawings on the token layer."}
				undo = {"action":"restore", "object":objects[index].duplicate(true)}
			else:
				if objects.size() >= 256: return {"ok":false, "error":"This map has 256 drawings. Remove one first."}
			var clean := {}
			for field in ["kind", "layer", "points", "color", "fill", "width", "text", "font", "font_size", "bold", "italic", "border", "border_color", "opacity", "bright", "dim", "enabled", "open", "source_type", "light_color", "angle_degrees", "spread_degrees", "ray_strength", "portal_width", "window_height", "sill_height"]:
				if o.has(field): clean[field] = o[field]
			clean.id = str(objects[index].id) if action == "update" else "drawing-%d-%d" % [Time.get_ticks_usec(), randi()]
			clean.owner = str(objects[index].owner) if action == "update" else player
			if action == "add":
				objects.append(clean)
				undo = {"action":"delete", "id":clean.id}
			else: objects[index] = clean
			scene.annotations = objects
		"delete":
			var found := false
			for i in objects.size():
				if str(objects[i].id) != str(command.get("id", "")): continue
				if player != "dm-local" and (str(objects[i].owner) != player or objects[i].get("layer","tokens") != "tokens"): return {"ok":false, "error":"You can remove only your own drawings on the token layer."}
				undo = {"action":"restore", "object":objects[i].duplicate(true)}
				objects.remove_at(i)
				found = true
				break
			if not found: return {"ok":false, "error":"That drawing is no longer on the map."}
			scene.annotations = objects
		"undo":
			var history: Array = board_undo.get(player, [])
			if history.is_empty() or history.back().scene != scene.id: return {"ok":false, "error":"No drawing edit to undo on this map."}
			var last: Dictionary = history.back()
			var affected_id := str(last.get("id",last.get("object",{}).get("id","")))
			for o in objects:
				if o.id == affected_id and player != "dm-local" and (o.owner != player or o.get("layer","tokens") != "tokens"): return {"ok":false,"error":"The DM has moved that drawing to another layer."}
			history.pop_back()
			if last.action == "delete":
				objects = objects.filter(func(o: Dictionary) -> bool: return o.id != last.id)
			else:
				var restored := false
				for i in objects.size():
					if objects[i].id == last.object.id:
						objects[i] = last.object
						restored = true
				if not restored and objects.size() < 256: objects.append(last.object)
			scene.annotations = objects
		"mask":
			if player != "dm-local": return {"ok":false, "error":"Only the DM edits the mask."}
			var cut: Variant = command.get("rect")
			if not cut is Rect2 or not Hearth20Contracts._valid_scene_rect(cut, scene): return {"ok":false, "error":"Draw a mask inside the map."}
			var fog: Array = scene.get("fog_rects", []).duplicate(true)
			if bool(command.get("reveal", false)):
				var parts: Array = []
				for rect in fog: parts.append_array(Hearth20BoardTools.subtract(Hearth20Contracts._rect_from_record(rect), cut))
				fog = parts
			else: fog.append(cut)
			if fog.size() > Hearth20Contracts.MAX_RECIPE_OBJECTS: return {"ok":false, "error":"Mask complexity reached. Reveal full page to reset it."}
			scene.fog_rects = fog
		"mask_all":
			if player != "dm-local": return {"ok":false, "error":"Only the DM edits the mask."}
			scene.fog_rects = [] if bool(command.get("reveal", false)) else [Rect2(Vector2.ZERO, Vector2(scene.width_cells, scene.height_cells))]
		"mask_polygon":
			if player != "dm-local": return {"ok":false, "error":"Only the DM edits the mask."}
			var points: Variant = command.get("points", [])
			if not points is Array or points.size() < 3 or points.size() > 64: return {"ok":false, "error":"Place 3 to 64 polygon corners."}
			for p in points:
				if not Hearth20BoardTools.point_ok(p, scene): return {"ok":false, "error":"Keep the polygon inside the map."}
			var polygon := PackedVector2Array(points)
			if Geometry2D.triangulate_polygon(polygon).is_empty(): return {"ok":false, "error":"The polygon must have an area and cannot cross itself."}
			var rect := Hearth20BoardTools._polygon_bounds(polygon)
			var cuts: Array = []
			var reveal := bool(command.get("reveal",false))
			for y in range(floori(rect.position.y*2),ceili(rect.end.y*2)):
				var run_start := -1
				for x in range(floori(rect.position.x*2),ceili(rect.end.x*2)+1):
					var cell := Rect2(Vector2(x,y)*0.5,Vector2.ONE*0.5)
					var square := PackedVector2Array([cell.position,Vector2(cell.end.x,cell.position.y),cell.end,Vector2(cell.position.x,cell.end.y)])
					var covered := not Geometry2D.intersect_polygons(polygon,square).is_empty()
					if reveal: covered = Geometry2D.clip_polygons(square,polygon).is_empty()
					if x >= ceili(rect.end.x*2): covered=false
					if covered and run_start < 0: run_start=x
					if not covered and run_start >= 0:
						cuts.append(Rect2(Vector2(run_start,y)*0.5,Vector2(x-run_start,1)*0.5))
						run_start=-1
			var fog: Array = scene.get("fog_rects",[]).duplicate(true)
			for cut in cuts:
				if reveal:
					var parts: Array=[]
					for r in fog: parts.append_array(Hearth20BoardTools.subtract(Hearth20Contracts._rect_from_record(r),cut))
					fog=parts
				else: fog.append(cut)
				if fog.size()>Hearth20Contracts.MAX_RECIPE_OBJECTS: return {"ok":false,"error":"This mask is too complex. Use fewer corners or reveal full page to reset."}
			scene.fog_rects=fog
		"fx":
			var settings: Variant = command.get("effect",{})
			if not settings is Dictionary or settings.size()>8: return {"ok":false,"error":"Invalid effect."}
			if not Hearth20BoardTools.point_ok(settings.get("start"),scene) or not Hearth20BoardTools.point_ok(settings.get("end"),scene): return {"ok":false,"error":"Place the effect inside the map."}
			if settings.get("effect","") not in Hearth20BoardTools.EFFECTS or not settings.get("color","") is String or not Color.html_is_valid(str(settings.color)): return {"ok":false,"error":"Choose a valid effect and color."}
			if settings.has("material") and settings.material not in Hearth20BoardTools.COLORS: return {"ok":false,"error":"Choose a supported effect material."}
			for field in ["size","duration","density"]:
				if not Hearth20Contracts._finite_number(settings.get(field)): return {"ok":false,"error":"Effect values must be finite numbers."}
			if float(settings.size)<0.25 or float(settings.size)>4 or float(settings.duration)<0.3 or float(settings.duration)>8 or int(settings.density)<8 or int(settings.density)>128: return {"ok":false,"error":"Effect values exceed the supported limits."}
			if settings.effect not in Hearth20BoardTools.CAST_EFFECTS: settings=settings.duplicate(true); settings.start=settings.end
			var range_check := {"points":[settings.start,settings.end],"shape":"line"}
			if player != "dm-local" and not Hearth20BoardTools.measure_visible(range_check,_sight_for(player,scene)): return {"ok":false,"error":"Choose a location your character can see."}
			var event := make_effect(settings,settings.start,settings.end)
			if not scene.get("fx") is Array: scene.fx=[]
			scene.fx.append(event)
			if scene.fx.size()>Hearth20Contracts.MAX_FX_EVENTS: scene.fx.pop_front()
		"save_fx_preset":
			if player != "dm-local": return {"ok":false,"error":"Only the DM saves table presets."}
			var preset_name := str(command.get("name","")).strip_edges()
			var settings: Variant = command.get("settings",{})
			if preset_name.is_empty() or preset_name.length()>48 or not Hearth20BoardTools.valid_fx_settings(settings): return {"ok":false,"error":"Name the effect and keep its settings within the supported ranges."}
			var presets: Dictionary = campaign.get("fx_presets",{})
			if presets.size()>=32 and not presets.has(preset_name): return {"ok":false,"error":"The table can save up to 32 custom effects."}
			var clean := {}
			for field in ["effect","color","size","duration","density"]: clean[field]=settings[field]
			clean.material=Hearth20BoardTools.fx_material(settings)
			presets[preset_name]=clean
			campaign.fx_presets=presets
		"actor_layer":
			if player != "dm-local" or command.get("layer", "") not in ["map", "tokens", "gm", "foreground"]: return {"ok":false, "error":"Only the DM moves tokens between layers."}
			var actor := Hearth20Contracts.find_actor(campaign, str(command.get("id", "")))
			if actor.is_empty(): return {"ok":false, "error":"Select a token."}
			actor.layer = command.layer
		"auto_vision":
			if player != "dm-local": return {"ok":false,"error":"Only the DM edits token vision."}
			var actor := Hearth20Contracts.find_actor(campaign,str(command.get("id","")))
			if actor.is_empty(): return {"ok":false,"error":"Select a character first."}
			if not actor.get("vision") is Dictionary: actor.vision={"enabled":true}
			actor.vision.darkvision_override=not bool(command.get("enabled",true))
		_:
			return {"ok":false, "error":"Unknown board edit."}
	if not undo.is_empty():
		undo.scene = scene.id
		var history: Array = board_undo.get(player, [])
		history.append(undo)
		if history.size() > 30: history.pop_front()
		board_undo[player] = history
	recent_requests[key] = true
	while recent_requests.size() > 2048: recent_requests.erase(recent_requests.keys()[0])
	if action!="move_path":campaign.revision = int(campaign.get("revision", 0)) + 1
	_broadcast_snapshots()
	return {"ok":true}

func send_tool_preview(measure: Dictionary) -> void:
	if local_role == "dm": _relay_tool_preview(measure, "dm-local")
	elif not local_player_id.is_empty(): request_tool_preview.rpc_id(1, measure)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func request_tool_preview(measure: Dictionary) -> void:
	if local_role != "dm" or not multiplayer.is_server(): return
	var player := str(peer_to_player.get(multiplayer.get_remote_sender_id(), ""))
	if not player.is_empty(): _relay_tool_preview(measure, player)

func _sight_for(player: String, scene: Dictionary) -> Dictionary:
	var cache: Dictionary = sight_cache.get(player, {})
	var revision := int(campaign.get("revision", 0))
	if cache.get("revision", -1) != revision or cache.get("scene", "") != scene.id:
		cache = {"revision":revision, "scene":scene.id, "sight":Hearth20Vision.build_view(campaign, player, scene)}
		sight_cache[player] = cache
	return cache.sight

func _relay_tool_preview(measure: Dictionary, player: String) -> void:
	if is_spectating(player):return
	var scene := Hearth20Contracts.find_scene(campaign, str(campaign.get("active_scene", "")))
	if scene.is_empty() or var_to_bytes(measure).size() > 8192: return
	if not measure.is_empty() and not Hearth20BoardTools.valid_measure(measure, scene): return
	var now := Time.get_ticks_msec()
	var rate_key := "preview:" + player
	if not measure.is_empty() and now - int(request_rates.get(rate_key, -1000)) < 65: return
	request_rates[rate_key] = now
	if player != "dm-local" and not measure.is_empty() and not Hearth20BoardTools.measure_visible(measure, _sight_for(player, scene)): return
	var event := {"sender":player, "measure":measure, "name":"DM" if player == "dm-local" else str(remote_players.get(player, {}).get("nickname", "Player"))}
	tool_preview_received.emit(event)
	for peer in peer_to_player:
		var recipient := str(peer_to_player[peer])
		var clean := event.duplicate(true)
		clean.sender = Hearth20Contracts._neutral_id(recipient, "ruler:" + player)
		clean.own = recipient == player
		if not measure.is_empty() and not Hearth20BoardTools.measure_visible(measure, _sight_for(recipient, scene)): clean.measure = {}
		receive_tool_preview.rpc_id(int(peer), clean)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func receive_tool_preview(event: Dictionary) -> void:
	if local_role == "player" and multiplayer.get_remote_sender_id() == 1:
		tool_preview_received.emit(event)

func make_effect(settings: Dictionary, start: Vector2, end: Vector2) -> Dictionary:
	var kind := str(settings.get("effect","breath"))
	var travel := start.distance_to(end)/10.0 if kind in ["missile","rocket"] else 0.0
	if kind not in Hearth20BoardTools.CAST_EFFECTS: start=end; travel=0
	return {"id":"fx-%d-%d" % [Time.get_ticks_usec(),randi()],"preset":"tabletop-fx-v1","effect":kind,"material":Hearth20BoardTools.fx_material(settings),"color":str(settings.get("color","#ff682b")),"size":float(settings.get("size",1)),"density":int(settings.get("density",48)),"source":start,"destination":end,"start":start,"end":end,"center":end,"started_usec":Time.get_ticks_usec(),"travel_usec":int(travel*1000000),"impact_duration_usec":int(float(settings.get("duration",2))*1000000),"seed":randi()&0x7fffffff,"public":true}

func _on_connected_to_server() -> void:
	if local_role == "player":
		var identity=Hearth20Identity.network_identity()
		identity.steam_features=["image-cache-v1","image-cache-v2"]
		send_handshake.rpc_id(1, identity, invite_secret, pending_nickname,Hearth20PlayerProfile.public_key())

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(multiplayer) and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()

func apply_character_sheet(actor_id: String, sheet: Dictionary, expected: String, portrait_png: PackedByteArray=PackedByteArray()) -> Dictionary:
	if local_role!="dm":return {"ok":false,"error":"Only the DM imports character sheets."}
	var checked:=Hearth20CharacterImport.validate(sheet)
	if not checked.ok:return checked
	var existing:=Hearth20Contracts.find_actor(campaign,actor_id)
	if not actor_id.is_empty() and (existing.is_empty() or existing.get("decorative",false)):return {"ok":false,"error":"The target token is no longer available."}
	if not existing.is_empty() and Hearth20CharacterImport.target_signature(existing)!=expected:return {"ok":false,"error":"This token's sheet changed while the draft was open. Reopen the import before applying."}
	if existing.is_empty() and campaign.actors.size()>=Hearth20Contracts.MAX_ACTORS:return {"ok":false,"error":"The campaign token inventory is full."}
	var proposed:=campaign.duplicate(true);var actor: Dictionary
	if existing.is_empty():
		actor=Hearth20TokenInventory.new_actor(str(sheet.name),true,Hearth20Contracts.find_scene(proposed,proposed.active_scene),Vector2(.5,.5));actor.in_inventory=true;proposed.actors.append(actor)
	else:actor=Hearth20Contracts.find_actor(proposed,actor_id)
	for field in Hearth20CharacterImport.IMPORT_FIELDS:
		if sheet.has(field):actor[field]=Hearth20TableData.safe_value(sheet[field])
	actor.is_hero=true;actor.armor_class=actor.ac
	if not portrait_png.is_empty():
		var image:=Hearth20Assets.inspect_token_png_bytes(portrait_png,"imported-character.png")
		if not image.ok:return image
		actor.png_asset_id=Hearth20Assets.store_asset(proposed,image,"token")
	var valid:=Hearth20Contracts.validate_campaign(proposed)
	if not valid.ok:return {"ok":false,"error":"Review the imported character: "+str(valid.errors)}
	if existing.is_empty():campaign.actors.append(actor)
	else:
		for field in Hearth20CharacterImport.IMPORT_FIELDS:
			if actor.has(field):existing[field]=actor[field]
		existing.is_hero=true;existing.armor_class=actor.ac;existing.png_asset_id=actor.get("png_asset_id","")
	campaign.assets=proposed.assets;_inventory_changed();return {"ok":true,"id":str(actor.id)}
func set_view_actor(actor_id: String) -> Dictionary:
	if local_role=="dm":return {"ok":false,"error":"The DM already sees the campaign. Use Player View to preview a character."}
	if local_player_id.is_empty() or multiplayer.is_server() or multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return {"ok":false,"error":"Join the table first."}
	request_view_actor.rpc_id(1,actor_id);return {"ok":true,"pending":true}
@rpc("any_peer","call_remote","reliable")
func request_view_actor(actor_id: String) -> void:
	if local_role!="dm" or not multiplayer.is_server():return
	var peer:=multiplayer.get_remote_sender_id();var player:=str(peer_to_player.get(peer,""))
	if player.is_empty() or not Hearth20Contracts.valid_identifier(actor_id):return
	if str(campaign.get("viewpoints",{}).get(player,""))==actor_id:return
	var now:=Time.get_ticks_msec();var rate_key:="view:"+player
	if now-int(request_rates.get(rate_key,-1000))<100:return
	request_rates[rate_key]=now
	var scene:=Hearth20Contracts.find_scene(campaign,campaign.active_scene);var eligible:=Hearth20Vision.view_actors(campaign,player,scene)
	if not eligible.any(func(actor):return str(actor.id)==actor_id):table_action_result.rpc_id(peer,false,"Choose one of your assigned, placed tokens on this map.");return
	if not campaign.get("viewpoints") is Dictionary:campaign.viewpoints={}
	campaign.viewpoints[player]=actor_id;_inventory_changed()

func submit_join_character(sheet: Dictionary, png: PackedByteArray) -> Dictionary:
	if local_role!="player" or local_player_id.is_empty() or multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return {"ok":false,"error":"Connect to the DM first."}
	if png.size()>Hearth20Assets.TOKEN_MAX_BYTES or var_to_bytes(sheet).size()>Hearth20CharacterImport.MAX_BYTES:return {"ok":false,"error":"The character or PNG is too large."}
	if transport=="steam":
		if steam_outgoing.has(1):return {"ok":false,"error":"Your character image is still uploading."}
		var job=Hearth20SteamChunks.make_job([sheet,png],"character",Hearth20Assets.TOKEN_MAX_BYTES+Hearth20CharacterImport.MAX_BYTES+4096)
		if job.is_empty():return {"ok":false,"error":"The character image could not be prepared."}
		steam_outgoing[1]={"active":job,"pending":{},"cache":{},"kind":"character"}
		return {"ok":true,"pending":true}
	request_join_character.rpc_id(1,sheet,png)
	return {"ok":true,"pending":true}
@rpc("any_peer","call_remote","reliable")
func request_join_character(sheet: Dictionary, png: PackedByteArray) -> void:
	if local_role!="dm" or not multiplayer.is_server():return
	var peer = multiplayer.get_remote_sender_id();var player = str(peer_to_player.get(peer,""))
	if player.is_empty():return
	if sheet.has("_h20_transfer"):
		if transport!="steam" or not steam_link.allows_peer(peer):return
		var received=steam_chunks.accept(peer,{"_h20_transfer":sheet._h20_transfer,"bytes":png},"character",Hearth20Assets.TOKEN_MAX_BYTES+Hearth20CharacterImport.MAX_BYTES+4096)
		if not received.ok:_steam_transfer_failed(peer,received.error);return
		if not received.complete:return
		if not received.value is Array or received.value.size()!=2 or not received.value[0] is Dictionary or not received.value[1] is PackedByteArray:_steam_transfer_failed(peer,"The character transfer was invalid.");return
		sheet=received.value[0];png=received.value[1]
	var rate_key = "join-character:"+player;var now = Time.get_ticks_msec()
	if now-int(request_rates.get(rate_key,-10000))<1500:return
	request_rates[rate_key]=now
	var result = Hearth20JoinCharacter.submit(campaign,player,sheet,png)
	if result.ok:
		_inventory_changed()
		status_changed.emit("%s's character is in the campaign token inventory."%str(remote_players.get(player,{}).get("nickname","Player")))
	receive_character_submission.rpc_id(peer,result)
@rpc("authority","call_remote","reliable")
func receive_character_submission(result: Dictionary) -> void:
	if local_role=="player" and multiplayer.get_remote_sender_id()==1:character_submission_result.emit(result)

func casino_action(command: Dictionary) -> Dictionary:
	if local_role=="dm":return _casino_action_as("dm-local",command)
	if local_player_id.is_empty() or multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return {"ok":false,"error":"Join the DM's table first."}
	var packet=command.duplicate(true);packet.request_id="casino-request-"+Crypto.new().generate_random_bytes(12).hex_encode()
	request_casino_action.rpc_id(1,packet);return {"ok":true,"pending":true}
func _casino_action_as(player: String, command: Dictionary) -> Dictionary:
	if is_spectating(player) and command.get("action","")!="acknowledge_balance":return {"ok":false,"error":"You are spectating during a blackout. The CM can manage your seat."}
	if player!="dm-local" and Hearth20JoinCharacter.current(campaign,player).is_empty():return {"ok":false,"error":"Create your character token before taking a casino seat."}
	var key="casino:"+player+":"+str(command.get("request_id",""))
	if command.has("request_id") and recent_requests.has(key):return {"ok":false,"error":"That action was already received."}
	var result=Hearth20TavernGames.apply(campaign,player,command,dice_rng)
	if result.ok:
		if command.has("request_id"):recent_requests[key]=true
		while recent_requests.size()>2048:recent_requests.erase(recent_requests.keys()[0])
		campaign.revision=int(campaign.get("revision",0))+1;_broadcast_snapshots()
	return result
@rpc("any_peer","call_remote","reliable")
func request_casino_action(command: Dictionary) -> void:
	if local_role!="dm" or not multiplayer.is_server():return
	var peer=multiplayer.get_remote_sender_id();var player=str(peer_to_player.get(peer,""))
	if player.is_empty() or var_to_bytes(command).size()>8192:return
	var key="casino-rate:"+player;var now=Time.get_ticks_msec()
	if now-int(request_rates.get(key,-1000))<90:
		receive_casino_action_result.rpc_id(peer,{"ok":false,"error":"Let the previous card action finish, then try again."});return
	request_rates[key]=now
	var result=_casino_action_as(player,command);receive_casino_action_result.rpc_id(peer,result)
@rpc("authority","call_remote","reliable")
func receive_casino_action_result(result: Dictionary) -> void:
	if local_role=="player" and multiplayer.get_remote_sender_id()==1:casino_action_result.emit(result)

func set_table_mode(mode: String) -> Dictionary:
	if is_spectating("dm-local"):return {"ok":false,"error":"You are spectating during a blackout."}
	if local_role!="dm" or mode not in ["map","casino"]:return {"ok":false,"error":"Only the DM can pull a table-mode rope."}
	if campaign.get("table_mode","map")==mode:return {"ok":true,"unchanged":true}
	campaign.table_mode=mode;campaign.revision=int(campaign.get("revision",0))+1;_broadcast_snapshots();return {"ok":true}

func is_spectating(player: String="") -> bool:
	if player.is_empty():player=local_player_id
	if local_role=="player":return player==local_player_id and bool(client_snapshot.get("refreshments",{}).get("spectating",false))
	return Hearth20Refreshments.spectating(campaign,player)
func refreshment_view() -> Dictionary:
	return Hearth20Refreshments.view(campaign,"dm-local",Time.get_unix_time_from_system()) if local_role=="dm" else client_snapshot.get("refreshments",Hearth20Refreshments.empty_state())
func refreshments_action(command: Dictionary) -> Dictionary:
	var packet=command.duplicate(true);packet.request_id="snack-"+Crypto.new().generate_random_bytes(12).hex_encode()
	if local_role=="dm":return _refreshment_action_as("dm-local",packet)
	if local_player_id.is_empty() or multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return {"ok":false,"error":"Join a table before ordering."}
	request_refreshment_action.rpc_id(1,packet);return {"ok":true,"pending":true}
func _refreshment_action_as(player: String,command: Dictionary) -> Dictionary:
	if not Hearth20Contracts.valid_identifier(command.get("request_id","")):return {"ok":false,"error":"Invalid serving request."}
	var key="snack:"+player+":"+str(command.request_id)
	if recent_requests.has(key):return {"ok":false,"error":"That serving request was already received."}
	var advanced=Hearth20Refreshments.advance(campaign,Time.get_unix_time_from_system())
	var result=Hearth20Refreshments.apply(campaign,player,command,Time.get_unix_time_from_system())
	if result.ok:
		recent_requests[key]=true
		while recent_requests.size()>2048:recent_requests.erase(recent_requests.keys()[0])
		var event: Dictionary=result.event;event.player_name="CM" if player=="dm-local" else str(remote_players.get(player,{}).get("nickname","Player")).left(40)
		refreshment_event.emit(event)
		for peer in peer_to_player:
			if int(peer) in multiplayer.get_peers():receive_refreshment_event.rpc_id(int(peer),event)
	if result.ok or advanced:
		_save_refreshment_ledger();campaign.revision=int(campaign.get("revision",0))+1;_broadcast_snapshots()
	return result
@rpc("any_peer","call_remote","reliable")
func request_refreshment_action(command: Dictionary) -> void:
	if local_role!="dm" or not multiplayer.is_server():return
	var peer=multiplayer.get_remote_sender_id();var player=str(peer_to_player.get(peer,""))
	if player.is_empty() or var_to_bytes(command).size()>1024:return
	var key="snack-rate:"+player;var now=Time.get_ticks_msec()
	if now-int(request_rates.get(key,-1000))<120:return
	request_rates[key]=now;var result=_refreshment_action_as(player,command);receive_refreshment_result.rpc_id(peer,result)
@rpc("authority","call_remote","reliable")
func receive_refreshment_event(event: Dictionary) -> void:
	if local_role=="player" and multiplayer.get_remote_sender_id()==1 and var_to_bytes(event).size()<2048:refreshment_event.emit(event)
@rpc("authority","call_remote","reliable")
func receive_refreshment_result(result: Dictionary) -> void:
	if local_role=="player" and multiplayer.get_remote_sender_id()==1:refreshment_action_result.emit(result)
func _process(delta: float) -> void:
	if transport=="steam" or not steam_outgoing.is_empty():
		steam_transfer_tick+=delta
		if steam_transfer_tick>=1./60.:steam_transfer_tick=0.;_pump_steam_transfers()
	if local_role!="dm" or campaign.is_empty():return
	refreshment_tick+=delta
	if refreshment_tick<.25:return
	refreshment_tick=0.
	if Hearth20Refreshments.advance(campaign,Time.get_unix_time_from_system()):
		_save_refreshment_ledger();campaign.revision=int(campaign.get("revision",0))+1;_broadcast_snapshots()
func _make_steam_snapshot_job(peer: int,snapshot: Dictionary) -> Dictionary:
	var cached=peer_steam_images.has(peer)
	var packet=peer_steam_images[peer].encode(snapshot) if cached else snapshot.duplicate(true)
	var state={"map":str(packet.get("map_sha256","")),"assets":"" if cached else Hearth20Contracts.sha256(var_to_bytes(packet.assets)),"light":Hearth20Contracts.sha256(var_to_bytes(snapshot.scene.get("light_field",{}))),"scene":str(packet.scene.get("id","")),"actors":snapshot.actors.map(func(actor):return str(actor.id))}
	var previous: Dictionary=peer_asset_state.get(peer,{})
	if cached:state.image_snapshot=snapshot
	else:
		if previous.get("map","")==state.map:packet.map_png=PackedByteArray();packet.map_unchanged=true
		if previous.get("assets","")==state.assets:packet.assets={};packet.assets_unchanged=true
	if (not cached or peer_steam_images[peer].protocol_version==1) and previous.get("light","")==state.light and previous.get("scene","")==state.scene:packet.scene.light_field={};packet.light_unchanged=true
	return {"job":Hearth20SteamChunks.make_job(packet,"snapshot"),"cache":state}
func _pump_steam_transfers() -> void:
	if transport=="steam" and (not is_instance_valid(steam_link) or not steam_link.initialized):return
	for peer in steam_chunks.expire():_steam_transfer_failed(peer,"The Steam transfer stalled. Join the table again.")
	var peers=steam_outgoing.keys()
	if peers.is_empty():return
	var began=Time.get_ticks_usec();var first=steam_peer_cursor%peers.size();steam_peer_cursor=(first+1)%peers.size()
	for offset in peers.size():
		if Time.get_ticks_usec()-began>=2000:break
		var peer=peers[(first+offset)%peers.size()]
		if peer not in multiplayer.get_peers():steam_outgoing.erase(peer);continue
		var slot: Dictionary=steam_outgoing[peer]
		if slot.active.is_empty():
			if slot.pending.is_empty():steam_outgoing.erase(peer);continue
			var prepared=_make_steam_snapshot_job(peer,slot.pending);slot.pending={};slot.active=prepared.job;slot.cache=prepared.cache
			if slot.active.is_empty():_steam_transfer_failed(peer,"This campaign exceeds the Steam transfer limit.");continue
		var job: Dictionary=slot.active
		if Time.get_ticks_msec()-int(job.get("last_sent",job.started))>45000:_steam_transfer_failed(peer,"The Steam transfer stalled. Join the table again.");continue
		# Native send queues are finite. Leave space for moves, rolls and control RPCs.
		while Time.get_ticks_usec()-began<2000:
			if transport=="steam" and not steam_link.can_send(peer):break
			var frame=Hearth20SteamChunks.frame(job);var result=OK
			if slot.kind=="snapshot":
				frame.merge(Hearth20Identity.network_identity());result=rpc_id(peer,"receive_snapshot",frame)
			else:result=rpc_id(peer,"request_join_character",{"_h20_transfer":frame._h20_transfer},frame.bytes)
			if result!=OK:_steam_transfer_failed(peer,"The Steam connection interrupted a transfer.");break
			job.next+=1;job.last_sent=Time.get_ticks_msec()
			if slot.kind=="character":steam_link.transfer_update(float(job.next)/float(job.count),"Sending your character image…")
			if job.next>=job.count:
				if slot.kind=="snapshot":
					var state: Dictionary=slot.cache.duplicate()
					if peer_steam_images.has(peer) and state.has("image_snapshot"):peer_steam_images[peer].remember(state.image_snapshot,true)
					state.erase("image_snapshot");peer_asset_state[peer]=state
				slot.active={}
				if slot.pending.is_empty():steam_outgoing.erase(peer)
				break
func _steam_transfer_failed(peer: int,note: String) -> void:
	_finish_map_download()
	steam_chunks.clear_peer(peer);steam_outgoing.erase(peer);peer_asset_state.erase(peer)
	status_changed.emit(note)
	if local_role=="dm":_reject_peer(peer)
	elif transport=="steam" and is_instance_valid(steam_link):steam_link.connection_lost.call_deferred()
	else:stop_session()
func _refreshment_ledger_path() -> String:
	return "user://hearth20/refreshments/"+str(campaign.get("refreshment_scope","invalid"))+".json"
func _load_refreshment_ledger() -> void:
	var path=_refreshment_ledger_path()
	if not FileAccess.file_exists(path):return
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>524288:return
	var parser=JSON.new()
	if parser.parse(file.get_as_text())!=OK or not Hearth20Refreshments.valid(parser.data):return
	if not campaign.get("refreshments") is Dictionary:campaign.refreshments={}
	for player in parser.data:
		if float(parser.data[player].updated_at)>float(campaign.refreshments.get(player,{}).get("updated_at",-1.)):campaign.refreshments[player]=parser.data[player]
	Hearth20Refreshments.advance(campaign,Time.get_unix_time_from_system())
func _save_refreshment_ledger() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://hearth20/refreshments"))
	var path=_refreshment_ledger_path();var file=FileAccess.open(path+".writing",FileAccess.WRITE)
	if file==null:return
	file.store_string(JSON.stringify(campaign.get("refreshments",{})));file.close();DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".writing"),ProjectSettings.globalize_path(path))

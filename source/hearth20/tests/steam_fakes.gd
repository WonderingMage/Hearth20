extends RefCounted
class Packet extends RefCounted:
	func get_connection_handle() -> int:return 7
class Peer extends MultiplayerPeerExtension:
	var hosting=false
	var status=MultiplayerPeer.CONNECTION_DISCONNECTED
	var target=0
	var channel=0
	var mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var refused=false
	var ids={1:76561198000000001,44:76561198000000002}
	var packet=Packet.new()
	var relay=true
	func create_host(_port: int) -> int:hosting=true;status=MultiplayerPeer.CONNECTION_CONNECTED;return OK
	func create_client(_owner: int,_port: int) -> int:hosting=false;status=MultiplayerPeer.CONNECTION_CONNECTING;return OK
	func set_server_relay(value: bool) -> void:relay=value
	func get_steam_id_for_peer_id(id: int) -> int:return int(ids.get(id,0))
	func get_peer(_id: int):return packet
	func _get_available_packet_count() -> int:return 0
	func _get_unique_id() -> int:return 1 if hosting else 44
	func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:return status
	func _is_server() -> bool:return hosting
	func _is_server_relay_supported() -> bool:return false
	func _get_max_packet_size() -> int:return 524288
	func _poll() -> void:pass
	func _close() -> void:status=MultiplayerPeer.CONNECTION_DISCONNECTED
	func _set_target_peer(value: int) -> void:target=value
	func _set_transfer_channel(value: int) -> void:channel=value
	func _get_transfer_channel() -> int:return channel
	func _set_transfer_mode(value: MultiplayerPeer.TransferMode) -> void:mode=value
	func _get_transfer_mode() -> MultiplayerPeer.TransferMode:return mode
	func _set_refuse_new_connections(value: bool) -> void:refused=value
	func _is_refusing_new_connections() -> bool:return refused
	func _get_packet_peer() -> int:return 1
	func _get_packet_channel() -> int:return 0
	func _get_packet_mode() -> MultiplayerPeer.TransferMode:return mode
	func _get_packet_script() -> PackedByteArray:return PackedByteArray()
	func _put_packet_script(_data: PackedByteArray) -> Error:return OK
	func _disconnect_peer(_id: int,_force: bool) -> void:pass
class Api extends Node:
	signal lobby_created(result: int,lobby: int)
	signal lobby_joined(lobby: int,permissions: int,locked: bool,response: int)
	signal lobby_data_update(success: int,lobby: int,member: int)
	signal lobby_chat_update(lobby: int,changed: int,making: int,state: int)
	signal join_requested(lobby: int,friend: int)
	signal steam_shutdown
	signal steam_server_disconnected(reason: int)
	var calls=[]
	var running=true
	var online=true
	var init_status=0
	var user=76561198000000001
	var lobby_owner=76561198000000001
	var members=[76561198000000001,76561198000000002]
	var data={}
	var pending=0
	var unacknowledged=0
	func isSteamRunning() -> bool:return running
	func steamInitEx(id: int,embed: bool) -> Dictionary:calls.append(["init",id,embed]);return {"status":init_status}
	func loggedOn() -> bool:return online
	func getSteamID() -> int:return user
	func getPersonaName() -> String:return "Fixture Adventurer"
	func steamShutdown() -> void:calls.append(["shutdown"])
	func initRelayNetworkAccess() -> void:calls.append(["relay"])
	func run_callbacks() -> void:pass
	func createLobby(kind: int,count: int) -> void:calls.append(["create",kind,count])
	func joinLobby(id: int) -> void:calls.append(["join",id])
	func leaveLobby(id: int) -> void:calls.append(["leave",id])
	func setLobbyData(_id: int,key: String,value: String) -> bool:data[key]=value;return true
	func getLobbyData(_id: int,key: String) -> String:return str(data.get(key,""))
	func getLobbyOwner(_id: int) -> int:return lobby_owner
	func getNumLobbyMembers(_id: int) -> int:return members.size()
	func getLobbyMemberByIndex(_id: int,index: int) -> int:return members[index]
	func setLobbyMemberLimit(_id: int,_count: int) -> bool:return true
	func setLobbyJoinable(_id: int,_value: bool) -> bool:return true
	func requestLobbyData(id: int) -> bool:calls.append(["data",id]);return true
	func isOverlayEnabled() -> bool:return false
	func activateGameOverlayInviteDialog(id: int) -> void:calls.append(["overlay",id])
	func getFriendCount(_flags: int) -> int:return 2
	func getFriendByIndex(index: int,_flags: int) -> int:return 76561198000000002+index
	func getFriendPersonaName(id: int) -> String:return "Bram" if id==76561198000000002 else "Aurelia"
	func inviteUserToLobby(lobby: int,id: int) -> bool:calls.append(["invite",lobby,id]);return true
	func getConnectionRealTimeStatus(_handle: int,_lanes: int,_status: bool) -> Dictionary:return {"response":1,"connection_status":{"pending_reliable":pending,"sent_unacknowledged_reliable":unacknowledged}}

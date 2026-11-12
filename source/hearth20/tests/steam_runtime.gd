extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func run() -> void:
	var link=root.get_node("SteamLink")
	expect(not link.initialized and not Engine.has_singleton("Steam"),"native Steam is lazy at startup")
	var loaded=Hearth20SteamRuntime.load_native();expect(loaded.ok,"pinned extension extracts, verifies and loads in the real engine")
	expect(Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer"),"native lobby and peer APIs are both registered")
	var peer=ClassDB.instantiate("SteamMultiplayerPeer");peer.transfer_channel=2
	expect(peer.transfer_channel==2,"native peer accepts the dedicated background-map channel without signing in")
	var native=Engine.get_singleton("Steam")
	for name_value in ["steamInitEx","run_callbacks","createLobby","joinLobby","leaveLobby","getLobbyData","setLobbyData","inviteUserToLobby","getConnectionRealTimeStatus","setGlobalConfigValueInt32","setConnectionConfigValueInt32","getConnectionInfo"]:expect(native.has_method(name_value),"native API is present: "+name_value)
	for name_value in ["lobby_created","lobby_joined","join_requested","lobby_data_update","steam_shutdown"]:expect(native.has_signal(name_value),"native signal is present: "+name_value)
	expect(not bool(ProjectSettings.get_setting("steam/initialization/processes/initialize_on_startup")),"loading the component does not auto-initialize Steam")
	expect(not link.initialized and link.api==null,"the runtime inspection never signs in or contacts Steam")
	expect(Hearth20SteamRuntime.load_native().ok,"repeated load reuses the existing component")
	print("Steam runtime: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

extends RefCounted
class_name Hearth20SteamRuntime
## Extract a pinned native component on demand; the portable stays self-contained.
const ROOT="res://hearth20/steam/"
static func load_native() -> Dictionary:
	if Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer"):return {"ok":true}
	if not OS.has_feature("windows") or not OS.has_feature("64"):return {"ok":false,"error":"Steam mode currently needs 64-bit Windows."}
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"native-manifest.json"))
	if not manifest is Dictionary or manifest.get("version","")!="4.23.2":return {"ok":false,"error":"The bundled Steam component is missing. Re-download this build."}
	var variant="native-debug.bin" if OS.has_feature("debug") else "native-release.bin"
	var folder=ProjectSettings.globalize_path("user://hearth20/steam-native/4.23.2-"+str(manifest.files[variant].sha256).left(12))
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:return {"ok":false,"error":"The Steam component could not be prepared in your local profile."}
	for name_value in [variant,"steam-api.bin"]:
		var record: Dictionary=manifest.files[name_value];var destination=folder.path_join(str(record.output))
		if FileAccess.file_exists(destination) and FileAccess.get_sha256(destination)==record.sha256:continue
		var bytes=FileAccess.get_file_as_bytes(ROOT+name_value)
		if bytes.size()!=int(record.bytes) or Hearth20Contracts.sha256(bytes)!=record.sha256:return {"ok":false,"error":"The bundled Steam component failed verification. Re-download this build."}
		var file=FileAccess.open(destination+".partial",FileAccess.WRITE)
		if file==null:return {"ok":false,"error":"Windows could not write the Steam component."}
		file.store_buffer(bytes);file.close()
		if DirAccess.rename_absolute(destination+".partial",destination)!=OK:return {"ok":false,"error":"The Steam component is in use. Close Hearth20 and try again."}
	var library=folder.path_join(str(manifest.files[variant].output)).replace("\\","/")
	var config=ConfigFile.new();config.set_value("configuration","entry_symbol","godotsteam_init");config.set_value("configuration","compatibility_minimum","4.4")
	config.set_value("libraries","windows.debug.x86_64",library);config.set_value("libraries","windows.release.x86_64",library)
	var extension=folder.path_join("hearth20-steam.gdextension")
	if config.save(extension)!=OK:return {"ok":false,"error":"The Steam component configuration could not be prepared."}
	ProjectSettings.set_setting("steam/initialization/processes/initialize_on_startup",false)
	ProjectSettings.set_setting("steam/initialization/processes/embed_callbacks",false)
	ProjectSettings.set_setting("steam/multiplayer_peer/max_channels",4)
	var result=GDExtensionManager.load_extension(extension)
	if result not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED] or not Engine.has_singleton("Steam") or not ClassDB.class_exists("SteamMultiplayerPeer"):
		return {"ok":false,"error":"This build could not load Steam networking. Direct IP is still available."}
	return {"ok":true}

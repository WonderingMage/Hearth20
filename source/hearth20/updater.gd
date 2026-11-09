extends Node
class_name Hearth20Updater
signal changed
const REPOSITORY="WonderingMage/Hearth20"
const RELEASES_PAGE="https://github.com/"+REPOSITORY+"/releases"
const API="https://api.github.com/repos/"+REPOSITORY+"/releases?per_page=100"
const ASSET="Hearth20_Beta_Portable.exe"
const MANIFEST="Hearth20-Beta-Manifest.json"
const TEST_MANIFEST="Hearth20-Steam-Test-Manifest.json"
const LIMIT=1500*1024*1024
var app: Hearth20App
var request: HTTPRequest
var release={}
var manifest={}
var stage="idle"
var busy=false
var verified=false
var progress=0.
var message="Check when you are ready. Updates are downloaded only when you ask."
var staged_path=""
var hashing: Thread
var tick=0.
var channel=Hearth20Preferences.values.get("update_channel",Hearth20Identity.UPDATE_CHANNEL_DEFAULT)
var startup_checked=false
var startup_watch=false
var startup_prompt: ConfirmationDialog
var startup_note: Label
var startup_progress: ProgressBar
var install_requested=false
static func service(owner: Node) -> Hearth20Updater:
	var shared=owner.get_node_or_null("/root/Updates")
	if shared!=null:return shared
	var updater=Hearth20Updater.new();owner.add_child(updater);return updater
func _ready() -> void:
	request=HTTPRequest.new();request.use_threads=true;request.timeout=30.;add_child(request);request.request_completed.connect(_received)
	changed.connect(_startup_status)
	var previous=JSON.parse_string(FileAccess.get_file_as_string(Hearth20Identity.UPDATE_ROOT+"/install-plan.json.result")) if FileAccess.file_exists(Hearth20Identity.UPDATE_ROOT+"/install-plan.json.result") else null
	if previous is Dictionary:
		message="Last update installed successfully." if previous.get("ok",false) else "The last update could not start. Your previous portable was restored." if previous.get("rolled_back",false) else "The last update was not installed. Your current game is unchanged."
func startup_check() -> void:
	if startup_checked:return
	startup_checked=true
	if not _startup_allowed() or not Hearth20Preferences.values.get("startup_updates",true):return
	channel=Hearth20Preferences.values.update_channel;startup_watch=true;check()
func _startup_allowed() -> bool:
	return DisplayServer.get_name()!="headless" and not OS.has_feature("editor") and "--script" not in OS.get_cmdline_args() and Hearth20MultiplayerLab.child_slot().is_empty()
func _startup_status() -> void:
	if startup_watch and not busy:
		startup_watch=false
		if not release.is_empty():show_startup_prompt()
	if not is_instance_valid(startup_prompt):return
	startup_note.text=message
	startup_progress.visible=busy;startup_progress.value=progress
	startup_prompt.get_ok_button().disabled=busy or install_requested
	startup_prompt.ok_button_text="Restart & update" if verified else "Update & restart"
	startup_prompt.get_cancel_button().text="Cancel download" if busy and stage=="download" else "Later"
func show_startup_prompt() -> void:
	if is_instance_valid(startup_prompt):return
	startup_prompt=ConfirmationDialog.new();startup_prompt.name="StartupUpdatePrompt";startup_prompt.title="A new chapter for Hearth20";startup_prompt.theme=Hearth20Design.theme();startup_prompt.exclusive=false;startup_prompt.dialog_hide_on_ok=false;startup_prompt.size=Vector2i(560,260)
	var column=VBoxContainer.new();column.custom_minimum_size=Vector2(500,180);column.add_theme_constant_override("separation",16);startup_prompt.add_child(column)
	var heading=Label.new();heading.text="HEARTH20 "+str(release.version);heading.add_theme_font_override("font",Hearth20Design.font(true));heading.add_theme_font_size_override("font_size",27);heading.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.GOLD));column.add_child(heading)
	startup_note=Label.new();startup_note.custom_minimum_size.x=500;startup_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;startup_note.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(startup_note)
	startup_progress=ProgressBar.new();startup_progress.custom_minimum_size.y=16;column.add_child(startup_progress)
	var detail=Label.new();detail.custom_minimum_size.x=500;detail.text="Download the verified release, then confirm the restart when it is ready.";detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(detail)
	startup_prompt.confirmed.connect(_accept_startup_update);startup_prompt.canceled.connect(_dismiss_startup_update);startup_prompt.close_requested.connect(_dismiss_startup_update)
	get_tree().root.add_child(startup_prompt);_startup_status();Hearth20Regal.sync(startup_prompt);startup_prompt.popup_centered(Vector2i(560,280))
func _accept_startup_update() -> void:
	if busy:return
	if verified:install()
	else:download()
func _dismiss_startup_update() -> void:
	if install_requested or (busy and stage=="install"):return
	if busy and stage=="download":cancel()
	if is_instance_valid(startup_prompt):startup_prompt.queue_free();startup_prompt=null
static func version_parts(value: String) -> Array:
	if value.length()>80:return []
	var rx=RegEx.new();rx.compile("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*))?$")
	var match_value=rx.search(value)
	return [] if match_value==null else [int(match_value.get_string(1)),int(match_value.get_string(2)),int(match_value.get_string(3)),match_value.get_string(4)]
static func newer(candidate: String,current: String) -> bool:
	var a=version_parts(candidate);var b=version_parts(current)
	if a.is_empty() or b.is_empty():return false
	for index in 3:
		if a[index]!=b[index]:return a[index]>b[index]
	if a[3]==b[3]:return false
	if a[3].is_empty():return true
	if b[3].is_empty():return false
	var left=a[3].split(".");var right=b[3].split(".")
	for index in mini(left.size(),right.size()):
		if left[index]==right[index]:continue
		if left[index].is_valid_int() and right[index].is_valid_int():return int(left[index])>int(right[index])
		if left[index].is_valid_int()!=right[index].is_valid_int():return not left[index].is_valid_int()
		return left[index]>right[index]
	return left.size()>right.size()
static func valid_asset(asset: Dictionary,tag: String,name_value: String) -> bool:
	var digest=str(asset.get("digest",""));var size_value=asset.get("size",0)
	return asset.get("name","")==name_value and asset.get("state","")=="uploaded" and Hearth20Contracts._integer_number(size_value) and size_value>0 and size_value<=LIMIT and digest.begins_with("sha256:") and digest.length()==71 and digest.substr(7).is_valid_hex_number(false) and asset.get("browser_download_url","")=="https://github.com/"+REPOSITORY+"/releases/download/"+tag+"/"+name_value
static func select_release(records: Variant,current: String,update_channel="beta") -> Dictionary:
	if not records is Array:return {}
	var best={}
	for item in records:
		if not item is Dictionary or item.get("draft",true):continue
		var tag=str(item.get("tag_name",""));var prefix="hearth20-steam-test-v" if tag.begins_with("hearth20-steam-test-v") else "hearth20-beta-v"
		var test_channel=prefix=="hearth20-steam-test-v"
		if not tag.begins_with(prefix) or (test_channel and update_channel!="steam-test"):continue
		var version=tag.trim_prefix(prefix)
		if not newer(version,current):continue
		var executable={};var metadata={}
		if not item.get("assets",[]) is Array:continue
		for asset in item.get("assets",[]):
			if not asset is Dictionary:continue
			if valid_asset(asset,tag,ASSET):executable=asset
			if valid_asset(asset,tag,TEST_MANIFEST if test_channel else MANIFEST) and int(asset.size)<=65536:metadata=asset
		if executable.is_empty() or metadata.is_empty():continue
		if best.is_empty() or newer(version,best.version):best={"tag":tag,"version":version,"channel":"steam-test" if test_channel else "beta","exe":executable.duplicate(true),"metadata":metadata.duplicate(true)}
	return best
static func valid_manifest(value: Variant,selected: Dictionary) -> bool:
	if not value is Dictionary or not selected.get("exe",{}) is Dictionary:return false
	if not Hearth20Contracts._integer_number(selected.exe.get("size")):return false
	for field in ["edition","product","version","tag","asset","sha256"]:
		if not value.get(field) is String:return false
	for field in ["bytes","schema","protocol"]:
		if not Hearth20Contracts._integer_number(value.get(field)):return false
	for field in ["version","tag"]:
		if not selected.get(field) is String:return false
	var selected_channel=selected.get("channel","beta")
	if not selected_channel is String or selected_channel not in ["beta","steam-test"]:return false
	if value.has("channel") and (not value.channel is String or value.channel!=selected_channel):return false
	if selected_channel=="steam-test" and value.get("channel","")!="steam-test":return false
	return value is Dictionary and value.get("edition","")==Hearth20Identity.EDITION and value.get("product","")==Hearth20Identity.PRODUCT_ID and value.get("version","")==selected.get("version","") and value.get("tag","")==selected.get("tag","") and value.get("asset","")==ASSET and value.get("bytes",0)==selected.get("exe",{}).get("size",-1) and value.get("sha256","")==str(selected.get("exe",{}).get("digest","")).trim_prefix("sha256:") and value.get("schema",-1)==Hearth20Identity.SCHEMA_VERSION and value.get("protocol",-1)==Hearth20Identity.NETWORK_PROTOCOL
func set_channel(value: String) -> void:
	if busy or install_requested or value not in ["beta","steam-test"]:return
	startup_watch=false;_dismiss_startup_update()
	channel=value;release={};manifest={};verified=false;stage="idle";_notify("Update channel changed. Check for updates to see its releases.")
func _notify(text: String) -> void:message=text;changed.emit()
func _fail(text: String) -> void:
	busy=false;stage="idle";request.download_file="";_notify(text)
func check() -> void:
	if busy or install_requested:return
	busy=true;verified=false;release={};manifest={};stage="check";request.download_file="";request.body_size_limit=4*1024*1024;request.timeout=30.;_notify("Checking GitHub · "+("Beta + Steam test builds…" if channel=="steam-test" else "Beta releases…"))
	if request.request(API,["Accept: application/vnd.github+json","User-Agent: Hearth20-Beta"])!=OK:_fail("GitHub could not be reached. Try again when you are online.")
func download() -> void:
	if busy or install_requested or release.is_empty():return
	busy=true;stage="metadata";request.download_file="";request.body_size_limit=65536;_notify("Checking the release information…")
	if request.request(release.metadata.browser_download_url,["User-Agent: Hearth20-Beta"])!=OK:_fail("The release information could not be downloaded.")
func _received(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		_fail("No Hearth20 Beta release is published yet." if stage=="check" and code==404 else "The update could not be fetched (HTTP %d). Your game is unchanged."%code);return
	if stage=="check":
		var records=JSON.parse_string(body.get_string_from_utf8())
		if not records is Array:_fail("GitHub returned unreadable release information. Try checking again.");return
		release=select_release(records,Hearth20Identity.VERSION,channel);busy=false;stage="idle"
		if release.is_empty():
			var other=select_release(records,Hearth20Identity.VERSION,"steam-test") if channel=="beta" else {}
			_notify("No newer Beta release. Steam test "+str(other.version)+" is available; select Beta + Steam test builds to download it." if not other.is_empty() else "No newer "+("Beta or Steam test" if channel=="steam-test" else "Beta")+" release. You are running "+Hearth20Identity.VERSION+".")
		else:_notify("Hearth20 "+str(release.version)+(" · Steam test" if release.channel=="steam-test" else " · Beta")+" is available. Download size: %.0f MB."%(float(release.exe.size)/1048576.))
		return
	if stage=="metadata":
		if Hearth20Contracts.sha256(body)!=str(release.metadata.digest).trim_prefix("sha256:"):_fail("Release information failed its GitHub checksum. Nothing was installed.");return
		var parsed=JSON.parse_string(body.get_string_from_utf8())
		if not valid_manifest(parsed,release):_fail("This release belongs to another edition or needs a different campaign/network version. Open the release page for instructions.");return
		manifest=parsed
		var folder=ProjectSettings.globalize_path(Hearth20Identity.UPDATE_ROOT+"/staged");DirAccess.make_dir_recursive_absolute(folder);staged_path=folder.path_join("Hearth20-"+str(release.version)+".exe")
		request.download_file=staged_path+".partial";request.body_size_limit=LIMIT;request.timeout=0.;stage="download";progress=0.;_notify("Downloading the verified release. You can cancel and keep playing.")
		if request.request(release.exe.browser_download_url,["User-Agent: Hearth20-Beta"])!=OK:_fail("The update download could not start.")
	elif stage=="download":
		var path=staged_path+".partial"
		var downloaded=FileAccess.open(path,FileAccess.READ)
		if downloaded==null or downloaded.get_length()!=int(release.exe.size):_fail("The downloaded file is incomplete. Nothing was installed.");return
		downloaded.close()
		stage="hash";_notify("Checking the complete download against GitHub’s SHA-256 checksum…");hashing=Thread.new();hashing.start(func():return FileAccess.get_sha256(path))
func _process(delta: float) -> void:
	tick+=delta
	if tick<.15:return
	tick=0.
	if busy and stage=="download":progress=100.*float(request.get_downloaded_bytes())/maxf(1.,float(release.exe.size));changed.emit()
	if hashing!=null and not hashing.is_alive():
		var digest=hashing.wait_to_finish();hashing=null
		if digest!=manifest.get("sha256",""):_fail("The download checksum did not match GitHub. Nothing was installed.");return
		if DirAccess.rename_absolute(staged_path+".partial",staged_path)!=OK:_fail("The verified update could not be staged. Check free disk space.");return
		verified=true;busy=false;stage="ready";progress=100.;_notify("Verified and ready. Leave multiplayer, then restart to update. Your previous EXE is retained as a backup.")
func cancel() -> void:
	var cancelled_download=busy and stage in ["download","hash"]
	if request!=null:request.cancel_request()
	if hashing!=null:hashing.wait_to_finish();hashing=null
	if stage in ["download","hash"] and FileAccess.file_exists(staged_path+".partial"):DirAccess.remove_absolute(staged_path+".partial")
	busy=false;stage="ready" if verified else "idle"
	if cancelled_download:message="Download cancelled. Your current portable is unchanged."
	changed.emit()
func install() -> void:
	if not verified or busy or install_requested:return
	install_requested=true;changed.emit()
	await _install_verified()
	install_requested=false;changed.emit()
func _install_verified() -> void:
	if not verified:return
	if not is_instance_valid(app):app=null
	if OS.has_feature("editor"):_notify("Restart updates are available in the portable edition.");return
	if app!=null and not (app.session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer):_notify("Leave the multiplayer session before restarting for an update.");return
	if app!=null and is_instance_valid(app.beyond_sheet):
		if not await app.beyond_sheet.release_for_shutdown():_notify("Return your browser to its own window before restarting to update.");return
	if app!=null and app.session.local_role=="dm":
		var backup=Hearth20Identity.save_campaign(app.campaign,Hearth20Identity.SAVE_ROOT+"/before-update-"+str(int(Time.get_unix_time_from_system()))+"-"+Crypto.new().generate_random_bytes(3).hex_encode()+"."+Hearth20Identity.SAVE_EXTENSION)
		if not backup.ok:_notify("A campaign backup could not be written. The update was not started.");return
		var saved=Hearth20Identity.save_campaign(app.campaign,Hearth20Identity.SAVE_ROOT+"/table."+Hearth20Identity.SAVE_EXTENSION)
		if not saved.ok:_notify("Your campaign could not be saved. The update was not started.");return
	var folder=ProjectSettings.globalize_path(Hearth20Identity.UPDATE_ROOT)
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:_notify("The update folder could not be prepared. Check that it is writable.");return
	var helper=folder.path_join("Hearth20UpdateHost.exe");var data=FileAccess.get_file_as_bytes("res://hearth20/updater/Hearth20UpdateHost.exe");var file=FileAccess.open(helper,FileAccess.WRITE)
	if file==null:_notify("The update helper could not be prepared.");return
	file.store_buffer(data);file.flush();var helper_error=file.get_error();file.close()
	if helper_error!=OK:_notify("The update helper could not be written. Check free space and folder access.");return
	var plan={"edition":Hearth20Identity.EDITION,"version":release.version,"target":OS.get_executable_path(),"staged":staged_path,"sha256":manifest.sha256,"pid":OS.get_process_id()}
	var path=folder.path_join("install-plan.json")
	if not _write_json(path,plan):_notify("The update plan could not be written. Check free space and folder access, then try again.");return
	for suffix in [".ready",".confirmed",".result"]:
		if DirAccess.dir_exists_absolute(path+suffix) or (FileAccess.file_exists(path+suffix) and DirAccess.remove_absolute(path+suffix)!=OK):_notify("The previous update markers could not be cleared. Check folder access, then try again.");return
	if OS.create_process(helper,[path])<0:_notify("Windows could not start the updater. Your game is unchanged.");return
	busy=true;stage="install";_notify("Preparing your replacement portable and backup. Hearth20 will restart when ready…")
	var deadline=Time.get_ticks_msec()+60000
	while is_inside_tree() and not FileAccess.file_exists(path+".ready") and not FileAccess.file_exists(path+".result") and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.15).timeout
	if FileAccess.file_exists(path+".ready"):get_tree().quit()
	else:_fail("The replacement could not be prepared. The current game is unchanged; check that the portable’s folder is writable and has enough free space.")
static func _write_json(path: String,value: Dictionary) -> bool:
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(value));file.flush()
	var error=file.get_error();file.close()
	return error==OK
static func confirm_startup() -> void:
	var args=OS.get_cmdline_user_args();var marker=args.find("--hearth20-update-confirm")
	if marker<0 or marker+1>=args.size():return
	var path=str(args[marker+1]).simplify_path();var root=ProjectSettings.globalize_path(Hearth20Identity.UPDATE_ROOT).simplify_path()
	if path.get_base_dir()!=root or path.get_file()!="install-plan.json":return
	var plan=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not plan is Dictionary or plan.get("edition","")!=Hearth20Identity.EDITION or plan.get("version","")!=Hearth20Identity.VERSION or str(plan.get("target","")).replace("\\","/")!=OS.get_executable_path().replace("\\","/"):return
	_write_json(path+".confirmed",{"version":Hearth20Identity.VERSION,"pid":OS.get_process_id()})
func _exit_tree() -> void:cancel()

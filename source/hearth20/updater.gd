extends Node
class_name Hearth20Updater
signal changed
const REPOSITORY="WonderingMage/Hearth20"
const RELEASES_PAGE="https://github.com/"+REPOSITORY+"/releases"
const API="https://api.github.com/repos/"+REPOSITORY+"/releases?per_page=30"
const ASSET="Hearth20_Beta_Portable.exe"
const MANIFEST="Hearth20-Beta-Manifest.json"
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
func _ready() -> void:
	request=HTTPRequest.new();request.use_threads=true;request.timeout=30.;add_child(request);request.request_completed.connect(_received)
	var previous=JSON.parse_string(FileAccess.get_file_as_string(Hearth20Identity.UPDATE_ROOT+"/install-plan.json.result")) if FileAccess.file_exists(Hearth20Identity.UPDATE_ROOT+"/install-plan.json.result") else null
	if previous is Dictionary:
		message="Last update installed successfully." if previous.get("ok",false) else "The last update could not start. Your previous portable was restored." if previous.get("rolled_back",false) else "The last update was not installed. Your current game is unchanged."
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
static func select_release(records: Variant,current: String) -> Dictionary:
	if not records is Array:return {}
	var best={}
	for item in records:
		if not item is Dictionary or item.get("draft",true):continue
		var tag=str(item.get("tag_name",""));var version=tag.trim_prefix("hearth20-beta-v")
		if not tag.begins_with("hearth20-beta-v") or not newer(version,current):continue
		var executable={};var metadata={}
		if not item.get("assets",[]) is Array:continue
		for asset in item.get("assets",[]):
			if not asset is Dictionary:continue
			if valid_asset(asset,tag,ASSET):executable=asset
			if valid_asset(asset,tag,MANIFEST) and int(asset.size)<=65536:metadata=asset
		if executable.is_empty() or metadata.is_empty():continue
		if best.is_empty() or newer(version,best.version):best={"tag":tag,"version":version,"exe":executable.duplicate(true),"metadata":metadata.duplicate(true)}
	return best
static func valid_manifest(value: Variant,selected: Dictionary) -> bool:
	return value is Dictionary and value.get("edition","")==Hearth20Identity.EDITION and value.get("product","")==Hearth20Identity.PRODUCT_ID and value.get("version","")==selected.get("version","") and value.get("tag","")==selected.get("tag","") and value.get("asset","")==ASSET and value.get("bytes",0)==selected.get("exe",{}).get("size",-1) and value.get("sha256","")==str(selected.get("exe",{}).get("digest","")).trim_prefix("sha256:") and value.get("schema",-1)==Hearth20Identity.SCHEMA_VERSION and value.get("protocol",-1)==Hearth20Identity.NETWORK_PROTOCOL
func _notify(text: String) -> void:message=text;changed.emit()
func _fail(text: String) -> void:
	busy=false;stage="idle";request.download_file="";_notify(text)
func check() -> void:
	if busy:return
	busy=true;verified=false;release={};manifest={};stage="check";request.download_file="";request.body_size_limit=2*1024*1024;request.timeout=30.;_notify("Looking for a Hearth20 Beta release on GitHub…")
	if request.request(API,["Accept: application/vnd.github+json","User-Agent: Hearth20-Beta"])!=OK:_fail("GitHub could not be reached. Try again when you are online.")
func download() -> void:
	if busy or release.is_empty():return
	busy=true;stage="metadata";request.download_file="";request.body_size_limit=65536;_notify("Checking the release information…")
	if request.request(release.metadata.browser_download_url,["User-Agent: Hearth20-Beta"])!=OK:_fail("The release information could not be downloaded.")
func _received(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		_fail("No Hearth20 Beta release is published yet." if stage=="check" and code==404 else "The update could not be fetched (HTTP %d). Your game is unchanged."%code);return
	if stage=="check":
		release=select_release(JSON.parse_string(body.get_string_from_utf8()),Hearth20Identity.VERSION);busy=false;stage="idle"
		_notify("You have the latest published Hearth20 Beta." if release.is_empty() else "Hearth20 Beta "+str(release.version)+" is available. Download size: %.0f MB."%(float(release.exe.size)/1048576.));return
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
	if not verified:return
	if OS.has_feature("editor"):_notify("Restart updates are available in the portable edition.");return
	if app!=null and not (app.session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer):_notify("Leave the multiplayer session before restarting for an update.");return
	if app!=null and app.session.local_role=="dm":
		var backup=Hearth20Identity.save_campaign(app.campaign,Hearth20Identity.SAVE_ROOT+"/before-update-"+str(int(Time.get_unix_time_from_system()))+"-"+Crypto.new().generate_random_bytes(3).hex_encode()+"."+Hearth20Identity.SAVE_EXTENSION)
		if not backup.ok:_notify("A campaign backup could not be written. The update was not started.");return
		var saved=Hearth20Identity.save_campaign(app.campaign,Hearth20Identity.SAVE_ROOT+"/table."+Hearth20Identity.SAVE_EXTENSION)
		if not saved.ok:_notify("Your campaign could not be saved. The update was not started.");return
	var folder=ProjectSettings.globalize_path(Hearth20Identity.UPDATE_ROOT);DirAccess.make_dir_recursive_absolute(folder)
	var helper=folder.path_join("Hearth20UpdateHost.exe");var data=FileAccess.get_file_as_bytes("res://hearth20/updater/Hearth20UpdateHost.exe");var file=FileAccess.open(helper,FileAccess.WRITE)
	if file==null:_notify("The update helper could not be prepared.");return
	file.store_buffer(data);file.close()
	var plan={"edition":Hearth20Identity.EDITION,"version":release.version,"target":OS.get_executable_path(),"staged":staged_path,"sha256":manifest.sha256,"pid":OS.get_process_id()};var path=folder.path_join("install-plan.json");FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(plan))
	for suffix in [".ready",".confirmed",".result"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	if OS.create_process(helper,[path])<0:_notify("Windows could not start the updater. Your game is unchanged.");return
	busy=true;stage="install";_notify("Preparing your replacement portable and backup. Hearth20 will restart when ready…")
	var deadline=Time.get_ticks_msec()+60000
	while is_inside_tree() and not FileAccess.file_exists(path+".ready") and not FileAccess.file_exists(path+".result") and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.15).timeout
	if FileAccess.file_exists(path+".ready"):get_tree().quit()
	else:_fail("The replacement could not be prepared. The current game is unchanged; check that the portable’s folder is writable and has enough free space.")
static func confirm_startup() -> void:
	var args=OS.get_cmdline_user_args();var marker=args.find("--hearth20-update-confirm")
	if marker<0 or marker+1>=args.size():return
	var path=str(args[marker+1]).simplify_path();var root=ProjectSettings.globalize_path(Hearth20Identity.UPDATE_ROOT).simplify_path()
	if path.get_base_dir()!=root or path.get_file()!="install-plan.json":return
	var plan=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not plan is Dictionary or plan.get("edition","")!=Hearth20Identity.EDITION or plan.get("version","")!=Hearth20Identity.VERSION or str(plan.get("target","")).replace("\\","/")!=OS.get_executable_path().replace("\\","/"):return
	FileAccess.open(path+".confirmed",FileAccess.WRITE).store_string(JSON.stringify({"version":Hearth20Identity.VERSION,"pid":OS.get_process_id()}))
func _exit_tree() -> void:cancel()

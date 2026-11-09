extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func release(version: String,test=false) -> Dictionary:
	var tag=("hearth20-steam-test-v" if test else "hearth20-beta-v")+version
	var assets=[]
	for name_value in [Hearth20Updater.ASSET,Hearth20Updater.TEST_MANIFEST if test else Hearth20Updater.MANIFEST]:
		assets.append({"name":name_value,"state":"uploaded","size":1024,"digest":"sha256:"+"a".repeat(64),"browser_download_url":"https://github.com/WonderingMage/Hearth20/releases/download/"+tag+"/"+name_value})
	return {"tag_name":tag,"draft":false,"prerelease":false,"assets":assets}
func run() -> void:
	expect(Hearth20Identity.UPDATE_CHANNEL_DEFAULT=="beta","regular portable defaults to the ordinary Beta channel")
	expect(Hearth20Preferences.DEFAULTS.update_channel=="beta","fresh settings use ordinary Beta updates")
	expect(Hearth20Preferences.sanitized({}).startup_updates,"fresh installations check for updates at launch")
	var catalog=[release("0.3.11-beta"),release("0.3.12-beta",true),release("0.2.4-beta")]
	var chosen=Hearth20Updater.select_release(catalog,"0.3.10-beta")
	expect(chosen.version=="0.3.11-beta" and chosen.channel=="beta","default selection discovers the regular release without opting in")
	for previous in ["0.2.3-beta","0.2.4-beta","0.3.6-beta","0.3.9-beta","0.3.10-beta"]:
		expect(Hearth20Updater.select_release(catalog,previous,"beta").version=="0.3.11-beta","ordinary upgrade from "+previous)
	expect(Hearth20Updater.select_release(catalog,"0.3.10-beta","steam-test").version=="0.3.12-beta","an explicit testing preference is honored")
	expect(Hearth20Updater.select_release([catalog[0]],"0.3.10-beta","steam-test").version=="0.3.11-beta","combined-channel users also receive the regular release")
	expect(Hearth20Updater.select_release(catalog,"0.3.11-beta","beta").is_empty(),"up-to-date ordinary users are not prompted for a test build")
	var bad=catalog[0].duplicate(true);bad.draft=true
	expect(Hearth20Updater.select_release([bad],"0.3.10-beta").is_empty(),"draft releases cannot be offered")
	bad=catalog[0].duplicate(true);bad.assets[0].digest="sha256:bad"
	expect(Hearth20Updater.select_release([bad],"0.3.10-beta").is_empty(),"invalid download digests cannot be offered")
	var metadata={"product":Hearth20Identity.PRODUCT_ID,"edition":Hearth20Identity.EDITION,"version":chosen.version,"tag":chosen.tag,"asset":Hearth20Updater.ASSET,"bytes":1024,"sha256":"a".repeat(64),"schema":1,"protocol":2}
	expect(Hearth20Updater.valid_manifest(metadata,chosen),"regular release manifest validates against the selected asset")
	for key in ["product","edition","version","tag","asset","bytes","sha256","schema","protocol"]:
		var tampered=metadata.duplicate(true);tampered[key]="forged"
		expect(not Hearth20Updater.valid_manifest(tampered,chosen),"tampered manifest rejected · "+key)
	for key in metadata:
		for value in [null,true,{},[],NAN,INF,"",-1]:
			var tampered=metadata.duplicate(true);tampered[key]=value
			expect(not Hearth20Updater.valid_manifest(tampered,chosen),"malformed manifest field rejected · "+key+" · "+str(value))
	for value in [null,true,{},[],NAN,INF,""]:
		var tampered=chosen.duplicate(true);tampered.exe.size=value
		expect(not Hearth20Updater.valid_manifest(metadata,tampered),"malformed selected download size rejected")
	print("Regular release: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

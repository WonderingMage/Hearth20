extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func asset(name_value: String,version="0.2.4-beta") -> Dictionary:
	var tag="hearth20-beta-v"+version
	return {"name":name_value,"state":"uploaded","size":4096,"digest":"sha256:"+"a".repeat(64),"browser_download_url":"https://github.com/"+Hearth20Updater.REPOSITORY+"/releases/download/"+tag+"/"+name_value}
func run() -> void:
	var clean=Hearth20Preferences.sanitized({"master":99,"party":-5,"width":-1,"height":99999,"window_mode":99,"fps":71,"vsync":"forged","quality":-1,"unknown":"ignored"})
	expect(clean.master==1. and clean.party==0.,"volume ranges clamped")
	expect(clean.width==960 and clean.height==4320 and clean.window_mode==2 and clean.quality==0,"display limits clamped")
	expect(clean.fps==60 and clean.vsync==true and not clean.has("unknown"),"invalid preferences retain defaults")
	var previous=Hearth20Preferences.values.duplicate(true);var settings=previous.duplicate();settings.master=.43;settings.party=.27;settings.fps=45;settings.background_fps=30
	expect(Hearth20Preferences.save(settings)==OK and Hearth20Preferences.read()==settings,"settings survive disk reload")
	Hearth20Preferences.apply_audio(settings)
	expect(absf(db_to_linear(AudioServer.get_bus_volume_db(0))-.43)<.001,"master volume applied")
	expect(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Tavern & Party")))-.27)<.001,"party volume independent")
	Hearth20Preferences.apply_focus(false);expect(Engine.max_fps==30,"background frame limit applied");Hearth20Preferences.apply_focus(true);expect(Engine.max_fps==45,"foreground frame limit applied")
	for pair in [["0.2.4-beta","0.2.3-beta",true],["0.2.3","0.2.3-beta",true],["0.2.3-beta.10","0.2.3-beta.9",true],["0.2.3-beta","0.2.3",false],["0.2.2-beta","0.2.3-beta",false],["0.2.3-beta","0.2.3-beta",false],["../../evil","0.2.3-beta",false]]:expect(Hearth20Updater.newer(pair[0],pair[1])==pair[2],"version ordering "+pair[0])
	var record={"tag_name":"hearth20-beta-v0.2.4-beta","draft":false,"prerelease":true,"assets":[asset(Hearth20Updater.ASSET),asset(Hearth20Updater.MANIFEST)]}
	var selected=Hearth20Updater.select_release([record],"0.2.3-beta");expect(not selected.is_empty() and selected.version=="0.2.4-beta","verified Beta release selected")
	expect(not Hearth20Updater.select_release(JSON.parse_string(JSON.stringify([record])),"0.2.3-beta").is_empty(),"GitHub JSON number types accepted")
	for field in ["digest","state","browser_download_url","size"]:
		var bad=record.duplicate(true);bad.assets[0][field]=-1 if field=="size" else "forged";expect(Hearth20Updater.select_release([bad],"0.2.3-beta").is_empty(),"reject altered release "+field)
	var draft=record.duplicate(true);draft.draft=true;expect(Hearth20Updater.select_release([draft],"0.2.3-beta").is_empty(),"drafts ignored")
	var classic=record.duplicate(true);classic.tag_name="v99.0.0";expect(Hearth20Updater.select_release([classic],"0.2.3-beta").is_empty(),"classic release channel ignored")
	expect(Hearth20Updater.select_release([record],"0.2.4-beta").is_empty(),"same release not offered as update")
	var manifest={"edition":Hearth20Identity.EDITION,"product":Hearth20Identity.PRODUCT_ID,"version":selected.version,"tag":selected.tag,"asset":Hearth20Updater.ASSET,"bytes":4096,"sha256":"a".repeat(64),"schema":1,"protocol":2}
	expect(Hearth20Updater.valid_manifest(manifest,selected),"matching edition manifest accepted")
	for field in manifest:
		var bad=manifest.duplicate(true);bad[field]=-1 if field in ["bytes","schema","protocol"] else "forged";expect(not Hearth20Updater.valid_manifest(bad,selected),"reject mismatched manifest "+field)
	Hearth20Preferences.save(previous);Hearth20Preferences.apply_audio(previous)
	print("Preferences and updates: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

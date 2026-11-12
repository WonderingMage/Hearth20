extends SceneTree
const Saved=preload("campaign_saves.gd")
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func complete(manager: Hearth20Autosave) -> void:
	var deadline=Time.get_ticks_msec()+15000
	while manager.active and Time.get_ticks_msec()<deadline:manager.tick(Time.get_ticks_msec());await process_frame
	expect(not manager.active and manager.last_result.get("ok",false),"background snapshot finishes successfully")
func run() -> void:
	create_timer(25).timeout.connect(func():push_error("Autosave test watchdog");quit(1))
	if not OS.get_environment("APPDATA").replace("\\","/").contains("/qa/"):
		push_error("Autosave checks require an isolated QA profile");quit(1);return
	for suffix in ["",".previous",".meta.json",".thumb.png"]:
		if FileAccess.file_exists(Hearth20Autosave.PATH+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(Hearth20Autosave.PATH+suffix))
	var app=Saved.AppFixture.new();root.add_child(app)
	var scene=app.campaign.scenes[0];var pawn=Hearth20TokenInventory.new_actor("Autosave hero",true,scene,Vector2(2.5,2.5));pawn.owner_player_id="autosave-player";app.campaign.actors.append(pawn)
	app.current_save_path=Hearth20Identity.SAVE_ROOT+"/named-table."+Hearth20Identity.SAVE_EXTENSION;app.dm_notes_editor.text="Unsaved DM notes"
	var manager=Hearth20Autosave.new();app.add_child(manager);manager.setup(app);manager.set_process(false);manager.reset_clock(1000)
	manager.tick(300999);expect(not manager.active and not FileAccess.file_exists(Hearth20Autosave.PATH),"autosave waits the full five-minute interval")
	var live_revision=app.campaign.revision;manager.tick(301000)
	expect(manager.active and manager.worker!=null,"five-minute deadline starts a background worker")
	expect(not manager.start(301001),"a second save cannot overlap the active snapshot")
	pawn.position=Vector2(3.5,2.5);app.campaign.revision+=1
	await complete(manager)
	var first=Hearth20CampaignArchive.read_table(Hearth20Autosave.PATH)
	expect(first.ok and first.campaign.actors[0].position==Vector2(2.5,2.5),"saved snapshot is detached from concurrent token movement")
	expect(app.campaign.actors[0].position==Vector2(3.5,2.5) and app.campaign.revision==live_revision+1,"saving never resets the live board or its revision")
	expect(first.campaign.dm_notes=="Unsaved DM notes","autosave includes the current notes editor")
	expect(app.current_save_path.ends_with("named-table."+Hearth20Identity.SAVE_EXTENSION),"autosave never redirects the named manual save slot")
	manager.start(601000);await complete(manager)
	var second=Hearth20CampaignArchive.read_table(Hearth20Autosave.PATH)
	expect(second.ok and second.campaign.actors[0].position==Vector2(3.5,2.5),"next autosave replaces the same slot with current data")
	var slots=Array(DirAccess.open(Hearth20Identity.SAVE_ROOT).get_files()).filter(func(path):return path.ends_with("."+Hearth20Identity.SAVE_EXTENSION))
	expect(slots==["autosave."+Hearth20Identity.SAVE_EXTENSION] and not FileAccess.file_exists(Hearth20Autosave.PATH+".previous"),"successful autosaves leave one slot and no accumulating recovery copies")
	var records=Hearth20CampaignArchive.list_tables();expect(records.size()==1 and records[0].get("autosave",false),"campaign vault identifies the autosave slot")
	var digest=FileAccess.get_sha256(Hearth20Autosave.PATH);var invalid=app.campaign.duplicate(true);invalid.revision=-1
	expect(not Hearth20Autosave.write_snapshot(invalid,Hearth20Autosave.PATH).ok and FileAccess.get_sha256(Hearth20Autosave.PATH)==digest,"failed validation preserves the previous autosave")
	app.session.local_role="player";expect(not manager.start(901000),"players cannot overwrite the host autosave slot")
	app.session.local_role="dm";app.campaign_progress=Hearth20CampaignProgress.new();app.campaign_progress.active=true
	expect(not manager.start(901000),"manual save/load work defers the automatic snapshot")
	app.campaign_progress.free();app.campaign_progress=null;manager.reset_clock(1000000)
	expect(manager.next_due==1300000,"opening another campaign resets its five-minute deadline")
	app.queue_free();await process_frame
	print("Autosave: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

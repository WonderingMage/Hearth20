extends Node
class_name Hearth20Autosave
## One detached snapshot, one replaceable slot, no modal window or live mutation.
signal changed(state: Dictionary)
const INTERVAL_MSEC=300000
const PATH=Hearth20CampaignArchive.AUTOSAVE_PATH
var app: Hearth20App
var worker: Thread
var mutex=Mutex.new()
var progress=0.
var message=""
var next_due=0
var active=false
var show_until=0
var last_result={}
func setup(owner_app: Hearth20App) -> void:
	app=owner_app;process_mode=Node.PROCESS_MODE_ALWAYS;reset_clock()
func reset_clock(now=-1) -> void:
	if now<0:now=Time.get_ticks_msec()
	next_due=now+INTERVAL_MSEC
func eligible() -> bool:
	if not is_instance_valid(app) or not is_instance_valid(app.session) or app.session.local_role!="dm" or app.campaign.is_empty():return false
	if is_instance_valid(app.campaign_progress) and app.campaign_progress.active:return false
	if not app.campaign.get("actors",[]).is_empty() or not app.current_save_path.is_empty():return true
	for scene in app.campaign.get("scenes",[]):
		if not str(scene.get("map_asset","")).is_empty() or not scene.get("annotations",[]).is_empty():return true
	return false
func report(value: float,note: String) -> void:
	mutex.lock();progress=value;message=note;mutex.unlock()
func state() -> Dictionary:
	mutex.lock();var result={"active":active,"progress":progress,"message":message};mutex.unlock()
	result.visible=active or Time.get_ticks_msec()<show_until
	return result
func tick(now: int) -> void:
	if worker!=null and not worker.is_alive():
		last_result=worker.wait_to_finish();worker=null;active=false;show_until=now+(3500 if last_result.get("ok",false) else 8000)
		report(1. if last_result.get("ok",false) else 0.,"Autosaved" if last_result.get("ok",false) else "Autosave failed · slot unchanged")
		changed.emit(state())
	if active or now<next_due or not eligible():return
	start(now)
func start(now=-1) -> bool:
	if now<0:now=Time.get_ticks_msec()
	if active or worker!=null or not eligible():return false
	# Dictionaries/arrays are detached here; strings and byte buffers use COW.
	if app.lite_bridge!=null:app.lite_bridge.sync_to_campaign()
	var snapshot=app.campaign.duplicate(true)
	if is_instance_valid(app.dm_notes_editor):snapshot.dm_notes=app.dm_notes_editor.text
	active=true;next_due=now+INTERVAL_MSEC;last_result={};report(.03,"Autosaving…")
	worker=Thread.new()
	var error=worker.start(func():return write_snapshot(snapshot,PATH,report))
	if error!=OK:worker=null;active=false;show_until=now+8000;report(0.,"Autosave could not start · previous save kept")
	changed.emit(state());return error==OK
static func write_snapshot(snapshot: Dictionary,path: String,callback: Callable=Callable()) -> Dictionary:
	# Do not acquire/evict the live renderer's image-validation cache in this
	# worker: large PNG validation must not block a map read on the main thread.
	var checked=Hearth20Contracts.validate_campaign(snapshot,false)
	if not checked.ok:return checked
	var result=Hearth20Identity._save_campaign_checked(snapshot,path,callback)
	if result.ok:
		Hearth20CampaignArchive.index_saved(snapshot,path)
		# A single slot replaces itself. The writer's recovery copy is retained
		# on failure and removed only after the replacement succeeded.
		if path==PATH and FileAccess.file_exists(path+".previous"):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".previous"))
	return result
func _process(_delta: float) -> void:
	tick(Time.get_ticks_msec())
	if active:changed.emit(state())
func _exit_tree() -> void:
	if worker!=null:worker.wait_to_finish();worker=null

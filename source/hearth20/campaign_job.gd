extends RefCounted
class_name Hearth20CampaignJob
var worker: Thread
var mutex=Mutex.new()
var progress=.05
var message="Preparing your table…"
var start_error: Error=OK
var listing_cancelled=false
func report(value: float,note: String) -> void:mutex.lock();progress=value;message=note;mutex.unlock()
func state() -> Dictionary:
	mutex.lock();var value={"progress":progress,"message":message};mutex.unlock();return value
func _start(work: Callable) -> void:
	worker=Thread.new()
	start_error=worker.start(work)
	if start_error!=OK:worker=null
func save(snapshot: Dictionary,path: String) -> void:
	_start(func():
		report(.1,"Checking your saved map and tokens…")
		var checked=Hearth20Contracts.validate_campaign(snapshot,false)
		if not checked.ok:return checked
		var result=Hearth20Identity._save_campaign_checked(snapshot,path,report)
		if result.ok:report(.96,"Finishing the campaign preview…");Hearth20CampaignArchive.index_saved(snapshot,path)
		return result)
func load_table(path: String) -> void:
	_start(func():
		if not Hearth20CampaignArchive.valid_path(path):
			return {"ok":false,"errors":["Choose a table from the campaign vault."]}
		report(.25,"Reading the saved map and tokens…")
		var result=Hearth20Identity.load_campaign(path,false)
		report(.85,"Preparing your table…")
		return result)
func list_tables() -> void:_start(func():return Hearth20CampaignArchive.list_tables(_listing_cancelled))
func cancel_listing() -> void:
	mutex.lock();listing_cancelled=true;mutex.unlock()
func _listing_cancelled() -> bool:
	mutex.lock();var cancelled=listing_cancelled;mutex.unlock();return cancelled
func done() -> bool:return start_error!=OK or (worker!=null and not worker.is_alive())
func finish() -> Variant:
	if worker==null:return null
	var result=worker.wait_to_finish()
	worker=null
	return result

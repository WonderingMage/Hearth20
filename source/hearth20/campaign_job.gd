extends RefCounted
class_name Hearth20CampaignJob
var worker: Thread
var mutex=Mutex.new()
var progress=.05
var message="Preparing your table…"
func report(value: float,note: String) -> void:mutex.lock();progress=value;message=note;mutex.unlock()
func state() -> Dictionary:
	mutex.lock();var value={"progress":progress,"message":message};mutex.unlock();return value
func save(snapshot: Dictionary,path: String) -> void:
	worker=Thread.new();worker.start(func():
		var result=Hearth20Identity._save_campaign_checked(snapshot,path,report)
		if result.ok:report(.96,"Finishing the campaign preview…");Hearth20CampaignArchive.index_saved(snapshot,path)
		return result)
func load_table(path: String) -> void:
	worker=Thread.new();worker.start(func():report(.25,"Reading the saved map and tokens…");var result=Hearth20CampaignArchive.read_table(path);report(.85,"Preparing your table…");return result)
func list_tables() -> void:worker=Thread.new();worker.start(Hearth20CampaignArchive.list_tables)
func done() -> bool:return worker!=null and not worker.is_alive()
func finish() -> Variant:return worker.wait_to_finish()

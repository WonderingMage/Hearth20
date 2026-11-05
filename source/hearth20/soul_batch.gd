extends RefCounted
class_name Hearth20SoulBatch
## Pure immutable spirit math only. Workers never touch nodes, materials or the network.
var jobs=[]
var frames=[]
var task=-1
var lock=Mutex.new()
func start(items: Array) -> void:
	jobs=items;frames.resize(jobs.size());task=WorkerThreadPool.add_group_task(_compute,jobs.size(),mini(4,jobs.size()),false,"Hearth20 spirit motion")
func _compute(index: int) -> void:
	var job: Dictionary=jobs[index];var frame=job.motion.frame(float(job.age),float(job.reveal))
	lock.lock();frames[index]=frame;lock.unlock()
func ready() -> bool:return task>=0 and WorkerThreadPool.is_group_task_completed(task)
func finish() -> void:
	if task>=0:WorkerThreadPool.wait_for_group_task_completion(task);task=-1

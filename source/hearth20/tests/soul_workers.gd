extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	var jobs=[]
	for sides in [4,6,8]:
		for value in range(1,sides+1):
			var motion=Hearth20SoulMotion.new();motion.setup(Hearth20DiceModel.shape(sides),value-1);jobs.append({"motion":motion,"age":0.,"reveal":0.})
	for stamp in [.1,.85,1.25,1.75,2.35,4.6,17.4]:
		for job in jobs:job.age=stamp;job.reveal=stamp
		var batch=Hearth20SoulBatch.new();batch.start(jobs)
		while not batch.ready():await process_frame
		batch.finish()
		for i in jobs.size():expect(var_to_bytes(batch.frames[i])==var_to_bytes(jobs[i].motion.frame(stamp,stamp)),"worker result exactly matches main-thread motion at "+str(stamp)+" / "+str(i))
	var abandoned=Hearth20SoulBatch.new();abandoned.start(jobs);abandoned.finish();expect(abandoned.task==-1 and abandoned.frames.size()==jobs.size(),"scene teardown drains work without touching freed actors")
	print("Soul workers: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)

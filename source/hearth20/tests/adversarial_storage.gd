extends SceneTree
const Saved=preload("campaign_saves.gd")
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func run() -> void:
	create_timer(20).timeout.connect(func():push_error("Storage audit watchdog expired.");quit(2))
	var base=Hearth20Identity.new_campaign("Storage audit")
	var nested={};var node=nested
	for depth in 80:node.child={};node=node.child
	var deep=base.duplicate(true);deep.extra=nested
	expect(not Hearth20Identity.validate_campaign(deep).ok,"excessive data nesting fails before serialization")
	for scenario in ["missing","truncated","bad-schema","bad-shape"]:
		var path=Hearth20Identity.SAVE_ROOT+"/storage-"+scenario+"."+Hearth20Identity.SAVE_EXTENSION
		expect(Hearth20Identity.save_campaign(base,path).ok,"fixture creates a valid "+scenario+" save")
		DirAccess.copy_absolute(path,path+".previous")
		if scenario=="missing":DirAccess.remove_absolute(path)
		elif scenario=="bad-shape":
			var malformed=base.duplicate(true);malformed.actors=[null]
			FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(Hearth20Identity._encode_variant(malformed)))
		else:FileAccess.open(path,FileAccess.WRITE).store_string("{broken" if scenario=="truncated" else JSON.stringify({"schema_version":{}}))
		var loaded=Hearth20Identity.load_campaign(path)
		expect(loaded.ok and loaded.get("recovered",false) and loaded.campaign.title==base.title,"backup recovery · "+scenario)
		var listed=Hearth20CampaignArchive.list_tables().filter(func(record):return record.path==path)
		expect(listed.size()==1 and (scenario=="bad-shape" or listed[0].get("recovered",false)) and not listed[0].get("invalid",false),"vault offers a recoverable table · "+scenario)
		expect(Hearth20Identity.save_campaign(loaded.campaign,path).ok,"recovered campaign can be saved normally")
		expect(Hearth20Identity._read_campaign_file(path+".previous").ok,"repairing a corrupt primary retains its good recovery copy")
	for round_index in 3:
		var path=Hearth20Identity.SAVE_ROOT+"/concurrent-storage."+Hearth20Identity.SAVE_EXTENSION
		var shared={"ready":0,"go":false};var mutex=Mutex.new();var threads=[]
		for index in 6:
			var snapshot=base.duplicate(true);snapshot.title="Writer "+str(round_index)+"-"+str(index);snapshot.dm_notes="n".repeat(100000)
			var thread=Thread.new();threads.append(thread)
			thread.start(func():
				mutex.lock();shared.ready+=1;mutex.unlock()
				while true:
					mutex.lock();var go=bool(shared.go);mutex.unlock()
					if go:break
					OS.delay_msec(1)
				return Hearth20Identity._save_campaign_checked(snapshot,path))
		while true:
			mutex.lock();var ready=int(shared.ready);mutex.unlock()
			if ready==threads.size():break
			await process_frame
		mutex.lock();shared.go=true;mutex.unlock()
		while threads.any(func(thread):return thread.is_alive()):await process_frame
		for thread in threads:expect(thread.wait_to_finish().ok,"simultaneous save completes consistently")
		var loaded=Hearth20Identity.load_campaign(path)
		expect(loaded.ok and loaded.campaign.dm_notes.length()==100000,"concurrent saves produce a complete campaign")
		expect(Hearth20Identity._read_campaign_file(path+".previous").ok,"concurrent saves retain a readable previous copy")
	var app=Saved.AppFixture.new();root.add_child(app);await process_frame
	var path=Hearth20Identity.SAVE_ROOT+"/invalid-current-shape."+Hearth20Identity.SAVE_EXTENSION
	expect(Hearth20Identity.save_campaign(base,path).ok,"fixture creates a campaign for recovery loading")
	DirAccess.copy_absolute(path,path+".previous")
	var invalid=base.duplicate(true);invalid.actors=[null]
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(Hearth20Identity._encode_variant(invalid)))
	var progress=Hearth20CampaignProgress.open(app,"load",path)
	while progress.active:await process_frame
	expect(progress.tried_previous and "previous save copy" in progress.caption.text,"load progress recovers a parseable but invalid main file")
	expect(app.campaign.title==base.title,"only a validated recovery campaign replaces the current table")
	progress.queue_free();app.queue_free();await process_frame;await process_frame
	print("Adversarial storage: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

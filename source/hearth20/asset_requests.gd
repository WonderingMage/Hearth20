extends RefCounted
## Godot retains one request reference until get() consumes it.
const TIMEOUT_MSEC = 30000

static func discard(tree: SceneTree, paths: Array) -> void:
	if paths.is_empty():return
	var pending=paths.duplicate()
	# The destination may already be gone. Poll without retaining that scene.
	while not pending.is_empty():
		await tree.process_frame
		for path in pending.duplicate():
			var status=ResourceLoader.load_threaded_get_status(path)
			if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:continue
			if status!=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:ResourceLoader.load_threaded_get(path)
			pending.erase(path)

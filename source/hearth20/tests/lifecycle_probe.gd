extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var shell=Hearth20SeatedShell.new();root.add_child(shell)
	while not shell.ready_to_show:await process_frame
	shell.app.session.refreshments_action({"action":"order","food":"chips","drink":"beer"})
	while not is_instance_valid(shell.refreshments.food_model):await process_frame
	await create_timer(1.).timeout;shell.queue_free();await create_timer(2.).timeout
	Hearth20RefreshmentModels.cache.clear();print("Lifecycle probe complete");quit.call_deferred()

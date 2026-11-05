extends SceneTree
## Run before any test which writes synthetic saves.
func _initialize() -> void:
	var expected := OS.get_environment("H20_QA_PROFILE").replace("\\", "/").to_lower().trim_suffix("/") + "/"
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if expected == "/" or not actual.begins_with(expected) or ProjectSettings.get_setting("application/config/name") != "Hearth20" or root.has_node("World") or root.has_node("UpdateBoot"):
		push_error("Refusing destructive tests outside isolated Hearth20 user data.")
		quit(1)
		return
	print("Verified disposable Hearth20 user data: ", actual)
	quit(0)

extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,960);root.title="Hearth20 Beyond · Embedded Sheet Check"
	var app=Hearth20App.new();app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(app);await process_frame;app.open_beyond_sheet()
	var deadline=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:await process_frame
	app.queue_free();await create_timer(.5).timeout;quit()

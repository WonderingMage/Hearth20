extends Window
class_name Hearth20CampaignProgress
signal finished(result: Dictionary)
var job: Hearth20CampaignJob
var app: Hearth20App
var caption: Label
var bar: ProgressBar
var done_button: Button
var active=true
var path=""
var table_title=""
var operation="save"
var abandoned=false
static func open(owner_app: Hearth20App,action: String,target: String,title_value="") -> Hearth20CampaignProgress:
	if is_instance_valid(owner_app.campaign_progress) and owner_app.campaign_progress.active:
		Hearth20Design.popup_window(owner_app.campaign_progress)
		return owner_app.campaign_progress
	var window=Hearth20CampaignProgress.new();window.app=owner_app;window.path=target;window.operation=action;window.table_title=title_value
	owner_app.campaign_progress=window;(owner_app.seated_shell if owner_app.seated_shell!=null else owner_app).add_child(window);window.setup();return window
func setup() -> void:
	title="Hearth20 · "+("Saving table" if operation=="save" else "Opening table");size=Vector2i(620,270);min_size=size;theme=Hearth20Design.theme();transient=true;exclusive=true
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Regal.swatch(Hearth20Regal.BG),3,28,Hearth20Regal.swatch(Hearth20Regal.GOLD)));add_child(panel)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",18);panel.add_child(box)
	var heading=Label.new();heading.text="✦  "+("PRESERVING YOUR ADVENTURE" if operation=="save" else "RETURNING TO YOUR TABLE");heading.add_theme_font_override("font",Hearth20Design.font(true));heading.add_theme_font_size_override("font_size",24);box.add_child(heading)
	caption=Label.new();caption.text="Preparing your table…";caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(caption)
	bar=ProgressBar.new();bar.custom_minimum_size.y=22;box.add_child(bar)
	done_button=Button.new();done_button.text="Continue playing" if operation=="save" else "Cancel opening";done_button.pressed.connect(_close);box.add_child(done_button)
	close_requested.connect(_close)
	window_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			set_input_as_handled()
			_close())
	Hearth20Design.popup_window(self);start.call_deferred()
func _close() -> void:
	hide()
	if not active:
		if job==null or job.worker==null:queue_free()
	elif operation=="load":
		active=false;abandoned=true
		if job==null:queue_free()
	else:
		app._on_status("Saving your table in the background…")
func start() -> void:
	await get_tree().process_frame;await get_tree().process_frame
	if abandoned or is_queued_for_deletion():return
	job=Hearth20CampaignJob.new()
	if operation=="save":
		if is_instance_valid(app.personal_journal):app.personal_journal.flush()
		app.lite_bridge.sync_to_campaign()
		var snapshot=app.campaign.duplicate(true)
		if is_instance_valid(app.dm_notes_editor):snapshot.dm_notes=app.dm_notes_editor.text
		if not table_title.strip_edges().is_empty():snapshot.title=table_title.strip_edges().left(96)
		job.save(snapshot,path)
	else:job.load_table(path)
func _process(_delta: float) -> void:
	if job==null:return
	if active:
		var state=job.state();bar.value=state.progress*100.;caption.text=state.message
	if not job.done():return
	var result=job.finish()
	job=null
	if abandoned:
		queue_free()
		return
	if not result is Dictionary:
		result={"ok":false,"errors":["The save or load task could not finish. Try again."]}
	if result.get("ok",false) and operation=="load":
		var recovered=bool(result.get("recovered",false))
		result=app.install_loaded_campaign(result.campaign,path)
		result.recovered=recovered
	complete(result)
func complete(result: Dictionary) -> void:
	active=false;done_button.disabled=false;done_button.text="Done" if result.get("ok",false) else "Return"
	if result.get("ok",false):
		title="Hearth20 · Table saved" if operation=="save" else "Hearth20 · Table opened"
		bar.value=100.;caption.text="Table saved on this PC. Your map, tokens and player ownership are preserved." if operation=="save" else "Your saved table is ready."
		if operation=="load" and result.get("recovered",false):caption.text="Opened the previous save copy. Save this table to restore its main save file."
		if operation=="save":app.current_save_path=path;app.campaign.title=table_title if not table_title.is_empty() else app.campaign.title
	else:title="Hearth20 · Save failed" if operation=="save" else "Hearth20 · Could not open table";caption.text="\n".join(PackedStringArray(result.get("errors",[str(result.get("error","The table could not be saved or opened."))])))
	app._on_status(caption.text);finished.emit(result)
	if not visible:queue_free()
func _exit_tree() -> void:
	if job!=null and job.worker!=null and job.worker.is_started():job.worker.wait_to_finish()

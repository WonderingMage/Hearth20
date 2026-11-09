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
var tried_previous=false
static func open(owner_app: Hearth20App,action: String,target: String,title_value="") -> Hearth20CampaignProgress:
	if is_instance_valid(owner_app.campaign_progress) and owner_app.campaign_progress.active:return owner_app.campaign_progress
	var window=Hearth20CampaignProgress.new();window.app=owner_app;window.path=target;window.operation=action;window.table_title=title_value
	owner_app.campaign_progress=window;(owner_app.seated_shell if owner_app.seated_shell!=null else owner_app).add_child(window);window.setup();return window
func setup() -> void:
	title="Hearth20 · "+("Saving table" if operation=="save" else "Opening table");size=Vector2i(620,270);min_size=size;theme=Hearth20Design.theme();transient=true;exclusive=true
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Regal.swatch(Hearth20Regal.BG),3,28,Hearth20Regal.swatch(Hearth20Regal.GOLD)));add_child(panel)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",18);panel.add_child(box)
	var heading=Label.new();heading.text="✦  "+("PRESERVING YOUR ADVENTURE" if operation=="save" else "RETURNING TO YOUR TABLE");heading.add_theme_font_override("font",Hearth20Design.font(true));heading.add_theme_font_size_override("font_size",24);box.add_child(heading)
	caption=Label.new();caption.text="Preparing your table…";caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(caption)
	bar=ProgressBar.new();bar.custom_minimum_size.y=22;box.add_child(bar)
	done_button=Button.new();done_button.text="Saving…" if operation=="save" else "Opening…";done_button.disabled=true;done_button.pressed.connect(queue_free);box.add_child(done_button)
	close_requested.connect(func():if not active:queue_free())
	popup_centered();start.call_deferred()
func start() -> void:
	await get_tree().process_frame;await get_tree().process_frame
	job=Hearth20CampaignJob.new()
	if operation=="save":
		app.lite_bridge.sync_to_campaign()
		var snapshot=app.campaign.duplicate(true)
		if not table_title.strip_edges().is_empty():snapshot.title=table_title.strip_edges().left(96)
		var checked=Hearth20Contracts.validate_campaign(snapshot)
		if not checked.ok:complete(checked);return
		job.save(snapshot,path)
	else:job.load_table(path)
func _process(_delta: float) -> void:
	if not active or job==null or job.worker==null:return
	var state=job.state();bar.value=state.progress*100.;caption.text=state.message
	if not job.done():return
	var result=job.finish()
	if result.get("ok",false) and operation=="load":
		var checked=Hearth20Contracts.validate_campaign(result.campaign)
		if not checked.ok:
			if not tried_previous and not result.get("recovered",false) and FileAccess.file_exists(path+".previous"):
				tried_previous=true;job=Hearth20CampaignJob.new();job.load_previous(path);return
			complete(checked);return
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
func _exit_tree() -> void:
	if job!=null and job.worker!=null and job.worker.is_started():job.worker.wait_to_finish()

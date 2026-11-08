extends Window
class_name Hearth20CampaignVault
var app: Hearth20App
var choose_callback: Callable
var action="open"
var listing: Hearth20CampaignJob
var rows: VBoxContainer
var status: Label
var details: Label
var preview: TextureRect
var name_field: LineEdit
var primary: Button
var selected_path=""
static func open(owner: Node,owner_app: Hearth20App=null,mode="open",callback: Callable=Callable()) -> Hearth20CampaignVault:
	for child in owner.get_children():
		if child is Hearth20CampaignVault and not child.is_queued_for_deletion():child.popup_centered();return child
	var window=Hearth20CampaignVault.new();window.app=owner_app;window.action=mode;window.choose_callback=callback;owner.add_child(window);window.setup();return window
func label(parent: Node,text: String,points=14) -> Label:
	var item=Label.new();item.text=text;item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;item.add_theme_font_size_override("font_size",points);parent.add_child(item);return item
func button(parent: Node,text: String,callback: Callable) -> Button:
	var item=Button.new();item.text=text;item.custom_minimum_size.y=42;item.pressed.connect(callback);parent.add_child(item);return item
func setup() -> void:
	title="Hearth20 · Campaign vault";size=Vector2i(960,720);min_size=Vector2i(800,640);theme=Hearth20Design.theme();transient=true;exclusive=true;close_requested.connect(queue_free)
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Regal.swatch(Hearth20Regal.BG),3,26,Hearth20Regal.swatch(Hearth20Regal.GOLD)));add_child(panel)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",16);panel.add_child(column)
	var heading=label(column,"✦  THE CAMPAIGN VAULT  ✦",30);heading.add_theme_font_override("font",Hearth20Design.font(true));heading.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.GOLD))
	status=label(column,"Reading the tables saved on this PC…",14)
	var body=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",22);column.add_child(body)
	var left=VBoxContainer.new();left.custom_minimum_size.x=350;left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(left)
	if action=="save":button(left,"＋  New table slot",func():select_new())
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;left.add_child(scroll)
	rows=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rows.add_theme_constant_override("separation",9);scroll.add_child(rows)
	var right=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.add_theme_constant_override("separation",14);body.add_child(right)
	preview=TextureRect.new();preview.custom_minimum_size=Vector2(240,180);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;preview.texture=Hearth20Design.icon("map",96);right.add_child(preview)
	details=label(right,"Choose a saved table to see its map, tokens and saved time.",17)
	name_field=LineEdit.new();name_field.placeholder_text="Campaign name";name_field.max_length=96;name_field.custom_minimum_size.y=44;name_field.visible=action=="save";right.add_child(name_field)
	if app!=null:name_field.text=str(app.campaign.get("title","New table"))
	name_field.text_changed.connect(func(_text):refresh_primary())
	var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",12);column.add_child(footer)
	button(footer,"Open AppData save folder",func():DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Hearth20Identity.SAVE_ROOT));OS.shell_open(ProjectSettings.globalize_path(Hearth20Identity.SAVE_ROOT)))
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(spacer);button(footer,"Back",queue_free)
	primary=button(footer,"Save new table" if action=="save" else "Open selected table",confirm);primary.custom_minimum_size.x=190
	listing=Hearth20CampaignJob.new();listing.list_tables();refresh_primary();popup_centered()
func _process(_delta: float) -> void:
	if listing==null or not listing.done():return
	var records: Array=listing.finish();listing=null
	status.text="%d saved table%s · stored in this PC’s AppData"%[records.size(),"" if records.size()==1 else "s"]
	if records.is_empty():label(rows,"Your adventures will appear here after their first save.",15)
	for record in records:
		var item=button(rows,"",func():select_record(record));item.custom_minimum_size.y=78;item.disabled=record.get("invalid",false)
		item.set_meta("save_path",str(record.path))
		var copy=VBoxContainer.new();copy.mouse_filter=Control.MOUSE_FILTER_IGNORE;copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);copy.offset_left=14;copy.offset_right=-14;copy.offset_top=9;copy.offset_bottom=-9;item.add_child(copy)
		var title_copy=label(copy,str(record.get("title","Untitled table")),18);title_copy.mouse_filter=Control.MOUSE_FILTER_IGNORE;title_copy.max_lines_visible=1;title_copy.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		var meta=label(copy,str(record.get("scene",""))+"  ·  "+saved_time(int(record.get("saved_at",0))),12);meta.mouse_filter=Control.MOUSE_FILTER_IGNORE;meta.max_lines_visible=1;meta.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		if app!=null and record.path==app.current_save_path:select_record(record)
	refresh_primary()
func saved_time(value: int) -> String:return Time.get_datetime_string_from_unix_time(value+int(Time.get_time_zone_from_system().bias)*60).replace("T","  ")
func select_new() -> void:
	selected_path="";preview.texture=Hearth20Design.icon("map",96);details.text="A new place for this adventure. Existing tables are preserved.";name_field.text=str(app.campaign.title);refresh_primary()
func select_record(record: Dictionary) -> void:
	selected_path=str(record.path);name_field.text=str(record.title)
	details.text=str(record.title)+"\n\n"+str(record.get("scene",""))+"\n%d maps · %d campaign tokens\n\nSaved %s"%[int(record.get("scenes",0)),int(record.get("tokens",0)),saved_time(int(record.saved_at))]
	preview.texture=Hearth20Design.icon("map",96)
	var thumb=selected_path+".thumb.png"
	if FileAccess.file_exists(thumb) and FileAccess.get_file_as_bytes(thumb).size()<524288:
		var image=Hearth20Assets.inspect_token_png(thumb)
		if image.get("ok",false):preview.texture=ImageTexture.create_from_image(image.image)
	refresh_primary()
func refresh_primary() -> void:
	if not is_instance_valid(primary):return
	primary.text=("Save new table" if selected_path.is_empty() else "Save selected table") if action=="save" else "Open selected table"
	primary.disabled=name_field.text.strip_edges().is_empty() if action=="save" else selected_path.is_empty()
func confirm() -> void:
	if action=="save":
		if app==null or name_field.text.strip_edges().is_empty():return
		var target=Hearth20CampaignArchive.new_path(name_field.text) if selected_path.is_empty() else selected_path
		hide();app.begin_campaign_save(target,name_field.text.strip_edges());queue_free()
	elif not selected_path.is_empty():
		if app!=null:
			if not app.session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer:status.text="Leave the active table before opening a different campaign.";return
			hide();Hearth20CampaignProgress.open(app,"load",selected_path);queue_free()
		elif choose_callback.is_valid():hide();choose_callback.call(selected_path);queue_free()
func _exit_tree() -> void:
	if listing!=null and listing.worker!=null and listing.worker.is_started():listing.worker.wait_to_finish()

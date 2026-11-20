extends Control
class_name Hearth20Boot
## The original full-resolution party illustration stays separate from table loading.
const APP_SCENE := "res://hearth20_seated.tscn"
const AssetRequests=preload("res://hearth20/asset_requests.gd")
const TITLE_ART := preload("res://hearth20/menu_art/party-revised.jpg")
const SCRIM := """
shader_type canvas_item;
void fragment(){
    float left=(1.-smoothstep(.17,.67,UV.x))*.96;
    float top=(1.-smoothstep(.015,.23,UV.y))*.44;
    float bottom=smoothstep(.61,1.,UV.y)*.55;
    COLOR=vec4(.026,.018,.012,1.-(1.-left)*(1.-max(top,bottom)));
}
"""
var artwork: TextureRect
var heading: Label
var progress: ProgressBar
var progress_note: Label
var cancel_loading_button: Button
var credits_button: Button
var menu: VBoxContainer
var utilities: HBoxContainer
var copy_column: VBoxContainer
var loading:=false
var mode:="new"
var load_paths: Array[String]=[]
var loaded: Array[Resource]=[]
var campaign_thread: Thread
var campaign_result: Dictionary={}
var campaign_path=""
var advance_pending:=false
var loading_drawn:=false
var loading_started=0
var menu_drawn_msec:=0
var debug_enabled:=bool(ProjectSettings.get_setting_with_override("application/config/hearth20_debug"))
var debug_dialog: AcceptDialog

func _ready() -> void:
	if not Hearth20MultiplayerLab.child_slot().is_empty():get_tree().change_scene_to_file.call_deferred(APP_SCENE);return
	Hearth20Regal.load_preference();theme=Hearth20Design.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork=TextureRect.new();artwork.name="PartyArtwork";artwork.texture=TITLE_ART
	artwork.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;artwork.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);artwork.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var detail=ShaderMaterial.new();detail.shader=preload("res://hearth20/menu_art/detail.gdshader");artwork.material=detail
	add_child(artwork)
	var rage:=TextureRect.new();rage.name="WarriorRage";rage.texture=preload("res://hearth20/menu_art/rage-overlay.png")
	rage.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;rage.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rage.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;rage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);rage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var rage_material:=ShaderMaterial.new();rage_material.shader=preload("res://hearth20/menu_art/rage.gdshader");rage.material=rage_material;add_child(rage)
	var scrim=ColorRect.new();scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);scrim.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader=Shader.new();shader.code=SCRIM;var material=ShaderMaterial.new();material.shader=shader;scrim.material=material;add_child(scrim)
	var margin=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:
		margin.add_theme_constant_override("margin_"+side,44)
	for side in ["top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,20)
	add_child(margin)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);margin.add_child(column)
	var top=HBoxContainer.new();top.add_theme_constant_override("separation",10);column.add_child(top)
	var brand := TextureRect.new()
	brand.texture=Hearth20Design.icon("crest",24)
	brand.modulate=Color("#e2bd79")
	brand.custom_minimum_size=Vector2(28,28)
	brand.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	brand.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	brand.mouse_filter=Control.MOUSE_FILTER_IGNORE
	top.add_child(brand)
	var version=_label("Version "+Hearth20Identity.VERSION,13)
	version.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	version.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	version.clip_text=true
	version.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(version)
	utilities=HBoxContainer.new()
	utilities.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	utilities.add_theme_constant_override("separation",7)
	top.add_child(utilities)
	var guide=_button(utilities,"How to play",func():Hearth20PartyGuide.open(self),38)
	var settings=_button(utilities,"Settings",func():Hearth20SettingsWindow.open(self),38)
	var quit=_button(utilities,"Quit",func():get_tree().quit(),38)
	_style_art_button(guide)
	_style_art_button(settings,true)
	_style_art_button(quit)
	var appearance=Hearth20Regal.ThemeMedallion.new();appearance.name="TitleAppearance";top.add_child(appearance)
	var rail=ScrollContainer.new()
	rail.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	rail.size_flags_vertical=Control.SIZE_EXPAND_FILL
	rail.follow_focus=true
	column.add_child(rail)
	copy_column=VBoxContainer.new()
	copy_column.size_flags_vertical=Control.SIZE_EXPAND_FILL
	copy_column.alignment=BoxContainer.ALIGNMENT_END
	copy_column.add_theme_constant_override("separation",17)
	rail.add_child(copy_column)
	heading=_label("Hearth20",68,true)
	copy_column.add_child(heading)
	var rule=ColorRect.new()
	rule.color=Color("#c89d62")
	rule.custom_minimum_size=Vector2(63,2)
	rule.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
	copy_column.add_child(rule)
	menu=VBoxContainer.new()
	menu.add_theme_constant_override("separation",6)
	copy_column.add_child(menu)
	var actions=HFlowContainer.new()
	actions.add_theme_constant_override("h_separation",10)
	actions.add_theme_constant_override("v_separation",8)
	menu.add_child(actions)
	var join=_button(actions,"Join a table",func():begin_loading("join"),52)
	join.name="JoinTable"
	join.custom_minimum_size.x=156
	join.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	_style_menu_button(join,"connect",17)
	Hearth20Design.primary(join)
	var host=_button(actions,"Host a new game",func():begin_loading("host"),52)
	host.name="HostTable"
	host.custom_minimum_size.x=171
	host.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	_style_menu_button(host,"host",17)
	_style_art_button(host,true)
	actions.sort_children.connect(func():
		var wide=is_equal_approx(join.position.y,host.position.y)
		join.focus_neighbor_right=join.get_path_to(host) if wide else NodePath()
		join.focus_neighbor_bottom=NodePath() if wide else join.get_path_to(host)
		host.focus_neighbor_left=host.get_path_to(join) if wide else NodePath()
		host.focus_neighbor_top=NodePath() if wide else host.get_path_to(join)
	)
	var saved=_button(menu,"Open saved campaign",open_campaign_vault,38)
	_style_menu_button(saved,"open",14)
	_style_art_button(saved)
	saved.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	if Hearth20MultiplayerLab.enabled():
		_button(menu,"Multiplayer Lab · DM + 2 Players",func():Hearth20MultiplayerLab.start_on_table=true;begin_loading("lab"),36)
	progress=ProgressBar.new();progress.show_percentage=false;progress.max_value=100;progress.custom_minimum_size.y=4;progress.hide();copy_column.add_child(progress)
	progress_note=_label("",13)
	progress_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	progress_note.hide()
	copy_column.add_child(progress_note)
	cancel_loading_button=_button(copy_column,"Cancel loading",_cancel_loading,36)
	cancel_loading_button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	_style_art_button(cancel_loading_button,true)
	cancel_loading_button.hide()
	credits_button=_button(column,"Scene credits",_show_scene_credits,32)
	_style_art_button(credits_button)
	credits_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	resized.connect(_layout_menu)
	_layout_menu()
	Hearth20Regal.sync(self)
	RenderingServer.frame_post_draw.connect(_on_first_title_draw,CONNECT_ONE_SHOT)

func _on_first_title_draw() -> void:
	menu_drawn_msec=Time.get_ticks_msec()
	Hearth20Updater.confirm_startup()
	get_node("/root/Updates").startup_check()
	if get_node("/root/SteamLink").pending_invite>0:begin_loading("join")

func _label(text_value: String,points: int,serif: bool=false) -> Label:
	var label=Label.new();label.text=text_value;label.add_theme_font_size_override("font_size",points)
	label.add_theme_color_override("font_color",Color("#f4e6c9") if points>15 else Color("#cfb995"))
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,.7));label.add_theme_constant_override("shadow_offset_y",2)
	if serif:label.add_theme_font_override("font",Hearth20Design.font(true))
	return label

func _button(parent: Node,caption: String,action: Callable,height: int=40) -> Button:
	var button=Button.new();button.text=caption;button.tooltip_text=caption;button.custom_minimum_size.y=height;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.pressed.connect(action);parent.add_child(button);return button

func _style_menu_button(button: Button,glyph: String,points: int) -> void:
	button.icon=Hearth20Design.icon(glyph,19)
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width",19)
	button.add_theme_constant_override("h_separation",12)
	button.add_theme_font_size_override("font_size",points)

func _style_art_button(button: Button,outlined:=false) -> void:
	# The illustration stays dark even when the app uses its parchment theme.
	button.theme_type_variation="QuietButton"
	if outlined:
		button.add_theme_stylebox_override("normal",Hearth20Design.panel(Color("#211911"),6,8,Color("#745d40")))
	button.add_theme_stylebox_override("hover",Hearth20Design.panel(Color("#271f18"),6,8,Color("#745d40")))
	button.add_theme_stylebox_override("pressed",Hearth20Design.panel(Color("#34261c"),6,8,Color("#c89d62")))
	for state in ["color","hover_color","pressed_color","focus_color"]:
		button.add_theme_color_override("font_"+state,Color("#f5e9d4"))
	for state in ["normal_color","hover_color","pressed_color","focus_color"]:
		button.add_theme_color_override("icon_"+state,Color("#d8be97"))

func _unhandled_key_input(event: InputEvent) -> void:
	if loading and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		_cancel_loading()
		get_viewport().set_input_as_handled()

func _show_scene_credits() -> void:
	var dialog=AcceptDialog.new()
	dialog.title="Hearth20 · Artwork and scene credits"
	dialog.theme=theme
	dialog.size=Vector2i(620,410)
	dialog.ok_button_text="Return to the menu"
	var label=RichTextLabel.new()
	label.custom_minimum_size=Vector2(560,310)
	label.text="Revised party illustration supplied by the Hearth20 creator.\n\nThe 2752 × 1536 image is preserved at full resolution. A separate AI-generated crimson mist/glow layer adds rage around the two axe-wielding warriors. Their original faces and physical artwork are retained.\n\nThe menu opens directly into Join, Host or saved campaigns."
	label.text+="\n\nStatic tavern and tabletop models supplied by the Hearth20 creator. Optimized runtime copies retain their original textures and UVs.\n\nAdditional room kits (CC BY 4.0):\n• Stylized Low-poly Wooden beam — Rocco Giandomenico\n• Stylized Modular Stonewalls — @blue.blender.print\n• Tileable Stylized Wooden Floor Texture — JennyB\n\nFull source links, licenses and modifications:\n"+FileAccess.get_file_as_string("res://hearth20/generated_models/CREDITS.md")
	dialog.add_child(label)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	Hearth20Design.popup_window(dialog)

func open_campaign_vault() -> void:
	Hearth20CampaignVault.open(self,null,"open",func(path):begin_loading("saved",path))
func begin_loading(action: String,save_path="") -> void:
	if loading: return
	if action=="saved" and save_path.is_empty():open_campaign_vault();return
	campaign_path=save_path
	if is_instance_valid(debug_dialog): debug_dialog.queue_free()
	loaded.clear();loading_drawn=DisplayServer.get_name()=="headless";advance_pending=false
	mode=action;loading=true;loading_started=Time.get_ticks_msec();menu.hide();utilities.hide();credits_button.hide();progress.show();progress_note.show();cancel_loading_button.show();progress.value=0;progress_note.text="Preparing your table…"
	var paths=[APP_SCENE,"res://hearth20/fx_noise.png"]
	for entry in Hearth20MapLibrary.catalog():paths.append("res://hearth20/sample_maps/"+str(entry.id)+"-thumb.png")
	for path in paths:
		if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path)!=OK:
			_return_from_loading("A bundled resource could not load. You can retry or quit.")
			return
		load_paths.append(path)
	if action=="saved":
		campaign_thread=Thread.new()
		if campaign_thread.start(func():return Hearth20Identity.load_campaign(save_path))!=OK:
			campaign_thread=null
			_return_from_loading("Could not start reading the save. You can retry or open a different campaign.")
			return
	if not loading_drawn:RenderingServer.frame_post_draw.connect(_on_loading_drawn,CONNECT_ONE_SHOT)
func _on_loading_drawn() -> void:
	loading_drawn=true
func _layout_menu() -> void:
	copy_column.custom_minimum_size.x=clampf(size.x*.39,260.,500.)
	heading.add_theme_font_size_override("font_size",roundi(clampf(minf(size.x*.079,size.y*.125),42.,106.)))
func _process(_delta: float) -> void:
	if not loading or advance_pending:return
	if Time.get_ticks_msec()-loading_started>=AssetRequests.TIMEOUT_MSEC:
		_return_from_loading("Loading took too long. You can retry or open a different campaign.")
		return
	if not loading_drawn:return
	var complete:=0; var total:=0.0
	for path in load_paths:
		var fraction:=[];var status:=ResourceLoader.load_threaded_get_status(path,fraction)
		if status==ResourceLoader.THREAD_LOAD_LOADED: complete+=1; total+=1
		elif status!=ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_return_from_loading("A bundled resource could not load. You can retry or quit.")
			return
		elif not fraction.is_empty():total+=float(fraction[0])
	var campaign_ready:=campaign_thread==null or not campaign_thread.is_alive()
	progress.value=total/maxf(1,load_paths.size())*100
	progress_note.text="Reading campaign and player grants…" if not campaign_ready else "Preparing map library and table controls…"
	if complete==load_paths.size() and campaign_ready:
		advance_pending=true; call_deferred("_enter_table")
func _enter_table() -> void:
	if not loading or not advance_pending:return
	for path in load_paths: loaded.append(ResourceLoader.load_threaded_get(path))
	load_paths.clear()
	if campaign_thread!=null:
		var result=campaign_thread.wait_to_finish();campaign_thread=null
		campaign_result=result if result is Dictionary else {}
		if not campaign_result.get("ok",false):
			_return_from_loading("No saved campaign could be opened. Start a new table or try again.")
			return
	var packed: PackedScene=loaded[0]
	if packed==null:
		_return_from_loading("The table could not be opened. You can retry or quit.")
		return
	var experience: Control=packed.instantiate()
	get_parent().add_child(experience)
	var app: Hearth20App=experience.app
	if mode=="lab":app._load_sample_map("sunspire-sanctum",false)
	if mode=="saved": app.install_loaded_campaign(campaign_result.campaign,campaign_path)
	elif mode in ["host","join"]:experience.focus_connections_when_ready(mode)
	get_tree().current_scene=experience
	queue_free()
func _cancel_loading() -> void:
	_return_from_loading("Loading cancelled.")
func _return_from_loading(message: String) -> void:
	_release_loading()
	loaded.clear();loading=false;advance_pending=false;menu.show();utilities.show();credits_button.show();progress.hide();cancel_loading_button.hide();progress_note.text=message
func _release_loading() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_loading_drawn):RenderingServer.frame_post_draw.disconnect(_on_loading_drawn)
	AssetRequests.discard(get_tree(),load_paths)
	load_paths.clear()
	if campaign_thread!=null:
		_discard_campaign_read(get_tree(),campaign_thread)
		campaign_thread=null
static func _discard_campaign_read(tree: SceneTree,worker: Thread) -> void:
	while worker.is_alive():await tree.process_frame
	worker.wait_to_finish()
func _exit_tree() -> void:
	_release_loading()

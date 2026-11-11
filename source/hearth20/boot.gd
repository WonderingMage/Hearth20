extends Control
class_name Hearth20Boot
## The original full-resolution party illustration stays separate from table loading.
const APP_SCENE := "res://hearth20_seated.tscn"
const TITLE_ART := preload("res://hearth20/menu_art/party-revised.jpg")
const SCRIM := """
shader_type canvas_item;
void fragment(){
    float shade=(1.-smoothstep(.08,.61,UV.x))*.90;
    float edge=pow(length((UV-vec2(.5))*vec2(.85,1.1)),2.)*.38;
    COLOR=vec4(.026,.018,.012,clamp(shade+edge,0.,.96));
}
"""
var artwork: TextureRect
var heading: Label
var progress: ProgressBar
var progress_note: Label
var menu: VBoxContainer
var copy_column: VBoxContainer
var loading:=false
var mode:="new"
var load_paths: Array[String]=[]
var loaded: Array[Resource]=[]
var load_errors: Array[String]=[]
var campaign_thread: Thread
var campaign_result: Dictionary={}
var campaign_path=""
var advance_pending:=false
var loading_drawn:=false
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
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,46)
	for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,28)
	add_child(margin)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);margin.add_child(column)
	var top=HBoxContainer.new();top.add_theme_constant_override("separation",10);column.add_child(top)
	var edition=_label("A   T A B L E   F O R   L E G E N D S",11);edition.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(edition)
	var appearance=Hearth20Regal.ThemeMedallion.new();appearance.name="TitleAppearance";top.add_child(appearance)
	var middle=HBoxContainer.new();middle.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(middle)
	var rail=ScrollContainer.new();rail.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;rail.size_flags_vertical=Control.SIZE_EXPAND_FILL;middle.add_child(rail)
	copy_column=VBoxContainer.new();copy_column.custom_minimum_size.x=340;copy_column.add_theme_constant_override("separation",13);rail.add_child(copy_column)
	var above=Control.new();above.size_flags_vertical=Control.SIZE_EXPAND_FILL;above.custom_minimum_size.y=12;copy_column.add_child(above)
	heading=_label("Hearth20",54,true);copy_column.add_child(heading)
	copy_column.add_child(_label("G A T H E R   Y O U R   P A R T Y",11))
	var rule=HSeparator.new();copy_column.add_child(rule)
	var description=_label("A seat at the table. A world beyond the horizon.",16);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;copy_column.add_child(description)
	var gap=Control.new();gap.custom_minimum_size.y=16;copy_column.add_child(gap)
	menu=VBoxContainer.new();menu.add_theme_constant_override("separation",10);copy_column.add_child(menu)
	var join=_button(menu,"Join a table",func():begin_loading("join"),60);join.name="JoinTable";join.add_theme_font_size_override("font_size",23);join.focus_neighbor_bottom="../HostTable"
	var host=_button(menu,"Host a new game",func():begin_loading("host"),60);host.name="HostTable";host.add_theme_font_size_override("font_size",23)
	_button(menu,"Open saved campaign",open_campaign_vault,36)
	var utilities=GridContainer.new();utilities.columns=2;utilities.add_theme_constant_override("h_separation",8);utilities.add_theme_constant_override("v_separation",8);menu.add_child(utilities)
	_button(utilities,"How to play",func():Hearth20PartyGuide.open(self),36)
	_button(utilities,"Settings",func():Hearth20SettingsWindow.open(self),36)
	_button(utilities,"Quit",func():get_tree().quit(),34)
	_button(utilities,"Scene credits",_show_scene_credits,34)
	if Hearth20MultiplayerLab.enabled():_button(menu,"Multiplayer Lab · DM + 2 Players",func():Hearth20MultiplayerLab.start_on_table=true;begin_loading("lab"),36)
	var below=Control.new();below.size_flags_vertical=Control.SIZE_EXPAND_FILL;below.custom_minimum_size.y=12;copy_column.add_child(below)
	var space=Control.new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;space.mouse_filter=Control.MOUSE_FILTER_IGNORE;middle.add_child(space)
	progress=ProgressBar.new();progress.show_percentage=false;progress.max_value=100;progress.custom_minimum_size.y=4;progress.hide();column.add_child(progress)
	progress_note=_label("",13);progress_note.hide();column.add_child(progress_note)
	var footer=HBoxContainer.new();column.add_child(footer)
	var version=_label("BETA  /  "+Hearth20Identity.VERSION,11);version.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(version)
	var place=_label("YOUR PARTY.    YOUR LEGEND.",11);place.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;footer.add_child(place)
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

func _unhandled_key_input(_event: InputEvent) -> void:
	pass

func _show_scene_credits() -> void:
	var dialog=AcceptDialog.new()
	dialog.title="Hearth20 · Menu artwork"
	dialog.theme=theme
	dialog.size=Vector2i(620,410)
	dialog.ok_button_text="Return to the menu"
	var label=RichTextLabel.new()
	label.custom_minimum_size=Vector2(560,310)
	label.text="Revised party illustration supplied by the Hearth20 creator.\n\nThe 2752 × 1536 image is preserved at full resolution. A separate AI-generated crimson mist/glow layer adds rage around the two axe-wielding warriors. Their original faces and physical artwork are retained.\n\nThe menu opens directly into Join, Host or saved campaigns."
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
	load_errors.clear(); loaded.clear(); loading_drawn=false; advance_pending=false
	mode=action; loading=true; menu.hide(); progress.show(); progress_note.show(); progress.value=0; progress_note.text="Preparing your table…"
	load_paths=[APP_SCENE,"res://hearth20/fx_noise.png"]
	for entry in Hearth20MapLibrary.catalog(): load_paths.append("res://hearth20/sample_maps/"+str(entry.id)+"-thumb.png")
	for path in load_paths:
		if ResourceLoader.load_threaded_request(path,"",false)!=OK: load_errors.append(path)
	if action=="saved":
		campaign_thread=Thread.new()
		campaign_thread.start(func(): return Hearth20Identity.load_campaign(campaign_path))
	RenderingServer.frame_post_draw.connect(_on_loading_drawn,CONNECT_ONE_SHOT)
func _on_loading_drawn() -> void:
	loading_drawn=true
func _process(_delta: float) -> void:
	Hearth20Regal.sync(self)
	if copy_column!=null:
		copy_column.custom_minimum_size.x=clampf(size.x*.30,280.,380.)
		if size.y<680:heading.add_theme_font_size_override("font_size",42)
		else:heading.add_theme_font_size_override("font_size",54)
	if not loading or not loading_drawn or advance_pending: return
	var complete:=0; var total:=0.0
	for path in load_paths:
		var status:=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_LOADED: complete+=1; total+=1
		elif status==ResourceLoader.THREAD_LOAD_FAILED:
			if path not in load_errors: load_errors.append(path)
		else:
			var fraction:=[]; ResourceLoader.load_threaded_get_status(path,fraction)
			if not fraction.is_empty(): total+=float(fraction[0])
	var campaign_ready:=campaign_thread==null or not campaign_thread.is_alive()
	progress.value=total/maxf(1,load_paths.size())*100
	progress_note.text="Reading campaign and player grants…" if not campaign_ready else "Preparing map library and table controls…"
	if complete==load_paths.size() and campaign_ready:
		advance_pending=true; call_deferred("_enter_table")
	elif not load_errors.is_empty():
		loading=false; menu.show(); progress_note.text="A bundled resource could not load. You can retry or quit."
func _enter_table() -> void:
	for path in load_paths: loaded.append(ResourceLoader.load_threaded_get(path))
	if campaign_thread!=null:
		campaign_result=campaign_thread.wait_to_finish(); campaign_thread=null
		if not campaign_result.get("ok",false):
			loading=false; advance_pending=false; menu.show(); progress.hide(); progress_note.text="No saved campaign could be opened. Start a new table or try again."; return
	var packed: PackedScene=loaded[0]
	var experience: Control=packed.instantiate()
	get_parent().add_child(experience)
	var app: Hearth20App=experience.app
	if mode=="lab":app._load_sample_map("sunspire-sanctum",false)
	if mode=="saved": app.install_loaded_campaign(campaign_result.campaign,campaign_path)
	elif mode in ["host","join"]:experience.focus_connections_when_ready(mode)
	get_tree().current_scene=experience
	queue_free()
func _exit_tree() -> void:
	if campaign_thread!=null: campaign_thread.wait_to_finish()

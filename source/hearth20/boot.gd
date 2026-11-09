extends Control
class_name Hearth20Boot
## Lightweight title first; heavy app/resources and saved campaign load afterward.
const APP_SCENE := "res://hearth20_seated.tscn"
const BACKGROUND := """
shader_type canvas_item;
uniform vec4 base : source_color=vec4(.035,.029,.023,1);
float hash(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){vec2 p=UV*vec2(3,2);float fog=noise(p*3.+vec2(TIME*.015,-TIME*.01))*.6+noise(p*7.-TIME*.02)*.25;float vignette=1.-smoothstep(.1,.8,length(UV-vec2(.45,.5)));vec3 c=base.rgb+vec3(.05,.04,.028)*fog*vignette;vec2 grid=UV*vec2(60,36);float star=pow(max(0.,1.-length(fract(grid)-.5)*12.),4.)*step(.978,hash(floor(grid)));c+=vec3(.65,.46,.19)*star*(.4+.4*sin(TIME*.4+floor(grid).x));COLOR=vec4(c,1);}
"""
var viewer: Hearth20BestiaryViewer
var heading: Label
var creature_name: Label
var creature_type: Label
var tagline: Label
var tip: Label
var tip_counter: Label
var progress: ProgressBar
var progress_note: Label
var menu: GridContainer
var content: HBoxContainer
var copy_column: VBoxContainer
var creature_index:=0
var tip_index:=0
var loading:=false
var mode:="new"
var load_paths: Array[String]=[]
var loaded: Array[Resource]=[]
var load_errors: Array[String]=[]
var campaign_thread: Thread
var campaign_result: Dictionary={}
var campaign_path=""
var advance_pending:=false
var codex:=false
var loading_drawn:=false
var background_material: ShaderMaterial
var menu_drawn_msec:=0
var showcase_reset: Button
var showcase_help: Label
var play_button: Button
var mute_button: Button
var video_volume: HSlider
var debug_enabled:=bool(ProjectSettings.get_setting_with_override("application/config/hearth20_debug"))
var debug_preview:=false
var debug_progress:=42.0
var debug_dialog: AcceptDialog
var debug_creature: OptionButton
var debug_tip: OptionButton
var debug_progress_slider: HSlider
func _ready() -> void:
	if not Hearth20MultiplayerLab.child_slot().is_empty():get_tree().change_scene_to_file.call_deferred(APP_SCENE);return
	Hearth20Regal.load_preference(); theme=Hearth20Design.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg:=ColorRect.new(); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new(); shader.code=BACKGROUND; background_material=ShaderMaterial.new(); background_material.shader=shader; bg.material=background_material; add_child(bg)
	var margin:=MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,50)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,30)
	add_child(margin)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",12); margin.add_child(column)
	var top:=HBoxContainer.new(); top.add_theme_constant_override("separation",14); column.add_child(top)
	heading=_label("H E A R T H 2 0",39,true); heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL; top.add_child(heading)
	var appearance:=Hearth20Regal.ThemeMedallion.new(); appearance.name="TitleAppearance"; top.add_child(appearance)
	_button(top,"Host & join guide",func():Hearth20PartyGuide.open(self),36)
	var strap:=_label("THE ADVENTURE AT YOUR TABLE",11); column.add_child(strap)
	var line:=HSeparator.new(); column.add_child(line)
	content=HBoxContainer.new(); content.size_flags_vertical=Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",44); column.add_child(content)
	var model_column:=VBoxContainer.new(); model_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; model_column.size_flags_stretch_ratio=1.25; content.add_child(model_column)
	viewer=Hearth20BestiaryViewer.new(); viewer.defer_loading=true; viewer.name="LoadingCreature"; viewer.size_flags_vertical=Control.SIZE_EXPAND_FILL; model_column.add_child(viewer)
	var controls:=HBoxContainer.new(); controls.alignment=BoxContainer.ALIGNMENT_CENTER; controls.add_theme_constant_override("separation",10); model_column.add_child(controls)
	_button(controls,"‹",func(): choose_creature(creature_index-1),38)
	showcase_reset=_button(controls,"Reset view",func(): viewer.reset_view(),34)
	play_button=_button(controls,"Pause",func(): viewer.toggle_playback(); play_button.text="Play" if viewer.video_paused else "Pause",34)
	mute_button=_button(controls,"Mute",func(): viewer.toggle_mute(); mute_button.text="Unmute" if viewer.video_muted else "Mute",34)
	video_volume=HSlider.new(); video_volume.min_value=0; video_volume.max_value=1; video_volume.step=.01; video_volume.value=.8; video_volume.custom_minimum_size.x=65; video_volume.tooltip_text="Showcase audio volume"; video_volume.value_changed.connect(func(value): viewer.set_video_volume(value)); controls.add_child(video_volume)
	_button(controls,"›",func(): choose_creature(creature_index+1),38)
	showcase_help=_label("DRAG TO ROTATE  ·  RIGHT-DRAG TO LIFT  ·  WHEEL TO ZOOM",10); showcase_help.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; model_column.add_child(showcase_help)
	copy_column=VBoxContainer.new(); copy_column.custom_minimum_size.x=340; copy_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; copy_column.add_theme_constant_override("separation",12); content.add_child(copy_column)
	var spacer:=Control.new(); spacer.custom_minimum_size.y=12; copy_column.add_child(spacer)
	creature_type=_label("",11); copy_column.add_child(creature_type)
	creature_name=_label("",34,true); creature_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; copy_column.add_child(creature_name)
	tagline=_label("",15); tagline.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; copy_column.add_child(tagline)
	copy_column.add_child(HSeparator.new())
	tip=_label("",18); tip.custom_minimum_size.y=66; tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; copy_column.add_child(tip)
	var tip_row:=HBoxContainer.new(); copy_column.add_child(tip_row)
	tip_counter=_label("",11); tip_counter.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tip_row.add_child(tip_counter)
	_button(tip_row,"Next tip  ›",next_tip,32)
	menu=GridContainer.new(); menu.columns=1; menu.add_theme_constant_override("v_separation",8); menu.add_theme_constant_override("h_separation",8); copy_column.add_child(menu)
	_button(menu,"Host a new game",func(): begin_loading("host"))
	if Hearth20MultiplayerLab.enabled():_button(menu,"Multiplayer Lab · DM + 2 Players",func(): Hearth20MultiplayerLab.start_on_table=true;begin_loading("lab"))
	_button(menu,"Open saved campaign",open_campaign_vault)
	_button(menu,"Join a table",func(): begin_loading("join"))
	_button(menu,"Creature codex",_show_codex)
	_button(menu,"Model credits",_show_credits)
	_button(menu,"Settings",func():Hearth20SettingsWindow.open(self))
	_button(menu,"Quit",func(): get_tree().quit())
	progress=ProgressBar.new(); progress.show_percentage=false; progress.max_value=100; progress.custom_minimum_size.y=5; progress.visible=false; column.add_child(progress)
	progress_note=_label("Twenty creatures. Two hundred field notes. Your next story awaits.",12); column.add_child(progress_note)
	if debug_enabled:
		var debug_row:=HBoxContainer.new(); debug_row.add_theme_constant_override("separation",14); column.add_child(debug_row)
		var badge:=_label("D E B U G   W O R K S H O P",11); badge.size_flags_horizontal=Control.SIZE_EXPAND_FILL; debug_row.add_child(badge)
		_button(debug_row,"Loading Lab  ·  F6",_show_debug_lab,32)
	choose_creature(randi_range(0,Hearth20BestiaryCatalog.all().size()-1))
	Hearth20Regal.sync(self)
	RenderingServer.frame_post_draw.connect(_on_first_title_draw,CONNECT_ONE_SHOT)
func _on_first_title_draw() -> void:
	menu_drawn_msec=Time.get_ticks_msec()
	Hearth20Updater.confirm_startup()
	get_node("/root/Updates").startup_check()
	viewer.start_pending()
	if get_node("/root/SteamLink").pending_invite>0:begin_loading("join")
func _label(text_value: String, points: int, serif: bool=false) -> Label:
	var label:=Label.new(); label.text=text_value; label.add_theme_font_size_override("font_size",points)
	label.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.INK if points>15 else Hearth20Regal.MUTED))
	if serif: label.add_theme_font_override("font",Hearth20Design.font(true))
	return label
func _button(parent: Node, caption: String, action: Callable, height: int=40) -> Button:
	var button:=Button.new(); button.text=caption; button.tooltip_text=caption; button.clip_text=parent is GridContainer; button.custom_minimum_size.y=height
	if parent is GridContainer: button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.pressed.connect(action); parent.add_child(button); return button
func choose_creature(index: int) -> void:
	var entries:=Hearth20BestiaryCatalog.all()
	if entries.is_empty(): return
	creature_index=posmod(index,entries.size()); tip_index=randi_range(0,9)
	var entry: Dictionary=entries[creature_index]
	creature_type.text="CREATURE CODEX  /  "+str(entry.type).to_upper()
	creature_name.text=str(entry.name); tagline.text=str(entry.tagline)
	viewer.choose(str(entry.id)); _show_tip()
	showcase_reset.text="Replay" if viewer.video_mode else "Reset view"
	showcase_help.text="VIDEO SHOWCASE  ·  LOOPS WITH SOUND" if viewer.video_mode else "DRAG TO ROTATE  ·  RIGHT-DRAG TO LIFT  ·  WHEEL TO ZOOM"
	play_button.visible=viewer.video_mode; mute_button.visible=viewer.video_mode; video_volume.visible=viewer.video_mode; play_button.text="Pause"
	mute_button.text="Unmute" if viewer.video_muted else "Mute"
func next_tip() -> void:
	tip_index=(tip_index+1)%10; _show_tip()
func _show_codex() -> void:
	var dialog:=AcceptDialog.new(); dialog.title="Creature codex · Choose a showcase"; dialog.min_size=Vector2i(500,400); dialog.size=Vector2i(560,510); dialog.theme=theme; dialog.ok_button_text="Close"
	var list:=ItemList.new(); list.custom_minimum_size=Vector2(470,420); list.auto_height=false
	for entry in Hearth20BestiaryCatalog.all(): list.add_item(str(entry.name)+"  ·  "+str(entry.type))
	list.select(creature_index); list.item_selected.connect(func(index): choose_creature(index); dialog.queue_free())
	dialog.add_child(list); dialog.confirmed.connect(dialog.queue_free); dialog.canceled.connect(dialog.queue_free); add_child(dialog); dialog.popup_centered()
func _show_credits() -> void:
	var dialog:=AcceptDialog.new(); dialog.title="Creature showcase · Credits"; dialog.min_size=Vector2i(560,330); dialog.size=Vector2i(660,420); dialog.theme=theme
	var scroll:=ScrollContainer.new(); scroll.custom_minimum_size=Vector2(540,310); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; dialog.add_child(scroll)
	var label:=Label.new(); label.text=Hearth20BestiaryCatalog.credit(str(Hearth20BestiaryCatalog.all()[creature_index].id)); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.x=510; label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(label)
	dialog.confirmed.connect(dialog.queue_free); dialog.canceled.connect(dialog.queue_free); add_child(dialog); dialog.popup_centered()
func _show_tip() -> void:
	var entry: Dictionary=Hearth20BestiaryCatalog.all()[creature_index]
	tip.text=str(entry.tips[tip_index]); tip_counter.text="FIELD NOTE %02d / 10   ·   CREATURE %02d / 20"%[tip_index+1,creature_index+1]
func set_debug_preview(enabled: bool) -> void:
	if not debug_enabled or loading: return
	debug_preview=enabled; menu.visible=not enabled; progress.visible=enabled
	progress_note.text="Twenty creatures. Two hundred field notes. Your next story awaits."
func _show_debug_lab() -> void:
	if not debug_enabled or loading: return
	if is_instance_valid(debug_dialog): debug_dialog.popup_centered(); return
	debug_dialog=AcceptDialog.new(); debug_dialog.title="Hearth20 · Loading Lab"; debug_dialog.theme=theme; debug_dialog.size=Vector2i(570,470); debug_dialog.ok_button_text="Close lab"
	var column:=VBoxContainer.new(); column.custom_minimum_size=Vector2(530,380); column.add_theme_constant_override("separation",12); debug_dialog.add_child(column)
	var note:=_label("Browse every creature and field note.\nHold the loading screen open for inspection.",16); column.add_child(note)
	column.add_child(_label("CREATURE SHOWCASE",11)); debug_creature=OptionButton.new(); debug_creature.custom_minimum_size.y=38; column.add_child(debug_creature)
	for entry in Hearth20BestiaryCatalog.all(): debug_creature.add_item(str(entry.name))
	debug_creature.select(creature_index); debug_creature.item_selected.connect(func(index): choose_creature(index); _debug_refresh_tips())
	column.add_child(_label("FIELD NOTE / TIP",11)); debug_tip=OptionButton.new(); debug_tip.custom_minimum_size.y=38; column.add_child(debug_tip); _debug_refresh_tips()
	debug_tip.item_selected.connect(func(index): tip_index=index; _show_tip())
	var preview:=CheckButton.new(); preview.text="Hold loading screen preview"; preview.button_pressed=debug_preview; preview.toggled.connect(set_debug_preview); column.add_child(preview)
	column.add_child(_label("PREVIEW PROGRESS",11)); debug_progress_slider=HSlider.new(); debug_progress_slider.min_value=0; debug_progress_slider.max_value=100; debug_progress_slider.step=1; debug_progress_slider.value=debug_progress; debug_progress_slider.value_changed.connect(func(value): debug_progress=value; progress.value=value); column.add_child(debug_progress_slider)
	_button(column,"Return to title menu",func(): set_debug_preview(false); debug_dialog.queue_free())
	debug_dialog.confirmed.connect(debug_dialog.queue_free); debug_dialog.canceled.connect(debug_dialog.queue_free); add_child(debug_dialog); debug_dialog.popup_centered()
func _debug_refresh_tips() -> void:
	debug_tip.clear()
	var entry: Dictionary=Hearth20BestiaryCatalog.all()[creature_index]
	for i in entry.tips.size(): debug_tip.add_item("%02d  ·  %s"%[i+1,str(entry.tips[i]).left(58)])
	debug_tip.select(tip_index)
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F6 and debug_enabled: _show_debug_lab(); get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ESCAPE and debug_preview: set_debug_preview(false); get_viewport().set_input_as_handled()
func open_campaign_vault() -> void:
	Hearth20CampaignVault.open(self,null,"open",func(path):begin_loading("saved",path))
func begin_loading(action: String,save_path="") -> void:
	if loading: return
	if action=="saved" and save_path.is_empty():open_campaign_vault();return
	campaign_path=save_path
	set_debug_preview(false)
	if is_instance_valid(debug_dialog): debug_dialog.queue_free()
	mode=action; loading=true; menu.hide(); progress.show(); progress.value=0; progress_note.text="Preparing your table…"
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
	if background_material!=null: background_material.set_shader_parameter("base",Hearth20Regal.swatch(Hearth20Regal.BG))
	if content!=null:
		var compact:=size.x<1100
		content.add_theme_constant_override("separation",18 if compact else 44)
		menu.columns=2 if compact else 1
		creature_name.add_theme_font_size_override("font_size",27 if compact else 34)
	if debug_preview:
		progress.value=debug_progress; progress_note.text="LOADING PREVIEW  ·  %d%%  ·  F6 opens the lab  ·  Esc returns to the title"%int(debug_progress); return
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
	var model_ready:=viewer.ready_to_show() or viewer.load_failed
	if not model_ready: progress_note.text="Loading the selected creature in the background…"
	if complete==load_paths.size() and campaign_ready and model_ready:
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

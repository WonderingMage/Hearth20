extends ConfirmationDialog
class_name Hearth20SettingsWindow
var app: Hearth20App
var pending={}
var tabs: TabContainer
var updater: Hearth20Updater
var update_note: Label
var update_progress: ProgressBar
var check_button: Button
var download_button: Button
var install_button: Button
var stop_button: Button
var preview: ConfirmationDialog
var preview_until=0
var preview_label: Label
var closed=false
var preview_applied=false
var display_baseline={}
var window_position=Vector2i.ZERO
static func open(owner: Node,owner_app: Hearth20App=null) -> Hearth20SettingsWindow:
	for child in owner.get_children():
		if child is Hearth20SettingsWindow:child.popup_centered();return child
	var window=Hearth20SettingsWindow.new();owner.add_child(window);window.setup(owner_app);window.popup_centered();return window
func setup(owner_app: Hearth20App) -> void:
	app=owner_app;name="Hearth20Preferences";title="Hearth20 · Settings";theme=Hearth20Design.theme();size=Vector2i(980,650);min_size=Vector2i(780,540);exclusive=true;dialog_hide_on_ok=false;ok_button_text="Apply changes";get_cancel_button().text="Close";pending=Hearth20Preferences.values.duplicate(true)
	if DisplayServer.get_name()!="headless":
		var main=get_tree().root;pending.monitor=main.current_screen;window_position=main.position
		pending.window_mode=0 if main.mode in [Window.MODE_WINDOWED,Window.MODE_MAXIMIZED] else 2 if main.mode==Window.MODE_EXCLUSIVE_FULLSCREEN else 1
		if pending.window_mode==0:pending.width=main.size.x;pending.height=main.size.y
	display_baseline=pending.duplicate(true)
	var column=VBoxContainer.new();column.custom_minimum_size=Vector2(740,460);column.add_theme_constant_override("separation",12);add_child(column)
	var heading=Label.new();heading.text="THE CHAMBER OF PREFERENCES";heading.add_theme_font_override("font",Hearth20Design.font(true));heading.add_theme_font_size_override("font_size",25);heading.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.GOLD));column.add_child(heading)
	tabs=TabContainer.new();tabs.custom_minimum_size=Vector2(740,440);tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tabs)
	updater=Hearth20Updater.new();add_child(updater);updater.changed.connect(_update_status);updater.app=app
	_build();confirmed.connect(_apply);canceled.connect(_cancel);close_requested.connect(_cancel)
	Hearth20Regal.sync(self)
func page(caption: String) -> VBoxContainer:
	var scroll=ScrollContainer.new();scroll.name=caption;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",16);scroll.add_child(column);return column
func note(parent: Node,text: String) -> Label:
	var label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",14);parent.add_child(label);return label
func row(parent: Node,title_text: String) -> HBoxContainer:
	var line=HBoxContainer.new();line.add_theme_constant_override("separation",18);parent.add_child(line);var label=Label.new();label.text=title_text;label.custom_minimum_size.x=220;line.add_child(label);return line
func choice(parent: Node,caption: String,key: String,options: Array) -> OptionButton:
	var control=OptionButton.new();control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;control.custom_minimum_size.y=36;row(parent,caption).add_child(control)
	for item in options:
		control.add_item(str(item[0]));control.set_item_metadata(control.item_count-1,item[1])
		if pending.get(key)==item[1]:control.select(control.item_count-1)
	control.item_selected.connect(func(index):pending[key]=control.get_item_metadata(index));return control
func toggle(parent: Node,caption: String,key: String) -> CheckButton:
	var control=CheckButton.new();control.text=caption;control.button_pressed=pending[key];control.toggled.connect(func(value):pending[key]=value);parent.add_child(control);return control
func button(parent: Node,caption: String,action: Callable) -> Button:
	var control=Button.new();control.text=caption;control.custom_minimum_size.y=38;control.pressed.connect(action);parent.add_child(control);return control
func _build() -> void:
	var display=page("Display");note(display,"Choose how your table is presented. Display changes have a twenty-second confirmation and return to the previous view if left unconfirmed.")
	choice(display,"Window mode","window_mode",[["Windowed",0],["Borderless fullscreen",1],["Exclusive fullscreen",2]])
	var resolutions=OptionButton.new();resolutions.custom_minimum_size.y=36;resolutions.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row(display,"Window size").add_child(resolutions)
	var sizes=[Vector2i(1280,720),Vector2i(1280,800),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]
	if Vector2i(pending.width,pending.height) not in sizes:sizes.append(Vector2i(pending.width,pending.height))
	for dimensions in sizes:
		resolutions.add_item("%d × %d"%[dimensions.x,dimensions.y]);resolutions.set_item_metadata(resolutions.item_count-1,dimensions)
		if dimensions==Vector2i(pending.width,pending.height):resolutions.select(resolutions.item_count-1)
	resolutions.item_selected.connect(func(index):var value=resolutions.get_item_metadata(index);pending.width=value.x;pending.height=value.y)
	var monitors=[]
	for index in maxi(1,DisplayServer.get_screen_count()):monitors.append(["Display "+str(index+1),index])
	choice(display,"Monitor","monitor",monitors);choice(display,"Frame-rate limit","fps",[["30 FPS",30],["45 FPS",45],["60 FPS",60],["90 FPS",90],["120 FPS",120],["144 FPS",144],["Uncapped",0]])
	choice(display,"When in background","background_fps",[["30 FPS",30],["45 FPS",45],["60 FPS",60]])
	choice(display,"3D edge smoothing","quality",[["Performance · no MSAA",0],["Balanced · original detail",1],["Cinematic · 4× MSAA",2]])
	toggle(display,"Synchronize frames with the display (VSync)","vsync")
	var audio=page("Audio");note(audio,"Volumes belong to this device. Adjust party sounds, the creature videos and the wake-up voice independently.")
	var devices=[]
	for device in AudioServer.get_output_device_list():devices.append(["System default" if device=="Default" else device,device])
	choice(audio,"Output device","audio_device",devices)
	for entry in [["Master volume","master"],["Dice & effects","effects"],["Tavern & party sounds","party"],["Creature showcases","showcase"],["Wake-up voice","wake"]]:
		var line=row(audio,entry[0]);var slider=HSlider.new();slider.min_value=0;slider.max_value=100;slider.step=1;slider.value=float(pending[entry[1]])*100.;slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(slider);var percent=Label.new();percent.custom_minimum_size.x=48;percent.text=str(roundi(slider.value))+"%";line.add_child(percent)
		var key=entry[1];slider.value_changed.connect(func(value):pending[key]=value/100.;percent.text=str(roundi(value))+"%";Hearth20Preferences.apply_audio(pending))
	toggle(audio,"Mute while Hearth20 is in the background","mute_unfocused");button(audio,"♪ Play a sound preview",_sound_preview)
	var updates=page("Updates");note(updates,"HEARTH20 BETA · "+Hearth20Identity.VERSION+"\nOfficial updates: WonderingMage/Hearth20 on GitHub. Campaigns, player identities, settings and website sign-in remain in your local profile.")
	var buttons=HBoxContainer.new();buttons.add_theme_constant_override("separation",10);updates.add_child(buttons)
	check_button=button(buttons,"Check for updates",func():updater.check());download_button=button(buttons,"Download update",func():updater.download());install_button=button(buttons,"Restart & update",func():updater.install());stop_button=button(buttons,"Cancel download",func():updater.cancel())
	update_note=note(updates,"");update_progress=ProgressBar.new();update_progress.show_percentage=true;update_progress.custom_minimum_size.y=18;updates.add_child(update_progress)
	button(updates,"Open Hearth20 releases",func():OS.shell_open(Hearth20Updater.RELEASES_PAGE));_update_status()
func _update_status() -> void:
	if update_note==null:return
	update_note.text=updater.message;update_progress.visible=updater.busy;update_progress.value=updater.progress;check_button.disabled=updater.busy;download_button.visible=not updater.release.is_empty() and not updater.verified;download_button.disabled=updater.busy;install_button.visible=updater.verified;stop_button.visible=updater.busy and updater.stage=="download"
func _display_changed() -> bool:
	for key in ["window_mode","width","height","monitor","vsync","fps","background_fps","quality"]:
		if pending[key]!=display_baseline[key]:return true
	return false
func _apply() -> void:
	if is_instance_valid(preview):return
	if not _display_changed():_keep();return
	preview_applied=true;Hearth20Preferences.preview_values=Hearth20Preferences.sanitized(pending);Hearth20Preferences.apply_display(pending);preview=ConfirmationDialog.new();preview.title="Keep this display?";preview.ok_button_text="Keep changes";preview.get_cancel_button().text="Revert";preview.theme=theme;preview.size=Vector2i(460,170);preview_label=Label.new();preview.add_child(preview_label);preview_until=Time.get_ticks_msec()+20000;preview.confirmed.connect(_keep);preview.canceled.connect(_revert);add_child(preview);preview.popup_centered()
func _process(_delta: float) -> void:
	if is_instance_valid(preview):
		var seconds=maxi(0,ceili(float(preview_until-Time.get_ticks_msec())/1000.));preview_label.text="Keep these display settings?\nYour previous view returns in %d seconds."%seconds
		if seconds==0:_revert()
func _keep() -> void:
	var changed_display=_display_changed() or preview_applied
	if Hearth20Preferences.save(pending)!=OK:return
	Hearth20Preferences.apply_audio(Hearth20Preferences.values)
	if changed_display:Hearth20Preferences.apply_display(Hearth20Preferences.values)
	_close()
func _revert() -> void:
	if preview_applied:
		Hearth20Preferences.preview_values={};Hearth20Preferences.apply_display(display_baseline);preview_applied=false
		if DisplayServer.get_name()!="headless" and display_baseline.window_mode==0:get_tree().root.position=window_position
	if is_instance_valid(preview):preview.queue_free();preview=null
func _cancel() -> void:
	if closed:return
	if updater.stage=="install":return
	_revert();Hearth20Preferences.apply_audio(Hearth20Preferences.values);_close()
func _close() -> void:
	if closed:return
	closed=true;updater.cancel();hide();queue_free()
func _sound_preview() -> void:
	Hearth20Preferences.apply_audio(pending)
	var clip=AudioStreamWAV.new();clip.format=AudioStreamWAV.FORMAT_16_BITS;clip.mix_rate=22050;var data=PackedByteArray();data.resize(13230)
	for index in 6615:data.encode_s16(index*2,roundi(sin(float(index)/22050.*TAU*660.)*pow(sin(float(index)/6615.*PI),2.)*10000.))
	clip.data=data;var player=AudioStreamPlayer.new();player.bus="Table FX";player.stream=clip;add_child(player);player.finished.connect(player.queue_free);player.play()

extends Window
class_name Hearth20AvatarWardrobe
var session: Hearth20Session
var is_host=false
var value={}
var preview: SubViewport
var avatar: Hearth20WizardAvatar
var stage: Node3D
var pendant: OptionButton
var note: Label
var appearance_tabs: TabContainer
var eye_buttons={}
var eye_color_buttons={}
var eye_treatment_buttons={}
var eye_icons={}
static func open(parent: Node,owner_session: Hearth20Session,host: bool) -> Hearth20AvatarWardrobe:
	var window=Hearth20AvatarWardrobe.new();window.session=owner_session;window.is_host=host
	parent.add_child(window);window.setup();return window
func setup() -> void:
	title="Hearth20 · Your wizard";size=Vector2i(860,740);min_size=Vector2i(740,700);theme=Hearth20Design.theme();transient=true;close_requested.connect(queue_free)
	value=Hearth20AvatarStyle.remembered(is_host)
	if is_host and session.local_role=="dm":value=Hearth20AvatarStyle.clean(session.campaign.get("host_avatar",value),true)
	elif not is_host and session.local_role=="player":
		for entry in session.table_roster:
			if entry.get("mine",false):value=Hearth20AvatarStyle.clean(entry.style,false)
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Regal.swatch(Hearth20Regal.BG),3,20,Hearth20Regal.swatch(Hearth20Regal.GOLD)));add_child(panel)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",12);panel.add_child(box)
	var heading=Label.new();heading.text="✦  THE GAME MASTER’S WARDROBE  ✦" if is_host else "✦  YOUR SEAT AT THE TABLE  ✦";heading.add_theme_font_size_override("font_size",23);box.add_child(heading)
	var row=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(row)
	var container=SubViewportContainer.new();container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;container.custom_minimum_size=Vector2(300,360);container.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(container)
	preview=SubViewport.new();preview.own_world_3d=true;preview.handle_input_locally=false;preview.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE;preview.size=Vector2i(360,420);container.add_child(preview)
	stage=Node3D.new();preview.add_child(stage)
	var env=WorldEnvironment.new();var settings=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("#16131d");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_energy=.7;env.environment=settings;stage.add_child(env)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.3;stage.add_child(light)
	var camera=Camera3D.new();camera.current=true;stage.add_child(camera);camera.position=Vector3(.25,1.16,2.7);camera.look_at(Vector3(0,.83,0));camera.fov=43
	appearance_tabs=TabContainer.new();appearance_tabs.custom_minimum_size.x=320;appearance_tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(appearance_tabs)
	var choices=_page("Robe & jewels")
	_option(choices,"Robe color","robe",Hearth20AvatarStyle.ROBES.keys())
	_option(choices,"Jewelry finish","metal",Hearth20AvatarStyle.METALS)
	_option(choices,"Chain style","chain",Hearth20AvatarStyle.CHAINS)
	# The option itself does not exist in a player's window.
	if is_host:pendant=_option(choices,"Game Master’s pendant","pendant",["none","d20"])
	_build_eyes(_page("Eyes"))
	note=Label.new();note.text="Your robe, eyes and jewelry are remembered for your next visit.";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(note)
	var actions=HBoxContainer.new();actions.alignment=BoxContainer.ALIGNMENT_END;box.add_child(actions)
	var cancel=Button.new();cancel.text="Cancel";cancel.pressed.connect(queue_free);actions.add_child(cancel)
	var save=Button.new();save.text="Take my seat";save.custom_minimum_size=Vector2(160,42);save.pressed.connect(_save);actions.add_child(save)
	Hearth20Design.popup_window(self);_prepare()
func _page(caption: String) -> VBoxContainer:
	var scroll=ScrollContainer.new();scroll.name=caption;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;appearance_tabs.add_child(scroll)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",12);box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(box);return box
func _build_eyes(parent: VBoxContainer) -> void:
	parent.add_theme_constant_override("separation",6)
	var treatments=HBoxContainer.new();parent.add_child(treatments);var treatment_group=ButtonGroup.new()
	for id in Hearth20AvatarStyle.EYE_TREATMENTS:
		var button=Button.new();button.text=Hearth20AvatarStyle.EYE_TREATMENTS[id];button.toggle_mode=true;button.button_group=treatment_group;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;treatments.add_child(button);eye_treatment_buttons[id]=button
		button.pressed.connect(func():_choose_eye(value.eye_style,value.eye_color,id))
	var description=Label.new();description.text="Choose your expression";description.add_theme_font_size_override("font_size",17);parent.add_child(description)
	var group=ButtonGroup.new();var grid=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",5);grid.add_theme_constant_override("v_separation",5);parent.add_child(grid)
	for id in Hearth20AvatarStyle.EYES:
		var button=Button.new();button.custom_minimum_size=Vector2(69,50);button.toggle_mode=true;button.button_group=group;button.tooltip_text=Hearth20AvatarStyle.EYES[id];grid.add_child(button);eye_buttons[id]=button
		var column=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);column.offset_left=4;column.offset_right=-4;column.offset_top=4;column.offset_bottom=-4;column.add_theme_constant_override("separation",0);button.add_child(column)
		var picture=TextureRect.new();picture.texture=Hearth20WizardEyes.icon(id);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.custom_minimum_size.y=24;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(picture);eye_icons[id]=picture
		var label=Label.new();label.text=Hearth20AvatarStyle.EYES[id];label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",10);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(label)
		button.pressed.connect(func():_choose_eye(id,value.eye_color))
	var caption=Label.new();caption.text="Glow color";parent.add_child(caption)
	var palette=GridContainer.new();palette.columns=3;palette.add_theme_constant_override("h_separation",5);palette.add_theme_constant_override("v_separation",5);parent.add_child(palette);var colors=ButtonGroup.new()
	for id in Hearth20AvatarStyle.EYE_COLORS:
		var button=Button.new();button.text=id.capitalize();button.custom_minimum_size=Vector2(93,32);button.toggle_mode=true;button.button_group=colors;button.add_theme_color_override("font_color",Color(Hearth20AvatarStyle.EYE_COLORS[id]));palette.add_child(button);eye_color_buttons[id]=button
		button.pressed.connect(func():_choose_eye(value.eye_style,id))
	_choose_eye(value.eye_style,value.eye_color)
func _choose_eye(id: String,color: String,treatment="") -> void:
	if treatment.is_empty():treatment=value.eye_treatment
	value.eye_style=id;value.eye_color=color;value.eye_treatment=treatment
	for key in eye_buttons:eye_buttons[key].set_pressed_no_signal(key==id);eye_icons[key].modulate=Color(Hearth20AvatarStyle.EYE_COLORS[color])
	for key in eye_color_buttons:eye_color_buttons[key].set_pressed_no_signal(key==color)
	for key in eye_treatment_buttons:eye_treatment_buttons[key].set_pressed_no_signal(key==treatment)
	if is_instance_valid(avatar):avatar.set_eyes(id,color,treatment)
func _option(parent: Node,caption: String,field: String,items: Array) -> OptionButton:
	var label=Label.new();label.text=caption;parent.add_child(label);var option=OptionButton.new();option.custom_minimum_size.y=40;parent.add_child(option)
	for item in items:option.add_item("D20 pendant" if item=="d20" else str(item).capitalize());option.set_item_metadata(option.item_count-1,item)
	option.select(items.find(value[field]));option.item_selected.connect(func(index):value[field]=option.get_item_metadata(index);_rebuild());return option
func _prepare() -> void:
	# Normally already loaded behind the seated loading screen. Never block title startup.
	if not Hearth20GeneratedModels.available("wizard_body") or not Hearth20GeneratedModels.available("wizard_hat"):await Hearth20GeneratedModels.prepare(get_tree())
	if is_instance_valid(self):_rebuild()
func _rebuild() -> void:
	if not Hearth20GeneratedModels.available("wizard_body") or not Hearth20GeneratedModels.available("wizard_hat"):return
	if is_instance_valid(avatar):avatar.free()
	avatar=Hearth20WizardAvatar.new();stage.add_child(avatar);avatar.setup(value,is_host)
func _save() -> void:
	if not Hearth20AvatarStyle.valid(value,is_host):return
	if (session.local_role=="dm")==is_host:
		if is_host or not session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
			var result=session.set_avatar(value)
			if not result.ok:note.text=result.error;return
	Hearth20AvatarStyle.remember(value,is_host);queue_free()

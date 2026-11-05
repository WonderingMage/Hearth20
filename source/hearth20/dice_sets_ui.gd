extends Window
class_name Hearth20DiceSetsWindow
var session: Hearth20Session
var chosen: String
var active: String=""
var preview: Node3D
var display: Node3D
var viewport: SubViewport
var heading: Label
var status: Label
var choose: Button
var buttons: Dictionary={}
var dragging:=false
var last_point:=Vector2.ZERO
var theme_revision:=-1
func setup(owner_session: Hearth20Session) -> void:
	session=owner_session; chosen=Hearth20DiceSets.selected(session.local_role); title="Hearth20 · Dice collection"; size=Vector2i(1100,760); min_size=Vector2i(920,650); theme=Hearth20Design.theme(); close_requested.connect(queue_free)
	var backdrop:=ColorRect.new(); backdrop.color=Hearth20Regal.swatch(Hearth20Regal.BG); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(backdrop)
	var margin:=MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",12); margin.add_child(column)
	heading=_label("Your dice collection",30); heading.add_theme_font_override("font",Hearth20Design.font(true)); column.add_child(heading)
	var note:=_label("The DM's personal forge · Public and private rolls use this set." if session.local_role=="dm" else "Seven collections. Your choice follows every roll and is remembered on this device.",14); column.add_child(note)
	var row:=HBoxContainer.new(); row.size_flags_vertical=Control.SIZE_EXPAND_FILL; row.add_theme_constant_override("separation",20); column.add_child(row)
	var scroll:=ScrollContainer.new(); scroll.custom_minimum_size.x=540; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; row.add_child(scroll)
	var grid:=GridContainer.new(); grid.columns=2; grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12); scroll.add_child(grid)
	for id in (["dm"] if session.local_role=="dm" else Hearth20DiceSets.PLAYER_IDS):
		var button:=Button.new(); button.custom_minimum_size=Vector2(255,166); button.tooltip_text=Hearth20DiceSets.NAMES[id]; button.pressed.connect(func(): select_set(id)); grid.add_child(button); buttons[id]=button
		var box:=VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.offset_left=8; box.offset_top=8; box.offset_right=-8; box.offset_bottom=-8; box.mouse_filter=Control.MOUSE_FILTER_IGNORE; button.add_child(box)
		var picture:=TextureRect.new(); picture.texture=load(Hearth20DiceSets.ROOT+id+"-thumb.png"); picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; picture.custom_minimum_size.y=120; picture.mouse_filter=Control.MOUSE_FILTER_IGNORE; box.add_child(picture)
		var label:=_label(Hearth20DiceSets.NAMES[id],14); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.mouse_filter=Control.MOUSE_FILTER_IGNORE; box.add_child(label)
	var detail:=VBoxContainer.new(); detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(detail)
	var surface:=SubViewportContainer.new(); surface.stretch=true; surface.size_flags_horizontal=Control.SIZE_EXPAND_FILL; surface.size_flags_vertical=Control.SIZE_EXPAND_FILL; surface.gui_input.connect(_drag); detail.add_child(surface)
	viewport=SubViewport.new(); viewport.own_world_3d=true; viewport.transparent_bg=true; viewport.msaa_3d=Viewport.MSAA_4X; surface.add_child(viewport); display=Node3D.new(); viewport.add_child(display)
	var camera:=Camera3D.new(); camera.current=true; camera.position=Vector3(0,1,3.5); display.add_child(camera); camera.look_at(Vector3.ZERO)
	var environment:=WorldEnvironment.new(); var env:=Environment.new(); env.background_mode=Environment.BG_COLOR; env.background_color=Color(0,0,0,0); env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color.WHITE; env.ambient_light_energy=.5; environment.environment=env; display.add_child(environment)
	for spec in [[Vector3(-40,-30,0),1.3],[Vector3(20,140,0),.8]]:
		var light:=DirectionalLight3D.new(); light.rotation_degrees=spec[0]; light.light_energy=spec[1]; display.add_child(light)
	status=_label("",14); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail.add_child(status)
	choose=Button.new(); choose.text="Use this collection"; choose.custom_minimum_size.y=46; choose.pressed.connect(func():
		if session.local_role!="dm": Hearth20PlayerProfile.remember_dice_set(chosen)
		status.text=Hearth20DiceSets.NAMES[chosen]+" is equipped. Everyone authorized to see your rolls sees these dice.")
	detail.add_child(choose)
	var credit:=RichTextLabel.new(); credit.bbcode_enabled=true; credit.fit_content=true; credit.custom_minimum_size.y=54; credit.add_theme_font_size_override("normal_font_size",11); credit.text="Supplied models: [url=https://sketchfab.com/3d-models/rpg-dice-set-2498c370c56842f89fa3d7096c72ed56]RPG Dice Set by ghosted[/url] · [url=https://sketchfab.com/3d-models/dungeons-and-dragons-dice-set-163950cff9694fe1a686d22fe7737236]Dungeons and Dragons Dice Set by JayDesigns3D[/url] · [url=https://creativecommons.org/licenses/by/4.0/]CC BY 4.0[/url]. Converted, normalized and calibrated; ordinary DM d10 numerals adapted."; credit.meta_clicked.connect(func(url): OS.shell_open(str(url))); column.add_child(credit)
	select_set(chosen); popup_centered()
func _label(text: String, points: int) -> Label:
	var label:=Label.new(); label.text=text; label.add_theme_font_size_override("font_size",points); label.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.INK)); return label
func select_set(id: String) -> void:
	chosen=id; active=""; heading.text=Hearth20DiceSets.NAMES[id]; status.text="Preparing your 3D preview…"; Hearth20DiceSets.request(id)
	if is_instance_valid(preview): preview.queue_free(); preview=null
	_style_cards()
func _process(delta: float) -> void:
	Hearth20Regal.sync(self); Hearth20DiceSets.poll()
	if session==null: return
	if session.local_role=="dm" and chosen!="dm": select_set("dm")
	if session.local_role!="dm" and chosen=="dm": queue_free(); return
	if active!=chosen and Hearth20DiceSets.ready(chosen):
		active=chosen; preview=Hearth20DiceSets.make(chosen,20,20); display.add_child(preview); preview.rotation=Vector3(.3,.4,0); status.text=("Equipped collection. " if chosen==Hearth20DiceSets.selected(session.local_role) else "Preview collection. Choose below to equip. ")+"Drag to turn the model."
	if is_instance_valid(preview) and not dragging: preview.rotate_y(delta*.22)
	if theme_revision!=Hearth20Regal.revision: _style_cards()
func _style_cards() -> void:
	theme_revision=Hearth20Regal.revision
	for id in buttons:
		buttons[id].add_theme_stylebox_override("normal",Hearth20Regal.button_style("pressed" if id==chosen else "normal"))
func _drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed; last_point=event.position
	if event is InputEventMouseMotion and dragging and is_instance_valid(preview): preview.rotate_y(event.relative.x*.009); preview.rotate_x(event.relative.y*.009)

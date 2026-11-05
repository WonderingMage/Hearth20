extends Window
class_name Hearth20FxStudioWindow
## The same table FX in an orbitable native3D study; this preview never broadcasts.
const PRESETS: Array=[["Ember comet","rocket","Fire"],["Sunlit aegis","shield","Holy"],["Crystal eruption","nova","Frost"],["Void rift","nova","Death"],["Blood impact","splatter","Blood"],["Arcane lance","missile","Magic"],["Tidal crown","explode","Water"],["Corrosive surge","breath","Acid"],["Ash plume","smoke","Smoke"],["Heart bloom","burst","Charm"],["Roaring pyre","burn","Fire"]]
var app: Hearth20App
var actor: Hearth20FxActor3D
var world: Node3D
var camera: Camera3D
var viewport: SubViewport
var surface: SubViewportContainer
var preset_list: ItemList
var element: OptionButton
var shape: OptionButton
var timeline: HSlider
var time_label: Label
var play_button: Button
var heading: Label
var frame_note: Label
var age:=0.0
var total:=7.0
var playing:=true
var looping:=true
var speed:=1.0
var drag:=false
var yaw:=.45
var elevation:=.65
var distance:=7.8
var syncing:=false
var current: Dictionary={}
var source:=Vector2.ZERO
var target:=Vector2.ZERO
func setup(owner_app: Hearth20App) -> void:
	app=owner_app;title="Hearth20 · Effects atelier";size=Vector2i(1280,860);min_size=Vector2i(1000,700);theme=Hearth20Design.theme();close_requested.connect(queue_free)
	var back:=ColorRect.new();back.color=Hearth20Regal.swatch(Hearth20Regal.BG);back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(back)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,20)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);margin.add_child(column)
	heading=_label("The effects atelier",30);heading.add_theme_font_override("font",Hearth20Design.font(true));column.add_child(heading)
	column.add_child(_label("Preview your effects in3D. Rotate the scene, slow the action or inspect an impact. Previews stay on this device.",13))
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",18);column.add_child(body)
	var rail:=VBoxContainer.new();rail.custom_minimum_size.x=235;body.add_child(rail);rail.add_child(_label("CURATED EFFECTS",12))
	preset_list=ItemList.new();preset_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;preset_list.custom_minimum_size.y=350
	for preset in PRESETS:preset_list.add_item(preset[0])
	preset_list.item_selected.connect(_preset);rail.add_child(preset_list)
	rail.add_child(_label("Material",12));element=OptionButton.new()
	for name_value in Hearth20BoardTools.COLORS:element.add_item(name_value)
	element.item_selected.connect(func(_index):
		if not syncing:_restart());rail.add_child(element)
	rail.add_child(_label("Shape",12));shape=OptionButton.new()
	for name_value in Hearth20BoardTools.EFFECTS:shape.add_item(name_value)
	shape.item_selected.connect(func(_index):
		if not syncing:_restart());rail.add_child(shape)
	var preview:=VBoxContainer.new();preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(preview)
	surface=SubViewportContainer.new();surface.stretch=true;surface.size_flags_horizontal=Control.SIZE_EXPAND_FILL;surface.size_flags_vertical=Control.SIZE_EXPAND_FILL;surface.custom_minimum_size=Vector2(660,430);surface.material=Hearth20FxPost.material();surface.gui_input.connect(_orbit);preview.add_child(surface)
	viewport=SubViewport.new();viewport.msaa_3d=Viewport.MSAA_4X;viewport.own_world_3d=true;surface.add_child(viewport);world=Node3D.new();viewport.add_child(world)
	camera=Camera3D.new();camera.current=true;camera.fov=44;world.add_child(camera);_camera()
	var env_node:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("#0e0d0c");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("#b1a28c");env.ambient_light_energy=.38;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env_node.environment=env;world.add_child(env_node)
	for spec in [[Vector3(-42,-30,0),1.5,Color("#ffe1b2")],[Vector3(-15,140,0),.75,Color("#9eacc5")]]:
		var light:=DirectionalLight3D.new();light.rotation_degrees=spec[0];light.light_energy=spec[1];light.light_color=spec[2];light.shadow_enabled=true;light.directional_shadow_max_distance=30;world.add_child(light)
	var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2.ONE*16;floor.mesh=plane;floor.position.y=-.055
	var shader:=Shader.new();shader.code="shader_type spatial; varying vec3 point;void vertex(){point=VERTEX;}void fragment(){vec2 grid=abs(fract(point.xz+.5)-.5);float line=1.-smoothstep(.009,.018,min(grid.x,grid.y));float grain=sin(point.x*51.+sin(point.z*37.))*sin(point.z*47.)*.006;ALBEDO=mix(vec3(.035,.031,.025)+grain,vec3(.16,.12,.062),line*.6);ROUGHNESS=.45;METALLIC=.18;}"
	var material_value:=ShaderMaterial.new();material_value.shader=shader;floor.material_override=material_value;world.add_child(floor)
	frame_note=_label("Drag to orbit · wheel to zoom · scrub the timeline to inspect an impact",12);preview.add_child(frame_note)
	var time_row:=HBoxContainer.new();time_row.add_theme_constant_override("separation",12);column.add_child(time_row)
	play_button=_button(time_row,"Pause",func():playing=not playing;play_button.text="Pause" if playing else "Play")
	_button(time_row,"Replay",func():age=0;playing=true;play_button.text="Pause")
	var loop:=CheckBox.new();loop.text="Loop";loop.button_pressed=true;loop.toggled.connect(func(value):looping=value);time_row.add_child(loop)
	var rate:=OptionButton.new()
	for label in ["¼ speed","½ speed","Full speed"]:rate.add_item(label)
	rate.selected=2;rate.item_selected.connect(func(index):speed=[.25,.5,1.][index]);time_row.add_child(rate)
	timeline=HSlider.new();timeline.min_value=0;timeline.max_value=7;timeline.step=.01;timeline.size_flags_horizontal=Control.SIZE_EXPAND_FILL;timeline.value_changed.connect(func(value):
		if not syncing:age=value);time_row.add_child(timeline)
	time_label=_label("0.00 s",13);time_label.custom_minimum_size.x=72;time_row.add_child(time_label)
	preset_list.select(0);_preset(0);popup_centered()
func _label(text: String, points: int) -> Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",points);label.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.INK));return label
func _button(parent: Node, text: String, action: Callable) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size.y=36;button.pressed.connect(action);parent.add_child(button);return button
func _preset(index: int) -> void:
	syncing=true;preset_list.select(index);var preset: Array=PRESETS[index];heading.text=preset[0]
	for i in element.item_count:
		if element.get_item_text(i)==preset[2]:element.select(i)
	for i in shape.item_count:
		if shape.get_item_text(i)==preset[1]:shape.select(i)
	syncing=false;_restart(true)
func _restart(keep_title: bool=false) -> void:
	if is_instance_valid(actor):actor.queue_free()
	var kind:=shape.get_item_text(shape.selected);var material_name:=element.get_item_text(element.selected);var cast: bool=Hearth20BoardTools.CAST_EFFECTS.has(kind)
	if not keep_title:heading.text=material_name+" · "+kind.capitalize();preset_list.deselect_all()
	source=Vector2(-2.1,0) if cast else Vector2.ZERO;target=Vector2(1.1,0) if cast else Vector2.ZERO
	current=app.session.make_effect({"effect":kind,"material":material_name,"color":Hearth20BoardTools.COLORS[material_name],"duration":6.,"density":128,"size":1.},source,target)
	current.started_usec=0;current.travel_usec=1300000 if kind in ["rocket","missile","bomb"] else 0;total=6.+current.travel_usec/1000000.;timeline.max_value=total
	actor=Hearth20FxActor3D.new();world.add_child(actor);actor.setup(current);age=0;playing=true;play_button.text="Pause"
func _camera() -> void:
	var focus:=Vector3(0,1.,0);camera.position=focus+Vector3(sin(yaw)*cos(elevation),sin(elevation),cos(yaw)*cos(elevation))*distance;camera.look_at(focus)
func _orbit(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:drag=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:distance=clampf(distance+(-.45 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .45),3.5,13);_camera()
	if event is InputEventMouseMotion and drag:yaw-=event.relative.x*.008;elevation=clampf(elevation+event.relative.y*.006,.15,1.45);_camera()
func _process(delta: float) -> void:
	Hearth20Regal.sync(self)
	if not is_instance_valid(actor):return
	if playing:age+=delta*speed
	if age>total:
		if looping:age=fmod(age,total)
		else:age=total;playing=false;play_button.text="Play"
	var travel:=float(current.travel_usec)/1000000.;var p:=clampf(age/maxf(.01,travel),0,1);var at:=source.lerp(target,p) if travel>0 else target
	actor.position=Vector3(at.x,sin(p*PI)*.6 if travel>0 and age<travel else 0,at.y);actor.animate(int(age*1000000),source-target)
	syncing=true;timeline.value=age;syncing=false;time_label.text="%.2f s"%age

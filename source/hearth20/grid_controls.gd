extends VBoxContainer
class_name Hearth20GridControls
var app: Hearth20App
var opacity: HSlider
var thickness: HSlider
var tint: ColorPickerButton
var values: Label
var syncing:=false
var pending: Timer
var signature:=""
func setup(owner_app: Hearth20App) -> void:
	app=owner_app
	var heading:=Label.new(); heading.text="GRID APPEARANCE"; heading.add_theme_font_size_override("font_size",11); add_child(heading)
	values=Label.new(); add_child(values)
	opacity=HSlider.new(); opacity.name="GridOpacity"; opacity.min_value=0; opacity.max_value=100; opacity.step=1; opacity.tooltip_text="Grid opacity"; add_child(opacity)
	thickness=HSlider.new(); thickness.name="GridThickness"; thickness.min_value=.5; thickness.max_value=4; thickness.step=.25; thickness.tooltip_text="Grid thickness in screen pixels"; add_child(thickness)
	tint=ColorPickerButton.new(); tint.custom_minimum_size.y=30; tint.tooltip_text="Grid line color"; add_child(tint)
	pending=Timer.new(); pending.one_shot=true; pending.wait_time=.18; add_child(pending)
	for slider in [opacity,thickness]: slider.value_changed.connect(func(_value): _edited())
	tint.color_changed.connect(func(_value): _edited())
	pending.timeout.connect(func(): app.session.set_grid_style(opacity.value/100.0,thickness.value,"#"+tint.color.to_html(false)))
	_sync()
func _edited() -> void:
	values.text="Opacity %.0f%%   ·   Thickness %.2f px"%[opacity.value,thickness.value]
	if not syncing: pending.start()
func _process(_delta: float) -> void:
	if app!=null and pending.is_stopped(): _sync()
func _sync() -> void:
	var scene: Dictionary=app.board.current_scene()
	var key:=str([scene.get("id"),scene.get("grid_opacity",.34),scene.get("grid_thickness",1.0),scene.get("grid_color","#d8c99e")])
	if key==signature: return
	signature=key; syncing=true
	opacity.value=float(scene.get("grid_opacity",.34))*100; thickness.value=float(scene.get("grid_thickness",1)); tint.color=Color(str(scene.get("grid_color","#d8c99e")))
	_edited(); syncing=false

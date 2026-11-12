extends Control
class_name Hearth20AutosaveIndicator
var manager: Hearth20Autosave
var app: Hearth20App
var caption: Label
var progress=0.
var active=false
var original_margin=0.
var footer_style: StyleBox
var last_state=[]
func setup(owner_app: Hearth20App,autosave: Hearth20Autosave) -> void:
	app=owner_app;manager=autosave;mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=1200
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);offset_top=-26;offset_bottom=0
	caption=Label.new();caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;caption.add_theme_font_size_override("font_size",11);caption.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.GOLD));caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);caption.offset_left=12;caption.offset_right=-12;caption.offset_bottom=-5;add_child(caption)
	if is_instance_valid(app.status_label):footer_style=app.status_label.get_parent().get_theme_stylebox("panel");original_margin=footer_style.content_margin_right
	manager.changed.connect(show_state);show_state(manager.state())
func show_state(state: Dictionary) -> void:
	var signature=[state.get("visible",false),state.get("active",false),state.get("progress",0),state.get("message",""),app.session.local_role]
	if signature==last_state:return
	last_state=signature
	visible=app.session.local_role=="dm" and bool(state.get("visible",false));active=bool(state.get("active",false));progress=clampf(float(state.get("progress",0)),0.,1.)
	caption.text=("Autosaving · %d%%"%roundi(progress*100.)) if active else str(state.get("message",""))
	if footer_style!=null:
		var margin=300. if visible else original_margin
		if not is_equal_approx(footer_style.content_margin_right,margin):footer_style.content_margin_right=margin
	queue_redraw()
func _process(_delta: float) -> void:
	if not manager.active:show_state(manager.state())
func _draw() -> void:
	if not active:return
	draw_rect(Rect2(0,size.y-3,size.x,3),Hearth20Regal.swatch(Hearth20Regal.SURFACE))
	draw_rect(Rect2(0,size.y-3,size.x*progress,3),Hearth20Regal.swatch(Hearth20Regal.GOLD))

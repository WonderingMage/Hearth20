extends PanelContainer
class_name Hearth20CharacterCard
## Read-only presentation of the already-authorized sheet, with genuine recorded stats.
var column: VBoxContainer

func _ready() -> void:
	add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#202a3a"),12,16,Color("#66583f")))

func present(actor: Dictionary) -> void:
	for child in get_children():
		remove_child(child); child.queue_free()
	visible=not actor.is_empty()
	if actor.is_empty(): return
	column=VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	add_child(column)
	var title:=Label.new()
	title.text=str(actor.get("name","Character"))
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font",Hearth20Design.font(true))
	title.add_theme_font_size_override("font_size",23)
	title.add_theme_color_override("font_color",Hearth20Design.INK)
	column.add_child(title)
	var identity:=Label.new()
	identity.text=" · ".join([str(actor.get("race","")),str(actor.get("class","")),"Level %d"%int(actor.get("level",1))].filter(func(s): return not s.is_empty()))
	identity.add_theme_font_size_override("font_size",12)
	identity.add_theme_color_override("font_color",Hearth20Design.MUTED)
	identity.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(identity)
	var stats:=HBoxContainer.new()
	stats.add_theme_constant_override("separation",8)
	column.add_child(stats)
	var hp: Variant=actor.get("hp",actor.get("hit_points","—"))
	var max_hp: Variant=actor.get("max_hp","—")
	_stat(stats,"HIT POINTS",_number(hp)+" / "+_number(max_hp),Hearth20Design.TEAL)
	_stat(stats,"ARMOR",_number(actor.get("ac",actor.get("armor_class","—"))),Hearth20Design.GOLD)
	_stat(stats,"SPEED",_number(actor.get("speed","—"))+" ft",Hearth20Design.INK)
	if (hp is int or hp is float) and (max_hp is int or max_hp is float) and float(max_hp)>0:
		var bar:=ProgressBar.new()
		bar.min_value=0
		bar.max_value=float(max_hp)
		bar.value=clampf(float(hp),0,float(max_hp))
		bar.show_percentage=false
		bar.custom_minimum_size.y=4
		bar.add_theme_stylebox_override("background",Hearth20Design.panel(Color("#0d1722"),2,0,Color(0,0,0,0)))
		bar.add_theme_stylebox_override("fill",Hearth20Design.panel(Hearth20Design.TEAL,2,0,Color(0,0,0,0)))
		column.add_child(bar)
	if float(actor.get("temp",0))>0:
		var temp:=Label.new()
		temp.text="+%s temporary hit points"%_number(actor.temp)
		temp.add_theme_font_size_override("font_size",11)
		temp.add_theme_color_override("font_color",Hearth20Design.TEAL)
		column.add_child(temp)

func _number(value: Variant) -> String:
	return str(int(value)) if value is float and is_finite(value) and is_equal_approx(value,roundf(value)) else str(value)

func _stat(parent: HBoxContainer, caption: String, value: String, color: Color) -> void:
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#151d2a"),7,9,Color("#364256")))
	parent.add_child(panel)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",4)
	panel.add_child(box)
	var name_label:=Label.new()
	name_label.text=caption
	name_label.add_theme_font_size_override("font_size",9)
	name_label.add_theme_color_override("font_color",Hearth20Design.MUTED)
	box.add_child(name_label)
	var metric:=Label.new()
	metric.text=value
	metric.add_theme_font_size_override("font_size",18)
	metric.add_theme_color_override("font_color",Hearth20Regal.resolve(color))
	metric.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(metric)

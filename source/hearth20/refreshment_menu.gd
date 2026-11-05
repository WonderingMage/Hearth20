extends Control
class_name Hearth20RefreshmentMenu
signal ordered(food: String,drink: String)
var food=""
var drink=""
var confirm: Button
var note: Label
var choices={}
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);z_index=1400;theme=Hearth20Design.theme()
	var shade=ColorRect.new();shade.color=Color(0,0,0,.78);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	var panel=PanelContainer.new();panel.anchor_left=.10;panel.anchor_right=.90;panel.anchor_top=.05;panel.anchor_bottom=.95;panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#21190f"),3,18,Color("#bc9250")));add_child(panel)
	var col=VBoxContainer.new();col.add_theme_constant_override("separation",10);panel.add_child(col)
	var title=Label.new();title.text="✦  THE HEARTH'S PROVISIONS  ✦";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",26);col.add_child(title)
	var subtitle=Label.new();subtitle.text="One dish. One drink. Conjured to your own little table.";subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;col.add_child(subtitle)
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;col.add_child(scroll)
	var contents=VBoxContainer.new();contents.size_flags_horizontal=Control.SIZE_EXPAND_FILL;contents.add_theme_constant_override("separation",12);scroll.add_child(contents)
	_section(contents,"FROM THE KITCHEN · 2 bites",Hearth20RefreshmentCatalog.FOODS,5)
	_section(contents,"FROM THE CELLAR · 3 sips",Hearth20RefreshmentCatalog.DRINKS,6)
	note=Label.new();note.text="Finish both servings before the menu returns. Beer effects last one hour each.";note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(note)
	var row=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;col.add_child(row)
	confirm=Button.new();confirm.text="Conjure my order";confirm.disabled=true;confirm.custom_minimum_size=Vector2(240,48);confirm.pressed.connect(func():confirm.disabled=true;ordered.emit(food,drink));row.add_child(confirm)
	var close=Button.new();close.text="Close menu";close.pressed.connect(hide);row.add_child(close);hide()
func _section(parent: Node,title: String,catalog: Dictionary,columns: int) -> void:
	var heading=Label.new();heading.text=title;heading.add_theme_color_override("font_color",Color("#e0bd72"));parent.add_child(heading)
	var grid=GridContainer.new();grid.columns=columns;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);parent.add_child(grid)
	for id in catalog:
		var b=Button.new();b.custom_minimum_size=Vector2(142,117);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.tooltip_text=catalog[id].name
		var thumb=Hearth20RefreshmentCatalog.BASE+"thumbs/"+id+".png"
		if ResourceLoader.exists(thumb):b.icon=load(thumb);b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP;b.expand_icon=true;b.add_theme_constant_override("icon_max_width",72)
		b.text=catalog[id].name;b.alignment=HORIZONTAL_ALIGNMENT_CENTER;b.add_theme_font_size_override("font_size",14);b.pressed.connect(func():_select(id,catalog==Hearth20RefreshmentCatalog.FOODS));grid.add_child(b);choices[id]=b
func _select(id: String,is_food: bool) -> void:
	if is_food:food=id
	else:drink=id
	for key in choices:choices[key].modulate=Color("#ffe1a0") if key in [food,drink] else Color.WHITE
	confirm.disabled=food.is_empty() or drink.is_empty();note.text=(Hearth20RefreshmentCatalog.FOODS[food].name if not food.is_empty() else "Choose a dish")+"  +  "+(Hearth20RefreshmentCatalog.DRINKS[drink].name if not drink.is_empty() else "choose a drink")
	if drink=="beer":note.text+=" · Alcohol: 3–5 beers blur the view; 6 means spectating."
func open() -> void:
	confirm.disabled=food.is_empty() or drink.is_empty();show()

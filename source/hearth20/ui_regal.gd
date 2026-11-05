extends RefCounted
class_name Hearth20Regal
## Shared semantic finish for existing native controls, with reversible local preference.
static var light_mode:=false
static var revision:=0
static var textures: Dictionary={}
const BG := ["#100e0b","#eee4cf"]
const SURFACE := ["#191610","#f7eedc"]
const RAISED := ["#252017","#e6d7b9"]
const BORDER := ["#5c4a2c","#b69a63"]
const INK := ["#f3e7cd","#302618"]
const MUTED := ["#b9a98a","#756345"]
const GOLD := ["#e0bd75","#8b6028"]
static func swatch(pair: Array) -> Color: return Color(str(pair[1 if light_mode else 0]))
static func resolve(c: Color) -> Color:
	if c.a<0.001: return c
	var hex:=c.to_html(false).to_lower()
	var target:=c
	for pair in [BG,SURFACE,RAISED,BORDER,INK,MUTED,GOLD]:
		if hex==Color(str(pair[0])).to_html(false) or hex==Color(str(pair[1])).to_html(false):
			var mapped:=swatch(pair); mapped.a=c.a; return mapped
	if hex in ["0b0e15","0b1018","0b1015","0d1420","0e1420","0b0e14","0c111b","0b0f17","0b101a","0d1421"]: target=swatch(BG)
	elif hex in ["131925","111722","111a28","111a27","101824","111b29","192130","192130","151d29","151d28","121b29","141c29","151d2a","161e2b"]: target=swatch(SURFACE)
	elif hex in ["1a2230","1b2331","222b3b","232d40","283248","1e2737","252f40","192130","192130","1c2534","182331","1c2634","1c2633","1e293b"]: target=swatch(RAISED)
	elif hex in ["2b3545","303b4d","596274","222b3a","38465d","30394c","354157","3a465c","66718a","303b4a","2b3546"]: target=swatch(BORDER)
	elif hex in ["edf0f6","f3ead8","d9e2e6","d2dce5","dce6ee","e8edf4","e6edf3"]: target=swatch(INK)
	elif hex in ["9ba6b9","9cadb5","93a4ac","8b9fa8","91a6ad","8b9fa8","8b9fa8","8b9fa8","8b9fa8","8b9fa8","8b9fa8","8b9fa8","748198","596375","8b9fa8","8b9fa8","8b9fa8","8b9fa8","8b9fa8","8b9fa8","8b9fa8","8b9fa8"]: target=swatch(MUTED)
	elif hex in ["ddbd82","ebcf9e","f0c674","d2ae79","80cbbf","76e0ca","62e4d1","9ee5d8"]: target=swatch(GOLD)
	elif hex in ["363124","3a3327"]: target=Color("#3c2c14") if not light_mode else Color("#d9bf8b")
	elif hex in ["605844","957c50","9a8050","a38958","756b56"]: target=swatch(BORDER)
	else:
		# Remaining desaturated blue chrome becomes warm charcoal/parchment.
		if c.b>c.r*1.13 and c.b>c.g*1.03 and c.v<0.40 and c.s<0.7:
			target=swatch(SURFACE) if c.v<0.2 else swatch(RAISED)
	target.a=c.a
	return target

static func load_preference() -> void:
	var file:=ConfigFile.new()
	if file.load("user://hearth20/interface.cfg")==OK:
		var selected:=bool(file.get_value("appearance","light",false))
		if selected!=light_mode: light_mode=selected; revision+=1
static func toggle() -> void:
	light_mode=not light_mode; revision+=1
	var file:=ConfigFile.new(); file.set_value("appearance","light",light_mode)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://hearth20"))
	file.save("user://hearth20/interface.cfg")

static func button_style(state: String, primary: bool=false) -> StyleBoxTexture:
	var key:=str(light_mode)+state+str(primary)
	if not textures.has(key):
		var face:=swatch(SURFACE).to_html(false)
		var edge:=swatch(BORDER).to_html(false)
		var shine:=swatch(GOLD).to_html(false)
		if state=="hover": face=swatch(RAISED).to_html(false); edge=shine
		if state=="pressed": face="d9bf8b" if light_mode else "3b2b12"; edge=shine
		var fill: String="url(#gold)" if primary else "#"+face
		var svg: String='<svg xmlns="http://www.w3.org/2000/svg" width="160" height="48" viewBox="0 0 160 48"><defs><linearGradient id="gold" x2="0" y2="1"><stop stop-color="#eed6a1"/><stop offset=".45" stop-color="#d6b56d"/><stop offset="1" stop-color="#a87d38"/></linearGradient></defs><path d="M8 1H152L159 8V40L152 47H8L1 40V8Z" fill="%s" stroke="#%s" stroke-width="1"/><path d="M10 4H150L156 10V38L150 44H10L4 38V10Z" fill="none" stroke="#%s" stroke-opacity=".3" stroke-width=".5"/><path d="M5 12L12 5M148 5L155 12M5 36L12 43M148 43L155 36" fill="none" stroke="#%s" stroke-width=".7"/></svg>'%[fill,edge,shine,shine]
		var image:=Image.new(); image.load_svg_from_string(svg)
		textures[key]=ImageTexture.create_from_image(image)
	var result:=StyleBoxTexture.new()
	result.texture=textures[key]
	for side in [SIDE_LEFT,SIDE_RIGHT]: result.set_texture_margin(side,12); result.set_content_margin(side,12)
	for side in [SIDE_TOP,SIDE_BOTTOM]: result.set_texture_margin(side,9); result.set_content_margin(side,8)
	return result

static func sync(node: Node) -> void:
	if node is Window or node is Control:
		if int(node.get_meta("regal_theme_revision",-1))!=revision:
			node.theme=Hearth20Design.theme()
			node.set_meta("regal_theme_revision",revision)
	if node is Control:
		for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color","icon_normal_color","icon_hover_color","icon_pressed_color"]:
			if not node.has_theme_color_override(key): continue
			var current: Color=node.get_theme_color(key)
			var last: Color=node.get_meta("regal_last_"+key,Color(-1,-1,-1,-1))
			if current!=last: node.set_meta("regal_raw_"+key,current)
			var color:=resolve(node.get_meta("regal_raw_"+key,current))
			node.add_theme_color_override(key,color); node.set_meta("regal_last_"+key,color)
		for key in ["panel","normal","hover","pressed","focus","selected","tab_selected","tab_hovered","tab_unselected"]:
			if not node.has_theme_stylebox_override(key): continue
			var style: StyleBox=node.get_theme_stylebox(key)
			if not style is StyleBoxFlat: continue
			if not style.has_meta("regal_raw"): style.set_meta("regal_raw",[style.bg_color,style.border_color])
			var raw: Array=style.get_meta("regal_raw")
			style.bg_color=resolve(raw[0]); style.border_color=resolve(raw[1])
		if node is ColorRect:
			if not node.has_meta("regal_raw_color"): node.set_meta("regal_raw_color",node.color)
			node.color=resolve(node.get_meta("regal_raw_color"))
		if node is Button and int(node.get_meta("regal_button_revision",-1))!=revision:
			var primary: bool=node.get_meta("h20_primary",false)
			for state in ["normal","hover","pressed"]: node.add_theme_stylebox_override(state,button_style(state,primary))
			node.set_meta("regal_button_revision",revision)
		if node is CanvasItem and node.modulate!=Color.WHITE:
			if not node.has_meta("regal_raw_modulate"): node.set_meta("regal_raw_modulate",node.modulate)
			node.modulate=resolve(node.get_meta("regal_raw_modulate"))
	for child in node.get_children(): sync(child)

class ThemeMedallion extends BaseButton:
	var hover:=0.0
	func _ready() -> void:
		custom_minimum_size=Vector2(54,54); size_flags_vertical=Control.SIZE_SHRINK_CENTER
		focus_mode=Control.FOCUS_ALL
		pressed.connect(func(): Hearth20Regal.toggle(); Hearth20Regal.sync(get_tree().root); get_tree().call_group("hearth20_themed","queue_redraw"))
	func _process(delta: float) -> void:
		hover=lerpf(hover,1.0 if is_hovered() or has_focus() else 0.0,delta*12)
		tooltip_text="Return to regal black" if Hearth20Regal.light_mode else "Switch to parchment light"
		queue_redraw()
	func _draw() -> void:
		var center:=size*0.5
		var gold:=Hearth20Regal.swatch(Hearth20Regal.GOLD)
		var bg:=Hearth20Regal.swatch(Hearth20Regal.SURFACE)
		draw_circle(center+Vector2(0,2),23,Color(0,0,0,.25))
		var points:=PackedVector2Array()
		for i in 32: points.append(center+Vector2.from_angle(float(i)*TAU/32)*(24.0 if i%2==0 else 21.5))
		draw_colored_polygon(points,bg); points.append(points[0]); draw_polyline(points,Color(gold,0.8+hover*.2),1.2,true)
		draw_arc(center,19,0,TAU,72,Color(gold,.5),.8,true)
		draw_arc(center,16,0,TAU,72,Color(gold,.22+hover*.4),.7,true)
		for i in 8:
			var d:=Vector2.from_angle(float(i)*TAU/8)
			var t:=d.orthogonal()
			draw_colored_polygon(PackedVector2Array([center+d*23,center+d*20+t*1.8,center+d*17.5,center+d*20-t*1.8]),gold)
		if Hearth20Regal.light_mode:
			draw_circle(center,8,gold); draw_circle(center+Vector2(4,-3),7,bg)
		else:
			draw_circle(center,5.5,gold)
			for i in 8:
				var d:=Vector2.from_angle(float(i)*TAU/8)
				draw_line(center+d*8,center+d*11,gold,1.3,true)

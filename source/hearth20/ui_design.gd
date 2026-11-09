extends RefCounted
class_name Hearth20Design
## Original native visual system: midnight surfaces, brass accents, crisp vector icons.
const BG := Color("#0b0e15")
const SURFACE := Color("#131925")
const RAISED := Color("#1a2230")
const BORDER := Color("#2b3545")
const INK := Color("#edf0f6")
const MUTED := Color("#9ba6b9")
const GOLD := Color("#ddbd82")
const TEAL := Color("#80cbbf")
static var icons: Dictionary = {}
static var fonts: Dictionary = {}
static var theme_cache: Theme
static var theme_revision:=-1

static func popup_window(window: Window) -> void:
	var available=window.get_tree().root.size-Vector2i(32,64)
	available=Vector2i(maxi(320,available.x),maxi(240,available.y))
	window.min_size=window.min_size.min(available)
	window.popup_centered(window.size.min(available))

static func track_number(input: SpinBox) -> void:
	input.get_line_edit().text_changed.connect(func(text):input.set_meta("number_draft",text))
	input.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:input.remove_meta("number_draft"))

static func commit_numbers(inputs: Array) -> Dictionary:
	for input in inputs:
		if not is_instance_valid(input) or not input is SpinBox or not input.editable or not input.visible:continue
		if not input.has_meta("number_draft"):continue
		var text=str(input.get_meta("number_draft")).strip_edges()
		text=text.trim_prefix(input.prefix.strip_edges()).strip_edges()
		text=text.trim_suffix(input.suffix.strip_edges()).strip_edges()
		var expression=Expression.new()
		var error="Enter a finite number between %s and %s." % [input.min_value,input.max_value]
		if text.is_empty() or text.length()>128:return {"ok":false,"error":error}
		for exponent in RegEx.create_from_string("[eE]([+-]?[0-9]+)").search_all(text):
			if exponent.get_string(1).length()>4 or absi(exponent.get_string(1).to_int())>100:return {"ok":false,"error":error}
		if expression.parse(TextServerManager.get_primary_interface().parse_number(text.replace(";",",")))!=OK:
			return {"ok":false,"error":error}
		var value=expression.execute([],null,false,true)
		if expression.has_execute_failed() or typeof(value) not in [TYPE_INT,TYPE_FLOAT]:return {"ok":false,"error":error}
		if not is_finite(float(value)) or value<input.min_value or value>input.max_value:return {"ok":false,"error":error}
		if input.step>=1 and float(value)!=floor(float(value)):return {"ok":false,"error":"Enter a whole number."}
		# Commit before the caller reads value. Native focus-loss commits are deferred.
		input.get_line_edit().text=str(value)
		input.apply()
		input.remove_meta("number_draft")
	return {"ok":true}

static func font(heading: bool = false) -> Font:
	var key := "heading" if heading else "body"
	if not fonts.has(key):
		var result := SystemFont.new()
		result.font_names = PackedStringArray(["Georgia", "DejaVu Serif"]) if heading else PackedStringArray(["Segoe UI", "Inter", "DejaVu Sans"])
		fonts[key] = result
	return fonts[key]

static func panel(fill: Color = SURFACE, radius: int = 14, padding: int = 14, border: Color = BORDER, shadow: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Hearth20Regal.resolve(fill)
	style.border_color = Hearth20Regal.resolve(border)
	style.set_meta("regal_raw",[fill,border])
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.anti_aliasing = true
	if shadow:
		style.shadow_color = Color(0,0,0,0.28)
		style.shadow_size = 10
		style.shadow_offset = Vector2(0,4)
	return style

static func icon(name_value: String, pixels: int = 20) -> Texture2D:
	var key := name_value + str(pixels)
	if icons.has(key): return icons[key]
	var paths := {
		"select":'<path d="M5 3l14 10-7 1-3 7z"/><path d="M12 14l4 6"/>',
		"draw":'<path d="M4 20l4-1 12-12-4-4L4 15zM13 6l4 4M4 15l4 4"/>',
		"text":'<path d="M4 6V4h16v2M12 4v16M8 20h8"/>',
		"measure":'<path d="M3 16L16 3l5 5L8 21zM7 12l3 3M10 9l2 2M13 6l3 3"/>',
		"dice":'<path d="M12 2l9 6v9l-9 5-9-5V8zM3 8l9 5 9-5M12 13v9M12 2v11M3 17l9-4 9 4"/>',
		"casino":'<path d="M3 7l10-4 5 14-10 4zM8 5h13v15H9M12 10l3 3-3 3-3-3z"/>',
		"fx":'<path d="M4 20L17 7M14 6l4 4M7 3v4M5 5h4M18 15v6M15 18h6M20 2v3M18.5 3.5h3"/>',
		"beacon":'<path d="M12 21s7-6 7-12a7 7 0 10-14 0c0 6 7 12 7 12z"/><circle cx="12" cy="9" r="2.5"/>',
		"mask":'<path d="M3 7c4 0 5-3 9-3s5 3 9 3v7c0 4-5 6-9 7-4-1-9-3-9-7zM7 10l3 2M17 10l-3 2M9 16h6"/>',
		"lighting":'<circle cx="12" cy="11" r="5"/><path d="M9 16v4h6v-4M12 1v2M3 11H1M23 11h-2M4 3l2 2M20 3l-2 2"/>',
		"layers":'<path d="M2 8l10-5 10 5-10 5zM3 13l9 5 9-5M3 18l9 5 9-5"/>',
		"sheet":'<path d="M6 3h9l4 4v14H6zM14 3v5h5M9 12h7M9 16h5"/>',
		"chat":'<path d="M4 4h16v12H9l-5 4zM8 8h8M8 12h5"/>',
		"journal":'<path d="M4 4h6l2 2 2-2h6v16h-6l-2 1-2-1H4zM12 6v15"/>',
		"save":'<path d="M4 3h14l3 3v15H3V3zM7 3v6h10V3M7 21v-8h10v8"/>',
		"open":'<path d="M3 19V5h7l3 3h8v11zM3 10h18l-3 9H3"/>',
		"search":'<circle cx="10" cy="10" r="6"/><path d="M15 15l6 6"/>',
		"panel":'<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M15 4v16M18 8h0M18 12h0"/>',
		"connect":'<circle cx="7" cy="7" r="3"/><circle cx="17" cy="7" r="3"/><path d="M2 21v-4a5 5 0 0110 0v4M14 13a5 5 0 018 4v4"/>',
		"fit":'<path d="M3 9V3h6M15 3h6v6M21 15v6h-6M9 21H3v-6M8 8h8v8H8z"/>',
		"plus":'<path d="M12 5v14M5 12h14"/>',
		"minus":'<path d="M5 12h14"/>',
		"close":'<path d="M6 6l12 12M18 6L6 18"/>',
		"undo":'<path d="M4 10h10a6 6 0 010 12M4 10l5-5M4 10l5 5"/>',
		"grid":'<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 3v18M15 3v18M3 9h18M3 15h18"/>',
		"line":'<path d="M4 20L20 4"/><circle cx="4" cy="20" r="2"/><circle cx="20" cy="4" r="2"/>',
		"freehand":'<path d="M3 17C7 3 12 1 12 7S5 24 15 15s8-6 6 3"/>',
		"rectangle":'<rect x="3" y="5" width="18" height="14" rx="1"/>',
		"square":'<rect x="4" y="4" width="16" height="16" rx="1"/>',
		"ellipse":'<ellipse cx="12" cy="12" rx="10" ry="7"/>',
		"circle":'<circle cx="12" cy="12" r="9"/>',
		"cone":'<path d="M3 12L20 3a19 19 0 010 18z"/>',
		"beam":'<path d="M3 7h18v10H3zM3 12h18"/>',
		"map":'<path d="M3 5l6-2 6 3 6-2v16l-6 2-6-3-6 2zM9 3v16M15 6v16"/>',
		"gm":'<path d="M3 9l4 4 5-9 5 9 4-4-2 11H5z"/>',
		"foreground":'<path d="M3 18l6-9 4 5 3-7 5 11z"/><circle cx="7" cy="5" r="2"/>',
		"tokens":'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="9" r="3"/><path d="M6 18a6 6 0 0112 0"/>',
		"light":'<path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2"/><circle cx="12" cy="12" r="5"/>',
		"crest":'<path d="M12 1l9 5v12l-9 5-9-5V6zM7 17V8l5 3 5-3v9M7 13h10"/>',
		"die4":'<path d="M12 2L23 21H1zM12 2v12L1 21M12 14l11 7"/>',
		"die6":'<rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="8" cy="8" r="1"/><circle cx="16" cy="8" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="8" cy="16" r="1"/><circle cx="16" cy="16" r="1"/>',
		"die8":'<path d="M12 1l10 11-10 11L2 12zM2 12l10 3 10-3M12 1v14"/>',
		"die10":'<path d="M12 1l10 10-4 9-6 3-6-3-4-9zM12 1L7 13l5 10 5-10zM2 11l5 2M22 11l-5 2"/>',
		"die12":'<path d="M7 2h10l6 10-6 10H7L1 12zM12 6l6 5-2 7H8l-2-7zM7 2l5 4 5-4M1 12l5-1M23 12l-5-1M7 22l1-4M17 22l-1-4"/>',
		"die20":'<path d="M12 1l10 6v11l-10 5-10-5V7zM12 1L6 16h12zM2 7l4 9-4 2M22 7l-4 9 4 2M6 16l6 7 6-7"/>',
		"die100":'<circle cx="12" cy="12" r="10"/><path d="M7 18L17 6"/><circle cx="7.5" cy="7.5" r="2"/><circle cx="16.5" cy="16.5" r="2"/>',
	}
	var body: String = paths.get(name_value, paths.dice)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [pixels*2,pixels*2,body]
	var bitmap := Image.new()
	if bitmap.load_svg_from_string(svg) != OK: return null
	var texture := ImageTexture.create_from_image(bitmap)
	icons[key] = texture
	return texture

static func theme() -> Theme:
	if theme_cache!=null and theme_revision==Hearth20Regal.revision: return theme_cache
	var result := Theme.new()
	result.default_font = font()
	result.default_font_size = 14
	for type_name in ["Label","Button","LineEdit","TextEdit","OptionButton","SpinBox","CheckButton","CheckBox","RichTextLabel","TabBar"]:
		result.set_color("font_color",type_name,INK)
		result.set_color("font_hover_color",type_name,Color.WHITE)
		result.set_color("font_pressed_color",type_name,GOLD)
		result.set_color("font_disabled_color",type_name,Color("#596375"))
		result.set_color("font_focus_color",type_name,INK)
	result.set_color("font_placeholder_color","LineEdit",Color("#748198"))
	result.set_color("font_placeholder_color","TextEdit",Color("#748198"))
	for variant in ["Button","OptionButton","CheckButton"]:
		result.set_stylebox("normal",variant,panel(Color("#1b2331"),8,9,Color("#303b4d")))
		result.set_stylebox("hover",variant,panel(Color("#283248"),8,9,Color("#596274")))
		result.set_stylebox("pressed",variant,panel(Color("#363124"),8,9,Color("#957c50")))
		result.set_stylebox("disabled",variant,panel(Color("#111722"),8,9,Color("#222b3a")))
		result.set_stylebox("focus",variant,panel(Color(0,0,0,0),8,0,TEAL))
		result.set_color("icon_normal_color",variant,MUTED)
		result.set_color("icon_hover_color",variant,GOLD)
		result.set_color("icon_pressed_color",variant,GOLD)
	result.set_type_variation("QuietButton","Button")
	result.set_type_variation("RailButton","Button")
	result.set_type_variation("ChoiceButton","Button")
	for variant in ["QuietButton","RailButton"]:
		result.set_stylebox("normal",variant,panel(Color(0,0,0,0),9,7,Color(0,0,0,0)))
		result.set_stylebox("hover",variant,panel(Color("#232d40"),9,7,Color("#38465d")))
		result.set_stylebox("pressed",variant,panel(Color("#3a3327"),9,7,Color("#9a8050")))
	for type_name in ["LineEdit","TextEdit","SpinBox"]:
		result.set_stylebox("normal",type_name,panel(Color("#0e1420"),7,9,Color("#303b4d")))
		result.set_stylebox("focus",type_name,panel(Color("#111a27"),7,9,Color("#9a8050")))
		result.set_color("selection_color",type_name,Color("#456b75"))
	result.set_stylebox("panel","PanelContainer",panel())
	result.set_stylebox("panel","AcceptDialog",panel(SURFACE,10,18,GOLD,true))
	result.set_stylebox("panel","ItemList",panel(BG,8,12,BORDER))
	result.set_stylebox("selected","ItemList",panel(RAISED,6,6,GOLD))
	result.set_stylebox("selected_focus","ItemList",panel(RAISED,6,6,GOLD))
	result.set_color("font_color","ItemList",INK)
	result.set_color("font_selected_color","ItemList",GOLD)
	result.set_stylebox("panel","TabContainer",panel(SURFACE,14,14,BORDER,true))
	for type_name in ["TabContainer","TabBar"]:
		result.set_font_size("font_size",type_name,12)
		result.set_stylebox("tab_selected",type_name,panel(Color("#222b3b"),7,9,Color("#605844")))
		result.set_stylebox("tab_unselected",type_name,panel(Color(0,0,0,0),7,9,Color(0,0,0,0)))
		result.set_stylebox("tab_hovered",type_name,panel(Color("#1e2737"),7,9,BORDER))
		result.set_color("font_selected_color",type_name,GOLD)
		result.set_color("font_unselected_color",type_name,MUTED)
		result.set_constant("h_separation",type_name,3)
	var empty := StyleBoxEmpty.new()
	result.set_stylebox("scroll","VScrollBar",empty)
	result.set_stylebox("grabber","VScrollBar",panel(Color("#3a465c"),3,0,Color(0,0,0,0)))
	result.set_stylebox("grabber_highlight","VScrollBar",panel(Color("#756b56"),3,0,Color(0,0,0,0)))
	result.set_constant("scrollbar_width","VScrollBar",5)
	result.set_stylebox("panel","TooltipPanel",panel(Color("#252f40"),8,10,Color("#66718a"),true))
	result.set_color("font_color","TooltipLabel",INK)
	result.set_font_size("font_size","TooltipLabel",12)
	for type_name in result.get_type_list():
		for key in result.get_color_list(type_name):
			var value: Color=result.get_color(key,type_name)
			result.set_color(key,type_name,Hearth20Regal.swatch(Hearth20Regal.INK) if value==Color.WHITE and key.begins_with("font") else Hearth20Regal.resolve(value))
	for kind in ["Button","OptionButton","CheckButton","QuietButton","RailButton","ChoiceButton"]:
		for state in ["normal","hover","pressed"]: result.set_stylebox(state,kind,Hearth20Regal.button_style(state))
	for kind in ["HSlider","VSlider"]:
		result.set_stylebox("slider",kind,panel(Color("#131925"),3,3,Color("#605844")))
		result.set_stylebox("grabber_area",kind,panel(GOLD,3,3,GOLD))
		result.set_stylebox("grabber_area_highlight",kind,panel(GOLD,3,3,GOLD))
		var bitmap:=Image.new()
		bitmap.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="26" viewBox="0 0 20 26"><path d="M10 1L18 13L10 25L2 13Z" fill="#1d180f" stroke="#d9b76b" stroke-width="1.5"/><path d="M10 6L14 13L10 20L6 13Z" fill="#ddbd82"/><path d="M10 8V18" stroke="#fff0c2" stroke-width="1"/></svg>')
		var thumb:=ImageTexture.create_from_image(bitmap)
		for state in ["grabber","grabber_highlight","grabber_disabled"]: result.set_icon(state,kind,thumb)
	theme_cache=result; theme_revision=Hearth20Regal.revision
	return result

static func primary(button: Button) -> void:
	button.set_meta("h20_primary",true)
	for state in ["normal","hover","pressed"]: button.add_theme_stylebox_override(state,Hearth20Regal.button_style(state,true))
	for key in ["font_color","font_hover_color","font_pressed_color","icon_normal_color","icon_hover_color","icon_pressed_color"]: button.add_theme_color_override(key,Color("#211c14"))

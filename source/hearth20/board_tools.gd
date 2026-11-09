extends RefCounted
class_name Hearth20BoardTools
## Bounded, data-only tabletop geometry shared by rendering and host validation.
const LAYERS := ["map", "tokens", "gm", "foreground", "light"]
const SHAPES := ["line", "square", "circle", "cone", "beam"]
const EFFECTS := ["beam", "bomb", "breath", "bubbling", "burn", "burst", "explode", "glow", "missile", "nova", "pooling", "rocket", "shield", "sparkle", "splatter"]
const COLORS := {"Fire":"#ff682b", "Charm":"#f05cba", "Acid":"#9ce537", "Death":"#9773ca", "Holy":"#ffe09a", "Blood":"#b51f42", "Frost":"#91e5ff", "Slime":"#39c77d", "Smoke":"#a7acb9", "Water":"#448bff", "Magic":"#ac84ff"}
const CAST_EFFECTS := ["beam","breath","missile","rocket"]

static func fx_material(settings: Dictionary) -> String:
	if settings.get("material","") in COLORS: return str(settings.material)
	var tint:=Color(str(settings.get("color","#ff682b"))).to_html(false)
	for key in COLORS:
		if Color(str(COLORS[key])).to_html(false)==tint: return str(key)
	return "Fire"

static func point_ok(p: Variant, scene: Dictionary) -> bool:
	return Hearth20Contracts.finite_point(p) and Hearth20Contracts._point_inside_scene(p, scene)

static func valid_object(o: Variant, scene: Dictionary) -> bool:
	if not o is Dictionary or o.size() > 40 or var_to_bytes(o).size() > 48000:
		return false
	if o.get("kind", "") not in ["freehand", "line", "rectangle", "ellipse", "text", "beacon", "wall", "window", "door", "light"] or o.get("layer", "tokens") not in LAYERS:
		return false
	if not o.get("points") is Array or o.points.is_empty() or o.points.size() > 512:
		return false
	for p in o.points:
		if not point_ok(p, scene): return false
	for field in ["color", "fill", "border_color"]:
		if not o.get(field, "#00000000") is String or not Color.html_is_valid(o.get(field, "#00000000")): return false
	for field in ["width", "font_size", "bright", "dim", "opacity"]:
		var v: Variant = o.get(field, 1.0)
		if not Hearth20Contracts._finite_number(v) or float(v) < 0 or float(v) > (1000 if field in ["bright", "dim"] else 144 if field == "font_size" else 24 if field == "width" else 1): return false
	if not o.get("text", "") is String or str(o.get("text", "")).length() > 2000 or o.get("font", "Sans") not in ["Sans", "Serif", "Mono"]: return false
	for field in ["bold", "italic", "border", "open", "enabled"]:
		if not o.get(field, false) is bool: return false
	if o.kind=="light" and not Hearth20Lighting.valid_source(o): return false
	return true

static func valid_measure(m: Variant, scene: Dictionary) -> bool:
	if not m is Dictionary or m.size() > 14 or var_to_bytes(m).size() > 8192: return false
	if m.get("shape", "line") not in SHAPES or m.get("origin", "center") not in ["center", "edge", "corner"] or m.get("snap", "none") not in ["none", "center", "corner"] or m.get("distance", "euclidean") not in ["euclidean", "grid", "alternating", "manhattan"]: return false
	if not m.get("points") is Array or m.points.size() < 2 or m.points.size() > 64: return false
	for p in m.points:
		if not point_ok(p, scene): return false
	if m.get("angle", 60) not in [45, 60, 90] or m.get("beam_width", 5) not in [5, 10, 15]: return false
	if not m.get("round", true) is bool or not m.get("linger", false) is bool: return false
	return m.get("color", "#76e0ca") is String and Color.html_is_valid(m.get("color", "#76e0ca"))

static func polygon(m: Dictionary, feet: float) -> PackedVector2Array:
	var a: Vector2 = m.points[0]
	var b: Vector2 = m.points.back()
	var delta := b - a
	var length := delta.length()
	var points := PackedVector2Array()
	match str(m.get("shape", "line")):
		"square":
			var side := maxf(absf(delta.x), absf(delta.y))
			var origin := str(m.get("origin", "center"))
			var low := a - Vector2.ONE * side
			var high := a + Vector2.ONE * side
			if origin == "corner":
				low = a.min(a + Vector2(signf(delta.x), signf(delta.y)) * side)
				high = a.max(a + Vector2(signf(delta.x), signf(delta.y)) * side)
			elif origin == "edge":
				if absf(delta.x) >= absf(delta.y):
					low = Vector2(minf(a.x, b.x), a.y - side * 0.5)
				else: low = Vector2(a.x - side * 0.5, minf(a.y, b.y))
				high = low + Vector2.ONE * side
			points = PackedVector2Array([low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)])
		"circle":
			var center := (a + b) * 0.5 if m.get("origin", "center") == "edge" else a
			var radius := length * (0.5 if m.get("origin", "center") == "edge" else 1.0)
			for i in 80: points.append(center + Vector2.from_angle(float(i) / 80.0 * TAU) * radius)
		"cone":
			var half := deg_to_rad(float(m.get("angle", 60))) * 0.5
			var direction := delta.angle()
			points.append(a)
			if bool(m.get("round", true)):
				for i in 41: points.append(a + Vector2.from_angle(direction - half + half * 2.0 * float(i) / 40.0) * length)
			else:
				var side := delta.normalized().orthogonal() * length * tan(half)
				points.append(b + side)
				points.append(b - side)
		"beam":
			var side := delta.normalized().orthogonal() * float(m.get("beam_width", 5)) / maxf(0.01, feet) * 0.5
			points = PackedVector2Array([a + side, b + side, b - side, a - side])
	return points

static func distance(m: Dictionary, feet: float) -> float:
	var result := 0.0
	var diagonals := 0.0
	for i in range(1, m.points.size()):
		var d: Vector2 = (m.points[i] - m.points[i - 1]).abs()
		match str(m.get("distance", "euclidean")):
			"grid": result += maxf(d.x, d.y)
			"manhattan": result += d.x + d.y
			"alternating":
				result += maxf(d.x, d.y)
				diagonals += minf(d.x, d.y)
			_: result += d.length()
	return (result + floorf(diagonals * 0.5)) * feet

static func bounds(o: Dictionary) -> Rect2:
	var rect := Rect2(o.points[0], Vector2.ZERO)
	for p in o.points: rect = rect.expand(p)
	return rect.grow(0.015)

static func object_visible(o: Dictionary, sight: Dictionary) -> bool:
	if o.get("layer", "tokens") in ["gm", "light"]: return false
	if o.get("kind", "") == "beacon": return true
	return area_visible(bounds(o), sight)

static func area_visible(rect: Rect2, sight: Dictionary) -> bool:
	if bool(sight.get("blackout", false)): return false
	var d := float(sight.subdivisions)
	for y in range(floori(rect.position.y * d), ceili(rect.end.y * d) + 1):
		for x in range(floori(rect.position.x * d), ceili(rect.end.x * d) + 1):
			if x < 0 or y < 0 or x >= int(sight.columns) or y >= int(sight.rows) or int(sight.levels[y * int(sight.columns) + x]) == 0: return false
	return true

static func measure_visible(m: Dictionary, sight: Dictionary) -> bool:
	var poly := polygon(m, float(sight.feet))
	if not poly.is_empty():
		return area_visible(Rect2(poly[0], Vector2.ZERO).expand(poly[0]).merge(_polygon_bounds(poly)), sight)
	for i in range(1, m.points.size()):
		if not Hearth20Vision.segment_visible(m.points[i-1], m.points[i], sight): return false
	return true

static func _polygon_bounds(poly: PackedVector2Array) -> Rect2:
	var rect := Rect2(poly[0], Vector2.ZERO)
	for p in poly: rect = rect.expand(p)
	return rect

static func subtract(rect: Rect2, cut: Rect2) -> Array:
	var overlap := rect.intersection(cut)
	if overlap.size.x <= 0 or overlap.size.y <= 0: return [rect]
	var result: Array = []
	for part in [Rect2(rect.position, Vector2(rect.size.x, overlap.position.y - rect.position.y)), Rect2(Vector2(rect.position.x, overlap.end.y), Vector2(rect.size.x, rect.end.y - overlap.end.y)), Rect2(Vector2(rect.position.x, overlap.position.y), Vector2(overlap.position.x - rect.position.x, overlap.size.y)), Rect2(Vector2(overlap.end.x, overlap.position.y), Vector2(rect.end.x - overlap.end.x, overlap.size.y))]:
		if part.size.x > 0.0001 and part.size.y > 0.0001: result.append(part)
	return result

static func darkvision(actor: Dictionary) -> float:
	var explicit: Dictionary = actor.get("vision", {}) if actor.get("vision", {}) is Dictionary else {}
	if explicit.has("darkvision_feet") and bool(explicit.get("darkvision_override",true)): return float(explicit.darkvision_feet)
	var regex := RegEx.new()
	regex.compile("(?i)darkvision[^0-9]{0,24}([0-9]{1,3})")
	var found := regex.search(str(actor.get("senses", "")) + " " + str(actor.get("features", "")))
	return float(found.get_string(1)) if found else 0.0

static func barriers(o: Dictionary) -> Array:
	var result: Array = []
	if bool(o.get("open",false)) or (o.get("layer","tokens") != "light" and o.get("kind","") not in ["wall","window","door"]): return result
	if o.kind in ["text","light","beacon"]: return result
	var points: Array = o.points.duplicate()
	if o.kind in ["rectangle","ellipse"] and points.size() > 1:
		var rect := Rect2(points[0],Vector2.ZERO).expand(points[-1])
		points = [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y),rect.position]
		if o.kind == "ellipse":
			points=[]
			for i in 65: points.append(rect.get_center()+Vector2.from_angle(float(i)/64*TAU)*rect.size*0.5)
	for i in range(1,points.size()): result.append([points[i-1],points[i]])
	return result

static func valid_fx_settings(settings: Variant) -> bool:
	if not settings is Dictionary or settings.size()>8 or settings.get("effect","") not in EFFECTS or not settings.get("color","") is String or not Color.html_is_valid(settings.color): return false
	if settings.has("material") and settings.material not in COLORS: return false
	for field in ["size","duration","density"]:
		if not Hearth20Contracts._finite_number(settings.get(field)): return false
	return float(settings.size)>=0.25 and float(settings.size)<=4 and float(settings.duration)>=0.3 and float(settings.duration)<=8 and int(settings.density)>=8 and int(settings.density)<=128

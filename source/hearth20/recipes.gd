extends RefCounted
class_name Hearth20Recipes
## Port of the offline, bounded scene-recipe vocabulary into a Godot data contract.

const MAX_ROOMS := 20
const MAX_PROPS := 100
const MAX_SIDE := 128
const MAX_TEXT := 4000
const MAX_JSON_BYTES := Hearth20Contracts.MAX_RECIPE_JSON_BYTES
const MAX_JSON_NODES := Hearth20Contracts.MAX_RECIPE_JSON_NODES
const MAX_JSON_DEPTH := Hearth20Contracts.MAX_RECIPE_JSON_DEPTH
const ROOT_KEYS := ["schema_version", "title", "prompt", "pattern", "grid", "rooms", "corridors", "props", "gm_only", "unresolved_requests", "provenance"]
const GRID_KEYS := ["width_cells", "height_cells", "feet_per_cell", "coordinate_unit"]
const ROOM_KEYS := ["id", "kind", "public_label", "grid", "initially_visible"]
const ROOM_GRID_KEYS := ["x", "y", "width", "height"]
const CORRIDOR_KEYS := ["id", "room_ids", "grid", "width_cells", "orientation"]
const PROP_KEYS := ["id", "kind", "label", "room_id", "position", "visibility", "gm_details"]
const POSITION_KEYS := ["x", "y"]
const PROP_KINDS := ["campfire", "tent", "hidden_cache", "trap", "pillar", "pew", "altar", "torch", "well", "bridge"]

static func _integer_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floorf(float(value)) == float(value)

static func _only_keys(value: Variant, allowed: Array) -> bool:
	if not value is Dictionary:
		return false
	for key in value:
		if not key is String or not allowed.has(key):
			return false
	return true

static func _json_only(value: Variant, depth: int, budget: Dictionary) -> bool:
	budget.nodes = int(budget.get("nodes", 0)) + 1
	if depth > MAX_JSON_DEPTH or int(budget.nodes) > MAX_JSON_NODES:
		return false
	if value == null or value is bool or value is String or value is int:
		return not value is String or value.length() <= MAX_TEXT
	if value is float:
		return is_finite(value)
	if value is Array:
		for item in value:
			if not _json_only(item, depth + 1, budget):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not key is String or key.length() > 128 or not _json_only(value[key], depth + 1, budget):
				return false
		return true
	return false

static func _preflight_json_text(text: String) -> Dictionary:
	var encoded_size := text.to_utf8_buffer().size()
	if encoded_size > MAX_JSON_BYTES:
		return {"ok": false, "error": "Recipe exceeds the %d-byte encoded data limit." % MAX_JSON_BYTES}
	var depth := 0
	var nodes := 0
	var in_string := false
	var escaped := false
	var index := 0
	while index < text.length():
		var character := text.substr(index, 1)
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == "\"":
				in_string = false
			index += 1
			continue
		if character == "\"":
			in_string = true
			nodes += 1 # Count keys and values conservatively before JSON parsing.
			if nodes > MAX_JSON_NODES:
				return {"ok": false, "error": "Recipe exceeds the maximum of %d JSON nodes." % MAX_JSON_NODES}
		elif character == "{" or character == "[":
			depth += 1
			nodes += 1
			if depth > MAX_JSON_DEPTH:
				return {"ok": false, "error": "Recipe exceeds the maximum nesting depth of %d." % MAX_JSON_DEPTH}
		elif character == "}" or character == "]":
			depth -= 1
			if depth < 0:
				return {"ok": false, "error": "Recipe has an unmatched closing delimiter before JSON parsing."}
		elif character not in [",", ":", " ", "\t", "\r", "\n"]:
			nodes += 1
			while index < text.length():
				var primitive_character := text.substr(index, 1)
				if primitive_character in [",", ":", "]", "}", " ", "\t", "\r", "\n"]:
					break
				index += 1
			# Leave the delimiter for the outer scanner so closing brackets update depth.
			index -= 1
		if nodes > MAX_JSON_NODES:
			return {"ok": false, "error": "Recipe exceeds the maximum of %d JSON nodes." % MAX_JSON_NODES}
		index += 1
	if depth != 0:
		return {"ok": false, "error": "Recipe has unclosed JSON containers before parsing."}
	return {"ok": true}

static func parse_bounded_json(text: String) -> Dictionary:
	var preflight := _preflight_json_text(text)
	if not preflight.ok:
		return {"ok": false, "errors": [preflight.error]}
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		return {"ok": false, "errors": ["Invalid recipe JSON: %s" % parser.get_error_message()]}
	var checked := validate(parser.data)
	if not checked.ok:
		return {"ok": false, "errors": checked.errors}
	return {"ok": true, "recipe": parser.data}

static func _validate_grid_bounds(value: Variant, max_x: int, max_y: int, min_size: int) -> bool:
	if not _only_keys(value, ROOM_GRID_KEYS) or not ["x", "y", "width", "height"].all(func(key): return _integer_number(value.get(key, null))):
		return false
	return int(value.x) >= 0 and int(value.y) >= 0 and int(value.width) >= min_size and int(value.height) >= min_size and int(value.x + value.width) <= max_x and int(value.y + value.height) <= max_y

static func author(prompt: String, seed: int = 1) -> Dictionary:
	return Hearth20Contracts.author_recipe(prompt, seed)

static func validate(recipe: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not recipe is Dictionary:
		return {"ok": false, "errors": ["Recipe must be a JSON object."]}
	var json_budget := {"nodes": 0}
	if not _json_only(recipe, 0, json_budget):
		return {"ok": false, "errors": ["Recipe must be bounded JSON data (maximum %d nodes and depth %d)." % [MAX_JSON_NODES, MAX_JSON_DEPTH]]}
	if JSON.stringify(recipe).to_utf8_buffer().size() > MAX_JSON_BYTES:
		return {"ok": false, "errors": ["Recipe exceeds the %d-byte encoded data limit." % MAX_JSON_BYTES]}
	if not _only_keys(recipe, ROOT_KEYS):
		errors.append("Recipe contains an unsupported root field.")
	if not _integer_number(recipe.get("schema_version", null)) or int(recipe.get("schema_version", 0)) != 1:
		errors.append("Unsupported recipe schema version.")
	if not recipe.get("title", null) is String or not recipe.get("prompt", null) is String or str(recipe.get("title", "")).length() > 96 or str(recipe.get("prompt", "")).length() > MAX_TEXT:
		errors.append("Recipe title or prompt exceeds the text limit.")
	if not recipe.get("pattern", null) is String or not Hearth20Contracts.RECIPE_PATTERNS.has(str(recipe.get("pattern", ""))):
		errors.append("Recipe pattern is not supported.")
	var grid: Variant = recipe.get("grid", null)
	if not _only_keys(grid, GRID_KEYS) or not _integer_number(grid.get("width_cells", null)) or not _integer_number(grid.get("height_cells", null)):
		errors.append("Recipe grid dimensions are missing.")
	else:
		if int(grid.width_cells) < 1 or int(grid.width_cells) > MAX_SIDE or int(grid.height_cells) < 1 or int(grid.height_cells) > MAX_SIDE:
			errors.append("Recipe grid must be 1 to 128 cells per side.")
		if not _integer_number(grid.get("feet_per_cell", null)) and not (grid.get("feet_per_cell", null) is float and is_finite(float(grid.feet_per_cell))):
			errors.append("Recipe grid scale must be a finite number.")
		elif float(grid.get("feet_per_cell", 0)) <= 0.0 or float(grid.get("feet_per_cell", 0)) > 1000.0:
			errors.append("Recipe grid scale is invalid.")
		if grid.get("coordinate_unit", "grid_cells") != "grid_cells":
			errors.append("Recipe coordinates must use grid_cells.")
	var rooms: Variant = recipe.get("rooms", null)
	var corridors: Variant = recipe.get("corridors", null)
	var props: Variant = recipe.get("props", null)
	if not rooms is Array or rooms.is_empty() or rooms.size() > MAX_ROOMS:
		errors.append("Recipe must contain 1 to 20 rooms.")
	if not corridors is Array or corridors.size() > MAX_ROOMS:
		errors.append("Recipe corridor count is invalid.")
	if not props is Array or props.size() > MAX_PROPS:
		errors.append("Recipe prop count exceeds 100.")
	if not errors.is_empty() or not grid is Dictionary:
		return {"ok": false, "errors": errors}
	var room_ids := {}
	var room_records: Dictionary = {}
	var room_bounds: Array[Rect2i] = []
	for room in rooms:
		if not _only_keys(room, ROOM_KEYS) or not Hearth20Contracts.valid_identifier(room.get("id")) or room_ids.has(str(room.get("id"))):
			errors.append("Room identifiers must be valid and unique.")
			continue
		var rect: Variant = room.get("grid", null)
		if not _validate_grid_bounds(rect, int(grid.width_cells), int(grid.height_cells), 2):
			errors.append("Room bounds must be integer grid cells.")
			continue
		if room.has("kind") and (not room.kind is String or not Hearth20Contracts.RECIPE_PATTERNS.has(room.kind)):
			errors.append("Room kind is not supported.")
		if room.has("public_label") and (not room.public_label is String or room.public_label.length() > 80):
			errors.append("Room label exceeds its text limit.")
		if room.has("initially_visible") and not room.initially_visible is bool:
			errors.append("Room visibility must be a boolean.")
		var room_rect := Rect2i(int(rect.x), int(rect.y), int(rect.width), int(rect.height))
		for previous in room_bounds:
			if previous.intersects(room_rect):
				errors.append("Room footprints may not overlap.")
		room_bounds.append(room_rect)
		room_ids[str(room.id)] = true
		room_records[str(room.id)] = room
	var corridor_ids := {}
	for corridor in corridors:
		if not _only_keys(corridor, CORRIDOR_KEYS) or not Hearth20Contracts.valid_identifier(corridor.get("id")) or not corridor.get("room_ids") is Array or corridor.room_ids.size() != 2 or not corridor.room_ids.all(func(room_id): return room_id is String) or str(corridor.room_ids[0]) == str(corridor.room_ids[1]) or not room_ids.has(str(corridor.room_ids[0])) or not room_ids.has(str(corridor.room_ids[1])):
			errors.append("Each corridor must connect two known rooms.")
			continue
		if corridor_ids.has(str(corridor.id)):
			errors.append("Corridor identifiers must be unique.")
			continue
		corridor_ids[str(corridor.id)] = true
		var rect: Variant = corridor.get("grid", null)
		if not _validate_grid_bounds(rect, int(grid.width_cells), int(grid.height_cells), 1):
			errors.append("Corridor bounds must be integer grid cells.")
			continue
		if corridor.has("width_cells") and (not _integer_number(corridor.width_cells) or int(corridor.width_cells) < 1 or int(corridor.width_cells) > 16):
			errors.append("Corridor width is invalid.")
		if corridor.has("orientation") and (not corridor.orientation is String or corridor.orientation != "east-west"):
			errors.append("Only east-west corridors are supported by this recipe renderer.")
	var occupied_cells := {}
	var prop_ids := {}
	for prop in props:
		if not _only_keys(prop, PROP_KEYS) or not Hearth20Contracts.valid_identifier(prop.get("id")) or not PROP_KINDS.has(str(prop.get("kind", ""))) or not prop.get("label", null) is String or prop.label.length() > 80 or not prop.get("room_id", null) is String or not ["public", "gm"].has(str(prop.get("visibility", ""))):
			errors.append("Props must use bounded labels and public or GM visibility.")
			continue
		if prop_ids.has(str(prop.id)):
			errors.append("Prop identifiers must be unique.")
			continue
		prop_ids[str(prop.id)] = true
		var position: Variant = prop.get("position", null)
		if not _only_keys(position, POSITION_KEYS) or not _integer_number(position.get("x", null)) or not _integer_number(position.get("y", null)):
			errors.append("Prop positions must be integer grid cells.")
			continue
		var room_id := str(prop.get("room_id", ""))
		if not room_records.has(room_id):
			errors.append("Prop must name a room from the recipe.")
			continue
		var bounds: Dictionary = room_records[room_id].grid
		if int(position.x) < int(bounds.x) or int(position.y) < int(bounds.y) or int(position.x) >= int(bounds.x + bounds.width) or int(position.y) >= int(bounds.y + bounds.height):
			errors.append("Prop positions must lie inside their named room.")
		var cell_key := "%d,%d" % [int(position.x), int(position.y)]
		if occupied_cells.has(cell_key):
			errors.append("Prop positions must be unique.")
		occupied_cells[cell_key] = true
		if prop.has("gm_details") and (not prop.gm_details is String or prop.gm_details.length() > 1000):
			errors.append("GM details exceed the text limit.")
	if recipe.has("gm_only"):
		var gm_only: Variant = recipe.gm_only
		if not _only_keys(gm_only, ["secrets"]) or not gm_only.get("secrets", null) is Array or not gm_only.secrets.is_empty():
			errors.append("Store secret scene details as bounded GM-only props; unsupported gm_only data is rejected.")
	if recipe.has("provenance"):
		var provenance: Variant = recipe.provenance
		if not _only_keys(provenance, ["generator", "version", "seed"]) or not provenance.get("generator", null) is String or provenance.generator.length() > 80 or not _integer_number(provenance.get("version", null)) or not _integer_number(provenance.get("seed", null)):
			errors.append("Recipe provenance contains unsupported fields or values.")
	var unresolved: Variant = recipe.get("unresolved_requests", [])
	if not unresolved is Array or unresolved.size() > 64:
		errors.append("Unresolved requests must be a list of at most 64 items.")
	else:
		for item in unresolved:
			if not item is String or item.length() > 80:
				errors.append("An unresolved request exceeds its text limit.")
	return {"ok": errors.is_empty(), "errors": errors}

static func apply_to_scene(recipe: Dictionary, scene: Dictionary) -> Dictionary:
	var checked := validate(recipe)
	if not checked.ok:
		return {"ok": false, "errors": checked.errors}
	var grid: Dictionary = recipe.grid
	scene.width_cells = int(grid.width_cells)
	scene.height_cells = int(grid.height_cells)
	scene.feet_per_cell = float(grid.feet_per_cell)
	scene.narrative_recipe = recipe.duplicate(true)
	scene.rooms = recipe.rooms.duplicate(true)
	scene.corridors = recipe.corridors.duplicate(true)
	scene.props = []
	scene.walls = _room_wall_segments(recipe.rooms, recipe.corridors)
	scene.doors = _door_segments(recipe.rooms, recipe.corridors)
	for prop in recipe.props:
		scene.props.append({"id": prop.id, "kind": prop.kind, "label": prop.label, "position": Vector2(float(prop.position.x) + 0.5, float(prop.position.y) + 0.5), "public": prop.visibility == "public", "hidden": prop.visibility != "public", "gm_details": prop.get("gm_details", "")})
	return {"ok": true, "unresolved_requests": recipe.get("unresolved_requests", []).duplicate(), "scene": scene}

static func _room_wall_segments(rooms: Array, corridors: Array) -> Array[Dictionary]:
	var walls: Array[Dictionary] = []
	for room in rooms:
		var rect: Dictionary = room.grid
		var x := float(rect.x)
		var y := float(rect.y)
		var w := float(rect.width)
		var h := float(rect.height)
		_add_wall(walls, Vector2(x, y), Vector2(x + w, y))
		_add_wall(walls, Vector2(x, y + h), Vector2(x + w, y + h))
		var left_openings := _openings_for_room(room.id, corridors, rooms, true)
		var right_openings := _openings_for_room(room.id, corridors, rooms, false)
		_add_wall_with_openings(walls, Vector2(x, y), Vector2(x, y + h), left_openings)
		_add_wall_with_openings(walls, Vector2(x + w, y), Vector2(x + w, y + h), right_openings)
	return walls

static func _openings_for_room(room_id: String, corridors: Array, rooms: Array, left_side: bool) -> Array[Vector2]:
	var openings: Array[Vector2] = []
	for corridor in corridors:
		if str(corridor.get("orientation", "east-west")) != "east-west" or not corridor.room_ids.has(room_id):
			continue
		var room_index := 0 if str(corridor.room_ids[0]) == room_id else 1
		var other_id := str(corridor.room_ids[1 - room_index])
		var other: Dictionary = rooms.filter(func(item): return str(item.id) == other_id)[0] if rooms.any(func(item): return str(item.id) == other_id) else {}
		if other.is_empty():
			continue
		var this_rect: Dictionary = rooms.filter(func(item): return str(item.id) == room_id)[0].grid
		var this_right := float(this_rect.x + this_rect.width)
		var other_right := float(other.grid.x + other.grid.width)
		var opening_x := this_right if other.grid.x >= this_right else float(this_rect.x)
		if left_side and opening_x != float(this_rect.x):
			continue
		if not left_side and opening_x != this_right:
			continue
		var corridor_rect: Dictionary = corridor.grid
		openings.append(Vector2(float(corridor_rect.y), float(corridor_rect.y + corridor_rect.height)))
	return openings

static func _add_wall_with_openings(walls: Array[Dictionary], start: Vector2, finish: Vector2, openings: Array[Vector2]) -> void:
	if start.x != finish.x:
		_add_wall(walls, start, finish)
		return
	var ranges := openings.duplicate()
	ranges.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
	var cursor := start.y
	for opening in ranges:
		var opening_start := clampf(opening.x, start.y, finish.y)
		var opening_end := clampf(opening.y, start.y, finish.y)
		if opening_start > cursor:
			_add_wall(walls, Vector2(start.x, cursor), Vector2(start.x, opening_start))
		cursor = maxf(cursor, opening_end)
	if cursor < finish.y:
		_add_wall(walls, Vector2(start.x, cursor), finish)

static func _door_segments(rooms: Array, corridors: Array) -> Array[Dictionary]:
	var doors: Array[Dictionary] = []
	for corridor in corridors:
		var rect: Dictionary = corridor.grid
		var center_y := float(rect.y) + float(rect.height) * 0.5
		for room_id in corridor.room_ids:
			var room: Dictionary = rooms.filter(func(item): return str(item.id) == str(room_id))[0]
			var r: Dictionary = room.grid
			var left_x := float(r.x)
			var right_x := float(r.x + r.width)
			var near_left := absf(left_x - float(rect.x + rect.width)) < absf(right_x - float(rect.x))
			var edge_x := left_x if near_left else right_x
			doors.append({"id": "door-%s-%s" % [corridor.id, room_id], "a": {"x": edge_x, "y": center_y - 0.45}, "b": {"x": edge_x, "y": center_y + 0.45}, "open": true, "hidden": false})
	return doors

static func _add_wall(walls: Array[Dictionary], a: Vector2, b: Vector2) -> void:
	walls.append({"a": {"x": a.x, "y": a.y}, "b": {"x": b.x, "y": b.y}, "hidden": false})

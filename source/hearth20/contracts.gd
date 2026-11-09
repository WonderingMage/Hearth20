extends RefCounted
class_name Hearth20Contracts
## Hearth20's bounded campaign, movement, projection, and offline recipe contracts.

const MAX_ACTORS := 2000
const MAX_SCENES := 256
const MAX_FX_EVENTS := 256
const MAX_RECIPE_TEXT := 4000
const MAX_RECIPE_OBJECTS := 512
const MAX_SIDE := 128
const MAX_PROJECTION_BYTES := 64 * 1024 * 1024
const MAX_RECIPE_JSON_BYTES := 262_144
const MAX_RECIPE_JSON_NODES := 20_000
const MAX_RECIPE_JSON_DEPTH := 16
const MAX_REVISION := 9_007_199_254_740_990
const MOVEMENT_MODES := ["blocked", "turn_allowance", "grant", "free_until_revoked"]
const RECIPE_PATTERNS := ["forest_camp", "ruined_chapel", "cave", "castle", "ruins"]
const RECIPE_NUMBER_WORDS := {"zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20}
const KNOWN_REQUESTS := ["forest", "camp", "chapel", "ruin", "ruined", "cave", "dungeon", "castle", "campfire", "fire", "tent", "cache", "trap", "pillar", "pew", "altar", "torch", "well", "bridge", "room", "rooms", "corridor", "corridors", "connected"]
const RECIPE_STOP_WORDS := ["a", "an", "the", "and", "or", "to", "of", "in", "on", "at", "by", "with", "for", "from", "under", "over", "as", "is", "are", "be", "it", "this", "that", "there", "where", "nearby", "across", "through", "around", "beside", "inside", "outside", "between", "into", "onto", "then", "have", "has", "make", "build", "create", "scene", "area", "place", "show", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]

static func finite_point(value: Variant) -> bool:
	return value is Vector2 and is_finite(value.x) and is_finite(value.y) and absf(value.x) <= 1_000_000.0 and absf(value.y) <= 1_000_000.0

static func valid_identifier(value: Variant, max_len: int = 96) -> bool:
	if not value is String or value.is_empty() or value.length() > max_len:
		return false
	var first_character := true
	for character in value:
		var codepoint: int = character.unicode_at(0)
		var digit: bool = codepoint >= 48 and codepoint <= 57
		if not (character.is_valid_identifier() or digit or character == "-" or character == "_") or (first_character and digit):
			return false
		first_character = false
	return true

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer_number(value: Variant) -> bool:
	return _finite_number(value) and floorf(float(value)) == float(value)

static func _point_from_record(value: Variant) -> Vector2:
	if value is Vector2:
		return value if finite_point(value) else Vector2(2_000_000.0, 2_000_000.0)
	if not value is Dictionary or not _finite_number(value.get("x", null)) or not _finite_number(value.get("y", null)):
		return Vector2(2_000_000.0, 2_000_000.0)
	var point := Vector2(float(value.x), float(value.y))
	return point if finite_point(point) else Vector2(2_000_000.0, 2_000_000.0)

static func _point_inside_scene(point: Vector2, scene: Dictionary) -> bool:
	return finite_point(point) and point.x >= 0.0 and point.y >= 0.0 and point.x <= float(scene.width_cells) and point.y <= float(scene.height_cells)

static func _rect_from_record(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	if not value is Dictionary:
		return Rect2(Vector2(-1.0, -1.0), Vector2.ZERO)
	for key in ["x", "y", "width", "height"]:
		if not _finite_number(value.get(key, null)):
			return Rect2(Vector2(-1.0, -1.0), Vector2.ZERO)
	return Rect2(Vector2(float(value.x), float(value.y)), Vector2(float(value.width), float(value.height)))

static func _valid_scene_rect(rect: Rect2, scene: Dictionary) -> bool:
	return is_finite(rect.position.x) and is_finite(rect.position.y) and is_finite(rect.size.x) and is_finite(rect.size.y) and rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.size.x > 0.0 and rect.size.y > 0.0 and rect.end.x <= float(scene.width_cells) and rect.end.y <= float(scene.height_cells)

static func valid_scene(scene: Variant) -> bool:
	if not scene is Dictionary:
		return false
	if not valid_identifier(scene.get("id")) or not _integer_number(scene.get("width_cells", null)) or not _integer_number(scene.get("height_cells", null)):
		return false
	if int(scene.width_cells) < 1 or int(scene.height_cells) < 1 or int(scene.width_cells) > 256 or int(scene.height_cells) > 256:
		return false
	if not _finite_number(scene.get("feet_per_cell")):
		return false
	if float(scene.feet_per_cell) <= 0.0 or float(scene.feet_per_cell) > 1000.0:
		return false
	if scene.has("cell_pixels") and (not scene.cell_pixels is float and not scene.cell_pixels is int):
		return false
	if not is_finite(float(scene.get("cell_pixels", 64.0))) or float(scene.get("cell_pixels", 64.0)) <= 0.0 or float(scene.get("cell_pixels", 64.0)) > 65536.0:
		return false
	for collection in ["walls", "doors", "props", "fog_rects", "fx"]:
		if not scene.get(collection, []) is Array or scene.get(collection, []).size() > MAX_RECIPE_OBJECTS:
			return false
	for flag in ["dynamic_lighting", "blackout"]:
		if scene.has(flag) and not scene[flag] is bool:
			return false
	if scene.get("ambient_light", "bright") not in ["bright", "dim", "dark"]:
		return false
	if scene.has("natural_light") and not Hearth20NaturalLight.valid(scene.natural_light): return false
	if scene.has("grid_opacity") and (not _finite_number(scene.grid_opacity) or float(scene.grid_opacity)<0 or float(scene.grid_opacity)>1): return false
	if scene.has("grid_thickness") and (not _finite_number(scene.grid_thickness) or float(scene.grid_thickness)<0.5 or float(scene.grid_thickness)>4): return false
	if scene.has("grid_color") and (not scene.grid_color is String or not Color.html_is_valid(scene.grid_color)): return false
	if not scene.get("annotations", []) is Array or scene.get("annotations", []).size() > 256:
		return false
	for object in scene.get("annotations", []):
		if not Hearth20BoardTools.valid_object(object, scene) or not valid_identifier(object.get("id", "")) or not valid_identifier(object.get("owner", "")):
			return false
	if not scene.get("lights", []) is Array or scene.get("lights", []).size() > 128:
		return false
	for light in scene.get("lights", []):
		if not light is Dictionary or not Hearth20Lighting.valid_source(light): return false
		if not light is Dictionary or not _point_inside_scene(_point_from_record(light.get("position")), scene):
			return false
		for key in ["bright_feet", "dim_feet"]:
			if not _finite_number(light.get(key, 0.0)) or float(light.get(key, 0.0)) < 0.0 or float(light.get(key, 0.0)) > 1000.0:
				return false
		if not light.get("enabled", true) is bool:
			return false
	if not scene.get("templates", []) is Array or scene.get("templates", []).size() > 128:
		return false
	for template in scene.get("templates", []):
		if not template is Dictionary or not valid_identifier(template.get("id", "")) or template.get("shape", "") not in ["circle", "rectangle", "line", "cone"] or not finite_point(template.get("start")) or not finite_point(template.get("end")):
			return false
		if not _point_inside_scene(template.start, scene) or not _point_inside_scene(template.end, scene):
			return false
	for wall in scene.get("walls", []):
		if not wall is Dictionary or (wall.has("hidden") and not wall.hidden is bool):
			return false
		var wall_a := _point_from_record(wall.get("a", null))
		var wall_b := _point_from_record(wall.get("b", null))
		if not _point_inside_scene(wall_a, scene) or not _point_inside_scene(wall_b, scene) or wall_a.distance_squared_to(wall_b) < 0.000001:
			return false
	for door in scene.get("doors", []):
		if not door is Dictionary or not door.get("open", false) is bool or (door.has("hidden") and not door.hidden is bool):
			return false
		var door_a := _point_from_record(door.get("a", null))
		var door_b := _point_from_record(door.get("b", null))
		if not _point_inside_scene(door_a, scene) or not _point_inside_scene(door_b, scene) or door_a.distance_squared_to(door_b) < 0.000001:
			return false
	for prop in scene.get("props", []):
		if not prop is Dictionary or not prop.get("position", null) is Vector2 or not finite_point(prop.position):
			return false
		if not _point_inside_scene(prop.position, scene) or str(prop.get("kind", "")).length() > 40 or str(prop.get("label", "")).length() > 80 or str(prop.get("gm_details", "")).length() > 1000:
			return false
		for flag in ["public", "hidden"]:
			if prop.has(flag) and not prop[flag] is bool:
				return false
	for fog in scene.get("fog_rects", []):
		if not _valid_scene_rect(_rect_from_record(fog), scene):
			return false
	for fx in scene.get("fx", []):
		if not fx is Dictionary or not fx.get("public", false) is bool:
			return false
		for point_key in ["source", "destination", "center", "start", "end"]:
			if fx.has(point_key) and (not fx[point_key] is Vector2 or not finite_point(fx[point_key]) or not _point_inside_scene(fx[point_key], scene)):
				return false
		for timing_key in ["started_usec", "travel_usec", "impact_duration_usec"]:
			if fx.has(timing_key) and not _integer_number(fx[timing_key]):
				return false
		if int(fx.get("travel_usec", 0)) < 0 or int(fx.get("travel_usec", 0)) > 120_000_000 or int(fx.get("impact_duration_usec", 950_000)) < 1 or int(fx.get("impact_duration_usec", 950_000)) > 120_000_000:
			return false
		if fx.has("private_recipients") and (not fx.private_recipients is Array or fx.private_recipients.size() > 256):
			return false
	return true

static func validate_campaign(campaign: Variant) -> Dictionary:
	var result := Hearth20Identity.validate_campaign(campaign)
	if not result.ok:
		return result
	var checked: Dictionary = campaign
	if not _integer_number(checked.get("revision",0)) or checked.get("revision",0)<0 or checked.get("revision",0)>MAX_REVISION:
		return {"ok":false,"errors":["Campaign revision is invalid."]}
	var turn_budgets=checked.get("turn_remaining_feet",{})
	if not turn_budgets is Dictionary or turn_budgets.size()>MAX_ACTORS:
		return {"ok":false,"errors":["Turn movement allowances are invalid."]}
	for actor_id in turn_budgets:
		if not valid_identifier(actor_id) or not _finite_number(turn_budgets[actor_id]) or turn_budgets[actor_id]<0 or turn_budgets[actor_id]>1_000_000:
			return {"ok":false,"errors":["Turn movement allowances must be finite, non-negative distances."]}
	if checked.scenes.size() > MAX_SCENES or checked.actors.size() > MAX_ACTORS:
		return {"ok": false, "errors": ["Campaign exceeds scene or actor count limits."]}
	var encoded_asset_bytes := 0
	for asset_id in checked.assets:
		var asset: Variant = checked.assets[asset_id]
		if not asset is Dictionary or asset.get("kind", "") not in ["map", "token"] or not asset.get("base64", "") is String:
			return {"ok": false, "errors": ["Campaign contains an invalid asset record."]}
		encoded_asset_bytes += str(asset.base64).length()
		if encoded_asset_bytes > Hearth20Identity.MAX_SAVE_BYTES:
			return {"ok": false, "errors": ["Campaign assets exceed the supported aggregate transfer size."]}
	for asset_id in checked.assets:
		if not Hearth20Assets.read_asset(checked, str(asset_id)).size() > 0:
			return {"ok": false, "errors": ["Campaign contains an invalid or corrupt image asset."]}
	var scene_ids := {}
	for scene in checked.scenes:
		if not valid_scene(scene) or scene_ids.has(scene.id):
			return {"ok": false, "errors": ["Campaign has an invalid or duplicate scene."]}
		var map_asset_id := str(scene.get("map_asset", ""))
		if not map_asset_id.is_empty() and (not checked.assets.has(map_asset_id) or checked.assets[map_asset_id].get("kind", "") != "map"):
			return {"ok": false, "errors": ["Campaign scene references a missing or non-map image asset."]}
		scene_ids[scene.id] = true
	if not scene_ids.has(str(checked.active_scene)):
		return {"ok": false, "errors": ["Active scene is missing."]}
	if not checked.get("fx_presets",{}) is Dictionary or checked.get("fx_presets",{}).size()>32: return {"ok":false,"errors":["Invalid custom effect library."]}
	for name_value in checked.get("fx_presets",{}):
		if not name_value is String or name_value.length()>48 or not Hearth20BoardTools.valid_fx_settings(checked.fx_presets[name_value]): return {"ok":false,"errors":["Invalid custom effect preset."]}
	if not Hearth20PlayerProfile.valid_participants(checked.get("participants",{})): return {"ok":false,"errors":["Invalid saved player identities."]}
	if checked.has("viewpoints"):
		if not checked.viewpoints is Dictionary or checked.viewpoints.size()>256:return {"ok":false,"errors":["Invalid character viewpoints."]}
		for player in checked.viewpoints:
			if not valid_identifier(player) or not valid_identifier(checked.viewpoints[player]):return {"ok":false,"errors":["Invalid character viewpoint identifiers."]}
	if not Hearth20TavernGames.valid(checked.get("tavern_game",{})):return {"ok":false,"errors":["Invalid casino state."]}
	if checked.get("table_mode","map") not in ["map","casino"]:return {"ok":false,"errors":["Unknown seated table mode."]}
	if not Hearth20CasinoWallet.valid(checked):return {"ok":false,"errors":["Invalid declared casino balances or settlement notices."]}
	if not Hearth20Refreshments.valid(checked.get("refreshments",{})):return {"ok":false,"errors":["Invalid saved refreshments."]}
	if not Hearth20CasinoGames.integer(checked.get("casino_house_cp",0)):return {"ok":false,"errors":["Invalid casino reserve."]}
	if not checked.get("tavern_ledger",[]) is Array or checked.get("tavern_ledger",[]).size()>1000 or var_to_bytes(checked.get("tavern_ledger",[])).size()>524288:return {"ok":false,"errors":["Invalid casino ledger."]}
	var actor_ids := {}
	for actor in checked.actors:
		if not actor is Dictionary or not valid_identifier(actor.get("id")) or actor_ids.has(actor.id):
			return {"ok": false, "errors": ["Actor record is invalid or duplicated."]}
		if actor.has("vision") and not Hearth20Vision.valid_settings(actor.vision):
			return {"ok": false, "errors": ["Actor vision settings exceed supported ranges."]}
		if actor.has("decorative") and not actor.decorative is bool: return {"ok":false,"errors":["Invalid foreground object flag."]}
		if actor.has("in_inventory") and not actor.in_inventory is bool: return {"ok":false,"errors":["Invalid token inventory flag."]}
		if actor.get("layer", "tokens") not in ["map", "tokens", "gm", "foreground"]:
			return {"ok":false,"errors":["Unknown token layer."]}
		if actor.has("abilities"):
			if not actor.abilities is Array or actor.abilities.size() != 6:
				return {"ok": false, "errors": ["An actor must have six ability scores."]}
			for score in actor.abilities:
				if not _integer_number(score) or int(score) < 1 or int(score) > 100:
					return {"ok": false, "errors": ["Ability scores must be whole numbers from 1 to 100."]}
		for field in ["save_bonuses", "skill_bonuses", "skills", "resources", "coins"]:
			if actor.has(field) and not actor[field] is Dictionary:
				return {"ok": false, "errors": ["Sheet bonus/resource fields must be records."]}
		for field in ["hp", "max_hp", "temp", "ac", "speed", "level", "prof_bonus", "initiative_bonus", "attack", "hit_die", "hit_dice", "death_success", "death_failure", "exhaustion"]:
			if actor.has(field) and (not _integer_number(actor[field]) or absf(float(actor[field])) > 1000000.0):
				return {"ok": false, "errors": ["Sheet statistics must be bounded whole numbers."]}
		for field in ["save_bonuses", "skill_bonuses", "skills"]:
			for bonus in actor.get(field, {}).values():
				if not _integer_number(bonus) or absf(float(bonus)) > 1000.0:
					return {"ok": false, "errors": ["Recorded save/skill bonuses exceed supported ranges."]}
		if not actor.get("save_profs", []) is Array:
			return {"ok": false, "errors": ["Save training must be an array of ability indices."]}
		for ability in actor.get("save_profs", []):
			if not _integer_number(ability) or int(ability) < 0 or int(ability) > 5:
				return {"ok": false, "errors": ["Save training names an invalid ability."]}
		var actor_scene := find_scene(checked, str(actor.get("scene_id", "")))
		if not finite_point(actor.get("position", null)) or actor_scene.is_empty() or not _inside_scene(actor.position, actor_scene):
			return {"ok": false, "errors": ["Actor position or scene reference is invalid."]}
		var policy: Variant = actor.get("movement_policy", default_movement_policy("blocked"))
		if not valid_movement_policy(policy):
			return {"ok": false, "errors": ["Actor movement policy is unsupported."]}
		var actor_asset_id := str(actor.get("png_asset_id", ""))
		if not actor_asset_id.is_empty() and (not checked.assets.has(actor_asset_id) or checked.assets[actor_asset_id].get("kind", "") != "token"):
			return {"ok": false, "errors": ["Actor references a missing or non-token PNG asset."]}
		actor_ids[actor.id] = true
	if not checked.get("table_timeline", []) is Array or checked.get("table_timeline", []).size() > 200 or var_to_bytes(checked.get("table_timeline", [])).size() > 2 * 1024 * 1024:
		return {"ok": false, "errors": ["Chat history exceeds supported bounds."]}
	if not checked.get("handouts", []) is Array or checked.get("handouts", []).size() > 128:
		return {"ok": false, "errors": ["Handout collection exceeds supported bounds."]}
	for entry in checked.get("table_timeline", []):
		if not entry is Dictionary or entry.get("type", "") not in ["chat", "roll"] or entry.get("visibility", "") not in ["public", "gm", "self", "secret"] or not entry.get("recipients", []) is Array or entry.get("recipients", []).size() > 8:
			return {"ok": false, "errors": ["Chat history contains an invalid audience or record."]}
		for recipient in entry.get("recipients", []):
			if not valid_identifier(recipient):
				return {"ok": false, "errors": ["Chat history contains an invalid private recipient."]}
		for field in ["text", "sender", "actor_name", "label", "formula", "time"]:
			if not entry.get(field, "") is String or str(entry.get(field, "")).length() > (2000 if field == "text" else 128):
				return {"ok": false, "errors": ["Chat history contains oversized or invalid text."]}
		if entry.get("type") == "roll" and (not _integer_number(entry.get("total")) or not entry.get("dice", []) is Array or entry.get("dice", []).size() > 50):
			return {"ok": false, "errors": ["Chat history contains an invalid dice result."]}
	for handout in checked.get("handouts", []):
		if not handout is Dictionary or not valid_identifier(handout.get("id", "")) or not handout.get("public", false) is bool or not handout.get("title", "") is String or str(handout.get("title", "")).length() > 96 or not handout.get("body", "") is String or str(handout.get("body", "")).length() > 12000:
			return {"ok": false, "errors": ["Handout fields exceed supported bounds."]}
	return {"ok": true, "errors": []}

static func valid_movement_policy(policy: Variant) -> bool:
	if not policy is Dictionary or policy.get("mode","blocked") not in MOVEMENT_MODES:
		return false
	var controllers=policy.get("controllers",[])
	if not controllers is Array or controllers.size()>256:return false
	for controller in controllers:
		if not valid_identifier(controller):return false
	var remaining=policy.get("remaining_feet",0.0)
	if not _finite_number(remaining) or remaining<0 or remaining>1_000_000:return false
	var revision=policy.get("revision",0)
	if not _integer_number(revision) or revision<0 or revision>MAX_REVISION:return false
	if policy.get("expiry","campaign") not in ["campaign","scene","turn"]:return false
	for field in ["grant_id","expiry_id"]:
		if not policy.get(field,"") is String or policy.get(field,"").length()>96:return false
	return true

static func default_movement_policy(mode: String = "blocked", controllers: Array[String] = []) -> Dictionary:
	if not MOVEMENT_MODES.has(mode) or controllers.size() > 256:
		return {}
	var unique_controllers: Array[String] = []
	for controller in controllers:
		if not valid_identifier(controller) or unique_controllers.has(controller):
			return {}
		unique_controllers.append(controller)
	return {"mode": mode, "controllers": unique_controllers, "revision": 0, "remaining_feet": 0.0, "grant_id": "", "expiry": "campaign"}

static func set_movement_policy(campaign: Dictionary, actor_id: String, mode: String, controllers: Array[String], grant_feet: float = 0.0, grant_id: String = "", expiry: String = "campaign") -> Dictionary:
	if mode not in MOVEMENT_MODES or not ["turn", "scene", "campaign"].has(expiry) or not is_finite(grant_feet) or grant_feet < 0.0 or grant_feet > 1_000_000.0:
		return {"ok": false, "reason": "invalid_policy"}
	var actor := find_actor(campaign, actor_id)
	if actor.is_empty():
		return {"ok": false, "reason": "unknown_actor"}
	var policy := default_movement_policy(mode, controllers)
	if policy.is_empty():
		return {"ok": false, "reason": "invalid_controllers"}
	if mode == "grant":
		if not valid_identifier(grant_id) or grant_feet <= 0.0:
			return {"ok": false, "reason": "invalid_grant"}
		policy.grant_id = grant_id
		policy.remaining_feet = grant_feet
		policy.expiry = expiry
		policy.expiry_id = str(campaign.get("turn_id", "")) if expiry == "turn" else str(campaign.get("active_scene", "")) if expiry == "scene" else "campaign"
	policy.revision = int(actor.get("movement_policy", {}).get("revision", 0)) + 1
	actor.movement_policy = policy
	if mode == "turn_allowance":
		campaign.turn_id = "turn-%d" % Time.get_ticks_usec()
		campaign.active_turn_actor = actor_id
		if not campaign.get("turn_remaining_feet") is Dictionary:
			campaign.turn_remaining_feet = {}
		campaign.turn_remaining_feet[actor_id] = grant_feet
		actor.turn_allowance_turn_id = str(campaign.get("turn_id", "turn-0"))
	campaign.revision = int(campaign.get("revision", 0)) + 1
	return {"ok": true, "policy": policy.duplicate(true)}

static func revoke_movement(campaign: Dictionary, actor_id: String) -> Dictionary:
	return set_movement_policy(campaign, actor_id, "blocked", [])

static func find_actor(campaign: Dictionary, actor_id: String) -> Dictionary:
	for actor in campaign.get("actors", []):
		if str(actor.get("id", "")) == actor_id:
			return actor
	return {}

static func authorize_and_apply_move(campaign: Dictionary, authenticated_player: String, actor_role: String, actor_id: String, expected_from: Vector2, destination: Vector2, measured_distance_feet: float) -> Dictionary:
	if not finite_point(expected_from) or not finite_point(destination) or not is_finite(measured_distance_feet) or measured_distance_feet < 0.0 or measured_distance_feet > 1_000_000.0:
		return {"ok": false, "reason": "invalid_move"}
	var actor := find_actor(campaign, actor_id)
	if actor.is_empty() or actor.get("in_inventory",false) or str(actor.get("scene_id", "")) != str(campaign.get("active_scene", "")):
		return {"ok": false, "reason": "unknown_or_inactive_actor"}
	if actor.get("position") != expected_from:
		return {"ok": false, "reason": "stale_origin"}
	var scene := find_scene(campaign, str(actor.scene_id))
	if not _inside_scene(destination, scene):
		return {"ok": false, "reason": "outside_scene"}
	if actor_role == "dm":
		actor.position = destination
		campaign.revision = int(campaign.get("revision", 0)) + 1
		return {"ok": true, "reason": "dm_override", "position": destination}
	if actor.get("layer","tokens") != "tokens": return {"ok":false,"reason":"token_layer_required"}
	if _crosses_blocking_geometry(expected_from, destination, scene):
		return {"ok": false, "reason": "blocked_by_wall_or_door"}
	if actor_role != "player" or not valid_identifier(authenticated_player):
		return {"ok": false, "reason": "invalid_role"}
	var policy_value=actor.get("movement_policy", {})
	if not valid_movement_policy(policy_value):return {"ok":false,"reason":"invalid_policy"}
	var policy: Dictionary=policy_value
	var mode := str(policy.get("mode", "blocked"))
	if mode == "blocked":
		return {"ok": false, "reason": "blocked"}
	if not policy.get("controllers", []).has(authenticated_player):
		return {"ok": false, "reason": "not_controller"}
	if mode == "turn_allowance":
		if str(campaign.get("active_turn_actor", "")) != actor_id or str(actor.get("turn_allowance_turn_id", "")) != str(campaign.get("turn_id", "turn-0")):
			return {"ok": false, "reason": "not_active_turn"}
		var budgets=campaign.get("turn_remaining_feet",{})
		if not budgets is Dictionary:return {"ok":false,"reason":"invalid_policy"}
		var budget=budgets.get(actor_id,0.0)
		if not _finite_number(budget) or budget<0 or budget>1_000_000:return {"ok":false,"reason":"invalid_policy"}
		var remaining := float(budget)
		if measured_distance_feet > remaining:
			return {"ok": false, "reason": "insufficient_turn_allowance"}
		budgets[actor_id]=remaining-measured_distance_feet
		campaign.turn_remaining_feet=budgets
	elif mode == "grant":
		if policy.get("expiry") == "turn" and str(campaign.get("turn_id", "")) != str(policy.get("expiry_id", "")):
			return {"ok": false, "reason": "grant_expired"}
		if policy.get("expiry") == "scene" and str(campaign.get("active_scene", "")) != str(policy.get("expiry_id", "")):
			return {"ok": false, "reason": "grant_expired"}
		if measured_distance_feet > float(policy.get("remaining_feet", 0.0)):
			return {"ok": false, "reason": "insufficient_grant"}
		policy.remaining_feet = float(policy.get("remaining_feet",0.0)) - measured_distance_feet
		policy.revision = int(policy.get("revision", 0)) + 1
	elif mode != "free_until_revoked":
		return {"ok": false, "reason": "invalid_policy"}
	actor.position = destination
	campaign.revision = int(campaign.get("revision", 0)) + 1
	return {"ok": true, "reason": "moved", "position": destination, "remaining_feet": float(policy.get("remaining_feet", 0.0)), "policy_revision": int(policy.get("revision", 0))}

static func find_scene(campaign: Dictionary, scene_id: String) -> Dictionary:
	for scene in campaign.get("scenes", []):
		if scene is Dictionary and str(scene.get("id", "")) == scene_id:
			return scene
	return {}

static func _inside_scene(point: Vector2, scene: Dictionary) -> bool:
	return point.x >= 0.0 and point.y >= 0.0 and point.x <= float(scene.get("width_cells", 0)) and point.y <= float(scene.get("height_cells", 0))

static func _crosses_blocking_geometry(start: Vector2, finish: Vector2, scene: Dictionary) -> bool:
	for object in scene.get("annotations", []):
		for segment in Hearth20BoardTools.barriers(object):
			if segment_intersects(start,finish,segment[0],segment[1]): return true
	for wall in scene.get("walls", []):
		if wall is Dictionary and segment_intersects(start, finish, Vector2(wall.get("a", {}).get("x", 0.0), wall.get("a", {}).get("y", 0.0)), Vector2(wall.get("b", {}).get("x", 0.0), wall.get("b", {}).get("y", 0.0))):
			return true
	for door in scene.get("doors", []):
		if door is Dictionary and not bool(door.get("open", false)) and segment_intersects(start, finish, Vector2(door.get("a", {}).get("x", 0.0), door.get("a", {}).get("y", 0.0)), Vector2(door.get("b", {}).get("x", 0.0), door.get("b", {}).get("y", 0.0))):
			return true
	return false

static func segment_intersects(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var denominator := ab.cross(cd)
	if absf(denominator) < 0.00001:
		if ab.length_squared() < 0.00001:
			if cd.length_squared() < 0.00001:
				return a.distance_to(c) < 0.00001
			var point_t := (a - c).dot(cd) / cd.length_squared()
			return absf((a - c).cross(cd)) < 0.00001 and point_t >= 0.0 and point_t <= 1.0
		if absf((c - a).cross(ab)) >= 0.00001:
			return false
		var t0 := (c - a).dot(ab) / ab.length_squared()
		var t1 := (d - a).dot(ab) / ab.length_squared()
		return maxf(minf(t0, t1), 0.0) <= minf(maxf(t0, t1), 1.0)
	var t := (c - a).cross(cd) / denominator
	var u := (c - a).cross(ab) / denominator
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0

static func project_for_player(campaign: Dictionary, player_id: String, map_asset_bytes: PackedByteArray) -> Dictionary:
	var scene := find_scene(campaign, str(campaign.get("active_scene", "")))
	if scene.is_empty() or not valid_scene(scene) or not valid_identifier(player_id):
		return {}
	var sight := Hearth20Vision.build_view(campaign, player_id, scene)
	var projected_actors: Array[Dictionary] = []
	var visible_ids := {}
	for actor in campaign.get("actors", []):
		if not actor is Dictionary:
			continue
		if actor.get("in_inventory",false) or str(actor.get("scene_id", "")) != str(scene.id):
			continue
		var owned := str(actor.get("owner_player_id", "")) == player_id
		if actor.get("layer", "tokens") in ["gm", "light"]:
			continue
		var actor_position: Variant = actor.get("position", null)
		if not finite_point(actor_position) or not _point_inside_scene(actor_position, scene):
			continue
		if bool(sight.blackout) or ((bool(actor.get("hidden", false)) or not Hearth20Vision.visible(actor_position, sight)) and not owned):
			continue
		var token_size_value: Variant = actor.get("token_size", 1.0)
		var token_size := clampf(float(token_size_value), 0.1, 10.0) if _finite_number(token_size_value) else 1.0
		if actor.get("decorative",false)==true and not Hearth20BoardTools.area_visible(Rect2(actor_position-Vector2.ONE*token_size*0.5,Vector2.ONE*token_size),sight): continue
		var actor_asset_id := str(actor.get("png_asset_id", ""))
		var clean := {
			"id": str(actor.get("id", "")) if owned else _neutral_id(player_id, str(actor.get("id", ""))), "kind": "hero" if owned else "token",
			"position": actor_position, "size": token_size,
			"asset_id": actor_asset_id,
			"layer": str(actor.get("layer", "tokens")),
		}
		if actor.get("decorative",false)==true: clean.decorative=true
		if owned:
			var movement_value: Variant = actor.get("movement_policy", {})
			var movement: Dictionary = movement_value if movement_value is Dictionary else {}
			var remaining_value: Variant = movement.get("remaining_feet", 0.0)
			var remaining_feet := maxf(0.0, float(remaining_value)) if _finite_number(remaining_value) else 0.0
			if movement.get("mode", "blocked") == "turn_allowance":
				var turn_remaining: Variant = campaign.get("turn_remaining_feet", {}).get(str(actor.get("id", "")), 0.0)
				remaining_feet = maxf(0.0, float(turn_remaining)) if _finite_number(turn_remaining) else 0.0
			var movement_mode := str(movement.get("mode", "blocked"))
			if movement_mode not in MOVEMENT_MODES:
				movement_mode = "blocked"
			clean.movement = {"mode": movement_mode, "remaining_feet": remaining_feet, "revision": maxi(0, int(movement.get("revision", 0)))}
		projected_actors.append(clean)
		visible_ids[str(actor.get("id", ""))] = true
	var projected_fx: Array[Dictionary] = []
	for fx in scene.get("fx", []):
		if not fx is Dictionary or not bool(fx.get("public", false)):
			continue
		var target_id := str(fx.get("target_actor_id", ""))
		if not target_id.is_empty() and not visible_ids.has(target_id):
			_mark_fx_private_for(fx, player_id)
			continue
		var center: Variant = fx.get("center", null)
		var start_point: Variant = fx.get("start", center)
		var end_point: Variant = fx.get("end", center)
		if not finite_point(center) or not _point_inside_scene(center, scene) or not finite_point(start_point) or not finite_point(end_point) or not _point_inside_scene(start_point, scene) or not _point_inside_scene(end_point, scene):
			continue
		if not Hearth20Vision.segment_visible(start_point, end_point, sight) or not Hearth20Vision.visible(center, sight) or _segment_touches_fog(start_point, end_point, scene):
			_mark_fx_private_for(fx, player_id)
			continue
		if fx.get("private_recipients", []).has(player_id):
			continue
		var now_usec := Time.get_ticks_usec()
		var arrival := int(fx.get("started_usec", now_usec)) + int(fx.get("travel_usec", 0))
		var impact_duration := int(fx.get("impact_duration_usec", 950_000))
		if now_usec > arrival + impact_duration:
			continue
		var clean_fx := {"id": _neutral_id(player_id, str(fx.get("id", "effect"))), "preset": str(fx.get("preset","fire-rocket-impact-v1")), "center": center, "start": start_point, "end": end_point, "delay_to_arrival_msec": maxi(0, ceili(float(arrival - now_usec) / 1000.0)), "impact_duration_msec": ceili(float(impact_duration) / 1000.0),"elapsed_msec":maxi(0,floori(float(now_usec-int(fx.get("started_usec",now_usec)))/1000.)),"original_travel_msec":maxi(0,ceili(float(fx.get("travel_usec",0))/1000.)), "seed": int(fx.get("seed", 0)) & 0x7fffffff}
		for field in ["effect","material","color","size","density"]:
			if fx.has(field): clean_fx[field] = fx[field]
		projected_fx.append(clean_fx)
	var map_bytes := Hearth20Vision.mask_map(map_asset_bytes, sight) if bool(scene.get("dynamic_lighting", false)) or bool(sight.blackout) else _mask_fogged_map(map_asset_bytes, scene)
	var safe_assets := _visible_assets(campaign, projected_actors)
	if safe_assets.has("_h20_overflow"):
		return {}
	for actor in projected_actors:
		var projected_asset_id := str(actor.get("asset_id", ""))
		if not projected_asset_id.is_empty() and not safe_assets.has(projected_asset_id):
			actor.asset_id = ""
	var snapshot_scene := _public_scene(scene, sight)
	snapshot_scene.light_field=Hearth20Lighting.project_field(sight)
	snapshot_scene.annotations = []
	for object in scene.get("annotations", []):
		if Hearth20BoardTools.object_visible(object, sight):
			var clean: Dictionary = {}
			for field in ["id","kind","layer","points","color","fill","width","text","font","font_size","bold","italic","border","border_color","opacity"]:
				if object.has(field): clean[field] = object[field]
			clean.mine = str(object.owner) == player_id
			if not clean.mine: clean.id = _neutral_id(player_id, str(object.id))
			clean.erase("owner")
			snapshot_scene.annotations.append(clean)
	snapshot_scene.id = _neutral_id(player_id, "scene:" + str(scene.id))
	snapshot_scene.templates = []
	for template in scene.get("templates", []):
		if Hearth20Vision.template_visible(template, sight):
			snapshot_scene.templates.append({"id": _neutral_id(player_id, str(template.id)), "shape": str(template.shape), "start": template.start, "end": template.end})
	if bool(sight.blackout):
		snapshot_scene = {"id": "blackout", "title": "The DM has covered the table", "width_cells": 24, "height_cells": 16, "cell_pixels": 64.0, "feet_per_cell": 5.0, "grid_visible": false, "walls": [], "doors": [], "props": []}
		map_bytes = PackedByteArray()
		safe_assets = {}
		projected_fx = []
	var asset_bytes := map_bytes.size()
	for asset in safe_assets.values():
		asset_bytes += str(asset.get("base64", "")).to_utf8_buffer().size()
	# Reserve a bounded allowance for the remaining scene/token/effect metadata.
	var metadata_budget: int = projected_actors.size() * 384 + projected_fx.size() * 384 + (snapshot_scene.walls.size() + snapshot_scene.doors.size() + snapshot_scene.props.size()) * 192 + 4096
	if asset_bytes + metadata_budget > MAX_PROJECTION_BYTES:
		return {}
	var snapshot := Hearth20Identity.network_identity()
	snapshot.merge({"revision": int(campaign.get("revision", 0)), "scene": snapshot_scene, "actors": projected_actors, "sheets": Hearth20TableData.owned_sheets(campaign, player_id), "fx": projected_fx, "map_png": map_bytes, "map_sha256": sha256(map_bytes), "assets": safe_assets, "view_actor_id":Hearth20Vision.view_actor_id(campaign,player_id,scene),"vision_mask": Hearth20Vision.public_mask(sight) if not bool(sight.blackout) else {}}, true)
	return snapshot

static func _public_scene(scene: Dictionary, sight: Dictionary = {}) -> Dictionary:
	var props: Array[Dictionary] = []
	var walls: Array[Dictionary] = []
	for wall in scene.get("walls", []):
		if wall is Dictionary and not bool(wall.get("hidden", false)) and wall.has("a") and wall.has("b"):
			var wall_a := _point_from_record(wall.a)
			var wall_b := _point_from_record(wall.b)
			if not _point_inside_scene(wall_a, scene) or not _point_inside_scene(wall_b, scene) or _segment_touches_fog(wall_a, wall_b, scene) or (not sight.is_empty() and not Hearth20Vision.segment_visible(wall_a, wall_b, sight)):
				continue
			walls.append({"a": {"x": wall_a.x, "y": wall_a.y}, "b": {"x": wall_b.x, "y": wall_b.y}})
	var doors: Array[Dictionary] = []
	for door in scene.get("doors", []):
		if door is Dictionary and not bool(door.get("hidden", false)) and door.has("a") and door.has("b"):
			var door_a := _point_from_record(door.a)
			var door_b := _point_from_record(door.b)
			if not _point_inside_scene(door_a, scene) or not _point_inside_scene(door_b, scene) or _segment_touches_fog(door_a, door_b, scene) or (not sight.is_empty() and not Hearth20Vision.segment_visible(door_a, door_b, sight)):
				continue
			doors.append({"a": {"x": door_a.x, "y": door_a.y}, "b": {"x": door_b.x, "y": door_b.y}, "open": bool(door.get("open", false))})
	for prop in scene.get("props", []):
		if prop is Dictionary and bool(prop.get("public", false)) and not bool(prop.get("hidden", false)) and finite_point(prop.get("position", null)) and _point_inside_scene(prop.position, scene) and not _is_point_fogged(prop.position, scene) and (sight.is_empty() or Hearth20Vision.visible(prop.position, sight)):
			var safe_prop := {"kind": str(prop.get("kind", "")).left(40), "label": str(prop.get("label", "")).left(80), "position": prop.position, "public": true}
			props.append(safe_prop)
	return {"id": "active-scene", "title": "Battle map", "width_cells": scene.width_cells, "height_cells": scene.height_cells, "cell_pixels": scene.get("cell_pixels", 64.0), "feet_per_cell": scene.feet_per_cell, "grid_visible": scene.get("grid_visible", true),"grid_opacity":scene.get("grid_opacity",0.34),"grid_thickness":scene.get("grid_thickness",1.0),"grid_color":scene.get("grid_color","#d8c99e"), "snap_to_grid": scene.get("snap_to_grid", true), "walls": walls, "doors": doors, "props": props,"dynamic_lighting":scene.get("dynamic_lighting",false),"ambient_light":scene.get("ambient_light","bright"),"natural_light":Hearth20NaturalLight.settings(scene)}

static func _segment_touches_fog(a: Vector2, b: Vector2, scene: Dictionary) -> bool:
	for rect_data in scene.get("fog_rects", []):
		var rect := Rect2()
		if rect_data is Rect2:
			rect = rect_data
		elif rect_data is Dictionary:
			rect = Rect2(Vector2(rect_data.get("x", 0.0), rect_data.get("y", 0.0)), Vector2(rect_data.get("width", 0.0), rect_data.get("height", 0.0)))
		else:
			continue
		if rect.has_point(a) or rect.has_point(b):
			return true
		var top_left := rect.position
		var top_right := Vector2(rect.end.x, rect.position.y)
		var bottom_right := rect.end
		var bottom_left := Vector2(rect.position.x, rect.end.y)
		if segment_intersects(a, b, top_left, top_right) or segment_intersects(a, b, top_right, bottom_right) or segment_intersects(a, b, bottom_right, bottom_left) or segment_intersects(a, b, bottom_left, top_left):
			return true
	return false

static func _mark_fx_private_for(event: Dictionary, player_id: String) -> void:
	var recipients: Array = event.get("private_recipients", [])
	if not recipients.has(player_id):
		recipients.append(player_id)
	event.private_recipients = recipients

static func _visible_assets(campaign: Dictionary, actors: Array[Dictionary]) -> Dictionary:
	var allowed := {}
	var encoded_bytes := 0
	for actor in actors:
		var asset_id := str(actor.get("asset_id", ""))
		if asset_id.is_empty() or allowed.has(asset_id):
			continue
		var bytes := Hearth20Assets.read_asset(campaign, asset_id, "token")
		if bytes.is_empty():
			continue
		# read_asset already checked this exact record, digest, dimensions and PNG.
		var verified: Dictionary=campaign.assets[asset_id]
		var base64: String=verified.base64
		encoded_bytes += base64.to_utf8_buffer().size()
		if encoded_bytes > MAX_PROJECTION_BYTES:
			return {"_h20_overflow": true}
		allowed[asset_id] = {
			"kind": "token", "mime_type": "image/png", "width": int(verified.width),
			"height": int(verified.height), "sha256": str(verified.sha256),
			"base64": base64, "byte_length": bytes.size(),
		}
	return allowed

static func _is_point_fogged(point: Vector2, scene: Dictionary) -> bool:
	for rect_data in scene.get("fog_rects", []):
		if rect_data is Rect2 and rect_data.has_point(point):
			return true
		if rect_data is Dictionary:
			var rect := Rect2(Vector2(rect_data.get("x", 0.0), rect_data.get("y", 0.0)), Vector2(rect_data.get("width", 0.0), rect_data.get("height", 0.0)))
			if rect.has_point(point):
				return true
	return false

static func _clean_recipe_word(token: String) -> String:
	var trimmed := token.strip_edges()
	if trimmed.is_valid_float() and not trimmed.is_valid_int():
		return trimmed
	return token.strip_edges().replace(".", "").replace(",", "").replace("!", "").replace("?", "").replace(";", "").replace(":", "").replace("\"", "").replace("'", "").replace("(", "").replace(")", "").replace("[", "").replace("]", "")

static func _request_present(words: Array[String], noun: String) -> bool:
	return words.has(noun) or words.has(noun + "s")

static func _quantity_before(words: Array[String], noun_index: int, fallback: int = 1) -> int:
	for offset in range(1, 4):
		var index := noun_index - offset
		if index < 0:
			break
		var token := words[index]
		if token in ["a", "an", "the", "hidden", "secret", "connected"]:
			continue
		if token.is_valid_int():
			return int(token)
		if RECIPE_NUMBER_WORDS.has(token):
			return int(RECIPE_NUMBER_WORDS[token])
		# Permit a count to cross at most two ordinary adjectives while keeping
		# those words in unresolved_requests for DM review. Structural words and
		# other supported nouns stop the scan so counts do not bleed across lists.
		if RECIPE_STOP_WORDS.has(token) or KNOWN_REQUESTS.has(token) or _is_supported_prop_word(token):
			break
	return fallback

static func _is_supported_prop_word(token: String) -> bool:
	for noun in ["campfire", "campfires", "fire", "fires", "tent", "tents", "cache", "caches", "trap", "traps", "pillar", "pillars", "pew", "pews", "altar", "altars", "torch", "torches", "well", "wells", "bridge", "bridges"]:
		if noun == token:
			return true
	return false

static func _requested_quantity(words: Array[String], aliases: Array) -> int:
	var total := 0
	for index in words.size():
		if aliases.has(words[index]):
			total += _quantity_before(words, index)
	return total

static func _recipe_cell_for_prop(rooms: Array[Dictionary], occupied: Dictionary) -> Dictionary:
	for room in rooms:
		var bounds: Dictionary = room.grid
		for y in range(int(bounds.y), int(bounds.y + bounds.height)):
			for x in range(int(bounds.x), int(bounds.x + bounds.width)):
				var key := "%d,%d" % [x, y]
				if occupied.has(key):
					continue
				occupied[key] = true
				return {"room_id": str(room.id), "position": {"x": x, "y": y}}
	return {}

static func _modifier_index(words: Array[String], modifier: String, noun: String, consumed: Array[int]) -> int:
	var articles := ["a", "an", "the"]
	for index in words.size():
		if words[index] != modifier or consumed.has(index):
			continue
		for offset in range(1, 4):
			var candidate_index := index + offset
			if candidate_index >= words.size():
				break
			var candidate_word := words[candidate_index]
			if candidate_word == noun or candidate_word == noun + "s":
				return index
			if not articles.has(candidate_word):
				break
	return -1

static func point_is_visible(point: Vector2, scene: Dictionary) -> bool:
	return not _is_point_fogged(point, scene)

static func path_is_visible(start: Vector2, end: Vector2, scene: Dictionary) -> bool:
	return not _segment_touches_fog(start, end, scene)

static func sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		context.update(bytes)
	return context.finish().hex_encode()

static func _neutral_id(recipient: String, internal_id: String) -> String:
	return "token-" + sha256((recipient + ":" + internal_id).to_utf8_buffer()).left(20)

static func _mask_fogged_map(source_bytes: PackedByteArray, scene: Dictionary) -> PackedByteArray:
	if source_bytes.is_empty():
		return PackedByteArray()
	var cache_key="fog:"+sha256(var_to_bytes([scene.get("fog_rects",[]),scene.get("cell_pixels",64.)]))
	var cached=Hearth20MaskedImageCache.lookup(cache_key,source_bytes)
	if not cached.is_empty():return cached
	var image := Hearth20Assets.decode_map(source_bytes)
	if image==null:
		return PackedByteArray()
	var cell_pixels := float(scene.get("cell_pixels", 64.0))
	for rect_data in scene.get("fog_rects", []):
		var rect := Rect2()
		if rect_data is Rect2:
			rect = rect_data
		elif rect_data is Dictionary:
			rect = Rect2(Vector2(rect_data.get("x", 0.0), rect_data.get("y", 0.0)), Vector2(rect_data.get("width", 0.0), rect_data.get("height", 0.0)))
		else:
			continue
		var pixel_rect := Rect2i(Vector2i(floori(rect.position.x * cell_pixels), floori(rect.position.y * cell_pixels)), Vector2i(ceili(rect.size.x * cell_pixels), ceili(rect.size.y * cell_pixels)))
		pixel_rect = pixel_rect.intersection(Rect2i(0, 0, image.get_width(), image.get_height()))
		image.fill_rect(pixel_rect,Color.BLACK)
	var result=image.save_png_to_buffer();Hearth20MaskedImageCache.put(cache_key,source_bytes,result);return result

static func author_recipe(prompt: String, seed: int = 1) -> Dictionary:
	var text := prompt.strip_edges().to_lower()
	if text.is_empty() or text.length() > MAX_RECIPE_TEXT:
		return {"ok": false, "error": "Enter a scene request of at most %d characters." % MAX_RECIPE_TEXT}
	var words: Array[String] = []
	for token in text.split(" ", false):
		words.append(_clean_recipe_word(str(token)))
	var pattern := "ruins"
	if "forest" in text or "camp" in text:
		pattern = "forest_camp"
	elif "chapel" in text or "pew" in text or "altar" in text:
		pattern = "ruined_chapel"
	elif "cave" in text or "dungeon" in text:
		pattern = "cave"
	elif "castle" in text or "throne" in text:
		pattern = "castle"
	var requested_rooms := 3
	for room_word_index in words.size():
		if words[room_word_index] not in ["room", "rooms"]:
			continue
		requested_rooms = _quantity_before(words, room_word_index, 3)
		break
	var room_count := clampi(requested_rooms, 1, 20)
	var width := mini(MAX_SIDE, maxi(18, room_count * 6 + 2))
	var rooms: Array[Dictionary] = []
	var corridors: Array[Dictionary] = []
	var props: Array[Dictionary] = []
	for index in room_count:
		var x := 1 + index * 6
		var y := 3
		var room_id := "room-%02d" % index
		rooms.append({"id": room_id, "kind": pattern, "public_label": "Room %d" % (index + 1), "grid": {"x": x, "y": y, "width": 5, "height": 5}, "initially_visible": index == 0})
		if index > 0:
			corridors.append({"id": "hall-%02d" % index, "room_ids": ["room-%02d" % (index - 1), room_id], "grid": {"x": x - 1, "y": y + 2, "width": 1, "height": 1}, "width_cells": 1, "orientation": "east-west"})
	var candidates := [
		{"aliases": ["campfire", "campfires"], "kind": "campfire"},
		{"aliases": ["fire", "fires"], "kind": "campfire"},
		{"aliases": ["tent", "tents"], "kind": "tent"},
		{"aliases": ["cache", "caches"], "kind": "hidden_cache"},
		{"aliases": ["trap", "traps"], "kind": "trap"},
		{"aliases": ["pillar", "pillars"], "kind": "pillar"},
		{"aliases": ["pew", "pews"], "kind": "pew"},
		{"aliases": ["altar", "altars"], "kind": "altar"},
		{"aliases": ["torch", "torches"], "kind": "torch"},
		{"aliases": ["well", "wells"], "kind": "well"},
		{"aliases": ["bridge", "bridges"], "kind": "bridge"},
	]
	var occupied_cells := {}
	var consumed_modifiers: Array[int] = []
	var unresolved: Array[String] = []
	if requested_rooms < 1 or requested_rooms > 20:
		unresolved.append("out-of-range room count %d (supported 1–20); generated %d" % [requested_rooms, room_count])
	var prop_index := 0
	for candidate in candidates:
		var requested_count := _requested_quantity(words, candidate.aliases)
		if requested_count < 0:
			unresolved.append("out-of-range %s count %d; counts must be zero or greater" % [str(candidate.kind), requested_count])
			continue
		if requested_count == 0:
			continue
		var hidden_index := _modifier_index(words, "hidden", str(candidate.aliases[0]).trim_suffix("s"), consumed_modifiers)
		if hidden_index >= 0:
			consumed_modifiers.append(hidden_index)
		var secret_index := _modifier_index(words, "secret", str(candidate.aliases[0]).trim_suffix("s"), consumed_modifiers)
		if secret_index >= 0:
			consumed_modifiers.append(secret_index)
		var secret: bool = candidate.kind in ["hidden_cache", "trap"] or hidden_index >= 0 or secret_index >= 0
		var place_count := mini(requested_count, 100 - props.size())
		var placed := 0
		while placed < place_count:
			var cell := _recipe_cell_for_prop(rooms, occupied_cells)
			if cell.is_empty():
				break
			props.append({"id": "prop-%03d" % prop_index, "kind": candidate.kind, "label": candidate.kind.replace("_", " ").capitalize(), "room_id": cell.room_id, "position": cell.position, "visibility": "gm" if secret else "public", "gm_details": "DM review required" if secret else ""})
			prop_index += 1
			placed += 1
		if placed < requested_count:
			unresolved.append("unplaced %s count %d (placed %d; bounded scene capacity is %d props)" % [str(candidate.kind), requested_count - placed, placed, mini(100, room_count * 25)])
	for word_index in words.size():
		var clean := words[word_index]
		var supported_prop_word := false
		for candidate in candidates:
			if candidate.aliases.has(clean):
				supported_prop_word = true
				break
		if clean.is_empty() or KNOWN_REQUESTS.has(clean) or RECIPE_STOP_WORDS.has(clean) or RECIPE_NUMBER_WORDS.has(clean) or clean.is_valid_int() or consumed_modifiers.has(word_index) or supported_prop_word:
			continue
		if not unresolved.has(clean):
			unresolved.append(clean)
	if unresolved.size() > 64:
		var omitted_count := unresolved.size() - 63
		unresolved = unresolved.slice(0, 63)
		unresolved.append("%d more unsupported terms omitted; shorten prompt." % omitted_count)
	var recipe := {"schema_version": 1, "title": "Generated Hearth20 Scene", "prompt": prompt, "pattern": pattern, "grid": {"width_cells": width, "height_cells": 18, "feet_per_cell": 5, "coordinate_unit": "grid_cells"}, "rooms": rooms, "corridors": corridors, "props": props, "gm_only": {"secrets": []}, "unresolved_requests": unresolved, "provenance": {"generator": "hearth20-offline-recipe", "version": 1, "seed": seed}}
	return {"ok": true, "recipe": recipe, "unresolved_requests": unresolved.duplicate()}

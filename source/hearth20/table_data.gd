extends RefCounted
class_name Hearth20TableData
## Small shared data contract for owner sheets and recorded dice; no rules outcomes.

const ABILITIES := ["str", "dex", "con", "int", "wis", "cha"]
const SKILLS := {"Acrobatics": 1, "Animal Handling": 4, "Arcana": 3, "Athletics": 0, "Deception": 5, "History": 3, "Insight": 4, "Intimidation": 5, "Investigation": 3, "Medicine": 4, "Nature": 3, "Perception": 4, "Performance": 5, "Persuasion": 5, "Religion": 3, "Sleight of Hand": 1, "Stealth": 1, "Survival": 4}
const SHEET_FIELDS := ["name", "class", "subclass", "race", "background", "alignment", "level", "xp", "hp", "max_hp", "temp", "ac", "speed", "abilities", "prof_bonus", "initiative_bonus", "save_profs", "save_bonuses", "skills", "skill_bonuses", "conditions", "senses", "inspiration", "hit_die", "hit_dice", "death_success", "death_failure", "exhaustion", "weapon", "attack", "damage", "attack_profiles", "inventory", "equipment", "coins", "features", "spells", "spellbook", "prepared_spells", "slots", "slots_max", "spell_ability", "spell_dc", "spell_attack", "languages", "proficiencies", "defenses", "traits", "ideals", "bonds", "flaws", "backstory", "notes", "description", "resources","class_levels","xp_text","rules_version","custom_skills","passives","movement_speeds","hit_dice_text","special_senses","spell_resources","save_modifiers","custom_actions","conditional_notes","spellcasting","appearance","size_category","import_record"]

static func safe_value(value: Variant, depth: int = 0) -> Variant:
	if depth > 8:
		return null
	if value is String or value is StringName:
		return str(value).left(32000)
	if value is bool or value is int:
		return value
	if value is float:
		return value if is_finite(value) else 0.0
	if value is Array:
		var array: Array = []
		for entry in value.slice(0, 512):
			array.append(safe_value(entry, depth + 1))
		return array
	if value is Dictionary:
		var dictionary := {}
		for key in value.keys().slice(0, 4096):
			if key is String or key is StringName:
				dictionary[str(key).left(256)] = safe_value(value[key], depth + 1)
		return dictionary
	return null

static func sheet(actor: Dictionary) -> Dictionary:
	var result := {"id": str(actor.get("id", ""))}
	for field in SHEET_FIELDS:
		if actor.has(field):
			result[field] = safe_value(actor[field])
	result.name = str(actor.get("name", "Hero")).left(96)
	var abilities: Variant = actor.get("abilities", [10, 10, 10, 10, 10, 10])
	result.abilities = abilities.duplicate() if abilities is Array and abilities.size() == 6 else [10, 10, 10, 10, 10, 10]
	var settings: Variant = actor.get("vision", {})
	result.vision = {}
	if Hearth20Vision.valid_settings(settings):
		for field in ["enabled", "darkvision_feet", "bright_light_feet", "dim_light_feet","blindsight_feet","truesight_feet","tremorsense_feet"]:
			result.vision[field] = settings.get(field, true if field == "enabled" else 0.0)
		result.vision.darkvision_feet = Hearth20BoardTools.darkvision(actor)
	return result

static func owned_sheets(campaign: Dictionary, player_id: String) -> Array:
	var out=[]
	for actor in campaign.get("actors",[]):
		if actor.get("owner_player_id","")!=player_id or not actor.get("is_hero",false):continue
		out.append({"id":str(actor.id),"name":str(actor.get("name","Character")),"in_inventory":bool(actor.get("in_inventory",false)),"sheet_external":true})
	return out

static func ability_index(key: String) -> int:
	var cleaned := key.to_lower()
	if cleaned.is_valid_int():
		return int(cleaned) if int(cleaned) >= 0 and int(cleaned) < 6 else -1
	return ABILITIES.find(cleaned)

static func skill_name(key: String) -> String:
	for label in SKILLS:
		if str(label).to_lower().replace(" ", "_") == key.to_lower().replace(" ", "_"):
			return str(label)
	return ""

static func modifier(actor: Dictionary, kind: String, key: String) -> Dictionary:
	var abilities: Variant = actor.get("abilities", [10, 10, 10, 10, 10, 10])
	if not abilities is Array or abilities.size() != 6:
		return {"ok": false, "error": "This sheet needs six recorded ability scores."}
	for score in abilities:
		if not (score is int or score is float) or not is_finite(float(score)) or floorf(float(score)) != float(score) or float(score) < 1.0 or float(score) > 100.0:
			return {"ok": false, "error": "This sheet contains an invalid ability score."}
	for field in ["save_bonuses", "skill_bonuses", "skills"]:
		var bonuses: Variant = actor.get(field, {})
		if not bonuses is Dictionary:
			return {"ok": false, "error": "This sheet contains an invalid bonus record."}
		for number in bonuses.values():
			if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number)) > 1000.0:
				return {"ok": false, "error": "This sheet contains an invalid bonus."}
	if not actor.get("save_profs", []) is Array:
		return {"ok": false, "error": "This sheet contains invalid save training."}
	var index := ability_index(key)
	var label := ""
	if kind == "initiative":
		index = 1
		label = "Initiative"
	elif kind == "skill":
		label = skill_name(key)
		if label.is_empty():
			return {"ok": false, "error": "Choose a recorded skill."}
		index = int(SKILLS[label])
	elif kind in ["ability", "save"] and index >= 0:
		label = str(ABILITIES[index]).to_upper() + (" save" if kind == "save" else " check")
	else:
		return {"ok": false, "error": "Choose an ability, save, skill, initiative or dice roll."}
	var bonus := floori((float(abilities[index]) - 10.0) / 2.0) if abilities.size() == 6 else 0
	var proficiency := int(actor.get("prof_bonus", 2 + floori(float(clampi(int(actor.get("level", 1)), 1, 20) - 1) / 4.0)))
	if kind == "save":
		var saves: Dictionary = actor.get("save_bonuses", {})
		var key_name := str(ABILITIES[index])
		bonus = int(saves.get(key_name.to_upper(), saves.get(key_name, bonus + (proficiency if actor.get("save_profs", []).has(index) else 0))))
	elif kind == "skill":
		var skills: Dictionary = actor.get("skill_bonuses", {})
		bonus = int(skills.get(label, skills.get(label.to_lower().replace(" ", "_"), bonus + int(actor.get("skills", {}).get(label, 0)) * proficiency)))
	elif kind == "initiative":
		bonus = int(actor.get("initiative_bonus", bonus))
	return {"ok": true, "bonus": clampi(bonus, -1000, 1000), "label": label}

static func roll(actor: Dictionary, kind: String, key: String, mode: String, expression: String, rng: RandomNumberGenerator) -> Dictionary:
	if mode not in ["normal", "advantage", "disadvantage"]:
		return {"ok": false, "error": "Choose normal, advantage, or disadvantage."}
	var count := 1
	var sides := 20
	var bonus := 0
	var label := "Dice"
	if kind == "dice":
		var pattern := RegEx.new()
		pattern.compile("^([0-9]{1,2})d([0-9]{1,4})([+-][0-9]{1,4})?$")
		var match_result := pattern.search(expression.strip_edges().to_lower().replace(" ", ""))
		if match_result == null:
			return {"ok": false, "error": "Use dice such as 1d20+3 or 2d6. Up to 50 dice, d2 to d1000."}
		count = int(match_result.get_string(1))
		sides = int(match_result.get_string(2))
		bonus = int(match_result.get_string(3)) if not match_result.get_string(3).is_empty() else 0
		if count < 1 or count > 50 or sides < 2 or sides > 1000 or absi(bonus) > 1000:
			return {"ok": false, "error": "Dice exceed the supported limits."}
		if mode != "normal" and (count != 1 or sides != 20):
			return {"ok": false, "error": "Advantage and disadvantage apply to one d20."}
	else:
		var checked := modifier(actor, kind, key)
		if not checked.ok:
			return checked
		bonus = int(checked.bonus)
		label = str(checked.label)
	var dice: Array = []
	var total := 0
	for index in (2 if mode != "normal" else count):
		var value := rng.randi_range(1, sides)
		dice.append(value)
		total += value
	var kept := total
	if mode == "advantage":
		kept = maxi(int(dice[0]), int(dice[1]))
	elif mode == "disadvantage":
		kept = mini(int(dice[0]), int(dice[1]))
	var formula := "%dd%d" % [count, sides] + ("%+d" % bonus if bonus != 0 else "")
	return {"ok": true, "type": "roll", "label": label, "formula": formula, "dice": dice, "kept": kept, "modifier": bonus, "total": kept + bonus, "mode": mode}

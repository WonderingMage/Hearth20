extends RefCounted
class_name Hearth20Identity
## Hearth20 identity and campaign persistence boundary.
## These identifiers are development namespace values, not a release identity.

const PRODUCT_ID := "com.wonderingmage.hearth20.seated"
const PRODUCT_NAME := "Hearth20 Beta"
const EDITION := "hearth20-seated"
const VERSION := "0.3.1-beta"
const SCHEMA_ID := "hearth20.seated.campaign.v1"
const SCHEMA_VERSION := 1
const NETWORK_MAGIC := "HEARTH20-SEATED"
const NETWORK_PROTOCOL := 2
const UPDATE_NAMESPACE := "hearth20-seated-updates-v1"
const DEVELOPMENT_GATE_EDITION := "hearth20-seated-development-gate"
const SAVE_EXTENSION := "h20scampaign"
const SAVE_ROOT := "user://hearth20/campaigns"
const UPDATE_ROOT := "user://hearth20/updates"
const MAX_SAVE_BYTES := 64 * 1024 * 1024
const SERIALIZATION_RESERVED_KEYS := ["$h20_vector2", "$h20_rect2", "$h20_literal_dictionary"]

static func new_campaign(title: String = "New Hearth20 table") -> Dictionary:
	return {
		"product_id": PRODUCT_ID,
		"edition": EDITION,
		"schema_id": SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
		"title": title.strip_edges().left(96),
		"revision": 0,
		"active_scene": "scene-start",
		"scenes": [{
			"id": "scene-start", "title": "New scene", "width_cells": 24, "height_cells": 16,
			"feet_per_cell": 5.0, "cell_pixels": 64.0, "grid_visible": true, "snap_to_grid": true,
			"map_asset": "", "fog_rects": [], "walls": [], "doors": [], "props": [], "fx": [],
		}],
		"actors": [],
		"assets": {},
		"lite_state": {},
		"movement_ledger": {},
		"participants": {},
		"dm_notes": "",
	}

static func validate_project_dispatch(project_name: String, project_edition: String) -> Dictionary:
	if project_name != PRODUCT_NAME:
		return {"ok": false, "error": "Hearth20 dispatch requires the Hearth20 application name."}
	if project_edition not in [EDITION, DEVELOPMENT_GATE_EDITION]:
		return {"ok": false, "error": "Hearth20 dispatch refused a foreign edition configuration."}
	return {"ok": true, "product_id": PRODUCT_ID, "edition": EDITION, "development_gate": project_edition == DEVELOPMENT_GATE_EDITION}

static func network_identity() -> Dictionary:
	return {
		"product_id": PRODUCT_ID,
		"edition": EDITION,
		"network_magic": NETWORK_MAGIC,
		"protocol": NETWORK_PROTOCOL,
		"schema_id": SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
	}

static func validate_network_identity(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var expected := network_identity()
	for key in expected:
		if value.get(key, null) != expected[key]:
			return false
	return true

static func validate_campaign(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not value is Dictionary:
		return {"ok": false, "errors": ["Campaign must be an object."]}
	for key in ["product_id", "edition", "schema_id", "schema_version"]:
		if not value.has(key):
			errors.append("Missing identity field: %s." % key)
	if value.get("product_id") != PRODUCT_ID or value.get("edition") != EDITION:
		errors.append("This is not a Hearth20 campaign. No data was changed.")
	if value.get("schema_id") != SCHEMA_ID or int(value.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("Unsupported Hearth20 campaign schema.")
	if not value.get("scenes") is Array or value.get("scenes", []).size() > 256:
		errors.append("Campaign scenes are missing or exceed the limit.")
	if not value.get("actors") is Array or value.get("actors", []).size() > 2000:
		errors.append("Campaign actors are missing or exceed the limit.")
	if not value.get("assets") is Dictionary or value.get("assets", {}).size() > 4096:
		errors.append("Campaign asset table is missing or exceeds the limit.")
	if str(value.get("title", "")).length() > 96 or str(value.get("dm_notes", "")).length() > 100_000:
		errors.append("Campaign text exceeds the supported limit.")
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	return {"ok": true, "errors": []}

static func save_campaign(value: Dictionary, file_path: String) -> Dictionary:
	var checked := Hearth20Contracts.validate_campaign(value)
	if not checked.ok:
		return checked
	if not file_path.ends_with("." + SAVE_EXTENSION):
		return {"ok": false, "errors": ["Hearth20 campaigns must use .%s." % SAVE_EXTENSION]}
	if not file_path.begins_with(SAVE_ROOT + "/") or file_path.contains("..") or file_path.contains("\\"):
		return {"ok": false, "errors": ["Campaign saves must stay under Hearth20's separate user-data root."]}
	var json := JSON.stringify(_encode_variant(value))
	if json.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return {"ok": false, "errors": ["Campaign exceeds the save size limit."]}
	var parent := file_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
	if dir_error != OK:
		return {"ok": false, "errors": ["Could not create the Hearth20 campaign directory."]}
	var temporary := file_path + ".writing"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["Could not write Hearth20 campaign."]}
	file.store_string(json)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return {"ok": false, "errors": ["Could not flush Hearth20 campaign."]}
	var absolute_temp := ProjectSettings.globalize_path(temporary)
	var absolute_destination := ProjectSettings.globalize_path(file_path)
	if FileAccess.file_exists(file_path):
		var backup := file_path + ".previous"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
		var backup_error := DirAccess.rename_absolute(absolute_destination, ProjectSettings.globalize_path(backup))
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temp)
			return {"ok": false, "errors": ["Could not preserve the prior campaign save."]}
	var rename_error := DirAccess.rename_absolute(absolute_temp, absolute_destination)
	if rename_error != OK:
		return {"ok": false, "errors": ["Could not finish Hearth20 campaign save."]}
	return {"ok": true, "errors": [], "path": file_path}

static func load_campaign(file_path: String) -> Dictionary:
	if not file_path.ends_with("." + SAVE_EXTENSION) or not file_path.begins_with(SAVE_ROOT + "/") or file_path.contains("..") or file_path.contains("\\") or not FileAccess.file_exists(file_path):
		return {"ok": false, "errors": ["Choose an existing Hearth20 campaign file."]}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_SAVE_BYTES:
		return {"ok": false, "errors": ["Campaign file size is invalid."]}
	var parsed: Variant = _decode_variant(JSON.parse_string(file.get_as_text()))
	var checked := Hearth20Contracts.validate_campaign(parsed)
	if not checked.ok:
		return checked
	return {"ok": true, "errors": [], "campaign": parsed}

static func validate_update_manifest(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if not validate_network_identity(value):
		return false
	if value.get("update_namespace", "") != UPDATE_NAMESPACE or not value.get("version", "") is String:
		return false
	var version_pattern := RegEx.new()
	version_pattern.compile("^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[A-Za-z0-9.-]+)?$")
	return version_pattern.search(str(value.version)) != null

static func _encode_variant(value: Variant) -> Variant:
	if value is Vector2:
		return {"$h20_vector2": [value.x, value.y]}
	if value is Rect2:
		return {"$h20_rect2": [value.position.x, value.position.y, value.size.x, value.size.y]}
	if value is Dictionary:
		var escape_dictionary := false
		for reserved_key in SERIALIZATION_RESERVED_KEYS:
			if value.has(reserved_key):
				escape_dictionary = true
				break
		if escape_dictionary:
			var entries: Array = []
			for key in value:
				entries.append([str(key), _encode_variant(value[key])])
			return {"$h20_literal_dictionary": entries}
		var result := {}
		for key in value:
			result[str(key)] = _encode_variant(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_encode_variant(item))
		return result
	return value

static func _decode_variant(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size() == 1 and value.get("$h20_literal_dictionary") is Array:
			var entries: Array = value["$h20_literal_dictionary"]
			var literal := {}
			var valid_entries := true
			for entry in entries:
				if not entry is Array or entry.size() != 2 or not entry[0] is String or literal.has(entry[0]):
					valid_entries = false
					break
				literal[entry[0]] = _decode_variant(entry[1])
			if valid_entries:
				return literal
		if value.size() == 1 and value.get("$h20_vector2") is Array and value["$h20_vector2"].size() == 2:
			var vector_data: Array = value["$h20_vector2"]
			if vector_data.all(func(item): return (item is int or item is float) and is_finite(float(item))):
				return Vector2(float(vector_data[0]), float(vector_data[1]))
		if value.size() == 1 and value.get("$h20_rect2") is Array and value["$h20_rect2"].size() == 4:
			var rect_data: Array = value["$h20_rect2"]
			if rect_data.all(func(item): return (item is int or item is float) and is_finite(float(item))):
				return Rect2(Vector2(float(rect_data[0]), float(rect_data[1])), Vector2(float(rect_data[2]), float(rect_data[3])))
		var result := {}
		for key in value:
			result[key] = _decode_variant(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_decode_variant(item))
		return result
	return value

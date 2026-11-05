extends RefCounted
class_name Hearth20BestiaryCatalog
static var records: Array=[]
static func all() -> Array:
	if records.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://hearth20/bestiary/catalog.json"))
		if parsed is Dictionary and parsed.get("creatures") is Array: records=parsed.creatures
	return records
static func model_path(id: String) -> String:
	for entry in all():
		if entry.id==id:
			var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://hearth20/bestiary/model-manifest.json"))
			var video:="res://hearth20/bestiary/imported/"+id+".ogv"
			if manifest is Dictionary and manifest.get("models",{}) is Dictionary and manifest.models.get(id,{}) is Dictionary and manifest.models.get(id,{}).get("kind","")=="video" and ResourceLoader.exists(video,"VideoStream"): return video
			var replacement:="res://hearth20/bestiary/imported/"+id+".scn"
			if manifest is Dictionary and manifest.get("models",{}) is Dictionary and manifest.models.has(id) and ResourceLoader.exists(replacement,"PackedScene"): return replacement
			return "res://hearth20/bestiary/"+id+".scn"
	return ""
static func credit(id: String) -> String:
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://hearth20/bestiary/model-manifest.json"))
	if manifest is Dictionary and manifest.get("models",{}) is Dictionary:
		return str(manifest.models.get(id,{}).get("attribution","Original Hearth20 showcase sculpture."))
	return "Original Hearth20 showcase sculpture."

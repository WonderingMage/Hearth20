extends RefCounted
class_name Hearth20LiteWorldAdapter
## Minimal Hearth20-owned adapter for invoking Lite's unchanged rules module.

var campaign: Dictionary
var data: Dictionary
var client := false
var preview := false

func _init(source_campaign: Dictionary) -> void:
	campaign = source_campaign
	data = {
		"actors": source_campaign.get("actors", []),
		"lite": source_campaign.get("lite_state", {}).duplicate(true),
	}

func actor(actor_id: String) -> Dictionary:
	for entry in data.get("actors", []):
		if entry is Dictionary and str(entry.get("id", "")) == actor_id:
			return entry
	return {}

func sync_to_campaign() -> void:
	campaign.actors = data.get("actors", [])
	campaign.lite_state = data.get("lite", {}).duplicate(true)
	campaign.revision = int(campaign.get("revision", 0)) + 1

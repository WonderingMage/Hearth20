extends RefCounted
class_name Hearth20LiteWorldAdapter
## Minimal Hearth20-owned adapter for invoking Lite's unchanged rules module.

var campaign: Dictionary
var _data: Dictionary
var data: Dictionary:
	get:
		_data.actors=campaign.get("actors",[])
		return _data
	set(value):
		_data=value
		_data.actors=campaign.get("actors",[])
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
	# Map imports and onboarding can replace the array after the adapter is created.
	# The campaign owns that collection; saving must never restore an older one.
	_data.actors=campaign.get("actors",[])
	campaign.lite_state = _data.get("lite", {}).duplicate(true)

extends RefCounted
class_name Hearth20LiteRulesBridge
## Keeps Lite's reviewed rules implementation as the rules engine, without making
## Lite's project configuration, presentation, saves, network identity or updater
## the Hearth20 dispatcher. The supplied world adapter is Hearth20-owned.

const LITE_RULES_PATH := "res://scripts/lite_rules.gd"
const RULES_SCRIPT: Script = preload("res://scripts/lite_rules.gd")

var world_adapter: Object
var rules_engine: RefCounted

func attach(adapter: Object) -> Dictionary:
	if adapter == null or not _has_property(adapter, "data") or not adapter.get("data") is Dictionary:
		return {"ok": false, "error": "Hearth20 rules adapter must expose a campaign data dictionary."}
	var adapter_data: Dictionary = adapter.get("data")
	if not adapter_data.get("actors", []) is Array:
		return {"ok": false, "error": "Hearth20 rules adapter lacks a valid actor collection."}
	if not adapter_data.get("lite_state") is Dictionary:
		adapter_data.lite_state = {}
	# Lite's engine expects `data.lite`; map it only in this transient adapter view.
	if not adapter_data.has("lite"):
		adapter_data.lite = adapter_data.lite_state
	adapter.set("data", adapter_data)
	world_adapter = adapter
	rules_engine = RULES_SCRIPT.new(adapter)
	if rules_engine.has_method("ensure"):
		rules_engine.call("ensure")
	adapter_data = adapter.get("data")
	adapter_data.lite_state = adapter_data.lite
	adapter.set("data", adapter_data)
	return {"ok": true, "engine": rules_engine, "source": LITE_RULES_PATH}

func detach() -> void:
	if world_adapter != null and _has_property(world_adapter, "data") and world_adapter.get("data") is Dictionary:
		var adapter_data: Dictionary = world_adapter.get("data")
		if adapter_data.get("lite") is Dictionary:
			adapter_data.lite_state = adapter_data.lite
			adapter_data.erase("lite")
			world_adapter.set("data", adapter_data)
	world_adapter = null
	rules_engine = null

func is_ready() -> bool:
	return rules_engine != null and world_adapter != null

func sync_to_campaign() -> void:
	if world_adapter != null and world_adapter.has_method("sync_to_campaign"):
		world_adapter.call("sync_to_campaign")

func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

extends RefCounted
class_name Hearth20RoomWorlds
## Small public preset IDs only. No remote file paths.
const IDS=["fey_forest","blue_dungeon","gold_vault","infernal_wastes"]
const ROOT="res://hearth20/window_worlds/"
const PRESETS={
	"fey_forest":{"title":"Fey forest","short":"FEY","sun":1.7,"color":Color("#ffdda8"),"scatter":1.,"glow":0.},
	"blue_dungeon":{"title":"Azure dungeon","short":"AZURE","sun":.55,"color":Color("#93c8ff"),"scatter":.48,"glow":.85},
	"gold_vault":{"title":"Golden vault","short":"GOLD","sun":.70,"color":Color("#ffe18a"),"scatter":.65,"glow":.45},
	"infernal_wastes":{"title":"Infernal wastes","short":"HELL","sun":.58,"color":Color("#f14a3f"),"scatter":.50,"glow":.90}
}
static func valid(id: Variant) -> bool:return id is String and id in IDS
static func clean(id: Variant) -> String:return id if valid(id) else "fey_forest"

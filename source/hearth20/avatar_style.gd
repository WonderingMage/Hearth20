extends RefCounted
class_name Hearth20AvatarStyle
## Cosmetic choices only. The authenticated session decides who is the DM.
const ROBES={"amethyst":"#7356b5","crimson":"#b33c47","emerald":"#36966a","sapphire":"#367dad","ivory":"#ddd0ad","onyx":"#45444e"}
const METALS=["gold","silver"]
const CHAINS=["none","cuban","rope","layered"]
const HOST_PENDANT="d20"
const EYES={"oval":"Oval","round":"Round","tiny":"Tiny","wide":"Wide-eyed","sleepy":"Sleepy","angry":"Angry","worried":"Sad","joyful":"Joyful","wink":"Wink","stars":"Starstruck","hearts":"Hearts","spirals":"Spirals","lashes":"Lashes","crossed":"Crossed","lopsided":"Goofy","slit":"Almond","half":"Half eyes","shine":"Shine","squint":"Squint","tears":"Cry"}
const EYE_COLORS={"gold":"#ffeb38","ivory":"#fff6df","ice":"#7ddcff","emerald":"#72ffc1","violet":"#c9a0ff","rose":"#ff8bba"}
const EYE_TREATMENTS={"visor":"Solid visor","cartoon":"Sclera + iris"}
static func defaults(host=false) -> Dictionary:
	return {"robe":"amethyst","metal":"gold","chain":"cuban","pendant":"d20" if host else "none","eye_style":"oval","eye_color":"gold","eye_treatment":"visor"}
static func valid(value: Variant,host: bool) -> bool:
	if not value is Dictionary or value.size() not in [4,6,7]:return false
	for field in ["robe","metal","chain","pendant"]:
		if not value.get(field) is String:return false
	if value.size()>=6:
		if not value.get("eye_style") is String or not value.get("eye_color") is String or value.eye_style not in EYES or value.eye_color not in EYE_COLORS:return false
	if value.size()==7 and (not value.get("eye_treatment") is String or value.eye_treatment not in EYE_TREATMENTS):return false
	return value.robe in ROBES and value.metal in METALS and value.chain in CHAINS and value.pendant in (["none",HOST_PENDANT] if host else ["none"])
static func clean(value: Variant,host: bool) -> Dictionary:
	var result=defaults(host)
	if not value is Dictionary:return result
	if value.get("robe") in ROBES:result.robe=value.robe
	if value.get("metal") in METALS:result.metal=value.metal
	if value.get("chain") in CHAINS:result.chain=value.chain
	if value.get("eye_style") in EYES:result.eye_style=value.eye_style
	if value.get("eye_color") in EYE_COLORS:result.eye_color=value.eye_color
	if value.get("eye_treatment") in EYE_TREATMENTS:result.eye_treatment=value.eye_treatment
	result.pendant=HOST_PENDANT if host and value.get("pendant")==HOST_PENDANT else "none"
	return result
static func remembered(host: bool) -> Dictionary:
	var config=ConfigFile.new();config.load(Hearth20PlayerProfile.SETTINGS_PATH)
	return clean(config.get_value("avatar","host" if host else "player",defaults(host)),host)
static func remember(value: Dictionary,host: bool) -> void:
	if not valid(value,host):return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Hearth20PlayerProfile.ROOT))
	var config=ConfigFile.new();config.load(Hearth20PlayerProfile.SETTINGS_PATH)
	config.set_value("avatar","host" if host else "player",clean(value,host));config.save(Hearth20PlayerProfile.SETTINGS_PATH)

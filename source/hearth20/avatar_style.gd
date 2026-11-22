extends RefCounted
class_name Hearth20AvatarStyle
## Cosmetic choices only. The authenticated session decides who is the DM.
const ROBES={
	"amethyst":"#7356b5",
	"crimson":"#b33c47",
	"emerald":"#36966a",
	"sapphire":"#367dad",
	"ivory":"#ddd0ad",
	"onyx":"#45444e",
	"burgundy":"#722f47",
	"dusty_rose":"#bf728d",
	"coral":"#db7661",
	"terracotta":"#a55239",
	"copper":"#ae6e43",
	"amber":"#c48c37",
	"saffron":"#dfb753",
	"ochre":"#987437",
	"olive":"#7a803b",
	"moss":"#53683c",
	"forest":"#2a5941",
	"sage":"#879e72",
	"jade":"#4fb486",
	"seafoam":"#7dbdaf",
	"teal":"#287c83",
	"turquoise":"#46aabc",
	"midnight":"#2c3b68",
	"storm_blue":"#65768a",
	"cerulean":"#5c9fca",
	"cobalt":"#4c58ad",
	"periwinkle":"#818bd2",
	"lilac":"#ae92c1",
	"plum":"#624369",
	"orchid":"#a25e9c",
	"sand":"#bd9e71",
	"taupe":"#89786c",
	"slate":"#696a7c",
	"charcoal":"#292b35",
}
const CLASSIC_ROBES=["amethyst","crimson","emerald","sapphire","ivory","onyx"]
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
static func wire_style(style: Dictionary,extended_palette: bool) -> Dictionary:
	if extended_palette or style.robe in CLASSIC_ROBES:return style
	var dye:=Color(ROBES[style.robe])
	var fallback: String=CLASSIC_ROBES[0]
	var nearest_distance:=INF
	for id in CLASSIC_ROBES:
		var classic:=Color(ROBES[id])
		var delta:=Vector3(dye.r-classic.r,dye.g-classic.g,dye.b-classic.b)
		var distance:=delta.length_squared()
		if distance<nearest_distance:
			nearest_distance=distance
			fallback=id
	var result:=style.duplicate()
	result.robe=fallback
	return result
static func remembered(host: bool) -> Dictionary:
	var config=ConfigFile.new();config.load(Hearth20PlayerProfile.SETTINGS_PATH)
	return clean(config.get_value("avatar","host" if host else "player",defaults(host)),host)
static func remember(value: Dictionary,host: bool) -> void:
	if not valid(value,host):return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Hearth20PlayerProfile.ROOT))
	var config=ConfigFile.new();config.load(Hearth20PlayerProfile.SETTINGS_PATH)
	config.set_value("avatar","host" if host else "player",clean(value,host));config.save(Hearth20PlayerProfile.SETTINGS_PATH)

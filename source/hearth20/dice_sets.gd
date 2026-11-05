extends RefCounted
class_name Hearth20DiceSets
## Only trusted bundled dice can be selected; load one collection off-thread at a time.
const PLAYER_IDS: Array=["set-1","set-2","set-3","set-4","set-5","set-6","set-7"]
const NAMES: Dictionary={"set-1":"Astral Tide","set-2":"Emerald Dream","set-3":"Amethyst Mist","set-4":"Crimson Aurora","set-5":"Moonstone Ash","set-6":"Royal Sapphire","set-7":"Amber Sunfire","dm":"Dungeon Master's Forge"}
const ROOT: String="res://hearth20/dice_sets/"
static var cache: Dictionary={}
static var recency: Array=[]
static var pending: Array=[]
static var failed: Dictionary={}
static var loading: String=""
static func valid(id: Variant, player_only: bool=false) -> bool:
	return id is String and (PLAYER_IDS.has(id) or (not player_only and id=="dm"))
static func selected(role: String) -> String:
	return "dm" if role=="dm" else Hearth20PlayerProfile.dice_set()
static func request(id: String) -> void:
	if not valid(id) or cache.has(id) or failed.has(id) or id==loading or pending.has(id): return
	pending.append(id)
	poll()
static func poll() -> void:
	if not loading.is_empty():
		var path:=ROOT+loading+".scn"; var status:=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			cache[loading]=ResourceLoader.load_threaded_get(path); touch(loading); loading=""
		elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]: failed[loading]=true; loading=""
	if loading.is_empty() and not pending.is_empty():
		loading=pending.pop_front()
		if ResourceLoader.load_threaded_request(ROOT+loading+".scn","PackedScene",false)!=OK: failed[loading]=true; loading=""
static func ready(id: String) -> bool: return cache.has(id) or failed.has(id)
static func touch(id: String) -> void:
	recency.erase(id); recency.append(id)
	while recency.size()>2: cache.erase(recency.pop_front())
static func make(id: String, sides: int, value: int, secondary: bool=false, tens: bool=false) -> Node3D:
	if not cache.has(id) or sides not in [4,6,8,10,12,20]: return Hearth20DiceModel.make(sides,value,secondary,tens)
	touch(id)
	var collection: Node3D=cache[id].instantiate(); var die: Node3D=collection.get_node("d%d"%sides); collection.remove_child(die); collection.free()
	var body:=Node3D.new(); body.add_child(die)
	var logical:=value/10 if tens else value
	if sides==10 and logical==0: logical=10
	var axes: Dictionary=die.get_meta("value_axes"); var face: Dictionary=axes[clampi(logical,1,sides)]; var normal: Vector3=face.normal
	body.set_meta("result_basis",Basis.looking_at(normal,face.up,true)); body.set_meta("result_normal",normal); body.set_meta("result_value",value); body.set_meta("sides",sides); body.set_meta("face_count",sides); body.set_meta("dice_set",id)
	# This supplied DM d10 has sculpted tens. Ordinary d10s need ones glyphs.
	if id=="dm" and sides==10 and not tens:
		for part in die.get_children():
			if part.name=="OnesFaces": part.show()
			elif part is MeshInstance3D and part.mesh.surface_get_material(0).resource_name=="Numbers": part.hide()
		var lettering:=SystemFont.new(); lettering.font_names=PackedStringArray(["Georgia","DejaVu Serif"]); lettering.font_weight=700
		var amber:=StandardMaterial3D.new(); amber.albedo_color=Color("#ffb75b"); amber.metallic=.22; amber.roughness=.35; amber.emission_enabled=true; amber.emission=Color("#ffb75b"); amber.emission_energy_multiplier=.5
		for number in axes:
			var axis: Dictionary=axes[number];var numeral=Hearth20DiceNumeral.new();numeral.name="OnesNumeral%d"%number;numeral.setup(str(int(number)%10),.62,.72,Color("#ffb75b"),.5);numeral.position=axis.get("ones_center",axis.center+axis.normal*.03);numeral.basis=Basis.looking_at(axis.normal,axis.up,true);die.add_child(numeral)


	if secondary: _dim(die)
	return body
static func _dim(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(i)
			if material is StandardMaterial3D:
				var copy: StandardMaterial3D=material.duplicate(); copy.albedo_color=copy.albedo_color.darkened(.48); copy.emission_energy_multiplier*=.4; node.set_surface_override_material(i,copy)
	elif node is Label3D: node.modulate=node.modulate.darkened(.45)
	for child in node.get_children(): _dim(child)

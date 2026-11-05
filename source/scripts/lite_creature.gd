extends RefCounted
## Data-only custom creatures. No script, shader, scene, or arbitrary resource path.
const SHAPES=["box","sphere","cylinder","cone","torus"]
const FIELDS=["name","class","race","hp","max_hp","ac","speed","token_size","abilities","attack","weapon","damage","attack_profiles","notes","miniature","lite_model","color","size_category","known_spells","custom_spells","features","damage_resistances","damage_immunities","damage_vulnerabilities","slots","slots_max","spell_ability","spell_dc","spell_attack","save_bonuses","skill_bonuses","save_profs","skills","reach_ft","range_normal_ft","range_long_ft","attack_type"]
static func package(a: Dictionary) -> Dictionary:
	var actor={}
	for key in FIELDS:
		if a.has(key):actor[key]=a[key]
	return {"format":1,"application":"Hearthtable Lite creature","actor":actor}
static func vector_valid(value,minimum: float,maximum: float) -> bool:
	if not value is Array or value.size()!=3:return false
	for n in value:
		if not (n is int or n is float) or not is_finite(float(n)) or n<minimum or n>maximum:return false
	return true
static func valid(model) -> bool:
	if not model is Array or model.is_empty() or model.size()>64:return false
	for part in model:
		if not part is Dictionary:return false
		for key in part:
			if key not in ["shape","position","scale","rotation","color"]:return false
		if part.get("shape","") not in SHAPES or not vector_valid(part.get("position"),-6,6) or not vector_valid(part.get("scale"),.02,8) or not vector_valid(part.get("rotation",[0,0,0]),-360,360):return false
		if not part.get("color") is String or part.color.length()!=7 or not Color.html_is_valid(part.color):return false
	return true
static func make(parent: Node3D,model: Array):
	if not valid(model):return
	for part in model:
		var mesh: PrimitiveMesh
		match part.shape:
			"box":mesh=BoxMesh.new();mesh.size=Vector3.ONE
			"sphere":mesh=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=16;mesh.rings=8
			"cylinder","cone":mesh=CylinderMesh.new();mesh.bottom_radius=.5;mesh.top_radius=0 if part.shape=="cone" else .5;mesh.height=1;mesh.radial_segments=16
			_:mesh=TorusMesh.new();mesh.inner_radius=.35;mesh.outer_radius=.5;mesh.rings=16;mesh.ring_segments=8
		var node=MeshInstance3D.new();node.mesh=mesh
		var material=StandardMaterial3D.new();material.albedo_color=Color(part.color);material.roughness=.85;node.material_override=material
		node.position=Vector3(part.position[0],part.position[1],part.position[2]);node.scale=Vector3(part.scale[0],part.scale[1],part.scale[2]);var rot=part.get("rotation",[0,0,0]);node.rotation_degrees=Vector3(rot[0],rot[1],rot[2]);parent.add_child(node)

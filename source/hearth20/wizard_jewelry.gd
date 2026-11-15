extends RefCounted
class_name Hearth20WizardJewelry
## Immutable poses captured from offline closed-chain/torso contact simulations.
const BAKE="res://hearth20/wizard_chain_bake.json"
static var data={}
static var batches={}
static var ring: TorusMesh
static func vector(v: Array) -> Vector3:return Vector3(float(v[0]),float(v[1]),float(v[2]))
static func pose(record: Dictionary) -> Transform3D:
	return Transform3D(Basis(vector(record.basis[0]),vector(record.basis[1]),vector(record.basis[2])),vector(record.position))
static func variant(style: Dictionary,host: bool) -> String:
	var pendant=host and style.get("pendant")=="d20";var kind=str(style.get("chain","none"))
	if kind=="none":return "cuban_d20" if pendant else ""
	return kind+("_d20" if pendant else "")
static func record(id: String) -> Dictionary:
	if data.is_empty() and FileAccess.file_exists(BAKE):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(BAKE))
		if parsed is Dictionary:data=parsed
	return data.get("variants",{}).get(id,{})
static func make(id: String,material_value: Material) -> MultiMeshInstance3D:
	var settled=record(id)
	if not settled.get("settled",false):push_error("Missing settled wizard chain bake: "+id);return null
	if not batches.has(id):
		if ring==null:ring=TorusMesh.new();ring.inner_radius=.0135;ring.outer_radius=.0225;ring.rings=16;ring.ring_segments=8
		var batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=ring;batch.instance_count=settled.links.size();var index=0
		for group in settled.groups:
			var scale_value=float(group.ring_scale)
			for _i in int(group.count):
				var transform=pose(settled.links[index]);transform.basis=transform.basis.scaled_local(Vector3(scale_value,scale_value,scale_value*1.31));batch.set_instance_transform(index,transform);index+=1
		batches[id]=batch
	var node=MultiMeshInstance3D.new();node.name="BakedCollarChains";node.multimesh=batches[id];node.material_override=material_value;node.set_meta("physics_bake",id);node.set_meta("closed_chain",true);return node

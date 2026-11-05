extends Node3D
class_name Hearth20BestiaryActor
## Gentle sculpt animation remains separate from the user's orbit transform.
var elapsed:=0.0
var parts: Array=[]
func _ready() -> void:
	_collect(self)
func _collect(node: Node) -> void:
	if node is Node3D and node.has_meta("idle_motion"):
		parts.append({"node":node,"motion":str(node.get_meta("idle_motion")),"position":node.position,"rotation":node.rotation,"scale":node.scale,"phase":float(parts.size())*1.73})
	for child in node.get_children(): _collect(child)
func _process(delta: float) -> void:
	elapsed+=delta
	for part in parts:
		var n: Node3D=part.node
		var clock:=elapsed+float(part.phase)
		n.position=part.position; n.rotation=part.rotation; n.scale=part.scale
		match part.motion:
			"breath": n.scale=Vector3(part.scale)*Vector3(1.0+sin(clock*1.4)*.012,1.0+sin(clock*1.4)*.018,1)
			"hover": n.position.y+=sin(clock*.9)*.055
			"jaw": n.rotation.x+=sin(clock*.65)*.045
			"tendril": n.rotation.z+=sin(clock*.8)*.045; n.rotation.x+=cos(clock*.7)*.025
			"wing": n.rotation.z+=sin(clock*.65)*.025
			"eye": n.scale.y*=1.0-smoothstep(.10,0.0,absf(fposmod(clock,5.0)-.2))*.88

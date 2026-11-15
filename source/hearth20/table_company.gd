extends Node3D
class_name Hearth20TableCompany
## Public company only: no character stats, browser textures, or private sheets.
var session: Hearth20Session
var avatars: Dictionary={}
func setup(owner_session: Hearth20Session) -> void:
	session=owner_session;name="PartyAtTheTable";session.table_presence_changed.connect(rebuild)
	rebuild(session.presence_for("dm-local") if session.local_role=="dm" else session.table_roster)
static func seat(index: int,count: int) -> Vector3:
	var angle=lerpf(-.90,.90,float(index)/maxi(1,count-1)) if count>1 else 0.
	return Vector3(sin(angle)*2.85,.79,.10-cos(angle)*2.22)
func rebuild(roster: Array) -> void:
	for child in get_children():remove_child(child);child.queue_free()
	avatars.clear()
	var others=roster.filter(func(entry):return not entry.get("mine",false))
	var fitting=minf(1.,6./maxi(1,others.size()))
	for i in others.size():
		var entry=others[i];var wizard=Hearth20WizardAvatar.new();add_child(wizard);wizard.setup(entry.style,entry.host)
		wizard.position=seat(i,others.size());wizard.rotation.y=atan2(-wizard.position.x,2.45-wizard.position.z);wizard.scale=Vector3.ONE*fitting;avatars[entry.id]=wizard
		var nameplate=Label3D.new();nameplate.name="PublicDisplayName";nameplate.text=str(entry.name).left(40);nameplate.font_size=42;nameplate.pixel_size=.0017;nameplate.position=Vector3(0,1.55,0);nameplate.modulate=Color("#ead3a0");nameplate.outline_size=8;nameplate.billboard=BaseMaterial3D.BILLBOARD_ENABLED;wizard.add_child(nameplate)
		var record=Node3D.new();record.name="GenericPublicSheet_"+str(i);record.position=wizard.position+wizard.basis.z*.65;record.position.y=.855;record.rotation.y=wizard.rotation.y+PI;record.scale=Vector3.ONE*.65;add_child(record)
		var paper=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(.58,.72);paper.mesh=plane;var parchment=StandardMaterial3D.new();parchment.albedo_color=Color("#cab98e");parchment.roughness=.98;paper.material_override=parchment;record.add_child(paper)
		# Unreadable decorative rules are deliberately unrelated to the private sheet.
		var ink=StandardMaterial3D.new();ink.albedo_color=Color("#6c5235");ink.roughness=1.
		for line in 9:
			var stroke=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(.40 if line%3 else .24,.0005,.003);stroke.mesh=box;stroke.position=Vector3(0,.001,-.24+line*.055);stroke.material_override=ink;record.add_child(stroke)

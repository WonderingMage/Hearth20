extends Node3D
class_name Hearth20WizardAvatar
## Shared static body/hood meshes with emissive cartoon eyes. No mouth or tracking.
var hood: Node3D
var eyes: MeshInstance3D
var style={}
var host=false
static var cloth_cache={}
static var metal_cache={}
func setup(value: Dictionary,is_host: bool) -> void:
	host=is_host;style=Hearth20AvatarStyle.clean(value,host);name="HostWizard" if host else "PlayerWizard"
	var body=Hearth20GeneratedModels.make("wizard_body",Vector3(1.05,.95,1.0))
	if body!=null:add_child(body);_cloth(body)
	hood=Node3D.new();hood.name="IndependentHood";hood.position=Vector3(-.025,.70,-.16);add_child(hood)
	var hat=Hearth20GeneratedModels.make("wizard_hat",Vector3(.83,.76,.72))
	if hat!=null:hood.add_child(hat);_cloth(hat)
	if hat!=null:eyes=Hearth20WizardEyes.make(hat,style);hood.add_child(eyes)
	_jewelry()
func _cloth(node: Node) -> void:
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original=mesh.get_active_material(surface)
			if not original is StandardMaterial3D:continue
			var key=str(original.get_instance_id())+style.robe
			if not cloth_cache.has(key):
				var shader=Shader.new();shader.code="""
shader_type spatial;
uniform sampler2D cloth:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D relief:hint_normal,filter_linear_mipmap_anisotropic;
uniform vec3 dye:source_color=vec3(.45,.2,.7);
void fragment(){
 vec3 tex=texture(cloth,UV).rgb;
 float hi=max(tex.r,max(tex.g,tex.b));float lo=min(tex.r,min(tex.g,tex.b));
 float neutral=1.-smoothstep(.035,.17,hi-lo);
 float mask=neutral*smoothstep(.035,.12,hi);
 ALBEDO=mix(tex,tex*dye*2.1,mask*.88);
 NORMAL_MAP=texture(relief,UV).rgb;NORMAL_MAP_DEPTH=.65;
 ROUGHNESS=mix(.88,.44,1.-neutral);METALLIC=(1.-neutral)*.55;
}
"""
				var material_value=ShaderMaterial.new();material_value.shader=shader;material_value.set_shader_parameter("cloth",original.albedo_texture);material_value.set_shader_parameter("relief",original.normal_texture);material_value.set_shader_parameter("dye",Color(Hearth20AvatarStyle.ROBES[style.robe]));cloth_cache[key]=material_value
			mesh.set_surface_override_material(surface,cloth_cache[key])
func set_eyes(id: String,color: String,treatment="") -> void:
	if treatment.is_empty():treatment=style.eye_treatment
	if id not in Hearth20AvatarStyle.EYES or color not in Hearth20AvatarStyle.EYE_COLORS or treatment not in Hearth20AvatarStyle.EYE_TREATMENTS:return
	style.eye_style=id;style.eye_color=color;style.eye_treatment=treatment
	if is_instance_valid(eyes):eyes.material_override=Hearth20WizardEyes.material(id,color,treatment)
static func metal(kind: String) -> StandardMaterial3D:
	if not metal_cache.has(kind):
		var mat=StandardMaterial3D.new();mat.albedo_color=Color("#d9a449" if kind=="gold" else "#becbd5");mat.metallic=.88;mat.roughness=.27;metal_cache[kind]=mat
	return metal_cache[kind]
func _jewelry() -> void:
	var variant=Hearth20WizardJewelry.variant(style,host)
	if variant.is_empty():return
	var chain=Hearth20WizardJewelry.make(variant,metal(style.metal))
	if chain==null:return
	add_child(chain)
	# Defense in depth: role is supplied by the authoritative roster, never style.
	if not host or style.pendant!="d20":return
	var settled=Hearth20WizardJewelry.record(variant)
	if not settled.has("pendant"):return
	# Keep the simulated mount independent of the replaceable visual model.
	var pendant=Node3D.new();pendant.name="DMOnlyD20Pendant";pendant.set_meta("attachment_local",Vector3(0,.095,-.035));pendant.set_meta("replaceable_model",true)
	var visual=Hearth20WizardPendant.make(style.metal)
	if visual==null:pendant.free();return
	pendant.add_child(visual);pendant.transform=Hearth20WizardJewelry.pose(settled.pendant);add_child(pendant)

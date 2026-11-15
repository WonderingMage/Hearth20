extends RefCounted
class_name Hearth20WizardPendant
## User's repaired asset, fitted uniformly about the recorded bail center.
const ID="dm_d20_pendant"
static var materials={}
static func make(finish: String) -> Node3D:
	var model=Hearth20GeneratedModels.raw(ID)
	if model==null:return null
	var fit=Hearth20GeneratedModels.catalog[ID].pendant_fit
	model.transform=Transform3D(Basis.from_scale(Vector3.ONE*float(fit.scale)),Hearth20GeneratedModels.vector(fit.translation))
	model.name="GeneratedPendantVisual";model.set_meta("source_model",ID)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source=mesh.get_active_material(surface)
			if not source is StandardMaterial3D:continue
			var key=str(source.get_instance_id())+finish
			if not materials.has(key):
				var shader=Shader.new();shader.code="""
shader_type spatial;render_mode cull_disabled;
uniform sampler2D paint:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D relief:hint_normal,filter_linear_mipmap_anisotropic;
uniform sampler2D orm:filter_linear_mipmap_anisotropic;
uniform bool silver=false;uniform bool has_relief=true;
void fragment(){
 vec3 color=texture(paint,UV).rgb;
 if(silver){float luminance=dot(color,vec3(.2126,.7152,.0722));color=vec3(luminance)*vec3(.94,.99,1.07);}
 ALBEDO=color;
 vec3 orm_sample=texture(orm,UV).rgb;METALLIC=clamp(orm_sample.b,.72,.96);ROUGHNESS=clamp(orm_sample.g,.28,.68);
 if(has_relief){NORMAL_MAP=texture(relief,UV).rgb;NORMAL_MAP_DEPTH=.7;}
}
"""
				var mat=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("paint",source.albedo_texture);mat.set_shader_parameter("relief",source.normal_texture);mat.set_shader_parameter("orm",source.roughness_texture);mat.set_shader_parameter("silver",finish=="silver");mat.set_shader_parameter("has_relief",source.normal_texture!=null);materials[key]=mat
			mesh.set_surface_override_material(surface,materials[key])
	return model

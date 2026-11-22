extends "res://addons/gdgs/runtime/nodes/gaussian_splat_node.gd"
## Hearth20 prepared assets are already Godot Y-up. Do not flip them again.
var clip_to_windows=false
var apertures: Array=[]
var window_material: ShaderMaterial
func _apply_default_orientation_if_needed() -> void:pass
func configure_hearth20_window_material(material: ShaderMaterial) -> void:
	window_material=material
	if not clip_to_windows:return
	var centers=PackedVector3Array();var normals=PackedVector3Array();var dimensions=PackedVector2Array();var profiles=PackedVector2Array()
	for aperture in apertures.slice(0,5):
		centers.append(aperture.center);normals.append(aperture.normal);dimensions.append(Vector2(aperture.width,aperture.height))
		profiles.append(Vector2(aperture.get("arch_rise",aperture.width*.5),float(not aperture.has("arch_rise"))))
	var count=centers.size()
	centers.resize(5);normals.resize(5);dimensions.resize(5);profiles.resize(5)
	material.set_shader_parameter("h20_window_clip",true);material.set_shader_parameter("h20_window_count",count)
	material.set_shader_parameter("h20_window_centers",centers);material.set_shader_parameter("h20_window_normals",normals);material.set_shader_parameter("h20_window_dimensions",dimensions)
	material.set_shader_parameter("h20_window_profiles",profiles)

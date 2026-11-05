extends MeshInstance3D
class_name Hearth20DiceNumeral
## Center the visible glyph geometry, rather than a font's line box/baseline.
static var meshes={}
var double_sided=false:
	set(value):
		double_sided=value
		if material_override is BaseMaterial3D:material_override.cull_mode=BaseMaterial3D.CULL_DISABLED if value else BaseMaterial3D.CULL_BACK
func setup(text: String, height: float, max_width: float, tint=Color.WHITE, glow=.65) -> void:
	var key=str([text,height,max_width])
	if not meshes.has(key):
		var glyph=TextMesh.new();glyph.font=Hearth20Design.font(true);glyph.font_size=128;glyph.pixel_size=1./128.;glyph.depth=.004;glyph.text=text;glyph.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;glyph.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		var arrays=glyph.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bounds=glyph.get_aabb();var center=bounds.get_center()
		var fit=minf(height/maxf(.001,bounds.size.y),max_width/maxf(.001,bounds.size.x))
		for i in vertices.size():vertices[i]=(vertices[i]-center)*fit
		arrays[Mesh.ARRAY_VERTEX]=vertices
		var centered=ArrayMesh.new();centered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);meshes[key]=centered
	mesh=meshes[key]
	var ink=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.albedo_color=tint;ink.emission_enabled=true;ink.emission=tint;ink.emission_energy_multiplier=glow;ink.roughness=.3;ink.render_priority=10;material_override=ink
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_meta("ink_center",mesh.get_aabb().get_center());set_meta("result_text",text)

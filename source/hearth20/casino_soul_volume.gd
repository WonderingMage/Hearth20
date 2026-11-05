extends RefCounted
class_name Hearth20CasinoSoulVolume
## Heterogeneous vapor: drifting hollow faces dissolve into long advected trails.
const SHADER_PATH="res://hearth20/casino/soul-volume.gdshader"
static func material(faces: Array) -> ShaderMaterial:
	var shader=load(SHADER_PATH);var m=ShaderMaterial.new();m.shader=shader;m.render_priority=4
	if Hearth20FxVolume.density==null:Hearth20FxVolume.density=load("res://hearth20/fx_noise_volume.res")
	m.set_shader_parameter("density_volume",Hearth20FxVolume.density);m.set_shader_parameter("face_count",faces.size())
	var planes=PackedVector4Array()
	for face in faces:planes.append(Vector4(face.normal.x,face.normal.y,face.normal.z,face.distance))
	while planes.size()<20:planes.append(Vector4(0,0,0,2))
	m.set_shader_parameter("planes",planes);return m

static func animate(material_value: ShaderMaterial, frame: Dictionary, age: float) -> void:
	material_value.set_shader_parameter("age",age)
	material_value.set_shader_parameter("intensity",1.0+sin(age*.7)*.08)
	material_value.set_shader_parameter("heads",frame.heads)
	material_value.set_shader_parameter("directions",frame.directions)
	material_value.set_shader_parameter("trails",frame.tails)
	material_value.set_shader_parameter("appearances",frame.appearances)

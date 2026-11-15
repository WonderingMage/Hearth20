extends RefCounted
class_name Hearth20WizardEyes
## Original emissive UV masks projected onto the hood's real shadow-face surface.
const ATLAS="res://hearth20/wizard_eye_atlas.png"
const PHOSPHOR="res://hearth20/wizard_eye_phosphor.png"
const GRID=Vector2(4,5)
static var face_mesh: ArrayMesh
static var shadow_texture: Texture2D
static var atlas: Texture2D
static var phosphor: Texture2D
static var materials={}
static var icons={}
static func texture() -> Texture2D:
	if atlas==null:atlas=load(ATLAS)
	return atlas
static func icon(id: String) -> AtlasTexture:
	if not icons.has(id):
		var index=Hearth20AvatarStyle.EYES.keys().find(id);var image=AtlasTexture.new();image.atlas=texture();image.region=Rect2(index%4*256+32,index/4*256+58,192,128);image.filter_clip=true;icons[id]=image
	return icons[id]
static func _surface(node: Node3D,at: Transform3D,tool: SurfaceTool) -> void:
	at*=node.transform
	if node is MeshInstance3D and node.mesh!=null:
		for surface in node.mesh.get_surface_count():
			var original=node.mesh.surface_get_material(surface)
			if original is StandardMaterial3D and shadow_texture==null:shadow_texture=original.albedo_texture
			var arrays=node.mesh.surface_get_arrays(surface);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var uvs=arrays[Mesh.ARRAY_TEX_UV];var indices=arrays[Mesh.ARRAY_INDEX];var normal_basis=at.basis.inverse().transposed()
			for i in range(0,indices.size(),3):
				var a=indices[i];var b=indices[i+1];var c=indices[i+2];var center=at*((points[a]+points[b]+points[c])/3.);var normal=(normal_basis*(normals[a]+normals[b]+normals[c])).normalized()
				if center.z<-.03 or center.x<-.40 or center.x>.22 or center.y<.16 or center.y>.68 or normal.z<.10:continue
				for j in [a,b,c]:
					var p=at*points[j];var n=(normal_basis*normals[j]).normalized();tool.set_normal(n);tool.set_uv(Vector2((p.x+.13)/.40+.5,.5-(p.y-.33)/.35));tool.set_uv2(uvs[j]);tool.add_vertex(p+n*.0006)
	for child in node.get_children():
		if child is Node3D:_surface(child,at,tool)
static func material(id: String,color: String,treatment="visor") -> ShaderMaterial:
	var key=id+":"+color+":"+treatment
	if not materials.has(key):
		var shader=Shader.new();shader.code="""
shader_type spatial;
render_mode unshaded,shadows_disabled,depth_draw_never;
uniform sampler2D phosphor_map:filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D shadow_face:source_color,filter_linear_mipmap_anisotropic;
uniform vec2 cell=vec2(0.);
uniform vec2 grid=vec2(4.,5.);
uniform vec3 tint:source_color=vec3(1.,.75,.25);
uniform float halo_strength=.8;
uniform bool cartoon=false;
void fragment(){
 float inside=step(0.,UV.x)*step(0.,UV.y)*step(UV.x,1.)*step(UV.y,1.);
 vec4 field=texture(phosphor_map,(cell+clamp(UV,vec2(.004),vec2(.996)))/grid)*inside;
 float iris=cartoon?field.g:0.;
 float core=field.r*(1.-iris);
 float dark_iris=1.-smoothstep(.02,.45,iris);
 float near_glow=field.b*dark_iris;float wide_glow=field.a*dark_iris;
 float rows=UV.y*48.;float resolve=1.-smoothstep(.5,1.2,fwidth(rows));
 float scanline=mix(1.,.88+.12*cos(rows*6.2831853),resolve);
 float grille=mix(1.,.985+.015*cos(UV.x*128.*6.2831853),1.-smoothstep(.4,1.,fwidth(UV.x*128.)));
 vec3 original=texture(shadow_face,UV2).rgb;
 float black_face=1.-smoothstep(.10,.24,max(original.r,max(original.g,original.b)));
 // Unshaded Compatibility rendering uses ALBEDO directly, including in darkness.
 ALBEDO=tint*(core*1.05*scanline*grille+halo_strength*(near_glow*.85+wide_glow*.60)*(1.-field.r));
 ALPHA=clamp(field.r+halo_strength*(near_glow*.85+wide_glow*.65),0.,1.)*black_face;
}
"""
		if phosphor==null:phosphor=load(PHOSPHOR)
		var index=Hearth20AvatarStyle.EYES.keys().find(id);var mat=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("phosphor_map",phosphor);mat.set_shader_parameter("shadow_face",shadow_texture);mat.set_shader_parameter("cell",Vector2(index%4,index/4));mat.set_shader_parameter("grid",GRID);mat.set_shader_parameter("tint",Color(Hearth20AvatarStyle.EYE_COLORS[color]));mat.set_shader_parameter("cartoon",treatment=="cartoon");materials[key]=mat
	return materials[key]
static func make(hat: Node3D,style: Dictionary) -> MeshInstance3D:
	if face_mesh==null:
		var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);_surface(hat,Transform3D.IDENTITY,tool);face_mesh=tool.commit()
	var eyes=MeshInstance3D.new();eyes.name="EmissiveEyes";eyes.mesh=face_mesh;eyes.material_override=material(style.eye_style,style.eye_color,style.eye_treatment);eyes.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;return eyes

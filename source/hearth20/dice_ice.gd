extends RefCounted
class_name Hearth20DiceIce
## Thin prismatic dendrites grow inward from the upper glazing seams.
static var meshes={}
static var crystal_material: ShaderMaterial
static func build(sides: int) -> MeshInstance3D:
	if not meshes.has(sides):
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in Hearth20DiceModel.shape(sides):
			var n: Vector3=face.normal;var basis=Basis.looking_at(n,Vector3.RIGHT if absf(n.y)>.98 else Vector3.UP,true)
			for edge in face.vertices.size():
				var a: Vector3=face.vertices[edge];var b: Vector3=face.vertices[(edge+1)%face.vertices.size()]
				if (basis.inverse()*((a+b)*.5-face.center)).y<.02:continue
				for cluster in 3:
					var root: Vector3=face.center+(a.lerp(b,.19+float(cluster)*.28)-face.center)*.88-n*.016
					var inward=(face.center-root).slide(n).normalized();var across=n.cross(inward).normalized()
					var length_value=minf(.14+.06*sin(float(edge*7+cluster)*2.31+1.),maxf(.035,(root-face.center).length()-.31))
					var tip=root+inward*length_value+across*sin(float(cluster)*2.1)*.022
					_spear(st,root,tip,n,.0105,.010)
					for branch in 3:
						var at=root.lerp(tip,.25+float(branch)*.23)
						for side in [-1,1]:
							var branch_tip=at+(inward*.62+across*.78*side)*length_value*(.44-float(branch)*.10)
							_spear(st,at,branch_tip,n,.0055,.006,.25+float(branch)*.23,.48+float(branch)*.23)
		meshes[sides]=st.commit()
	var node=MeshInstance3D.new();node.name="FreezingCrystalSpears";node.mesh=meshes[sides];node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.material_override=_material().duplicate();return node
static func _spear(st: SurfaceTool,a: Vector3,b: Vector3,n: Vector3,width: float,height: float,start=0.,finish=1.) -> void:
	var across=(b-a).cross(n).normalized()*width;var ridge=a.lerp(b,.40)+n*height;var left=a+across;var right=a-across
	for triangle in [[a,left,ridge],[left,b,ridge],[b,right,ridge],[right,a,ridge]]:
		var normal: Vector3=(triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
		if normal.dot(n)<0.:normal=-normal
		for i in 3:
			var along=a.distance_to(triangle[i])/maxf(.001,a.distance_to(b))
			st.set_normal(normal);st.set_uv(Vector2(along,float(i)/2.));st.set_uv2(Vector2(lerpf(start,finish,along),0));st.set_color(Color(.70+.30*float(i)/2.,1,1,1));st.add_vertex(triangle[i])
static func _material() -> ShaderMaterial:
	if crystal_material!=null:return crystal_material
	var shader=Shader.new();shader.code="""
shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_mix;
uniform float growth=.45;
void fragment(){
 if(UV2.x>growth)discard;
 float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
 float glint=pow(1.-facing,3.);float spine=pow(1.-abs(UV.y*2.-1.),6.);
 vec3 cold=mix(vec3(.33,.55,.70),vec3(.81,.94,1.),glint*.7+spine*.3);
 ALBEDO=cold;EMISSION=cold*(.09+glint*.22);ALPHA=(.50+glint*.30+spine*.13)*(1.-smoothstep(growth-.06,growth,UV2.x));
}
""";crystal_material=ShaderMaterial.new();crystal_material.shader=shader;crystal_material.render_priority=5;return crystal_material

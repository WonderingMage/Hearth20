extends RefCounted
class_name Hearth20SoulReveal
## A shared clock keeps five souls, the glazing, aura and glyph in one reveal.
const ROLL_SECONDS=1.15
const DURATION=2.35
static func envelope(time: float) -> Dictionary:
	if time<0.:return {"gather":0.,"morph":0.,"consume":0.,"flash":0.,"formation":0.,"rays":0.}
	var release=smoothstep(2.7,4.3,time)
	return {"gather":smoothstep(0.,.85,time)*(1.-release),"morph":smoothstep(.80,1.70,time)*(1.-release),"consume":smoothstep(1.15,2.,time)*(1.-release),"flash":smoothstep(.65,1.20,time)*(1.-smoothstep(1.35,2.25,time)),"formation":smoothstep(1.30,2.05,time),"rays":smoothstep(1.45,2.20,time)}
static func numeral_material() -> ShaderMaterial:
	var shader=Shader.new();shader.code="""
shader_type spatial;
render_mode unshaded,cull_back,depth_draw_never,blend_add;
uniform float formation=0.;
varying vec3 ink;
void vertex(){ink=VERTEX;}
void fragment(){
 float grain=fract(sin(dot(floor(ink*180.),vec3(12.9898,78.233,37.719)))*43758.5453);
 float edge=formation*1.12-grain;
 if(edge<0.)discard;
 float ignition=1.-smoothstep(0.,.12,edge);
 ALBEDO=vec3(.86,.94,1.);EMISSION=vec3(1.)*(.40+ignition*1.2);
 ALPHA=smoothstep(0.,.07,edge);
}
""";var material_value=ShaderMaterial.new();material_value.shader=shader;material_value.render_priority=10;return material_value
static func aura(face: Dictionary,basis: Basis) -> MeshInstance3D:
	var node=MeshInstance3D.new();node.name="SoulConfluenceAura";var quad=QuadMesh.new();quad.size=Vector2(2.2,2.2);node.mesh=quad;node.basis=basis;node.position=face.center+face.normal*.038;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader=Shader.new();shader.code="""
shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_add;
uniform float flash=0.;uniform float rays=0.;uniform float age=0.;
uniform int edge_count=4;uniform vec3 edges[8];
void fragment(){
 vec2 p=(UV-.5)*2.2;p.y=-p.y;
 float d=-20.;for(int k=0;k<8;k++){if(k>=edge_count)break;d=max(d,dot(p,edges[k].xy)-edges[k].z);}
 float pane=1.-smoothstep(-.035,.065,d);
 float halo=exp(-max(0.,d)*17.)*.34;
 float radius=length(p);float angle=atan(p.y,p.x);
 float filaments=pow(.5+.5*sin(angle*19.+sin(angle*7.+age*.38)*1.9),12.);
 filaments+=pow(.5+.5*sin(angle*31.-age*.22),22.)*.33;
 float radial=exp(-radius*4.5)*smoothstep(.10,.23,radius);
 float breath=.86+.14*sin(age*1.3);
 float light=flash*(pane*.78+halo)+rays*(filaments*radial*.34+exp(-radius*8.)*.075)*breath;
 ALBEDO=vec3(.83,.92,1.);EMISSION=vec3(1.)*light*1.45;ALPHA=clamp(light,0.,.95);
}
""";var material_value=ShaderMaterial.new();material_value.shader=shader;material_value.render_priority=9
	var edges=PackedVector3Array();var points=[]
	for vertex in face.vertices:var p=basis.inverse()*(vertex-face.center);points.append(Vector2(p.x,p.y)*.88)
	for i in points.size():
		var a: Vector2=points[i];var b: Vector2=points[(i+1)%points.size()];var tangent=(b-a).normalized();var normal=Vector2(tangent.y,-tangent.x);var distance=normal.dot(a)
		if distance<0.:normal=-normal;distance=-distance
		edges.append(Vector3(normal.x,normal.y,distance))
	material_value.set_shader_parameter("edge_count",edges.size())
	while edges.size()<8:edges.append(Vector3(0,0,20))
	material_value.set_shader_parameter("edges",edges);node.material_override=material_value;return node
static func glyph_anchors(mesh: Mesh) -> Array:
	var vertices: PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var anchors=[];var bounds=mesh.get_aabb()
	for i in 5:
		var angle=TAU*float(i)/5.+PI/2;var target=Vector2(cos(angle)*bounds.size.x*.45,sin(angle)*bounds.size.y*.45);var nearest=Vector3.ZERO;var score=INF
		for vertex in vertices:
			var distance=Vector2(vertex.x,vertex.y).distance_squared_to(target)
			if distance<score:score=distance;nearest=Vector3(vertex.x,vertex.y,0)
		anchors.append(nearest*.70)
	return anchors

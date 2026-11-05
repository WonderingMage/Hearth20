extends RefCounted
class_name Hearth20CathedralDie
## Shared detailed meshes: broad forged came, inset glazing and chased relief.
static var cache={}
static var brass: ShaderMaterial
static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uvs: Array, colors: Array=[]) -> void:
	var n=(b-a).cross(c-a).normalized()
	if n.dot((a+b+c)/3.)<0:n=-n
	for i in 3:
		st.set_normal(n);st.set_uv(uvs[i]);st.set_color(colors[i] if not colors.is_empty() else Color.WHITE);st.add_vertex([a,b,c][i])
static func build(sides: int) -> Dictionary:
	if cache.has(sides):return cache[sides]
	var faces=Hearth20DiceModel.shape(sides);var glazing=SurfaceTool.new();glazing.begin(Mesh.PRIMITIVE_TRIANGLES);var metal=SurfaceTool.new();metal.begin(Mesh.PRIMITIVE_TRIANGLES);var edges={};var points=[]
	for face in faces:
		var center: Vector3=face.center;var n: Vector3=face.normal;var u=(face.vertices[0]-center).normalized();var v=n.cross(u).normalized();var radius=center.distance_to(face.vertices[0])
		var outer=[];var inner=[];var rear=[]
		for p in face.vertices:
			outer.append(center+(p-center)*.947-n*.014);inner.append(center+(p-center)*.88-n*.022)
			rear.append(center+(p-center)*.74-n*Hearth20SoulMotion.GLASS_INSET)
		for i in outer.size():
			var j=(i+1)%outer.size();var uv_center=Vector2(.5,.5);var ui=uv_center+Vector2((inner[i]-center).dot(u),(inner[i]-center).dot(v))*.5/radius;var uj=uv_center+Vector2((inner[j]-center).dot(u),(inner[j]-center).dot(v))*.5/radius
			# Clear broad optical face with a real beveled perimeter and thickness.
			_triangle(glazing,center-n*.022,inner[j],inner[i],[uv_center,uj,ui],[Color(1,1,1),Color(.18,1,1),Color(.18,1,1)])
			var oi=uv_center+Vector2((outer[i]-center).dot(u),(outer[i]-center).dot(v))*.5/radius;var oj=uv_center+Vector2((outer[j]-center).dot(u),(outer[j]-center).dot(v))*.5/radius
			_triangle(glazing,inner[i],inner[j],outer[j],[ui,uj,oj],[Color(.18,1,1),Color(.18,1,1),Color(0,1,1)])
			_triangle(glazing,inner[i],outer[j],outer[i],[ui,oj,oi],[Color(.18,1,1),Color(0,1,1),Color(0,1,1)])
			# An inset rear lip creates a visibly deep glass reveal below the came.
			_triangle(glazing,inner[i],rear[i],rear[j],[ui,ui,uj],[Color(0,1,0),Color(0,1,0),Color(0,1,0)])
			_triangle(glazing,inner[i],rear[j],inner[j],[ui,uj,uj],[Color(0,1,0),Color(0,1,0),Color(0,1,0)])
			var a: Vector3=face.vertices[i];var b: Vector3=face.vertices[j];var key=str(a)+str(b) if str(a)<str(b) else str(b)+str(a)
			if not edges.has(key):edges[key]=[a,b]
			if not a in points:points.append(a)
			# Chased leaf at each face corner, raised above the glazing.
			var tip=center+(a-center)*.77+n*.008;var root=center+(a-center)*.48+n*.008;var tangent=(a-center).cross(n).normalized()
			_leaf(metal,root,tip,tangent,n,.042)
	for edge in edges.values():_came(metal,edge[0],edge[1])
	for p in points:_boss(metal,p)
	metal.generate_tangents();var result={"glass":glazing.commit(),"frame":metal.commit(),"faces":faces};cache[sides]=result;return result
static func _came(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var axis=(b-a).normalized();var outward=((a+b)*.5).normalized();var cross_axis=axis.cross(outward).normalized();var length_value=a.distance_to(b)
	# T-shaped came wraps over both glazing edges; shoulders and a raised center.
	var profile=[Vector2(-.061,-.026),Vector2(-.061,-.001),Vector2(-.046,.014),Vector2(-.025,.022),Vector2(-.014,.039),Vector2(.014,.039),Vector2(.025,.022),Vector2(.046,.014),Vector2(.061,-.001),Vector2(.061,-.026)]
	var sections=32
	for k in sections:
		for j in profile.size():
			var next=(j+1)%profile.size();var vertices=[];var uv=[]
			for spec in [[k,j],[k+1,j],[k+1,next],[k,next]]:
				var t=float(spec[0])/sections;var p: Vector2=profile[spec[1]];var hammer=sin(spec[0]*17.71+spec[1]*6.31+length_value)*.0016
				vertices.append(a.lerp(b,t)+cross_axis*p.x+outward*(p.y+hammer));uv.append(Vector2(t*length_value*2.5,float(spec[1])/profile.size()))
			_triangle(st,vertices[0],vertices[1],vertices[2],[uv[0],uv[1],uv[2]]);_triangle(st,vertices[0],vertices[2],vertices[3],[uv[0],uv[2],uv[3]])
	# Two raised continuous chased rails above the forged flange.
	for side in [-1,1]:
		var previous=a+cross_axis*.034*side+outward*.018
		for k in range(1,33):
			var t=float(k)/32.;var at=a.lerp(b,t)+cross_axis*(.034*side+sin(t*TAU*3)*.004)+outward*.022
			_ribbon(st,previous,at,outward,.005);previous=at
	for k in range(1,8):
		var at=a.lerp(b,float(k)/8.)+outward*.043
		_leaf(st,at-axis*.025,at+axis*.025,cross_axis,outward,.018)
static func _ribbon(st: SurfaceTool,a: Vector3,b: Vector3,n: Vector3,width: float) -> void:
	var across=(b-a).cross(n).normalized()*width
	_triangle(st,a-across,b+across,b-across,[Vector2(0,0),Vector2(1,1),Vector2(1,0)])
	_triangle(st,a-across,a+across,b+across,[Vector2(0,0),Vector2(0,1),Vector2(1,1)])
static func _leaf(st: SurfaceTool,root: Vector3,tip: Vector3,across: Vector3,n: Vector3,width: float) -> void:
	var left=[];var right=[];var ridge=[]
	for i in 7:
		var t=float(i)/6.;var breadth=sin(t*PI)*width*(.84+.16*cos(t*TAU*3));var mid=root.lerp(tip,t)
		left.append(mid-across*breadth);right.append(mid+across*breadth);ridge.append(mid+n*sin(t*PI)*width*.32)
	for i in 6:
		_triangle(st,left[i],ridge[i+1],left[i+1],[Vector2(0,0),Vector2(1,.5),Vector2(1,0)]);_triangle(st,left[i],ridge[i],ridge[i+1],[Vector2(0,0),Vector2(0,.5),Vector2(1,.5)])
		_triangle(st,ridge[i],right[i+1],ridge[i+1],[Vector2(0,.5),Vector2(1,1),Vector2(1,.5)]);_triangle(st,ridge[i],right[i],right[i+1],[Vector2(0,.5),Vector2(0,1),Vector2(1,1)])
static func _boss(st: SurfaceTool,p: Vector3) -> void:
	var n=p.normalized();var u=n.cross(Vector3.UP if absf(n.y)<.95 else Vector3.RIGHT).normalized();var v=n.cross(u)
	for ring in 3:
		var r0=float(ring)/3.;var r1=float(ring+1)/3.
		for k in 32:
			var points=[];var uvs=[]
			for spec in [[k,r0],[k+1,r0],[k+1,r1],[k,r1]]:
				var angle=float(spec[0])/32.*TAU;var radius=float(spec[1])*(.067+.015*cos(angle*4));points.append(p+(u*cos(angle)+v*sin(angle))*radius+n*(.037*(1.-float(spec[1])*float(spec[1]))));uvs.append(Vector2(angle/TAU,float(spec[1])))
			_triangle(st,points[0],points[1],points[2],[uvs[0],uvs[1],uvs[2]]);_triangle(st,points[0],points[2],points[3],[uvs[0],uvs[2],uvs[3]])
static func brass_material() -> ShaderMaterial:
	if brass!=null:return brass
	var shader=Shader.new();shader.code="""shader_type spatial;render_mode cull_disabled;
uniform sampler2D relief:filter_linear_mipmap,repeat_enable;
void fragment(){vec2 d=1./vec2(textureSize(relief,0));float h=texture(relief,UV).r;
vec2 slope=vec2(texture(relief,UV+vec2(d.x,0)).r-texture(relief,UV-vec2(d.x,0)).r,texture(relief,UV+vec2(0,d.y)).r-texture(relief,UV-vec2(0,d.y)).r);
NORMAL_MAP=normalize(vec3(-slope*2.4,1.))*.5+.5;NORMAL_MAP_DEPTH=.7;
ALBEDO=mix(vec3(.28,.14,.042),vec3(.86,.59,.20),smoothstep(.18,.65,h));METALLIC=.91;ROUGHNESS=mix(.42,.27,h);SPECULAR=.55;}
""";brass=ShaderMaterial.new();brass.shader=shader;brass.set_shader_parameter("relief",load("res://hearth20/casino/cathedral-brass-height-v1.png"));return brass
static func glass_material(sides: int=8) -> ShaderMaterial:
	var shader=Shader.new();shader.code="""shader_type spatial;render_mode unshaded,cull_back,depth_draw_never;
uniform sampler2D frost_map:filter_linear_mipmap,repeat_enable;
uniform sampler2D room:source_color,filter_linear_mipmap,repeat_disable;
uniform sampler2D souls:source_color,filter_linear,repeat_disable;
uniform bool has_buffers=false;
uniform vec4 soul_contacts[5];
uniform float reveal_glow=0.;
uniform vec3 result_normal=vec3(0,0,1);
uniform int face_count=8;
uniform vec4 inner_planes[20];
varying vec3 glass_point;
varying vec3 glass_eye;
varying vec3 glass_normal;
varying float clear_center;
void vertex(){clear_center=COLOR.r;glass_point=VERTEX;glass_normal=NORMAL;glass_eye=(inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1.)).xyz;}
void fragment(){
vec2 texel=1./vec2(textureSize(frost_map,0));float height=texture(frost_map,UV).r;
vec2 slope=vec2(texture(frost_map,UV+vec2(texel.x,0)).r-texture(frost_map,UV-vec2(texel.x,0)).r,texture(frost_map,UV+vec2(0,texel.y)).r-texture(frost_map,UV-vec2(0,texel.y)).r);
// Surface cold creates crystalline seams and a moving film of freezing breath,
// rather than an evenly sandblasted pane.
float cold_band=pow(1.-clear_center,3.);
float vapor=texture(frost_map,UV*1.7+vec2(TIME*.002,-TIME*.001)).r;
float condensation=smoothstep(.32,.80,vapor)*cold_band*(.75+.25*sin(TIME*.43+UV.x*8.));
float frost=clamp(smoothstep(.25,.84,height)*.045+cold_band*.055+condensation*.12,0.,.27);
vec3 normal=normalize(NORMAL+vec3(slope*.32,0.));float facing=clamp(dot(normal,normalize(VIEW)),.03,1.);
float fresnel=.045+.955*pow(1.-facing,5.);
vec3 local_ray=refract(normalize(glass_point-glass_eye),normalize(glass_normal),1./1.48);
float enter=0.;float leave=20.;
for(int k=0;k<20;k++){
 if(k>=face_count)break;
 float d=dot(local_ray,inner_planes[k].xyz);float gap=inner_planes[k].w-.145-dot(glass_point,inner_planes[k].xyz);
 if(abs(d)>.00001){float t=gap/d;if(d<0.)enter=max(enter,t);else leave=min(leave,t);}
}
float thickness=clamp(enter,.10,.65);float reveal=pow(1.-clear_center,5.);
// Finite frosted-glass transmission. The two explicit scene buffers include
// other transparent objects, unlike a normal opaque-only screen copy.
vec2 bend=normal.xy*.012*thickness+slope*.003;
vec2 at=clamp(SCREEN_UV+bend,vec2(.002),vec2(.998));vec2 blur=vec2(.00035+frost*.0035);
vec3 backdrop=texture(room,at).rgb*.28;
backdrop+=(texture(room,at+vec2(blur.x,0)).rgb+texture(room,at-vec2(blur.x,0)).rgb+texture(room,at+vec2(0,blur.y)).rgb+texture(room,at-vec2(0,blur.y)).rgb)*.13;
backdrop+=(texture(room,at+blur).rgb+texture(room,at-blur).rgb+texture(room,at+vec2(blur.x,-blur.y)).rgb+texture(room,at+vec2(-blur.x,blur.y)).rgb)*.05;
vec4 spirit=texture(souls,clamp(SCREEN_UV+bend*.55,vec2(.002),vec2(.998)));
vec3 transmission=exp(-vec3(2.4,1.05,.32)*thickness);
// Room light reflects from the outer pane; the interior is absorbing liquid.
vec3 through=(vec3(.001,.003,.012)+backdrop*.025+spirit.rgb*spirit.a*1.35)*transmission;
through*=1.-reveal*.45;
vec3 reflection=mix(vec3(.045,.10,.20),vec3(.36,.47,.61),pow(max(0.,dot(normal,normalize(vec3(-.45,.65,1.)))),22.));
vec3 color=mix(through,reflection,fresnel*.78)+vec3(.14,.22,.32)*frost*.3+vec3(.025,.055,.095)*reveal+vec3(.36,.47,.55)*condensation*.12;
float contact_glow=0.;for(int i=0;i<5;i++){vec3 delta=glass_point-soul_contacts[i].xyz;contact_glow+=exp(-dot(delta,delta)*105.)*soul_contacts[i].w;}
color+=vec3(.13,.20,.28)*contact_glow*.16;
color=mix(color,vec3(1.4),reveal_glow*pow(max(0.,dot(normalize(glass_normal),result_normal)),12.));
ALBEDO=has_buffers ? color : vec3(.018,.07,.17);ALPHA=.985;}
""";var m=ShaderMaterial.new();m.shader=shader;m.render_priority=3;m.set_shader_parameter("frost_map",load("res://hearth20/casino/soul-frost-height-v1.png"))
	var faces=Hearth20DiceModel.shape(sides);var planes=PackedVector4Array()
	for face in faces:planes.append(Vector4(face.normal.x,face.normal.y,face.normal.z,face.distance))
	while planes.size()<20:planes.append(Vector4(0,0,0,2))
	m.set_shader_parameter("inner_planes",planes);m.set_shader_parameter("face_count",faces.size());return m

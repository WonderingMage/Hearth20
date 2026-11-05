extends RefCounted
class_name Hearth20CasinoCard
## Shared physical card trim and clear typography; no extra viewports or raster text.
const MEDAL=Vector2(0,-.258)
const MEDAL_RADIUS=.074
var art: Texture2D
var atlas: Texture2D
var faces={}
var trim_mesh: ArrayMesh
var trim_material: ShaderMaterial
var velvet_material: ShaderMaterial
var velvet_mesh: ArrayMesh
var bold_font: SystemFont
var silver: StandardMaterial3D
var ink: StandardMaterial3D
var shadow: StandardMaterial3D
func setup(art_texture: Texture2D, materials_texture: Texture2D) -> void:
	art=art_texture;atlas=materials_texture
	bold_font=SystemFont.new();bold_font.font_names=PackedStringArray(["Georgia","DejaVu Serif"]);bold_font.font_weight=800
	silver=_ink(Color("#e8edf2"));ink=_ink(Color("#23160e"));shadow=_ink(Color("#351e1e"))
	var shader=Shader.new();shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas:source_color,filter_linear_mipmap;
void fragment(){
 float groove=smoothstep(.025,.065,abs(UV.y-.18)) * smoothstep(.025,.065,abs(UV.y-.82));
 vec3 grain=texture(atlas,vec2(fract(UV.x*.13)*.494+.002,.502+UV.y*.494)).rgb;
 vec3 brass=mix(vec3(.35,.18,.046),vec3(.72,.48,.15),grain.r);
 ALBEDO=brass*mix(.48,1.,groove);METALLIC=.83;ROUGHNESS=.31;
}""";trim_material=ShaderMaterial.new();trim_material.shader=shader;trim_material.set_shader_parameter("atlas",atlas)
	shader=Shader.new();shader.code="""shader_type spatial;
render_mode cull_disabled;
void fragment(){
 vec2 p=UV*2.-1.;float nap=fract(sin(dot(floor(UV*650.),vec2(12.9898,78.233)))*43758.5453);
 float fold=.5+.5*sin(p.x*9.+p.y*4.+sin(p.y*11.)*.4);
 ALBEDO=vec3(.29,.009,.034)*( .76+.17*fold+nap*.09 );
 EMISSION=vec3(.028,.0004,.002);ROUGHNESS=.98;SPECULAR=.18;
}""";velvet_material=ShaderMaterial.new();velvet_material.shader=shader
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 64:
		for p in [MEDAL,MEDAL+Vector2(cos(float(i+1)*TAU/64),sin(float(i+1)*TAU/64))*.0675,MEDAL+Vector2(cos(float(i)*TAU/64),sin(float(i)*TAU/64))*.0675]:
			st.set_uv((p-MEDAL)/.135+Vector2(.5,.5));st.add_vertex(Vector3(p.x,.0028,p.y))
	st.generate_normals();velvet_mesh=st.commit()
	st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var path=[Vector2(-.194,-.258),Vector2(-.074,-.258)]
	for i in range(1,49):
		var a=PI-float(i)*PI/48;path.append(MEDAL+Vector2(cos(a),sin(a))*MEDAL_RADIUS)
	path.append(Vector2(.194,-.258));path.append(Vector2(.194,.211))
	for i in range(1,9):
		var a=float(i)*PI*.5/8;path.append(Vector2(.176,.211)+Vector2(cos(a),sin(a))*.018)
	path.append(Vector2(-.176,.229))
	for i in range(1,9):
		var a=PI*.5+float(i)*PI*.5/8;path.append(Vector2(-.176,.211)+Vector2(cos(a),sin(a))*.018)
	path.append(path[0]);_ribbon(st,path,.010,.0031)
	# Upper half closes the medallion; lower half belongs to the dipped art frame.
	var crown=[]
	for i in 49:
		var a=PI+float(i)*PI/48;crown.append(MEDAL+Vector2(cos(a),sin(a))*MEDAL_RADIUS)
	_ribbon(st,crown,.010,.0031)
	# Raised beaded molding and small engraved scrolls are shared geometry.
	for side in [-1.,1.]:
		for i in 19:_bead(st,Vector2(side*.194,-.225+i*.023),.00155)
		for z in [-.248,.216]:
			var curl=[]
			for i in 41:
				var a=float(i)/40.*TAU*1.35;var radius=lerpf(.013,.002,float(i)/40.);curl.append(Vector2(side*.180,z)+Vector2(cos(a)*side,sin(a)) * radius)
			_ribbon(st,curl,.0018,.0054)
	for i in 29:_bead(st,MEDAL+Vector2(cos(float(i)*TAU/29),sin(float(i)*TAU/29))*.074,.00135)
	st.generate_normals();trim_mesh=st.commit()
func _ink(color: Color) -> StandardMaterial3D:
	var m=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=color;m.cull_mode=BaseMaterial3D.CULL_DISABLED;return m
func face(id: String, back=false) -> ShaderMaterial:
	var key="back" if back else id
	if faces.has(key):return faces[key]
	var c=Hearth20TavernGames.card(id);var index=int(c.get("art",0));var shader=Shader.new()
	shader.code="""shader_type spatial;render_mode unshaded,cull_disabled;
uniform sampler2D art:source_color,filter_linear_mipmap;
uniform sampler2D atlas:source_color,filter_linear_mipmap;
uniform vec2 cell;uniform bool back=false;
void fragment(){
 vec2 p=(UV-.5)*vec2(.45,.68);
 float grain=fract(sin(dot(floor(UV*800.),vec2(12.9898,78.233)))*43758.5453);
 vec3 paper=vec3(.72,.645,.465)+(grain-.5)*.024;
 vec3 color=paper;
 if(back){color=texture(atlas,vec2(.501,.501)+UV*.498).rgb;}
 else {
  bool inside=p.x>-.188&&p.x<.188&&p.y>-.252&&p.y<.223;
  bool outside_value=length(p-vec2(0.,-.258))>.079;
  if(inside&&outside_value){
   vec2 q=(p-vec2(0.,-.0145))/.479+vec2(.5);
   color=texture(art,cell+clamp(q,.002,.998)*vec2(.2,.25)).rgb;
  }
  // The art has a real exclusion mask, matching the circular brass contour.
  float edge=min(min(UV.x,1.-UV.x),min(UV.y,1.-UV.y));
  color*=mix(.78,1.,smoothstep(0.,.018,edge));
 }
 ALBEDO=color;ROUGHNESS=.92;METALLIC=.025;
}"""
	var m=ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("art",art);m.set_shader_parameter("atlas",atlas);m.set_shader_parameter("cell",Vector2(index%5,index/5)*Vector2(.2,.25));m.set_shader_parameter("back",back);faces[key]=m;return m
func decorate(parent: Node3D, card: Dictionary) -> void:
	var velvet=MeshInstance3D.new();velvet.name="RedVelvetValue";velvet.mesh=velvet_mesh;velvet.material_override=velvet_material;parent.add_child(velvet)
	var frame=MeshInstance3D.new();frame.name="OrnateBrassFrame";frame.mesh=trim_mesh;frame.material_override=trim_material;parent.add_child(frame)
	var value=str(card.strength)
	var under=_text(value,.126,.095,shadow);under.name="ValueEngravedEdge";under.scale*=1.045;_place_text(under,Vector3(.0007,.0058,MEDAL.y+.0006));parent.add_child(under)
	var number=_text(value,.126,.095,silver);number.name="SilverValue";_place_text(number,Vector3(0,.0065,MEDAL.y));parent.add_child(number)
	var name_label=_text(str(card.name),.039,.356,ink);name_label.name="CardName";_place_text(name_label,Vector3(0,.0021,.282));parent.add_child(name_label)
func _place_text(node: MeshInstance3D, center: Vector3) -> void:
	# Font line metrics are not the visible ink bounds, especially for numerals.
	node.position=center-node.basis*(node.mesh.get_aabb().get_center()*node.scale)
func _text(text: String, height: float, max_width: float, mat: Material) -> MeshInstance3D:
	var mesh=TextMesh.new();mesh.font=bold_font;mesh.font_size=112;mesh.pixel_size=height/112.;mesh.depth=.00035;mesh.text=text;mesh.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var node=MeshInstance3D.new();node.mesh=mesh;node.rotation.x=-PI/2;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mesh.get_aabb().size.x>max_width:node.scale.x=max_width/mesh.get_aabb().size.x
	return node
func _ribbon(st: SurfaceTool, path: Array, width: float, y: float) -> void:
	if path.size()<2:return
	var distance=0.;var profile=[Vector2(-.5,0),Vector2(-.34,.0018),Vector2(.34,.0018),Vector2(.5,0)]
	for i in range(path.size()-1):
		var a: Vector2=path[i];var b: Vector2=path[i+1];var tangent=(b-a).normalized();var n=Vector2(-tangent.y,tangent.x);var next_distance=distance+a.distance_to(b)
		for k in 3:
			var p=profile[k];var q=profile[k+1]
			for spec in [[a,p,distance],[b,q,next_distance],[b,p,next_distance],[a,p,distance],[a,q,distance],[b,q,next_distance]]:
				var at=spec[0]+n*spec[1].x*width;st.set_uv(Vector2(spec[2]/.04,spec[1].x+.5));st.add_vertex(Vector3(at.x,y+spec[1].y,at.y))
		distance=next_distance
func _bead(st: SurfaceTool, p: Vector2, radius: float) -> void:
	for i in 8:
		for spec in [[p,.0066],[p+Vector2(cos(float(i+1)*TAU/8),sin(float(i+1)*TAU/8))*radius,.0048],[p+Vector2(cos(float(i)*TAU/8),sin(float(i)*TAU/8))*radius,.0048]]:
			st.set_uv(Vector2(float(i)/8.,.5));st.add_vertex(Vector3(spec[0].x,spec[1],spec[0].y))

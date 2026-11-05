extends Node3D
class_name Hearth20SeatedPapyrus
## A thin, curled writing surface; the private website thumbnail is local only.
var preview: MeshInstance3D
var markings: Node3D
func setup() -> void:
	var parchment=ShaderMaterial.new();var shader=Shader.new();shader.code="""
shader_type spatial;
render_mode cull_disabled;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 p=UV;float fiber=sin(p.x*1900.+sin(p.y*160.)*2.)*.018+sin(p.y*2400.+p.x*12.)*.014;
 float flecks=hash(floor(p*vec2(1000.,700.)))*.06;
 float edge=pow(abs(p.x*2.-1.),12.)+pow(abs(p.y*2.-1.),12.);
 float stain=sin(p.x*16.+p.y*7.)*sin(p.y*19.-p.x*8.)*.028;
 ALBEDO=mix(vec3(.72,.51,.25),vec3(.89,.76,.50),clamp(.89-edge*.40+fiber+flecks+stain,0.,1.));
	 EMISSION=ALBEDO*.22;ROUGHNESS=.98;METALLIC=0.;
}
""";parchment.shader=shader
	var paper=MeshInstance3D.new();paper.name="CurledPapyrusSheet";paper.mesh=_sheet(false);paper.material_override=parchment;add_child(paper)
	for z in [-.268,.268]:
		var curl=MeshInstance3D.new();var roll=CylinderMesh.new();roll.top_radius=.012;roll.bottom_radius=.012;roll.height=.805;roll.radial_segments=24;curl.mesh=roll;curl.material_override=parchment;curl.rotation.z=PI/2;curl.position=Vector3(0,.020,z);add_child(curl)
	preview=MeshInstance3D.new();preview.mesh=_sheet(true);preview.position.y=.0018;add_child(preview);preview.hide()
	markings=Node3D.new();add_child(markings)
	_text("ADVENTURER’S RECORD",.030,Vector3(0,.011,-.17))
	_text("Your character · Your story",.013,Vector3(0,.012,-.126))
	_text("Open your D&D Beyond sheet",.015,Vector3(.06,.013,.19))
	var ink=StandardMaterial3D.new();ink.albedo_color=Color("#62482d");ink.roughness=1.
	# Fine writing rules and a portrait outline belong to this sheet alone.
	for i in 8:
		var line=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(.43 if i<5 else .60,.0005,.0008);line.mesh=box;line.material_override=ink;line.position=Vector3(.055 if i<5 else 0,.011,-.075+i*.029);markings.add_child(line)
	var portrait=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=.045;torus.outer_radius=.046;torus.rings=48;torus.ring_segments=6;portrait.mesh=torus;portrait.material_override=ink;portrait.position=Vector3(-.27,.011,-.01);markings.add_child(portrait)
func _text(value: String,height: float,at: Vector3) -> void:
	var glyph=Hearth20DiceNumeral.new();glyph.setup(value,height,.70,Color("#513720"),0.);glyph.rotation.x=-PI/2;glyph.position=at;markings.add_child(glyph)
func _sheet(inset: bool) -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 36:
		for col in 56:
			for spec in [[col,row],[col+1,row+1],[col+1,row],[col,row],[col,row+1],[col+1,row+1]]:
				var uv=Vector2(float(spec[0])/56.,float(spec[1])/36.)
				var raw=uv if not inset else Vector2(.055,.075)+uv*Vector2(.89,.85)
				var x=(raw.x-.5)*.84;var z=(raw.y-.5)*.55
				var ragged=(sin(raw.y*107.)+sin(raw.y*237.)*.4)*.0013*pow(absf(raw.x*2.-1.),16.)
				var curl=pow(absf(raw.y*2.-1.),12.)*.037+pow(absf(raw.x*2.-1.),12.)*.009
				var wave=sin(raw.x*9.+raw.y*6.)*.003
				st.set_uv(uv);st.set_normal(Vector3.UP);st.add_vertex(Vector3(x+ragged,.008+curl+wave,z))
	return st.commit()
func set_preview(texture: Texture2D) -> void:
	var material_value=StandardMaterial3D.new();material_value.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material_value.albedo_texture=texture;material_value.albedo_color=Color(.94,.87,.70);material_value.cull_mode=BaseMaterial3D.CULL_DISABLED;preview.material_override=material_value;preview.show();markings.hide()

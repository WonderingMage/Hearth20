extends RefCounted
class_name Hearth20FxSurfaces
const CODE:="""
shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_mix;
uniform vec4 tint:source_color;uniform float age=0.;uniform float phase=0.;uniform float strength=1.;uniform int mode=0;
float ring(float r,float target,float width){return 1.-smoothstep(width,width*2.,abs(r-target));}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=(UV-.5)*2.;float r=length(p);float a=atan(p.y,p.x);float glow=0.;
 if(mode==0){float k=a+age*.18;float glyph=step(.72,sin(k*24.))*step(.3,sin(r*90.+floor(k*7.)*3.));glow=ring(r,.82,.006)+ring(r,.74,.004)+ring(r,.46,.005)+glyph*ring(r,.64,.052);glow+=pow(max(0.,cos(a*6.-age)),48.)*ring(r,.9,.02);}
 else if(mode==1){float radius=clamp(phase*3.7,0.,1.3);float broken=.45+.55*noise(vec2(a*7.,age*4.));glow=ring(r,radius,.012)*broken*(1.-smoothstep(.12,.55,phase));glow+=ring(r,radius*.82,.025)*.25*(1.-smoothstep(.1,.5,phase));}
 else if(mode==2){float spiral=sin(a*6.+r*24.-age*5.);float edge=pow(max(0.,spiral),16.)*smoothstep(.12,.8,r)*smoothstep(1.,.72,r);glow=edge*.65+ring(r,.82+sin(a*7.+age)*.035,.012)*.8;}
 else{float shards=pow(max(0.,sin(a*13.+sin(a*31.)*.6)),48.);glow=shards*smoothstep(1.,.15,r)*smoothstep(.05,.4,r)+ring(r,.72,.006)*.2;}
 ALBEDO=tint.rgb*1.4;EMISSION=tint.rgb*.3;ALPHA=clamp(glow*strength,0.,.78);
}
"""
static var shader: Shader
static func material(color: Color, mode: int) -> ShaderMaterial:
	if shader==null:shader=Shader.new();shader.code=CODE
	var result:=ShaderMaterial.new();result.shader=shader;result.set_shader_parameter("tint",color);result.set_shader_parameter("mode",mode);return result

const CORE:="""
shader_type spatial;render_mode cull_disabled,blend_mix;
uniform vec4 tint:source_color;uniform float age=0.;varying vec3 point;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){point=VERTEX;VERTEX*=1.+sin(VERTEX.x*24.+VERTEX.y*17.+age*12.)*.055;}
void fragment(){vec3 p=point*9.+vec3(age*2.,-age*4.,age);float n=noise(p)*.7+noise(p*2.1)*.3;float vein=pow(1.-abs(n*2.-1.),5.);ALBEDO=tint.rgb*.12;EMISSION=mix(tint.rgb*.1,tint.rgb*3.+vec3(.7,.25,.02),vein);ROUGHNESS=.24;METALLIC=.15;}
"""
static var core_shader: Shader
static func core_material(color: Color) -> ShaderMaterial:
	if core_shader==null:core_shader=Shader.new();core_shader.code=CORE
	var result:=ShaderMaterial.new();result.shader=core_shader;result.set_shader_parameter("tint",color);return result

const CROWN:="""
shader_type spatial;render_mode cull_disabled,blend_mix;
uniform vec4 tint:source_color;uniform float age=0.;uniform float strength=1.;uniform bool blood=false;varying vec2 sheet_uv;
void vertex(){
 float a=UV.x*6.2831853;float v=UV.y;float time=max(0.,age);float height=sin(clamp(time/.9,0.,1.)*3.14159)*(.55+pow(max(0.,sin(a*13.+1.7)),6.)*.9);
 float radius=(.12+v*(.4+time*.65))*(1.+sin(a*7.)*.045);VERTEX=vec3(cos(a)*radius,sin(v*3.14159)*height+pow(v,4.)*height*.26,sin(a)*radius);sheet_uv=UV;
}
void fragment(){
 vec3 n=normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));NORMAL=dot(n,VIEW)<0.?-n:n;
 float foam=blood?0.:smoothstep(.89,1.,sheet_uv.y)*.55;ALBEDO=mix(tint.rgb*(blood?.12:.18),vec3(.75,.85,.88),foam);ROUGHNESS=.085;SPECULAR=.95;CLEARCOAT=.9;CLEARCOAT_ROUGHNESS=.07;ALPHA=strength*(blood?.9:.62)*(1.-smoothstep(.9,1.5,age));
}
"""
static var crown_shader: Shader
static var crown_geometry: ArrayMesh
static func crown(color: Color, blood: bool) -> MeshInstance3D:
	if crown_shader==null:crown_shader=Shader.new();crown_shader.code=CROWN
	if crown_geometry==null:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 144:
			for j in 8:
				for point in [Vector2(i/144.0,j/8.0),Vector2((i+1)/144.0,j/8.0),Vector2((i+1)/144.0,(j+1)/8.0),Vector2(i/144.0,j/8.0),Vector2((i+1)/144.0,(j+1)/8.0),Vector2(i/144.0,(j+1)/8.0)]:surface.set_uv(point);surface.set_normal(Vector3.UP);surface.add_vertex(Vector3(point.x,point.y,0))
		crown_geometry=surface.commit()
	var node:=MeshInstance3D.new();node.mesh=crown_geometry;node.custom_aabb=AABB(Vector3(-4,0,-4),Vector3(8,3,8));var material_value:=ShaderMaterial.new();material_value.shader=crown_shader;material_value.set_shader_parameter("tint",color);material_value.set_shader_parameter("blood",blood);node.material_override=material_value;return node

extends MeshInstance3D
class_name Hearth20FxRibbon3D
## A genuine swept 3D tube: history, curl and cross-section are animated on the GPU.
const CODE:="""
shader_type spatial;
render_mode cull_disabled,depth_draw_never,blend_mix;
uniform vec4 tint:source_color;
uniform float age=0.;uniform float phase=0.;uniform float travel=0.;uniform float seed=0.;uniform float width=.025;uniform float opacity=1.;uniform int mode=0;
uniform vec3 delta=vec3(0);uniform bool liquid=false;uniform bool cyclic=false;
varying vec2 ribbon_uv;
vec3 curve(float t){
 float a=seed*6.2831853;vec3 radial=vec3(cos(a),0.,sin(a));float spin=age*1.8+seed*13.;
 if(mode==0){float p=clamp(age/max(.01,travel),0.,1.);float q=clamp((age-t*.7)/max(.01,travel),0.,1.);return delta*(p-q)+vec3(sin(t*18.+spin),cos(t*12.-spin),cos(t*21.+spin))*(.018+t*.12)+vec3(0.,(sin(q*3.14159)-sin(p*3.14159))*.6,0.);}
 if(mode==1){float k=t*6.2831853+spin;return vec3(cos(k),sin(k*2.+a)*.48+.7,sin(k))*(.72+sin(k*3.-age)*.09);}
 if(mode==2){float life=cyclic?mod(age*.68+seed,1.):clamp((age-seed*.16)/1.5,0.,1.);float q=t*life*1.6;return radial*q*(1.2+seed*.7)+vec3(0.,max(.015,(2.6+seed)*q-2.3*q*q),0.);}
 if(mode==3){vec3 d=delta*(1.-t);vec3 side=normalize(cross(normalize(delta+vec3(.001,0,0)),vec3(0,1,0)));return d+side*sin(t*22.-age*12.+a)*.045+vec3(0,.22+sin(t*17.+age*9.+a)*.05,0);}
 if(mode==4){float k=t*8.+age*1.7;return vec3(sin(k+a)*(.12+t*.08)+cos(a)*.17,t*2.3,cos(k*1.3-a)*(.12+t*.08)+sin(a)*.17);}
 float spread=.2+phase*2.4;return radial*t*spread+vec3(0.,sin(t*3.14159)*(.2+seed)*sin(clamp(phase*1.8,0.,1.)*3.14159),0.);
}
void vertex(){
 float t=UV.x;float theta=UV.y*6.2831853;vec3 p=curve(t);vec3 tangent=normalize(curve(min(.999,t+.003))-curve(max(.001,t-.003))+vec3(.00001));vec3 u=normalize(cross(tangent,abs(tangent.y)>.95?vec3(1,0,0):vec3(0,1,0)));vec3 v=cross(tangent,u);vec3 n=u*cos(theta)+v*sin(theta);
 float taper=pow(max(.0001,1.-t),.8)*smoothstep(0.,.04,t);VERTEX=p+n*width*taper;NORMAL=n;ribbon_uv=UV;
}
void fragment(){
 float t=ribbon_uv.x;float flow=.55+.45*sin(t*50.-age*24.+seed*30.);float tail=pow(max(0.,1.-t),.5);float pulse=smoothstep(.03,.35,t)*tail*opacity;
 ALBEDO=tint.rgb*(liquid?.55:.4);ROUGHNESS=liquid?.09:.3;METALLIC=liquid?.05:.2;SPECULAR=.8;CLEARCOAT=liquid?.8:0.;CLEARCOAT_ROUGHNESS=.08;
 EMISSION=liquid?vec3(0):mix(tint.rgb,tint.rgb*.8+vec3(.08),flow)*1.5;ALPHA=pulse*(liquid?.65:.7);
}
"""
static var tube: ArrayMesh
static var shader: Shader
static var wet_shader: Shader
var fx_material: ShaderMaterial
var style:=0
var liquid:=false
func setup(color: Color, kind: int, seed_value: float, radius: float, wet: bool=false) -> void:
	style=kind;liquid=wet
	if tube==null:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 48:
			for j in 8:
				for point in [Vector2(i/48.0,j/8.0),Vector2((i+1)/48.0,j/8.0),Vector2((i+1)/48.0,(j+1)/8.0),Vector2(i/48.0,j/8.0),Vector2((i+1)/48.0,(j+1)/8.0),Vector2(i/48.0,(j+1)/8.0)]:surface.set_uv(point);surface.set_normal(Vector3.UP);surface.add_vertex(Vector3(point.x,cos(point.y*TAU)*.02,sin(point.y*TAU)*.02))
		tube=surface.commit()
	if shader==null:shader=Shader.new();shader.code=CODE
	if wet and wet_shader==null:wet_shader=Shader.new();wet_shader.code=CODE.replace("blend_add","blend_mix")
	mesh=tube;custom_aabb=AABB(Vector3(-512,-32,-512),Vector3(1024,128,1024));fx_material=ShaderMaterial.new();fx_material.shader=wet_shader if wet else shader;fx_material.set_shader_parameter("tint",color);fx_material.set_shader_parameter("mode",kind);fx_material.set_shader_parameter("seed",seed_value);fx_material.set_shader_parameter("width",radius);fx_material.set_shader_parameter("liquid",wet);material_override=fx_material
func animate(time: float, phase_value: float, duration: float, source: Vector2, fade: float) -> void:
	fx_material.set_shader_parameter("age",time);fx_material.set_shader_parameter("phase",phase_value);fx_material.set_shader_parameter("travel",duration);fx_material.set_shader_parameter("delta",Vector3(source.x,0,source.y))
	var flight_fade:=1.0-smoothstep(duration,duration+.7,time) if style==0 else 1.0
	if style==2 and not fx_material.get_shader_parameter("cyclic"):flight_fade*=1.-smoothstep(1.1,1.8,time-duration)
	fx_material.set_shader_parameter("opacity",fade*flight_fade)

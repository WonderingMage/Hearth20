extends RefCounted
class_name Hearth20FxPost
## Multiscale bloom reads only the transparent FX viewport, leaving table text sharp.
const CODE:="""
shader_type canvas_item;
render_mode unshaded;
uniform float strength=.85;
vec3 bright(sampler2D source,vec2 uv){vec4 s=texture(source,uv);float e=smoothstep(.42,.92,max(max(s.r,s.g),s.b))*s.a;return s.rgb*e;}
void fragment(){
 vec4 base=texture(TEXTURE,UV);vec3 bloom=vec3(0.);vec2 px=TEXTURE_PIXEL_SIZE;
 for(int level=0;level<3;level++){
  float r=level==0?2.:level==1?7.:18.;float w=level==0?.42:level==1?.35:.23;
  vec3 b=bright(TEXTURE,UV)*.20;
  b+=(bright(TEXTURE,UV+px*vec2(r,0))+bright(TEXTURE,UV-px*vec2(r,0))+bright(TEXTURE,UV+px*vec2(0,r))+bright(TEXTURE,UV-px*vec2(0,r)))*.12;
  b+=(bright(TEXTURE,UV+px*vec2(r,r))+bright(TEXTURE,UV+px*vec2(-r,r))+bright(TEXTURE,UV+px*vec2(r,-r))+bright(TEXTURE,UV-px*vec2(r,r)))*.08;
  bloom+=b*w;
 }
 bloom*=strength;float a=clamp(base.a+max(max(bloom.r,bloom.g),bloom.b)*.5,0.,1.);
 COLOR=vec4((base.rgb*base.a+bloom*.65*(vec3(1.)-base.rgb*base.a))/max(.001,a),a);
}
"""
static var shader: Shader
static func material() -> ShaderMaterial:
	if shader==null:shader=Shader.new();shader.code=CODE
	var result:=ShaderMaterial.new();result.shader=shader;return result

extends RefCounted
class_name Hearth20FxVolume
## Bounded64-step heterogeneous volume with periodic3D density and self-shadowing.
const CODE:="""
shader_type spatial;
render_mode unshaded,cull_back,depth_draw_never,blend_mix;
uniform vec4 tint:source_color=vec4(1,.25,.04,1);
uniform sampler3D density_volume:filter_linear,repeat_enable;
uniform float age=0.;uniform float strength=1.;uniform int substance=0;uniform int shape_mode=0;uniform int steps=64;
varying vec3 local_point;varying vec3 local_camera;
float noise3(vec3 p){return texture(density_volume,p*.17).r;}
float fbm(vec3 p){return noise3(p)*.66+noise3(p*2.03+4.3)*.24+noise3(p*4.17-3.1)*.1;}
float density_at(vec3 p){
 if(max(max(abs(p.x),abs(p.y)),abs(p.z))>1.)return 0.;
 float h=(p.y+1.)*.5;vec3 flow=p*3.7+vec3(sin(h*5.+age)*.35,-age*1.8,cos(age*.7+h*6.)*.3);
 vec3 warp=vec3(noise3(flow+7.),noise3(flow*.8-3.),noise3(flow*.9+12.))-.5;
 float n=fbm(flow+warp*2.3);float radius=substance==0?mix(.91,.15,h):mix(.76,.94,h);
 if(shape_mode==1)radius=.47;
 float radial=length(p.xz+vec2(sin(h*7.-age*2.),cos(h*5.+age))*h*.09);
 float envelope=smoothstep(radius,radius-.23,radial)*smoothstep(1.,.72,h)*smoothstep(0.,.06,h);
 if(shape_mode==2)envelope=smoothstep(1.,.62,length(p))*smoothstep(.13,.62,n);
 float structure=substance==0?max(0.,n-(shape_mode==2?.27:.25+.27*h))*5.1:smoothstep(.23,.7,n)*1.35;
 return structure*envelope*strength;
}
void vertex(){local_point=VERTEX;local_camera=(inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1.)).xyz;}
void fragment(){
 vec3 direction=normalize(local_point-local_camera);vec3 safe_dir=mix(vec3(.00001),direction,greaterThan(abs(direction),vec3(.00001)));
 vec3 t0=(-vec3(1)-local_camera)/safe_dir,t1=(vec3(1)-local_camera)/safe_dir;
 vec3 near_t=min(t0,t1),far_t=max(t0,t1);float begin=max(0.,max(max(near_t.x,near_t.y),near_t.z));float end=min(min(far_t.x,far_t.y),far_t.z);
 float step_size=max(.0001,(end-begin)/float(steps));float transmittance=1.;vec3 radiance=vec3(0.);vec3 illumination=normalize(vec3(-.4,.7,.3));
 float jitter=fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453);
 for(int i=0;i<64;i++){
  if(i>=steps)break;vec3 p=local_camera+direction*(begin+(float(i)+jitter)*step_size);float h=(p.y+1.)*.5;float density=density_at(p);float opacity=1.-exp(-density*step_size*(substance==0?4.0:2.1));
  vec3 color=tint.rgb;
  if(substance==0){float heat=clamp(density*.19+(1.-h)*.57,0.,1.);color=mix(tint.rgb*.055,tint.rgb*1.8,smoothstep(.06,.73,heat));color=mix(color,vec3(2.1,1.05,.2),smoothstep(.75,.98,heat)*.7);}
  else{
   float shadow=0.;if(density>.1){for(int j=1;j<=4;j++)shadow+=density_at(p+illumination*float(j)*.18)*.18;}
   float cosine=dot(direction,illumination);float g=.32;float phase=(1.-g*g)/pow(max(.01,1.+g*g-2.*g*cosine),1.5);
   color*=.18+exp(-shadow*2.8)*(.32+phase*.25);color+=tint.rgb*.09*pow(max(0.,1.-density),2.);
  }
  radiance+=color*opacity*transmittance;transmittance*=1.-opacity;if(transmittance<.01)break;
 }
 ALBEDO=radiance/max(.001,1.-transmittance);ALPHA=clamp(1.-transmittance,0.,.96);
}
"""
static var shader: Shader
static var density: Texture3D
static func material(color: Color, smoky: bool) -> ShaderMaterial:
	if shader==null:shader=Shader.new();shader.code=CODE
	if density==null:density=load("res://hearth20/fx_noise_volume.res")
	var result:=ShaderMaterial.new();result.shader=shader;result.set_shader_parameter("tint",color);result.set_shader_parameter("substance",1 if smoky else 0);result.set_shader_parameter("density_volume",density);return result

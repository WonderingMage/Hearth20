shader_type spatial;
uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D height_map : repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.);
uniform int kind = 0;
uniform float normal_strength=.30;
varying vec3 world_point;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float seed=hash(vec2(COLOR.r*531.,COLOR.g*137.));
 vec2 uv;
 if(kind==2){
  // Choose individual stone faces from a shared source, with independent wear.
  vec2 offset=vec2(seed,hash(vec2(seed*19.,37.)))*.72;
  uv=offset+UV*vec2(.24,.15);
 }else{
  // A plank receives a grain strip, never a picture of several floor boards.
  float strip=floor(seed*4.);
  uv=vec2(strip*.25+.025+UV.x*.195,UV.y*.62+fract(seed*7.1));
 }
 vec3 base=texture(albedo_map,uv).rgb;
 float macro=noise(world_point.xz*.20+world_point.xy*.11);
 float relief=texture(height_map,uv).r;
 float wear=kind==0?(1.-smoothstep(1.2,4.4,length(world_point.xz-vec2(0.,.4)))):0.;
 float damp=kind==2?(1.-smoothstep(.1,1.2,world_point.y))*.12:0.;
 ALBEDO=base*tint.rgb*COLOR.rgb*mix(.91,1.075,macro)*(1.-damp)*(1.+wear*.045);
 ALBEDO*=mix(.97,1.015,relief);
 // RGTC normal textures store XY. Reconstruct Z rather than reading a zero
 // blue channel as a backwards normal on the Compatibility renderer.
 vec2 normal_xy=texture(normal_map,uv).rg*2.-1.;
 NORMAL_MAP=vec3(normal_xy,sqrt(max(.001,1.-dot(normal_xy,normal_xy))))*.5+.5;
 NORMAL_MAP_DEPTH=normal_strength;
 ROUGHNESS=clamp(texture(roughness_map,uv).r*.55+.35-wear*.055,.68,.98);
 SPECULAR=.24;METALLIC=0.;
}

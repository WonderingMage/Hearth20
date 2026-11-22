shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;
#include "res://hearth20/room_craft/window_shape.gdshaderinc"
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D sun_depth : repeat_disable, filter_nearest;
uniform mat4 sun_view;
uniform mat4 sun_projection;
uniform vec3 sun_direction;
uniform int portal_count=0;
uniform vec4 portal_centers[5];
uniform vec2 portal_dimensions[5];
uniform vec2 portal_profiles[5];
uniform vec3 portal_normals[5];
uniform vec3 beam_lower[5];
uniform vec3 beam_upper[5];
uniform int steps=32;
uniform float environment_strength=1.;
uniform vec4 light_tint : source_color = vec4(1.,.78,.47,1.);
uniform vec3 room_lower=vec3(-8.,.01,-8.);
uniform vec3 room_upper=vec3(8.,6.05,8.);
uniform bool debug_no_shadow=false;
uniform bool debug_field=false;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float unpack_depth(vec3 p){return dot(p,vec3(1.,1./255.,1./65025.))*48.;}
float illumination(vec3 p){
 vec4 v=sun_view*vec4(p,1.);vec4 clip=sun_projection*v;
 vec2 uv=clip.xy/clip.w*.5+.5;
 // The offscreen depth image is top-left oriented. Calibrated against known
 // exterior wall points; omitting this flip shadows the wrong room heights.
 uv.y=1.-uv.y;
 float actual=-v.z;
 float a=unpack_depth(texture(sun_depth,uv+vec2(-.0007,0)).rgb);
 float b=unpack_depth(texture(sun_depth,uv+vec2(.0007,0)).rgb);
 float c=unpack_depth(texture(sun_depth,uv+vec2(0,.0007)).rgb);
 return (smoothstep(actual-.075,actual-.025,a)+smoothstep(actual-.075,actual-.025,b)+smoothstep(actual-.075,actual-.025,c))/3.;
}
float aperture(vec3 p){
 float coverage=0.;
 for(int i=0;i<5;i++){
  if(i>=portal_count)break;
  vec3 n=portal_normals[i];vec3 center=portal_centers[i].xyz;
  float distance_to_window=dot(p-center,n)/max(.001,dot(sun_direction,n));
  if(distance_to_window<0.||distance_to_window>23.)continue;
  vec3 entry=p-sun_direction*distance_to_window-center;
  float x=abs(n.x)>.5?entry.z:entry.x;
  float y=entry.y;float h=portal_dimensions[i].y;
  float edge=h20_window_edge(vec2(x,y),portal_dimensions[i],portal_profiles[i].x);
  float frame=smoothstep(.008,.055,edge);
  float mullion=1.;
  if(portal_profiles[i].y>.5){
   float crossbar=min(abs(y+h*(.5-.36)),abs(y+h*(.5-.69)));
   mullion=smoothstep(.019,.037,abs(x))*smoothstep(.019,.037,crossbar);
  }
  coverage=max(coverage,frame*mullion*exp(-distance_to_window*.032));
 }
 return coverage;
}
void vertex(){POSITION=vec4(VERTEX.xy,1.,1.);}
void fragment(){
 float depth=texture(scene_depth,SCREEN_UV).r;
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc=vec3(SCREEN_UV,depth)*2.-1.;
 #else
 vec3 ndc=vec3(SCREEN_UV*2.-1.,depth);
 #endif
 vec4 view=INV_PROJECTION_MATRIX*vec4(ndc,1.);view/=view.w;
 vec3 end=(INV_VIEW_MATRIX*vec4(view.xyz,1.)).xyz;
 vec3 eye=INV_VIEW_MATRIX[3].xyz;
 vec3 ray=normalize(end-eye);float reach=min(length(end-eye),25.);
 // Intersect the camera ray with the actual illuminated window volumes first.
 // Empty air never pays for the 48/56-sample integral, and narrow shafts retain
 // more samples per meter instead of spreading them over the entire room.
 vec3 inverse_ray=sign(ray+vec3(.0000001))/max(abs(ray),vec3(.00001));
 float begin=reach;float finish=0.;
 for(int j=0;j<5;j++){
  if(j>=portal_count)break;
  vec3 a=(beam_lower[j]-eye)*inverse_ray;vec3 b=(beam_upper[j]-eye)*inverse_ray;
  vec3 low=min(a,b),high=max(a,b);
  float near=max(0.,max(low.x,max(low.y,low.z)));
  float far=min(reach,min(high.x,min(high.y,high.z)));
  if(far>near){begin=min(begin,near);finish=max(finish,far);}
 }
 float step_size=max(0.,finish-begin)/float(steps);float jitter=hash(FRAGCOORD.xy);
 float transmittance=1.;float scattering=0.;
 for(int i=0;i<56;i++){
  if(i>=steps||step_size<.0001||environment_strength<.001)break;
  vec3 p=eye+ray*(begin+(float(i)+jitter)*step_size);
  if(any(lessThan(p,room_lower))||any(greaterThan(p,room_upper)))continue;
  float beam=aperture(p);
  if(beam<.001)continue;
  float dust=.90+.10*sin(p.x*1.4+p.y*2.3+TIME*.045)*sin(p.z*2.5-p.y*.9);
  float density=.095*environment_strength*beam*dust*(debug_no_shadow?1.:illumination(p));
  float transmission=exp(-density*step_size);
  scattering+=transmittance*(1.-transmission);
  transmittance*=transmission;
 }
 float phase=.78+.32*pow(max(0.,dot(ray,sun_direction)),3.);
 ALBEDO=light_tint.rgb*phase*1.8;
 ALPHA=clamp(scattering,0.,.35);
 if(debug_field){ALBEDO=vec3(float(portal_count)/5.,reach/25.,scattering*8.);ALPHA=1.;}
}

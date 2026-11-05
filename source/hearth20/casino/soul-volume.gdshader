shader_type spatial;
render_mode unshaded,cull_back,depth_draw_never,blend_mix;
uniform sampler3D density_volume:filter_linear,repeat_enable;
uniform float age=0.;
uniform float intensity=1.;
uniform int face_count=6;
uniform vec4 planes[20];
uniform vec4 heads[5];
uniform vec4 directions[5];
uniform vec4 trails[40];
uniform vec4 appearances[5];
varying vec3 point;
varying vec3 eye;
float noise3(vec3 p){return texture(density_volume,p*.17).r;}
float fbm(vec3 p){return noise3(p)*.72+noise3(p*2.07+7.1)*.28;}
float segment(vec3 p,vec3 a,vec3 b){vec3 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/max(.00001,dot(v,v)),0.,1.));}
float smoke_thread(float distance,float width){return exp(-pow(distance/max(.003,width),2.));}
float mist(vec3 p){
 vec3 warp=vec3(noise3(p*9.+vec3(0,-age*.24,0)),noise3(p*8.+6.4),noise3(p*9.-4.2))-.5;
 vec3 q=p+warp*.014;
 float fog=0.;
 for(int j=0;j<5;j++){
  vec3 head=heads[j].xyz;float pressure=heads[j].w;float seed=directions[j].w;
  // Free souls turn through the volume. At contact they face the actual pane.
  vec3 view=normalize(eye-head);
  vec3 front=normalize(mix(normalize(view*.65+directions[j].xyz*.35),directions[j].xyz,pressure));
  vec3 reference=abs(front.y)>.92?vec3(1,0,0):vec3(0,1,0);
  vec3 right=normalize(cross(reference,front));vec3 up=cross(front,right);
  vec3 f=vec3(dot(q-head,right),dot(q-head,up),dot(q-head,front))/.76;
  float wail=.043+.014*sin(age*2.1+seed)+pressure*.018;
  float depth=mix(.062,.023,pressure);
  float stretch=1.+sin(age*1.47+seed)*.10+pressure*.12;
  float shape=length(f/vec3(.093,.123*stretch,depth));
  // A hollow, elongated ectoplasmic hood; never a solid glowing sphere.
  float hood=exp(-pow((shape-.78)/.24,2.))*.34;
  hood+=max(0.,1.-shape)*.08;
  float mouth=1.-smoothstep(.72,1.15,length((f.xy-vec2(0,-.043))/vec2(.027,wail)));
  float eyes=1.-smoothstep(.65,1.28,min(length((f.xy-vec2(-.033,.046))/vec2(.014,.023)),length((f.xy-vec2(.033,.046))/vec2(.014,.023))));
  float tear=exp(-pow((abs(f.x)-.034)*150.,2.))*(1.-smoothstep(-.063,.018,f.y));
  float turbulent=fbm(q*24.+vec3(seed,-age*.75,seed*2.));
  hood*=1.-mouth*.998;hood*=1.-eyes*.997;hood*=1.-tear*.40;
  hood*=mix(.60,1.28,smoothstep(.20,.78,turbulent));
  float arms=0.;
  if(pressure>.01){for(int side=0;side<2;side++){
   float s=side==0?-1.:1.;vec3 shoulder=vec3(s*.052,-.080,-.020);vec3 palm=vec3(s*.120,-.022,depth*.68);
   arms+=smoke_thread(segment(f,shoulder,palm),.010)*.22;
   arms+=exp(-dot((f-palm)/vec3(.017,.022,.008),(f-palm)/vec3(.017,.022,.008)))*.32;
   for(int finger=0;finger<3;finger++){
    vec3 start=palm+vec3((float(finger)-1.)*.010,0,0);
    vec3 tip=start+vec3((float(finger)-1.)*.007,.029+float(finger%2)*.008,0);
    arms+=smoke_thread(segment(f,start,tip),.0035)*.18;
   }
  }}
  float tail=0.;vec3 previous=head-up*.092-front*.012;
  for(int k=0;k<8;k++){
   vec3 next=trails[j*8+k].xyz;float fade=trails[j*8+k].w;
   float width=mix(.008,.047,fade);float d=segment(q,previous,next);
   tail+=smoke_thread(d,width)*fade*.33;
   // Thin split filaments flicker along the same advected path.
   vec3 curl=right*sin(age*1.1+float(k)*1.7+seed)*.022*fade;
   tail+=smoke_thread(segment(q,previous+curl,next-curl),width*.32)*fade*.12;
   previous=next;
  }
  tail*=smoothstep(.23,.74,turbulent);
  // A soul only becomes visible as it rises out of the absorbing liquid.
  fog+=(hood+arms*pressure)*appearances[j].x+tail;
 }
 return fog*intensity;
}
void vertex(){point=VERTEX;eye=(inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1.)).xyz;}
void fragment(){
 vec3 direction=normalize(point-eye);vec3 safe=direction+vec3(.000001);
 vec3 lo=(-vec3(1)-eye)/safe,hi=(vec3(1)-eye)/safe;vec3 a=min(lo,hi),b=max(lo,hi);
 float entry=max(0.,max(max(a.x,a.y),a.z));float exit=min(min(b.x,b.y),b.z);
 // Clip the integration interval to the physical inner faces once per ray.
 for(int k=0;k<20;k++){
  if(k>=face_count)break;
  float denominator=dot(direction,planes[k].xyz);float distance=planes[k].w-.145-dot(eye,planes[k].xyz);
  if(abs(denominator)<.00001){if(distance<0.)discard;}
  else{float crossing=distance/denominator;if(denominator>0.)exit=min(exit,crossing);else entry=max(entry,crossing);}
 }
 if(exit<=entry)discard;
 float step_size=(exit-entry)/56.;float jitter=fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453);
 vec3 transmit=vec3(1.);vec3 glow=vec3(0.);
 for(int i=0;i<56;i++){
  vec3 p=eye+direction*(entry+(float(i)+jitter)*step_size);float density=mist(p);
  float opacity=1.-exp(-density*step_size*28.);
  vec3 color=mix(vec3(.47,.67,.88),vec3(.96,1.,1.05),smoothstep(.03,.34,density));
  // Beer-Lambert absorption makes deep spirits disappear into an inky abyss.
  float liquid=1.0+fbm(p*5.+vec3(0,age*.09,0))*.45;
  glow+=color*opacity*transmit;
  transmit*=exp(-(vec3(4.6,3.1,1.9)*liquid+vec3(density*28.))*step_size);
  if(max(transmit.r,max(transmit.g,transmit.b))<.025)break;
 }
 ALBEDO=glow*1.35+vec3(.0015,.0035,.012)*(vec3(1.)-transmit);EMISSION=ALBEDO*.48;ALPHA=.995;
}

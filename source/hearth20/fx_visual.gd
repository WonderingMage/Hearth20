extends Polygon2D
class_name Hearth20FxVisual
## Bounded GPU spell cinema: advected fluid fields, corona, smoke and ballistic embers.
const MODES := {"beam":0,"breath":1,"burn":2,"bomb":3,"burst":3,"explode":3,"nova":9,"shield":4,"glow":4,"pooling":5,"sparkle":6,"bubbling":7,"splatter":8,"missile":10,"rocket":10}
const SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec2 source;
uniform vec2 destination;
uniform float scale_px=64.0;
uniform float age=0.0;
uniform float duration=2.0;
uniform float travel=0.0;
uniform float seed=1.0;
uniform vec4 tint : source_color=vec4(1,.3,.03,1);
uniform int mode=3;
uniform int variant=0;
uniform int particle_count=48;
uniform int element_id=0;
uniform sampler2D volume_noise : filter_linear, repeat_disable;
uniform sampler2D fire_cloud : filter_linear_mipmap, repeat_disable;
uniform sampler2D flame_jet : filter_linear_mipmap, repeat_disable;
varying vec2 position;
void vertex(){ position=VERTEX; }
float hash(vec2 p){ p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32+fract(seed*.00123)*17.17);return fract(p.x*p.y); }
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.0,a=.53;mat2 m=mat2(vec2(1.6,1.2),vec2(-1.2,1.6));for(int i=0;i<5;i++){v+=noise(p)*a;p=m*p+3.17;a*=.49;}return v;}
float segment(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/max(dot(v,v),.0001),0.0,1.0));}
float ring(float r,float radius,float width){return exp(-pow((r-radius)/max(width,.001),2.0));}
vec2 rotate(vec2 p,float a){float c=cos(a),s=sin(a);return mat2(vec2(c,s),vec2(-s,c))*p;}
float density_noise(vec3 p){
 p=fract((p+vec3(24.5,18.3,32.1))/64.0)*63.0;
 float z=floor(p.z),next_z=mod(z+1.0,64.0);
 vec2 a=(vec2(mod(z,8.0),floor(z/8.0))*64.0+p.xy+vec2(.5))/512.0;
 vec2 b=(vec2(mod(next_z,8.0),floor(next_z/8.0))*64.0+p.xy+vec2(.5))/512.0;
 return mix(texture(volume_noise,a).r,texture(volume_noise,b).r,fract(p.z));
}
float volume_density(vec3 p,float progress,float clock,int kind,float extent){
 float field=density_noise(p*24.0+vec3(clock*9.5,-clock*17.6,clock*4.3));
 float detail=density_noise(p*61.0+vec3(-clock*15.7,clock*8.0,clock*6.0));
 if(kind==1){
  float width=.075+max(p.x,0.0)*.25;
  float radial=length(p.yz)/width;
  float cap=smoothstep(-.03,.12,p.x)*(1.0-smoothstep(extent*.87,extent*1.02,p.x));
  return max(0.0,(1.15-radial)*3.2+(field-.5)*3.7+(detail-.5)*.8)*cap;
 }
 if(kind==2){
  float y=-p.y+.2;
  float width=max(.015,.42-y*.17);
  float shape=(1.0-length(p.xz)/width)*2.7+(field-.5)*3.2+(detail-.5)*.6;
  return max(0.0,shape)*smoothstep(-.25,.1,y)*(1.0-smoothstep(.9,1.75,y+field*.5));
 }
 float radius=.2+1.3*pow(progress,.52);
 vec3 q=p;
 if(variant==5)q.y=(q.y+progress*.7)*.72;
 float perturbation=(field-.5)*.95+(detail-.5)*.34;
 return max(0.0,(radius-length(q)+perturbation)*3.5);
}
vec4 march_volume(vec2 xy,float progress,float clock,int kind,float extent){
 float depth=kind==2?.62:kind==1?max(.4,extent*.28):1.9;
 float step_length=depth*2.0/18.0;
 vec3 accumulated=vec3(0.0);
 float transmission=1.0;
 vec3 light_direction=normalize(vec3(-.45,-.55,1.0));
 for(int k=0;k<18;k++){
  vec3 p=vec3(xy,depth-(float(k)+.5)*step_length);
  float density=volume_density(p,progress,clock,kind,extent);
  if(density>.015){
   float shadow_density=volume_density(p+light_direction*.17,progress,clock,kind,extent);
   float self_light=exp(-shadow_density*.38);
   float temperature=clamp(density*.14+density_noise(p*37.0+vec3(clock*11.0,-clock*19.0,0))*.70,0.0,1.0);
   float heat=kind==1 || kind==2?1.0:1.0-smoothstep(.2,.72,progress);
   vec3 ember=mix(tint.rgb*.5,mix(tint.rgb,vec3(1.0,.95,.79),.75),temperature);
   vec3 smoke=mix(vec3(.075,.07,.065),vec3(.27,.24,.21),self_light);
   vec3 radiance=mix(smoke,ember*(.38+self_light*.8),heat);
   float attenuation=exp(-density*step_length*2.1);
   accumulated+=transmission*(1.0-attenuation)*radiance;
   transmission*=attenuation;
  }
  if(transmission<.015)break;
 }
 float alpha=1.0-transmission;
 return vec4(accumulated/max(alpha,.001),alpha);
}
float diamond(vec2 p,float radius){return abs(p.x)*1.7+abs(p.y)-radius;}
float crystal(vec2 p,float radius,float clock){
 vec2 q=rotate(p,clock);
 float d=diamond(q,radius);
 float face=1.0-smoothstep(-.009,.009,d);
 float facet=(q.x>0.0?.95:.42)*(q.y>0.0?.75:1.0);
 float glint=exp(-abs(q.x)*140.0)*exp(-abs(q.y)*12.0)+exp(-abs(q.y)*140.0)*exp(-abs(q.x)*12.0);
 return face*facet+glint*.3;
}
vec4 material_field(vec2 p,float t,float clock){
 float radius=length(p),theta=atan(p.y,p.x);
 float stable=(mode==4 || mode==5 || mode==7 || mode==6)?1.0:0.0;
 float expand=mix(.15+1.20*pow(t,.52),.82,stable);
 float life=smoothstep(0.0,.04,t)*(1.0-smoothstep(.72,1.0,t));
 float a=0.0,shine=0.0,mist=0.0;
 vec3 color=tint.rgb;
 if(element_id==5 || element_id==9 || element_id==7 || element_id==2){
  // Advected liquid sheet, ballistic droplets, surface normals and wet highlights.
  bool blood=element_id==5, water=element_id==9, slime=element_id==7;
  float viscosity=slime?.35:blood?.75:1.2;
  vec2 q=p; q.y*=water?1.15:1.5;
  float warp=fbm(q*5.0+vec2(clock*viscosity,-clock*.6));
  float fluid=(expand*.55-length(q)+(warp-.5)*.23);
  float pool=smoothstep(-.025,.025,fluid);
  float rim=exp(-abs(fluid)*65.0);
  float layer=pool;
  shine=pow(max(0.0,sin(warp*11.0+q.x*3.0-clock)),14.0)*pool*.65+rim*.25;
  for(int i=0;i<40;i++){
   if(i>=particle_count)break;
   float f=float(i),h=hash(vec2(f,8.1));
   float ph=fract(clock*(water?.7:slime?.23:.48)+h);
   float ang=h*6.28318+f*2.39996;
   vec2 direction=vec2(cos(ang),sin(ang));
   float flight=stable>.5?ph:t;
   vec2 point=direction*(.10+flight*(.7+h*.8))*viscosity;
   point.y+=flight*flight*.45;
   point+=vec2(sin(clock*2.0+f)*.025,0);
   float drop_size=(.025+h*.035)*(1.0-flight*.7)*(slime?1.8:1.0);
   vec2 local=p-point;
   local=rotate(local,-ang); local.x*=mix(.45,1.0,flight);
   float d=length(local);
   float drop=1.0-smoothstep(drop_size-.007,drop_size+.007,d);
   layer=max(layer,drop*(1.0-smoothstep(.65,1.0,flight)));
   shine+=drop*exp(-dot(local-vec2(-drop_size*.3,-drop_size*.35),local-vec2(-drop_size*.3,-drop_size*.35))/max(drop_size*drop_size*.08,.00001))*.9;
   if(slime){float strand=segment(p,point*.62,point);layer=max(layer,exp(-strand*strand/.00015)*(1.0-flight)*.35);}
  }
  a=layer*(water?.48:blood?.88:.72);
  if(water){
   float ripple=ring(length(p*vec2(1,1.4)),fract(clock*.42)*1.35,.012)*(1.0-fract(clock*.42));
   a+=ripple*.45;shine+=ripple*.8;
  }else if(!blood){
   for(int i=0;i<10;i++){
    float f=float(i),h=hash(vec2(f,4));
    vec2 at=vec2(sin(f*7.0),cos(f*13.0))*sqrt(h)*.4;
    float phase=fract(clock*(slime?.35:.9)+h);
    float bubble=ring(length(p-at),.02+phase*.075,.005)*(1.0-phase)*pool;
    shine+=bubble; a+=bubble*.6;
   }
  }
  if(blood || element_id==2){
   vec2 flow=p+vec2(sin(clock*.7)*.12,clock*.14);
   float vapor=fbm(flow*7.0+vec2(clock*.8,-clock*.3));
   mist=smoothstep(.42,.78,vapor)*exp(-radius*radius/(expand*expand+.1))*(blood?.20:.36);
   a=max(a,mist);
  }
  color=mix(tint.rgb*(blood?.32:.55),tint.rgb,clamp(layer+mist,0.0,1.0));
  color+=vec3(.85,.90,.95)*min(shine,1.3)*(water?.7:blood?.32:.5);
 }else if(element_id==4 || element_id==6){
  // Solid planes of light and ice have hard geometric faces, not flame recolors.
  bool holy=element_id==4;
  float planes=0.0;
  for(int i=0;i<40;i++){
   if(i>=particle_count)break;
   float f=float(i),h=hash(vec2(f,9));
   float phase=fract(clock*(holy?.30:.18)+h);
   float ang=f*2.39996+clock*(holy?.16:-.12);
   float dist=(mode==4?.78:sqrt(h)*expand)*(holy?1.0:1.1);
   vec2 at=vec2(cos(ang),sin(ang))*dist;
   at.y-=sin(phase*3.14159)*.18;
   float facet=crystal(p-at,(holy?.07:.12)*(0.6+h),clock*(h-.5)+f);
   planes+=facet*pow(sin(phase*3.14159),.65);
  }
  float ringlight=ring(radius,.32+expand*.50,.008);
  float rays=pow(abs(sin(theta*(holy?6.0:3.0)+clock*.22)),32.0)*exp(-radius*radius*5.0);
  a=clamp(planes+ringlight*(holy?.5:.25)+rays*.6,0.0,1.0);
  color=mix(tint.rgb,vec3(1.0),clamp(planes*.7+rays*.4,0.0,.92));
  if(!holy){
   float branch=pow(abs(cos(theta*6.0-clock*.1)),48.0)*(1.0-smoothstep(.12,expand,radius));
   a=max(a,branch*.85);color+=vec3(.1,.15,.2)*branch;
  }
 }else if(element_id==8 || element_id==3){
  // Layered billows carry independent velocities and changing silhouettes.
  bool death=element_id==3;
  float cloud=0.0;
  for(int i=0;i<8;i++){
   float z=float(i)/8.0;
   vec2 flow=rotate(p,clock*(death?.24:.10)+z*.8);
   flow+=vec2(sin(clock*.6+z*6.0)*.20,-clock*(.18+z*.22));
   float n=density_noise(vec3(flow*7.0,z*6.0+clock*.5));
   float env=exp(-dot(p*vec2(1,death?.8:.7),p*vec2(1,death?.8:.7))/(expand*expand*.55+.08));
   cloud+=smoothstep(.37,.76,n)*env*.14;
  }
  float wisps=pow(max(0.0,sin(theta*5.0+radius*9.0-clock*3.0+fbm(p*3.0)*4.0)),12.0)*exp(-radius*1.9);
  a=clamp(cloud*(death?1.8:1.2)+wisps*(death?.7:.15),0.0,.85);
  color=mix(tint.rgb*.18,tint.rgb,cloud*.7+wisps*.6);
  if(death)color+=tint.rgb*wisps*.7;
 }else if(element_id==1){
  // Petals and heart silhouettes flutter on independent rising orbits.
  for(int i=0;i<32;i++){
   if(i>=particle_count)break;
   float f=float(i),h=hash(vec2(f,2));
   float phase=fract(clock*.32+h);
   vec2 at=vec2(sin(f*3.7+clock*.7)*(.25+h*.6),.7-phase*1.5);
   vec2 q=rotate(p-at,sin(clock+f)*.35)/(.06+h*.055);
   q.y=-q.y;
   float heart_base=q.x*q.x+q.y*q.y-1.0;
   float shape=heart_base*heart_base*heart_base-q.x*q.x*q.y*q.y*q.y;
   float heart=(1.0-smoothstep(-.1,.1,shape))*(1.0-smoothstep(1.4,1.6,length(q)));
   a+=heart*sin(phase*3.14159)*.75;
   shine+=heart*max(0.0,q.x+q.y)*.18;
  }
  color=tint.rgb+vec3(.3,.2,.2)*shine;
 }else{
  // Arcane knotwork, counter-rotating glyph rings and travelling nodes.
  float curl=theta+clock*.7+radius*2.0;
  float bands=pow(abs(sin(curl*3.0)),24.0)*ring(radius,.5+sin(clock*1.3)*.08,.13);
  float outer=ring(radius,expand*.8,.012);
  float glyph=pow(max(0.0,cos(theta*16.0-clock)),48.0)*ring(radius,expand*.8,.06);
  a=bands*.8+outer*.6+glyph;
  for(int i=0;i<12;i++){
   float ang=float(i)*2.39996+clock*(i%2==0?1.0:-.7);
   vec2 at=vec2(cos(ang),sin(ang))*(.2+float(i)/15.0);
   a+=exp(-dot(p-at,p-at)/.0008)*.8;
  }
  color=mix(tint.rgb,vec3(.92,.90,1),clamp(a*.65,0.0,.75));
 }
 if(mode==4){float shell=ring(radius,.78,.10);a*=shell;}
 if(mode==6){a*=smoothstep(.10,.35,radius);}
 if(mode==2){a*=1.0-smoothstep(.6,1.8,-p.y);}
 return vec4(clamp(color,vec3(0),vec3(1)),clamp(a,0.0,1.0)*life*tint.a);
}
void fragment(){
 float t=clamp((age-travel)/max(duration,.01),0.0,1.0);
 float fade=smoothstep(0.0,.045,t)*(1.0-smoothstep(.65,1.0,t));
 vec2 center=destination;
 bool flying=mode==10 && age<travel;
 if(flying){center=mix(source,destination,clamp(age/max(travel,.01),0.0,1.0));fade=1.0;}
 vec2 p=(position-center)/max(scale_px,1.0);
 vec2 delta=(destination-source)/max(scale_px,1.0);
 float distance_ab=max(length(delta),.1);
 vec2 direction=normalize(delta+vec2(.00001,0));
 vec2 tangent=vec2(-direction.y,direction.x);
 float r=length(p), angle=atan(p.y,p.x);
 if(element_id!=0){
  vec2 local=p;
  float cast_mask=1.0;
  if(mode==0 || mode==1){
   vec2 q=(position-source)/max(scale_px,1.0);
   float along=dot(q,direction),across=dot(q,tangent);
   float x=along/distance_ab;
   float width=mode==1?.10+max(along,0.0)*.24:.19;
   local=vec2(fract(x*2.0-age*.45)*1.6-.8,across/width*.65);
   cast_mask=smoothstep(0.0,.03,x)*(1.0-smoothstep(.97,1.0,x))*(1.0-smoothstep(.8,1.15,abs(across)/width));
  }
  if(flying)local*=2.0;
  COLOR=material_field(local,flying?.25:t,age);
  COLOR.a*=cast_mask;
 }else{
 float fire=0.0,core=0.0,glow=0.0,smoke=0.0,sparks=0.0;
 float n=fbm(p*3.1+vec2(age*.8,-age*1.4));
 if(mode==0 || mode==1){
  vec2 q=(position-source)/max(scale_px,1.0);
  float along=dot(q,direction),across=dot(q,tangent);
  float x=along/distance_ab;
  float gate=smoothstep(-.05,.03,x)*(1.0-smoothstep(.97,1.04,x));
  if(mode==0){
   float curl=sin(along*14.0-age*12.0)*.045+sin(along*27.0+age*8.0)*.022;
   float d=abs(across-curl);
   core=exp(-d*d/.0009)*gate;
   fire=exp(-d*d/.012)*gate*(.6+fbm(vec2(along*3.0-age*8.0,across*8.0)));
   glow=exp(-across*across/.09)*gate*.48;
   for(int j=0;j<3;j++){float path=sin(along*(9.0+float(j)*3.0)-age*(6.0+float(j)))*(.10+float(j)*.035);fire+=exp(-pow((across-path)/.013,2.0))*gate*.35;}
   core+=exp(-r*r/.009)*1.4;glow+=exp(-r*r/.16)*.5;
  }else{
   float width=.08+clamp(x,0.0,1.0)*distance_ab*.25;
   float turbulence=fbm(vec2(along*2.1-age*5.5,across*3.4));
   float edge=abs(across)/width;
   float density=smoothstep(1.2,.18,edge+turbulence*.6)*gate;
   fire=density*pow(turbulence+.3,1.8)*1.6;
   core=density*smoothstep(.6,.1,edge)*(.25+.6*turbulence);
   glow=density*.42;smoke=density*.18*(1.0-turbulence);
  }
 }else if(flying){
  float along=dot(p,direction),across=dot(p,tangent);
  float tail=smoothstep(-1.2,-.05,along)*(1.0-smoothstep(-.05,.12,along));
  float width=.02+max(0.0,-along)*.14;
  float flame=tail*exp(-across*across/(width*width))*(.6+fbm(vec2(along*6.0+age*14.0,across*9.0)));
  fire=flame;core=exp(-r*r/.0035)*1.5;glow=exp(-r*r/.05)*.65+flame*.35;
 }else if(mode==2){
  float y=-p.y+.25;
  float field=fbm(vec2(p.x*4.0,(p.y+age*1.9)*3.0));
  float width=max(.02,.43-y*.2);
  float plume=exp(-pow(p.x/width,2.0))*smoothstep(-.4,.1,y)*(1.0-smoothstep(.8,1.9,y+field*.65));
  fire=plume*(.4+field)*1.5;core=plume*smoothstep(.8,.15,y)*.75;
  glow=plume*.3+exp(-dot(p,p)*5.0)*.3;
  smoke=exp(-pow(p.x/(.35+max(y,0.0)*.2),2.0))*smoothstep(.5,1.1,y)*(1.0-smoothstep(1.5,2.3,y))*field*.25;
 }else if(mode==3 || mode==9 || mode==10){
  float expansion=.15+1.25*pow(t,.52);
	  if(variant==5){p.y+=t*.7;r=length(p*vec2(1.1,.72));}
  float cloud=fbm(p*(4.2-t)+vec2(age*.35,-age*.7));
  float density=smoothstep(expansion+.18,expansion-.22,r+cloud*.32);
  float heat=1.0-smoothstep(.08,.72,t);
  fire=density*heat*(.35+cloud)*1.8;
  core=exp(-r*r/(.016+t*.12))*exp(-t*14.0)*3.0;
  glow=density*heat*.6;
  smoke=density*smoothstep(.08,.55,t)*(.18+.22*cloud)*(1.0-t);
  float shock=ring(r,expansion*1.25,.018+.012*t)*(1.0-t);
  fire+=shock*(mode==9?1.6:.7);glow+=ring(r,expansion*1.25,.075)*(1.0-t)*.2;
  if(mode==9){fire+=ring(r,expansion*.8,.018)*(1.0-t)*.6;core+=pow(abs(sin(angle*12.0+age*4.0)),22.0)*ring(r,expansion,.09)*(1.0-t);}
 }else if(mode==4){
  float radius=.78+sin(age*3.0)*.018;
  float rim=ring(r,radius,.014),halo=ring(r,radius,.075);
  vec2 hex=rotate(p,age*.15)*13.0;
	  float lattice=pow(abs(sin(hex.x)*sin(hex.x*.5+hex.y*.866)*sin(hex.x*.5-hex.y*.866)),2.0);
  float globe=sqrt(max(0.0,1.0-r*r/(radius*radius)));
	  fire=rim*.9+halo*.24+lattice*step(r,radius)*.8+step(r,radius)*.035;
	  core=rim*(.2+.5*pow(max(0.0,cos(angle-age)),12.0))+exp(-length(p-vec2(-.28,-.32))*25.0)*.65;
  glow=exp(-r*r/.5)*.16+halo*.22;
  fire+=ring(r,radius*1.09,.008)*(.2+.2*sin(age*2.0));
	  if(variant==7){fire=halo*.12+exp(-r*r/.4)*(.18+.08*sin(age*2.0))+pow(abs(sin(angle*3.0+r*9.0-age*2.0)),16.0)*exp(-r*r/.6)*.22;core=exp(-r*r/.02)*.2;glow=exp(-r*r/.5)*.35;}
 }else if(mode==5 || mode==7){
  float edge=.8+sin(angle*7.0+age*1.6)*.025+sin(angle*13.0-age*2.1)*.018;
  float pool=smoothstep(edge+.03,edge-.04,r);
  float caustic=pow(abs(sin(p.x*12.0+age+fbm(p*5.0)*4.0)*sin(p.y*13.0-age)),8.0);
  fire=pool*(.15+.45*caustic)+ring(r,edge,.018)*.6;
  glow=pool*.15;core=pool*caustic*.3;
 }else if(mode==8){
  float splash=fbm(rotate(p,seed)*5.0);
  float radius=(.4+.35*splash)*min(1.0,t*6.0);
  fire=smoothstep(radius+.015,radius-.025,r)*.55;
  core=ring(r,radius,.009)*.1;
 }
 int count=min(particle_count,72);
 for(int i=0;i<72;i++){
  if(i>=count)break;
  float index=float(i);
  float random=hash(vec2(index+seed,6.71));
  float theta=hash(vec2(index,seed+4.3))*6.2831853;
  vec2 radial=vec2(cos(theta),sin(theta));
  float phase=fract(age*(.35+random*.3)+index/float(count));
  vec2 q;
  float size=.009+random*.014;
  if(mode==6){q=radial*(.2+.8*random)+vec2(sin(age+theta)*.1,-phase*1.1);vec2 d=p-q;float star=exp(-abs(d.x)*160.0-abs(d.y)*24.0)+exp(-abs(d.x)*24.0-abs(d.y)*160.0);sparks+=star*pow(sin(phase*3.1415926),3.0);}
  else if(mode==7 || mode==5){q=radial*sqrt(random)*.72+vec2(0,-sin(phase*3.14159)*.12);float br=.02+random*.04;float d=length(p-q);sparks+=ring(d,br,.005)*sin(phase*3.14159)*.4;core+=exp(-dot(p-q-vec2(-br*.35,-br*.4),p-q-vec2(-br*.35,-br*.4))/.00004)*.18;}
  else if(mode==0 || mode==1 || mode==4){continue;}
  else{
   float flight=(mode==2 || flying)?phase:t;
   q=radial*(.08+(1.0+random)*flight*.95)+vec2(0,flight*flight*.38);
   if(mode==2)q=vec2(radial.x*.3,-phase*1.9);
   vec2 velocity=radial*(.035+random*.05)+vec2(0,flight*.02);
   float d=segment(p,q-velocity,q);
   sparks+=exp(-d*d/(size*size))*max(0.0,1.0-flight)*(.35+random*.5);
  }
 }
 vec3 warm=mix(tint.rgb,vec3(1.0,.96,.85),.82);
 float opacity=(1.0-exp(-(fire+core+glow+sparks)*1.3))*fade;
 vec3 energy=tint.rgb*(fire+glow*.8+sparks*.7)+warm*(core+sparks*.35);
 vec3 color=energy/max(fire+core+glow+sparks,.001);
	 vec4 artwork=vec4(0.0);
	 if(mode==1){
	  vec2 q=(position-source)/max(scale_px,1.0);
	  vec2 uv=vec2(dot(q,direction)/distance_ab,dot(q,tangent)/(max(.1,distance_ab)*.58)+.5);
	  uv+=vec2(0.0,(fbm(uv*8.0+age*vec2(-2.5,.4))-.5)*.025);
	  if(uv.x>=0.0 && uv.x<=1.0 && uv.y>=0.0 && uv.y<=1.0)artwork=texture(flame_jet,uv);
	 }else if(mode==2){
	  vec2 uv=vec2((-.15-p.y)/1.9+.15,p.x/1.25+.5);
	  uv.y+=(fbm(uv*7.0+vec2(age*2.0,0))-.5)*.025;
	  if(uv.x>=0.0 && uv.x<=1.0 && uv.y>=0.0 && uv.y<=1.0)artwork=texture(flame_jet,uv);
	 }else if((mode==3 || mode==9 || mode==10) && !flying){
	  float radius=.25+1.3*pow(t,.45);
	  vec2 uv=rotate(p,age*.13)/max(radius*2.0,.1)+.5;
	  uv+=(vec2(fbm(uv*8.0+age),fbm(uv*8.0-age))-.5)*.025;
	  if(uv.x>=0.0 && uv.x<=1.0 && uv.y>=0.0 && uv.y<=1.0)artwork=texture(fire_cloud,uv);
	 }
 float smoke_alpha=smoke*fade;
 color=mix(vec3(.11,.105,.10),color,opacity/max(opacity+smoke_alpha,.001));
	 if((mode==1 || mode==2 || mode==3 || mode==9 || mode==10) && !flying){
	  vec2 xy=p;
	  if(mode==1){vec2 q=(position-source)/max(scale_px,1.0);xy=vec2(dot(q,direction),dot(q,tangent));}
	  vec4 volume=march_volume(xy,t,age,mode,distance_ab);
	  float volume_alpha=volume.a*fade;
	  color=mix(color,volume.rgb,volume.a*.92)+tint.rgb*sparks*.12;
	  opacity=max(opacity*.55,volume_alpha);
	 }
	 if(artwork.a>.002){
	  float brightness=dot(artwork.rgb,vec3(.2126,.7152,.0722));
	  float heat=(mode==1 || mode==2)?1.0:1.0-smoothstep(.45,.9,t);
	  vec3 painted=mix(tint.rgb*(.2+brightness*1.1),vec3(1.0,.97,.87),pow(brightness,2.8)*.8);
	  painted=mix(vec3(brightness*.32),painted,heat);
	  float alpha=artwork.a*fade*.07*fbm(p*9.0+vec2(age*3.0,-age*5.0));
	  color=mix(color,painted,alpha);
	  opacity=max(opacity,alpha);
	 }
 COLOR=vec4(color,clamp((opacity+smoke_alpha)*tint.a,0.0,1.0));
 }
}
"""
static var shader: Shader
var shader_material: ShaderMaterial
func _ready() -> void:
	if shader==null: shader=Shader.new(); shader.code=SHADER
	shader_material=ShaderMaterial.new(); shader_material.shader=shader
	material=shader_material
	shader_material.set_shader_parameter("volume_noise",load("res://hearth20/fx_noise.png"))
	shader_material.set_shader_parameter("fire_cloud",load("res://hearth20/fx-firecloud.png"))
	shader_material.set_shader_parameter("flame_jet",load("res://hearth20/fx-flamejet.png"))
func configure(event: Dictionary, world_scale: float, world_offset: Vector2, now: int) -> void:
	if shader_material==null: return
	var a: Vector2=event.source*world_scale-world_offset
	var b: Vector2=event.destination*world_scale-world_offset
	var scale:=world_scale*clampf(float(event.get("size",1)),0.25,4)
	var bounds:=Rect2(a,Vector2.ZERO).expand(b).grow(scale*2.5)
	polygon=PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	var kind:=str(event.get("effect","rocket"))
	shader_material.set_shader_parameter("element_id",Hearth20BoardTools.COLORS.keys().find(Hearth20BoardTools.fx_material(event)))
	for pair in [["source",a],["destination",b],["scale_px",scale],["age",float(now-int(event.started_usec))/1000000.0],["duration",float(event.impact_duration_usec)/1000000.0],["travel",float(event.travel_usec)/1000000.0],["mode",int(MODES.get(kind,3))],["variant",Hearth20BoardTools.EFFECTS.find(kind)],["particle_count",clampi(int(event.get("density",48)),8,128)],["seed",float(int(event.get("seed",1))%10000)],["tint",Color(str(event.get("color","#ff682b")))]]:
		shader_material.set_shader_parameter(str(pair[0]),pair[1])

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float density = .15;
varying vec3 dust_seed;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
    dust_seed=INSTANCE_CUSTOM.rgb;
    VERTEX.x+=mod(TIME*(1.4+dust_seed.x*1.8)+dust_seed.y*170.0,170.0)-85.0;
    VERTEX.y+=sin(TIME*.3+dust_seed.z*16.0)*.18;
}
void fragment(){
    vec2 p=UV*vec2(7.0,3.0)+vec2(-TIME*.10,dust_seed.z*31.0);
    float billow=noise(p+noise(p*.6)*2.0)*.7+noise(p*2.9)*.3;
    float edge=pow(max(0.0,sin(UV.y*3.14159265)),1.5)*smoothstep(0.0,.16,UV.x)*smoothstep(0.0,.16,1.0-UV.x);
    ALBEDO=mix(vec3(.61,.29,.095),vec3(.95,.58,.23),billow);
    ALPHA=edge*smoothstep(.25,.85,billow)*density;
}

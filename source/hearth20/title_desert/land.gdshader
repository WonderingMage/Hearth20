shader_type spatial;
render_mode diffuse_burley, depth_prepass_alpha;
uniform vec4 rock_color : source_color = vec4(.42,.16,.055,1.0);
uniform sampler2D sand_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 world_position;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    vec3 p=world_position;
    float strata=sin(p.y*3.1+sin(p.x*.18)*1.8+cos(p.z*.3))*.5+.5;
    float grain=noise(p.xz*.7)*.65+noise(p.xz*3.3)*.35;
    float ripple=noise(p.xz*.14)*.65+noise(p.xz*.047)*.35;
    float sand=pow(max(0.0,NORMAL.y),8.0);
    vec3 stone=rock_color.rgb*(.74+.26*strata);
    vec3 sand_color=texture(sand_texture,p.xz*.085).rgb;
    ALBEDO=mix(stone,sand_color*(.67+ripple*.27),sand)+vec3(grain*.005);
    ROUGHNESS=.90;
    SPECULAR=.18;
    float haze=1.0-exp(-length(VERTEX)*.006);
    ALBEDO=mix(ALBEDO,vec3(.36,.15,.06),haze*.25);
    ALPHA=1.0-smoothstep(28.0,125.0,-world_position.z);
}

shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
varying float distance_from_sun;
void vertex(){distance_from_sun=-(MODELVIEW_MATRIX*vec4(VERTEX,1.)).z;}
void fragment(){
 float depth=clamp(distance_from_sun/48.,0.,.99999);
 vec3 encoded=fract(depth*vec3(1.,255.,65025.));
 encoded-=encoded.yzz*vec3(1./255.,1./255.,0.);
 ALBEDO=encoded;
}

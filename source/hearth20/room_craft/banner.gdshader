shader_type spatial;
render_mode cull_disabled;
uniform sampler2D art : source_color, filter_linear_mipmap_anisotropic;
uniform float phase=0.;
void vertex(){
 float pin=UV.y*UV.y;
 float wave=TIME*.68+UV.x*5.+UV.y*6.+phase;
 VERTEX.z+=sin(wave)*.006*pin;
 NORMAL=normalize(NORMAL+vec3(-cos(wave)*.02*pin,sin(wave)*.005*pin,0.));
}
void fragment(){
 ALBEDO=texture(art,UV).rgb*.85;
 ROUGHNESS=.94;SPECULAR=.17;METALLIC=0.;
}

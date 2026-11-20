shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D atlas : source_color,filter_linear_mipmap;
uniform float phase=0.;
varying float animation_offset;
void vertex(){
 vec3 size=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*size.x,INV_VIEW_MATRIX[1]*size.y,INV_VIEW_MATRIX[2]*size.z,MODEL_MATRIX[3]);
 animation_offset=phase+INSTANCE_CUSTOM.z*16.;
 float tip=1.-UV.y;
 VERTEX.x+=sin(TIME*5.3+phase+UV.y*6.)*.006*tip*tip;
}
vec4 frame(float index,vec2 p){
 vec2 tile=vec2(mod(index,4.),floor(index/4.));
 return texture(atlas,(tile+clamp(p,vec2(.012),vec2(.988)))/4.);
}
void fragment(){
 float time=mod(TIME*13.+animation_offset,16.);float a=floor(time);float b=mod(a+1.,16.);
 vec2 p=UV;p.x+=sin(TIME*4.1+UV.y*8.+animation_offset)*.012*pow(1.-UV.y,2.);
 vec4 fire=mix(frame(a,p),frame(b,p),smoothstep(0.,1.,fract(time)));
 ALBEDO=fire.rgb;EMISSION=fire.rgb*1.5;
 ALPHA=fire.a*COLOR.a;
}

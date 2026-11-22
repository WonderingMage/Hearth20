shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D panorama : source_color,repeat_enable,filter_linear_mipmap_anisotropic;
uniform bool has_panorama=false;
uniform vec3 fallback=vec3(.3,.45,.35);
uniform float panorama_yaw=0.;
uniform float opacity=1.;
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec3 ray=normalize(world_point-INV_VIEW_MATRIX[3].xyz);
 vec2 uv=vec2((atan(ray.x,-ray.z)+panorama_yaw)/6.28318530718+.5,acos(clamp(ray.y,-1.,1.))/3.14159265359);
 vec3 color=has_panorama?texture(panorama,uv).rgb:fallback;
 // ALPHA selects the transparent pipeline, avoiding the opaque depth prepass.
 // Draw before Gaussian content, while retaining opaque wall/frame depth tests.
 ALBEDO=color;EMISSION=color*.10;ROUGHNESS=1.;ALPHA=opacity;
}

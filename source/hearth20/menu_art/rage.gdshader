shader_type canvas_item;
render_mode blend_add;
void fragment() {
    vec4 mist = texture(TEXTURE, UV);
    // Add only luminous red from the generated VFX layer. The base illustration
    // supplies all faces, bodies, equipment and fine material detail.
    float red = max(0.0, mist.r - max(mist.g, mist.b) * 0.7);
    float standing_face = 1.0 - smoothstep(0.75, 1.2, length((UV-vec2(.880,.405))/vec2(.027,.048)));
    float kneeling_face = 1.0 - smoothstep(0.75, 1.2, length((UV-vec2(.781,.626))/vec2(.033,.052)));
    float right_side = smoothstep(.61,.64,UV.x);
    float clear_faces = (1.0-standing_face)*(1.0-kneeling_face);
    float breathing = .96 + .04*sin(TIME*.85);
    COLOR = vec4(vec3(red, red*.035, red*.012), mist.a*.48*clear_faces*right_side*breathing);
}

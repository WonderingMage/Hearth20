shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, blend_mix;

varying float shimmer;

void vertex() {
	float phase = INSTANCE_CUSTOM.x * TAU;
	float speed = 0.28 + INSTANCE_CUSTOM.y * 0.54;
	vec3 sway = vec3(
		sin(TIME * speed + phase) * 0.21,
		sin(TIME * speed * 0.63 + phase * 1.7) * 0.13,
		cos(TIME * speed * 0.8 + phase) * 0.17
	);
	vec3 center = (MODEL_MATRIX * vec4(sway, 1.0)).xyz;
	vec4 view = VIEW_MATRIX * vec4(center, 1.0);
	float size = mix(0.010, 0.033, INSTANCE_CUSTOM.z);
	POSITION = PROJECTION_MATRIX * (view + vec4(VERTEX.xy * size, 0.0, 0.0));
	float near_fade = smoothstep(0.32, 1.7, -view.z);
	shimmer = near_fade * (0.55 + 0.45 * sin(phase + TIME * speed * 1.2)) * INSTANCE_CUSTOM.w;
}

void fragment() {
	float distance_from_center = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(1.0, 0.86, 0.65);
	ALPHA = (1.0 - smoothstep(0.02, 1.0, distance_from_center)) * shimmer;
}

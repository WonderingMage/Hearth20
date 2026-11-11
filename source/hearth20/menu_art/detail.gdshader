shader_type canvas_item;
// Display-only detail recovery. The supplied JPG remains byte-for-byte unchanged.
// Keep the correction small and bounded to the local range to avoid bright halos.
void fragment() {
    vec2 step_uv = TEXTURE_PIXEL_SIZE;
    vec4 original = texture(TEXTURE, UV);
    vec3 north = texture(TEXTURE, UV + vec2(0.0, -step_uv.y)).rgb;
    vec3 south = texture(TEXTURE, UV + vec2(0.0, step_uv.y)).rgb;
    vec3 east = texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).rgb;
    vec3 west = texture(TEXTURE, UV + vec2(-step_uv.x, 0.0)).rgb;
    vec3 low = min(original.rgb, min(min(north, south), min(east, west)));
    vec3 high = max(original.rgb, max(max(north, south), max(east, west)));
    vec3 detail = original.rgb - (north + south + east + west) * 0.25;
    COLOR = vec4(clamp(original.rgb + detail * 0.18, low, high), original.a);
}

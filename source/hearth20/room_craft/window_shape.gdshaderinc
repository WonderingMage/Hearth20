// Shared silhouette for exterior compositing and indoor light scattering.
float h20_window_edge(vec2 point, vec2 dimensions, float arch_rise) {
	vec2 half_size = dimensions * 0.5;
	float edge = min(half_size.x - abs(point.x), half_size.y - abs(point.y));
	float spring = half_size.y - arch_rise;
	if (arch_rise > 0.0 && point.y > spring) {
		vec2 arc = vec2(point.x / half_size.x, (point.y - spring) / arch_rise);
		edge = min(edge, (1.0 - length(arc)) * min(half_size.x, arch_rise));
	}
	return edge;
}

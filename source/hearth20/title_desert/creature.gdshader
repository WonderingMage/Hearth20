shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D hide_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform float surface_roughness = 0.6;
uniform float textured = 1.0;
uniform float bump_strength = 0.16;
uniform float wetness = 0.0;
uniform float iris = 0.0;
uniform float anatomy_layer = 0.0;
uniform float horn = 0.0;
uniform vec4 edge_color : source_color = vec4(0.0);
varying vec3 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec3 skin = texture(hide_texture, UV).rgb;
    vec2 pixel = vec2(1.0 / 1254.0);
    float left = dot(texture(hide_texture, UV - vec2(pixel.x, 0.0)).rgb, vec3(.299,.587,.114));
    float right = dot(texture(hide_texture, UV + vec2(pixel.x, 0.0)).rgb, vec3(.299,.587,.114));
    float down = dot(texture(hide_texture, UV - vec2(0.0, pixel.y)).rgb, vec3(.299,.587,.114));
    float up = dot(texture(hide_texture, UV + vec2(0.0, pixel.y)).rgb, vec3(.299,.587,.114));
    float horn_rings = .93 + .07 * sin(UV.y * 80.0 + sin(UV.x * 12.0));
    vec3 base = mix(tint.rgb * horn_rings, skin * tint.rgb, textured);
    base *= mix(1.0,mix(1.12,.35,smoothstep(.45,.98,UV2.y)),horn);
    base *= 1.0-iris*(.07+.07*sin(UV.x*90.0));
    float coverage=mix(1.0,smoothstep(0.0,1.0,UV2.x),anatomy_layer);
    vec3 edge=mix(skin*vec3(1.0,.92,.75),edge_color.rgb,edge_color.a);
    base=mix(edge,base,coverage);
    ALBEDO = base * mix(.65,1.0,COLOR.r);
    AO = COLOR.r;
    AO_LIGHT_AFFECT = .3;
    ROUGHNESS = clamp(mix(.65,surface_roughness,coverage) - length(skin)*.045*textured, .22, .95);
    SPECULAR = mix(.42,.75,wetness);
    CLEARCOAT = wetness*.45*coverage;
    CLEARCOAT_ROUGHNESS = .15;
    EMISSION = base*iris*.04;
    NORMAL_MAP = normalize(vec3((left-right)*bump_strength, (down-up)*bump_strength, 1.0))*.5+.5;
    NORMAL_MAP_DEPTH = mix(1.0,textured,coverage);
    // Only distant surfaces dissolve into airborne dust. Foreground detail stays crisp.
    float distance_haze = 1.0-exp(-length(VERTEX)*.0025);
    ALBEDO = mix(ALBEDO, vec3(.51,.24,.085), distance_haze*.22);
}

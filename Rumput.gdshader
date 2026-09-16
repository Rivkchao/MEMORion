shader_type spatial;
render_mode cull_disabled, unshaded;

uniform vec4 grass_color : source_color = vec4(0.2, 0.75, 0.9, 1.0);
uniform sampler2D texture_albedo : source_color;
uniform float wind_speed = 1.5;
uniform float wind_strength = 0.25;

uniform vec4 emission_color : source_color = vec4(1.0, 0.2, 0.8, 1.0);
uniform float emission_strength : hint_range(0.0, 5.0, 0.05) = 0.0;

varying float v_height;

void vertex() {
	float height_factor = max(0.0, VERTEX.y);
	v_height = clamp(VERTEX.y / 1.1, 0.0, 1.0);
	float wave = sin(TIME * wind_speed + (NODE_POSITION_WORLD.x + VERTEX.x) * 2.0) * wind_strength;
	VERTEX.x += wave * height_factor;
	VERTEX.z += wave * 1.0 * height_factor;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	vec3 base_col = albedo_tex.rgb * grass_color.rgb;
	// Pendaran halus pada helai rumput di malam hari agar kontras dan tidak nyaru dengan ground
	float tip_factor = mix(0.6, 1.3, v_height);
	vec3 glow = emission_color.rgb * emission_strength * tip_factor;
	ALBEDO = base_col + glow;
	ALPHA = albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
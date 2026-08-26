shader_type spatial;
render_mode cull_disabled;

uniform vec4 grass_color : source_color = vec4(0.2, 0.75, 0.9, 1.0); // Warna biru muda
uniform sampler2D texture_albedo : source_color;
uniform float wind_speed = 1.5;
uniform float wind_strength = 0.25;

void vertex() {
	// Pastikan hanya titik yang tingginya di atas 0 (batang ke atas) yang bergerak
	float height_factor = max(0.0, VERTEX.y);
	
	// Gerakan angin lembut berbasis koordinat dan waktu
	float wave = sin(TIME * wind_speed + (NODE_POSITION_WORLD.x + VERTEX.x) * 2.0) * wind_strength;
	
	// Terapkan goyangan hanya ke ujung atas rumput
	VERTEX.x += wave * height_factor;
	VERTEX.z += wave * 1.0 * height_factor;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo_tex.rgb * grass_color.rgb;
	ALPHA = albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5; // Memotong background transparan PNG
}
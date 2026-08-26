// Shader untuk Mesh Partikel (Glow Lingkaran)
shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded;

uniform vec4 particle_color : source_color = vec4(0.0, 0.5, 1.0, 1.0); // Biru glowing
uniform float glow_intensity = 2.0;

void vertex() {
	// Menghadapkan quad ke kamera (Billboard)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	
	// Mempertahankan skala asli partikel
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void fragment() {
	// Buat bentuk lingkaran dari UV
	float dist = distance(UV, vec2(0.5));
	float mask = smoothstep(0.5, 0.2, dist); // Lingkaran halus
	
	// Warna biru + intensitas glow (untuk WorldEnvironment Glow)
	ALBEDO = particle_color.rgb * glow_intensity;
	ALPHA = mask * particle_color.a * (1.0 - dist * 2.0); // Transparansi halus
}
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

// Konfigurasi dasar hologram (Cyan)
const vec3 BASE_COLOR = vec3(0.0, 0.25, 0.95);    // Biru pekat (Hex: #0040F2)
const vec3 FRESNEL_COLOR = vec3(0.1, 0.6, 1.0);   // Biru neon terang tepian (Hex: #1A99FF)
const float FRESNEL_POWER = 2.5;

// Efek garis & animasi
const float LINE_FREQUENCY = 45.0;  // Kerapatan garis scanline
const float LINE_SPEED = 3.0;       // Kecepatan garis bergerak
const float GLITCH_SPEED = 8.0;     // Kecepatan kedip/glitch
const float EMISSION_ENERGY = 2.0;  // Kekuatan cahaya glow

varying vec3 v_world_pos;

// Fungsi pseudo-random noise sederhana
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Efek sedikit jitter / glitch vertikal pada vertex
	float glitch_trigger = step(0.96, hash(vec2(floor(TIME * GLITCH_SPEED), 0.0)));
	VERTEX.x += glitch_trigger * (hash(vec2(TIME, VERTEX.y)) - 0.5) * 0.04;
}

void fragment() {
	// 1. Efek Fresnel (Tepi bersinar)
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), FRESNEL_POWER);
	
	// 2. Efek Scanlines bergerak secara vertikal
	float scanline = sin((v_world_pos.y * LINE_FREQUENCY) - (TIME * LINE_SPEED)) * 0.5 + 0.5;
	scanline = pow(scanline, 1.5);

	// 3. Gabungkan warna cyan
	vec3 final_color = mix(BASE_COLOR, FRESNEL_COLOR, fresnel);
	final_color += FRESNEL_COLOR * scanline * 0.4;

	// 4. Alpha / Transparansi hologram
	float alpha = clamp(fresnel * 0.8 + scanline * 0.35 + 0.15, 0.0, 1.0);

	ALBEDO = final_color;
	EMISSION = final_color * EMISSION_ENERGY;
	ALPHA = alpha;
}
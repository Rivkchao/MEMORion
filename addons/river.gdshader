shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// --- Warna Dasar Air (Lebih Cyan, Seimbang, & Alami) ---
uniform vec4 water_color : source_color = vec4(0.04, 0.38, 0.52, 0.85);
uniform vec4 shallow_color : source_color = vec4(0.15, 0.72, 0.78, 0.5);
uniform vec4 foam_color : source_color = vec4(0.85, 0.98, 1.0, 1.0);
uniform float transparency : hint_range(0.0, 1.0) = 0.8;

// --- Animasi Gelombang Mesh ---
uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wave_strength : hint_range(0.0, 0.2) = 0.03;

// --- Aliran Arus & Busa (Foam) ---
uniform vec2 flow_direction = vec2(1.0, 0.0);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.4;
uniform float foam_distance : hint_range(0.0, 3.0) = 0.6;
uniform float foam_cutoff : hint_range(0.0, 1.0) = 0.45;
uniform float foam_opacity : hint_range(0.0, 1.0) = 0.5;

// --- Pendaran Malam (Bioluminescence Glow HDR) ---
uniform float glow_intensity : hint_range(0.0, 10.0) = 0.0;
uniform vec4 night_glow_color : source_color = vec4(0.08, 0.78, 0.92, 1.0);
uniform float fresnel_power : hint_range(1.0, 8.0) = 4.0;
uniform float foam_glow_boost : hint_range(1.0, 6.0) = 3.5;

// --- Tekstur ---
uniform sampler2D foam_noise : repeat_enable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

void vertex() {
	vec2 dir = normalize(flow_direction);
	float wave = sin((VERTEX.x * dir.x + VERTEX.z * dir.y) * 3.0 + TIME * wave_speed) * wave_strength;
	wave += cos((VERTEX.z * dir.x - VERTEX.x * dir.y) * 2.0 + TIME * wave_speed * 0.8) * (wave_strength * 0.5);
	VERTEX.y += wave;
}

void fragment() {
	// 1. Kedalaman Air Linear
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	float depth_diff = -view_pos.z - VERTEX.z;

	// 2. Aliran UV Buih
	vec2 dir = normalize(flow_direction);
	vec2 flow_uv = UV + (dir * TIME * flow_speed);
	vec2 flow_uv_cross = (UV * 1.5) - (dir * TIME * (flow_speed * 0.6));

	// 3. Shore Foam & Surface Noise
	float shore_edge = 1.0 - clamp(depth_diff / foam_distance, 0.0, 1.0);
	float noise_val = texture(foam_noise, flow_uv).r * texture(foam_noise, flow_uv_cross).r;
	float surface_foam = step(foam_cutoff, noise_val + (shore_edge * 0.5));
	float final_foam = clamp(shore_edge + surface_foam, 0.0, 1.0);

	// 4. Komposisi Warna Albedo
	vec4 base_water = mix(shallow_color, water_color, clamp(depth_diff * 0.5, 0.0, 1.0));
	float effective_foam = final_foam * foam_opacity;
	vec3 final_color = mix(base_water.rgb, foam_color.rgb, effective_foam);
	float final_alpha = mix(transparency, 1.0, effective_foam);

	// 5. Output Pendaran Malam (EMISSION HDR)
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	float wave_pulse = sin(TIME * 2.0 + UV.x * 3.0) * 0.15 + 0.85;
	
	// Total pendaran: permukaan + tepian fresnel + buih pantai
	float total_glow = (0.7 + fresnel * 1.8 + (effective_foam * foam_glow_boost)) * wave_pulse;
	vec3 emission_out = night_glow_color.rgb * (glow_intensity * total_glow);

	ALBEDO = final_color;
	ALPHA = final_alpha;
	EMISSION = emission_out;
	ROUGHNESS = mix(0.1, 0.4, final_foam);
	METALLIC = 0.1;
	SPECULAR = 0.8;
}
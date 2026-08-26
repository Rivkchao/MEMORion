shader_type sky;

group_uniforms Sky_Day;
uniform vec4 sky_day : source_color = vec4(0.2, 0.55, 0.95, 1.0);       // Biru cerah
uniform vec4 horizon_day : source_color = vec4(0.7, 0.85, 1.0, 1.0);    // Horizon siang

group_uniforms Sky_Sunset;
uniform vec4 sky_sunset : source_color = vec4(0.35, 0.15, 0.45, 1.0);   // Langit atas senja (lembayung)
uniform vec4 horizon_sunset : source_color = vec4(1.0, 0.45, 0.1, 1.0); // Jingga kemerahan senja

group_uniforms Sky_Night;
uniform vec4 sky_night : source_color = vec4(0.02, 0.04, 0.09, 1.0);    // Malam gelap
uniform vec4 horizon_night : source_color = vec4(0.08, 0.1, 0.18, 1.0);  // Horizon malam

group_uniforms Sun;
uniform float sun_scale = 0.04;
uniform float sun_strength = 12.0;
uniform vec4 sun_color_day : source_color = vec4(1.0, 1.0, 1.0, 1.0);       // Matahari siang putih
uniform vec4 sun_color_sunset : source_color = vec4(1.0, 0.75, 0.2, 1.0);   // Matahari senja kuning/emas

group_uniforms Moon;
uniform float moon_scale = 0.045;
uniform float moon_strength = 4.0;
uniform vec4 moon_color : source_color = vec4(0.35, 0.7, 1.0, 1.0); // Bulan biru

group_uniforms Clouds;
uniform sampler2D cloud_tex_01;
uniform sampler2D cloud_tex_02;
uniform vec4 cloud_color : source_color = vec4(0.9, 0.92, 0.98, 1.0);
uniform vec2 cloud_tiling = vec2(1.0);
uniform vec2 wind_speed = vec2(0.5);
uniform float cloud_density : hint_range(0.0, 5.0, 0.1) = 0.7;
uniform float cloud_depth = 2.0;
uniform float cloud_shape_exponent = 2.0;
uniform float cloud_occlude_exponent = 1.0;

group_uniforms Stars;
uniform sampler2D night_noise_01;
uniform sampler2D night_noise_02;

group_uniforms Aurora;
uniform sampler2D aurora_noise;
uniform vec4 aurora_color_bottom : source_color = vec4(0.0, 1.0, 0.6, 1.0);
uniform vec4 aurora_color_top : source_color = vec4(0.3, 0.0, 0.9, 1.0);
uniform float aurora_speed = 0.05;
uniform float aurora_intensity = 1.5;

float plane_intersection(vec3 origin, vec3 normal, vec3 ray_start, vec3 ray_dir) {
	return dot(origin - ray_start, normal) / dot(ray_dir, normal);
}

float get_cloud_height(sampler2D tex, vec2 uv) {
	float height = texture(tex, uv).r;
	height = clamp((height - (1.0 - cloud_density)) / (cloud_density), 0.0, 1.0);
	return pow(height, cloud_shape_exponent);
}

void sky() {
	float t = plane_intersection(vec3(0.0, 1.0, 0.0), vec3(0.0, -1.0, 0.0), vec3(0.0), EYEDIR);
	
	// Arah vertikal matahari: 1.0 = siang tengah hari, ~0.0 s/d 0.25 = senja, < 0.0 = malam
	float sun_height = LIGHT0_DIRECTION.y;
	
	// Bobot pembagian waktu
	float day_weight = smoothstep(0.2, 0.6, sun_height);
	float sunset_weight = smoothstep(-0.05, 0.25, sun_height) * (1.0 - day_weight);
	float night_weight = smoothstep(0.1, -0.2, sun_height);

	// Awan
	float cloud_value = 0.0;
	if (t >= 0.0) {
		vec3 wind = vec3(wind_speed.x, 0.0, wind_speed.y) * TIME * 0.1;
		vec3 tiling = vec3(cloud_tiling.x, 1.0, cloud_tiling.y) * 0.2;
		vec3 cloud_pos1 = EYEDIR * t * tiling + wind;
		vec3 cloud_pos2 = EYEDIR * t * tiling + (wind * 0.5);

		float height1 = get_cloud_height(cloud_tex_01, cloud_pos1.xz);
		float height2 = get_cloud_height(cloud_tex_02, cloud_pos2.xz);
		cloud_pos1 += EYEDIR * height1 * cloud_depth * 0.1;
		cloud_pos2 += EYEDIR * height2 * cloud_depth * 0.1;
		height1 = get_cloud_height(cloud_tex_01, cloud_pos1.xz);
		height2 = get_cloud_height(cloud_tex_02, cloud_pos2.xz);
		cloud_value = min(height1, height1 * height2);
		cloud_value *= smoothstep(0.0, 0.2, EYEDIR.y);
	}

	// --- Matahari (Putih di Siang, Kuning di Senja) ---
	vec4 dynamic_sun_color = mix(sun_color_sunset, sun_color_day, day_weight);
	float sun_dist = distance(EYEDIR, LIGHT0_DIRECTION);
	float sun_mask = clamp(1.0 - sun_dist - pow(cloud_value, cloud_occlude_exponent), 0.0, 1.0);
	float sun_disc = clamp(smoothstep(1.0 - sun_scale, 1.0, sun_mask), 0.0, 1.0);
	float sun_glow = clamp(0.0, 1.0, pow(sun_mask, 4.0) * 0.08);
	vec3 sun = dynamic_sun_color.rgb * sun_strength * max(sun_disc, sun_glow) * (1.0 - night_weight);

	// --- Bulan (Pendar Biru di Malam Hari) ---
	float moon_dist = distance(EYEDIR, -LIGHT0_DIRECTION);
	float moon_mask = clamp(1.0 - moon_dist - pow(cloud_value, cloud_occlude_exponent), 0.0, 1.0);
	float moon_disc = clamp(smoothstep(1.0 - moon_scale, 1.0, moon_mask), 0.0, 1.0);
	float moon_glow = clamp(0.0, 1.0, pow(moon_mask, 3.5) * 0.06);
	vec3 moon = moon_color.rgb * moon_strength * max(moon_disc, moon_glow) * night_weight;

	// --- Bintang ---
	float star_sample = texture(night_noise_01, (EYEDIR / (1.0 - abs(t) * 0.05)).xz).r;
	float stars = smoothstep(0.92, 0.97, star_sample) * night_weight;
	stars = clamp(stars - cloud_value * 2.0, 0.0, 1.0);

	// --- Gradasi Warna Langit ---
	vec3 active_sky = (sky_day.rgb * day_weight) + (sky_sunset.rgb * sunset_weight) + (sky_night.rgb * night_weight);
	vec3 active_horizon = (horizon_day.rgb * day_weight) + (horizon_sunset.rgb * sunset_weight) + (horizon_night.rgb * night_weight);
	
	vec3 sky = mix(active_sky, active_horizon, pow(1.0 - clamp(abs(EYEDIR.y), 0.0, 1.0), 2.5));
	
	// Campur warna awan
	vec3 dynamic_cloud_tint = mix(cloud_color.rgb, horizon_sunset.rgb * 0.8, sunset_weight * 0.7);
	dynamic_cloud_tint = mix(dynamic_cloud_tint, sky_night.rgb * 1.5, night_weight * 0.8);
	sky = mix(sky, dynamic_cloud_tint, pow(cloud_value, 0.8));

	// Gabung bintang, matahari, dan bulan
	sky += stars;
	sky += sun * clamp(EYEDIR.y + 0.5, 0.0, 1.0);
	sky += moon * clamp(EYEDIR.y + 0.5, 0.0, 1.0);

	// --- Aurora Borealis ---
	vec2 aurora_uv = (EYEDIR / max(EYEDIR.y, 0.1)).xz * 0.1;
	aurora_uv += vec2(TIME * aurora_speed, sin(TIME * aurora_speed * 0.5) * 0.05);
	float a_noise = texture(aurora_noise, aurora_uv).r;
	float aurora_height_mask = smoothstep(0.1, 0.4, EYEDIR.y) * smoothstep(0.8, 0.4, EYEDIR.y);
	vec3 aurora_col = mix(aurora_color_bottom.rgb, aurora_color_top.rgb, smoothstep(0.1, 0.6, EYEDIR.y));
	vec3 aurora = aurora_col * pow(a_noise, 2.0) * aurora_height_mask * aurora_intensity * night_weight;

	sky += aurora;

	COLOR = sky;
}
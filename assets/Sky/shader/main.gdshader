shader_type sky;

group_uniforms Sky_Day;
uniform vec4 sky_day : source_color = vec4(0.2, 0.55, 0.95, 1.0);
uniform vec4 horizon_day : source_color = vec4(0.7, 0.85, 1.0, 1.0);

group_uniforms Sky_Sunset;
uniform vec4 sky_sunset : source_color = vec4(0.35, 0.15, 0.45, 1.0);
uniform vec4 horizon_sunset : source_color = vec4(1.0, 0.45, 0.1, 1.0);

group_uniforms Sky_Night;
uniform vec4 sky_night : source_color = vec4(0.02, 0.04, 0.09, 1.0);
uniform vec4 horizon_night : source_color = vec4(0.08, 0.1, 0.18, 1.0);

group_uniforms Sun;
uniform float sun_scale = 0.04;
uniform float sun_strength = 12.0;
uniform vec4 sun_color_day : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 sun_color_sunset : source_color = vec4(1.0, 0.75, 0.2, 1.0);

group_uniforms Moon;
uniform float moon_scale = 0.045;
uniform float moon_strength = 4.0;
uniform vec4 moon_color : source_color = vec4(0.35, 0.7, 1.0, 1.0);

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

group_uniforms Aurora_Raymarching;
uniform sampler2D aurora_color_gradient : source_color;
uniform float aurora_brightness = 1.7;
uniform float aurora_speed = 0.12;
uniform float aurora_height = 42.0;
uniform float aurora_scale = 0.8;
const float resolution_loop_count = 30.0;

// Helper Matematika & Raymarching Aurora
mat2 mm2(float a) {
	float c = cos(a), s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

float tri(float x) {
	return clamp(abs(fract(x) - 0.5), 0.01, 0.49);
}

vec2 tri2(vec2 p) {
	return vec2(tri(p.x) + tri(p.y), tri(p.y + tri(p.x)));
}

float trinoise2d(vec2 p, float t) {
	float z = 1.8;
	float z2 = 2.5;
	float rz = 0.0;

	p *= mm2(p.x * 0.06);
	vec2 bp = p;
	mat2 rot = mm2(t);

	for (int i = 0; i < 4; i++) {
		vec2 dg = tri2(bp * 1.85) * 0.75;
		dg = dg * rot;
		p -= dg / z2;

		bp *= 1.3;
		z2 *= 0.45;
		z *= 0.42;

		p *= 1.21 + (rz - 1.0) * 0.02;
		rz += tri(p.x + tri(p.y)) * z;

		p *= mat2(vec2(-0.95534, -0.29552), vec2(0.29552, -0.95534));
	}

	return clamp(1.0 / pow(rz * 29.0, 1.3), 0.0, 0.55);
}

vec4 get_aurora_color(vec3 direction) {
	vec4 color = vec4(0.0);
	vec4 average_color = vec4(0.0);
	
	float jitter = fract(sin(dot(direction.xz, vec2(13.0, 78.0))));
	float jitter_step_scale = aurora_height / resolution_loop_count;
	
	for (int i = 0; i < int(resolution_loop_count); i++) {
		float depth_step = (float(i) + jitter) * jitter_step_scale;
		float depth = ((aurora_scale + pow(depth_step, 1.4) * 0.002)) / (direction.y * 2.0 + 0.4);
		vec3 pos = depth * direction;
		float noise = trinoise2d(pos.zx, TIME * aurora_speed);

		vec4 col = vec4(0.0);
		col.a = noise;
		
		float weight = exp2(-depth_step * 0.065 - 2.5) * smoothstep(0.0, 5.0, depth_step);
		col.rgb = texture(aurora_color_gradient, vec2(depth_step / aurora_height, 0.0)).rgb * noise;
		average_color = mix(average_color, col, 0.5);
		
		color += average_color * weight * jitter_step_scale;
	}

	color *= clamp(direction.y * 15.0 + 0.4, 0.0, 1.0);
	color *= aurora_brightness;
	return color;
}

float plane_intersection(vec3 origin, vec3 normal, vec3 ray_start, vec3 ray_dir) {
	return dot(origin - ray_start, normal) / dot(ray_dir, normal);
}

float get_cloud_height(sampler2D tex, vec2 uv) {
	float height = texture(tex, uv).r;
	height = clamp((height - (1.0 - cloud_density)) / (cloud_density), 0.0, 1.0);
	return pow(height, cloud_shape_exponent);
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float t = plane_intersection(vec3(0.0, 1.0, 0.0), vec3(0.0, -1.0, 0.0), vec3(0.0), direction);
	
	// Pembagian waktu siang/senja/malam
	float sun_height = LIGHT0_DIRECTION.y;
	float day_weight = smoothstep(0.2, 0.6, sun_height);
	float sunset_weight = smoothstep(-0.05, 0.25, sun_height) * (1.0 - day_weight);
	float night_weight = smoothstep(0.1, -0.2, sun_height);

	// Awan
	float cloud_value = 0.0;
	if (t >= 0.0) {
		vec3 wind = vec3(wind_speed.x, 0.0, wind_speed.y) * TIME * 0.1;
		vec3 tiling = vec3(cloud_tiling.x, 1.0, cloud_tiling.y) * 0.2;
		vec3 cloud_pos1 = direction * t * tiling + wind;
		vec3 cloud_pos2 = direction * t * tiling + (wind * 0.5);

		float height1 = get_cloud_height(cloud_tex_01, cloud_pos1.xz);
		float height2 = get_cloud_height(cloud_tex_02, cloud_pos2.xz);
		cloud_pos1 += direction * height1 * cloud_depth * 0.1;
		cloud_pos2 += direction * height2 * cloud_depth * 0.1;
		height1 = get_cloud_height(cloud_tex_01, cloud_pos1.xz);
		height2 = get_cloud_height(cloud_tex_02, cloud_pos2.xz);
		cloud_value = min(height1, height1 * height2);
		cloud_value *= smoothstep(0.0, 0.2, direction.y);
	}

	// Matahari
	vec4 dynamic_sun_color = mix(sun_color_sunset, sun_color_day, day_weight);
	float sun_dist = distance(direction, LIGHT0_DIRECTION);
	float sun_mask = clamp(1.0 - sun_dist - pow(cloud_value, cloud_occlude_exponent), 0.0, 1.0);
	float sun_disc = clamp(smoothstep(1.0 - sun_scale, 1.0, sun_mask), 0.0, 1.0);
	float sun_glow = clamp(0.0, 1.0, pow(sun_mask, 4.0) * 0.08);
	vec3 sun = dynamic_sun_color.rgb * sun_strength * max(sun_disc, sun_glow) * (1.0 - night_weight);

	// Bulan
	float moon_dist = distance(direction, -LIGHT0_DIRECTION);
	float moon_mask = clamp(1.0 - moon_dist - pow(cloud_value, cloud_occlude_exponent), 0.0, 1.0);
	float moon_disc = clamp(smoothstep(1.0 - moon_scale, 1.0, moon_mask), 0.0, 1.0);
	float moon_glow = clamp(0.0, 1.0, pow(moon_mask, 3.5) * 0.06);
	vec3 moon = moon_color.rgb * moon_strength * max(moon_disc, moon_glow) * night_weight;

	// Bintang
	float star_sample = texture(night_noise_01, (direction / (1.0 - abs(t) * 0.05)).xz).r;
	float stars = smoothstep(0.92, 0.97, star_sample) * night_weight;
	stars = clamp(stars - cloud_value * 2.0, 0.0, 1.0);

	// Gradasi Langit
	vec3 active_sky = (sky_day.rgb * day_weight) + (sky_sunset.rgb * sunset_weight) + (sky_night.rgb * night_weight);
	vec3 active_horizon = (horizon_day.rgb * day_weight) + (horizon_sunset.rgb * sunset_weight) + (horizon_night.rgb * night_weight);
	vec3 sky = mix(active_sky, active_horizon, pow(1.0 - clamp(abs(direction.y), 0.0, 1.0), 2.5));
	
	// Campur Awan
	vec3 dynamic_cloud_tint = mix(cloud_color.rgb, horizon_sunset.rgb * 0.8, sunset_weight * 0.7);
	dynamic_cloud_tint = mix(dynamic_cloud_tint, sky_night.rgb * 1.5, night_weight * 0.8);
	sky = mix(sky, dynamic_cloud_tint, pow(cloud_value, 0.8));

	// Raymarched Aurora (Hanya aktif di malam hari & langit atas)
	if (direction.y > -0.1 && night_weight > 0.01) {
		vec4 raymarched_aurora = get_aurora_color(direction);
		// Ditutup jika terhalang awan tebal
		float cloud_aurora_occlude = clamp(1.0 - cloud_value * 1.5, 0.0, 1.0);
		sky += raymarched_aurora.rgb * raymarched_aurora.a * night_weight * cloud_aurora_occlude;
	}

	// Gabung bintang, matahari, dan bulan
	sky += stars;
	sky += sun * clamp(direction.y + 0.5, 0.0, 1.0);
	sky += moon * clamp(direction.y + 0.5, 0.0, 1.0);

	COLOR = sky;
}
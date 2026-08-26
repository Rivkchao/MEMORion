shader_type sky;

group_uniforms Sky_Colors;
uniform vec3 day_top_color : source_color = vec3(0.38, 0.45, 0.55);
uniform vec3 day_bottom_color : source_color = vec3(0.55, 0.65, 0.75);
uniform vec3 night_top_color : source_color = vec3(0.02, 0.01, 0.08);
uniform vec3 night_bottom_color : source_color = vec3(0.12, 0.05, 0.22);

group_uniforms Sun_and_Moon;
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float sun_size : hint_range(0.01, 0.5) = 0.04;
uniform float sun_blur : hint_range(0.01, 0.5) = 0.02;

uniform vec3 moon_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float moon_size : hint_range(0.01, 0.5) = 0.06;
uniform float moon_crescent : hint_range(-0.5, 0.5) = 0.02; // Offset bentuk bulan sabit
uniform float moon_glow : hint_range(0.0, 10.0) = 2.5;

group_uniforms Stars;
uniform float stars_density : hint_range(0.0, 500.0) = 150.0;
uniform float stars_speed : hint_range(0.0, 0.1) = 0.01;

// Hash random untuk bintang
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void sky() {
    float elevation = clamp(EYEDIR.y, 0.0, 1.0);
    
    // Deteksi posisi matahari dari arah cahaya utama (LIGHT0)
    float sun_direction = clamp(LIGHT0_DIRECTION.y, 0.0, 1.0);
    
    // Gradasi langit (berubah siang <-> malam)
    vec3 day_sky = mix(day_bottom_color, day_top_color, elevation);
    vec3 night_sky = mix(night_bottom_color, night_top_color, elevation);
    vec3 sky_gradient = mix(night_sky, day_sky, sun_direction);

    // Bintang di langit malam
    vec2 sky_uv = EYEDIR.xz / (abs(EYEDIR.y) + 0.3) * stars_density;
    sky_uv += TIME * stars_speed;
    float star_val = hash(floor(sky_uv));
    float star_mask = smoothstep(0.98, 1.0, star_val) * (1.0 - sun_direction) * (1.0 - elevation * 0.2);
    vec3 stars = vec3(star_mask) * (0.8 + 0.4 * sin(TIME * 3.0 + star_val * 10.0));

    // Matahari
    float sun_dist = distance(EYEDIR, -LIGHT0_DIRECTION);
    float sun_mask = 1.0 - smoothstep(sun_size, sun_size + sun_blur, sun_dist);
    vec3 sun = sun_color * sun_mask * 2.0;

    // Bulan (berada di arah berlawanan dari matahari)
    vec3 moon_dir = LIGHT0_DIRECTION;
    float moon_dist = distance(EYEDIR, moon_dir);
    float moon_mask = 1.0 - smoothstep(moon_size, moon_size + 0.01, moon_dist);
    
    // Potongan sabit pada bulan
    float cut_dist = distance(EYEDIR, moon_dir + vec3(moon_crescent, 0.0, 0.0));
    float cut_mask = 1.0 - smoothstep(moon_size, moon_size + 0.01, cut_dist);
    float final_moon = clamp(moon_mask - cut_mask, 0.0, 1.0);
    
    // Glow bulan
    float moon_halo = (1.0 - smoothstep(moon_size, moon_size * 4.0, moon_dist)) * (1.0 - sun_direction);
    vec3 moon = (moon_color * final_moon * 3.0) + (moon_color * moon_halo * moon_glow);

    // Gabungkan output visual langit
    COLOR = sky_gradient + stars + (sun * sun_direction) + (moon * (1.0 - sun_direction));
}
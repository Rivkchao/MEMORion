// Shader untuk Pergerakan Partikel (Acak dan Lambat)
shader_type particles;

uniform float spawn_radius = 5.0;      // Radius area munculnya partikel
uniform float move_speed = 0.2;        // Kecepatan gerakan
uniform float noise_scale = 0.5;       // Seberapa acak belokannya
uniform float smoothness = 0.98;       // Kehalusan belokan (0.0 - 1.0)

// Fungsi hash sederhana untuk random seed
float hash(uint x) {
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = (x >> 16u) ^ x;
	return float(x) / 4294967295.0;
}

void start() {
	// Posisi awal acak dalam radius
	vec3 pos;
	pos.x = (hash(NUMBER + uint(TIME * 1000.0)) - 0.5) * 2.0 * spawn_radius;
	pos.y = (hash(NUMBER + uint(TIME * 1000.0) + 1u) - 0.5) * 1.0 * spawn_radius + 1.0;
	pos.z = (hash(NUMBER + uint(TIME * 1000.0) + 2u) - 0.5) * 2.0 * spawn_radius;
	
	TRANSFORM[3].xyz = pos;
	
	// Kecepatan awal acak
	VELOCITY = vec3(
		hash(NUMBER) - 0.5,
		hash(NUMBER + 1u) - 0.5,
		hash(NUMBER + 2u) - 0.5
	) * move_speed;
}

void process() {
	vec3 pos = TRANSFORM[3].xyz;
	
	// Arah acak berbasis waktu dan ID partikel
	float t = TIME * noise_scale;
	vec3 random_dir;
	random_dir.x = sin(t + float(NUMBER) * 0.1) * cos(t * 0.7 + float(NUMBER) * 0.2);
	random_dir.y = sin(t * 0.8 + float(NUMBER) * 0.3) * 0.5; // Gerak vertikal lebih tenang
	random_dir.z = cos(t * 1.1 + float(NUMBER) * 0.4) * sin(t * 0.5 + float(NUMBER) * 0.5);
	
	// Interpolasi arah agar tidak patah
	VELOCITY = mix(VELOCITY, random_dir * move_speed, 1.0 - smoothness);
	
	// Batasi ketinggian agar tetap dekat tanah
	if (pos.y > 3.0) VELOCITY.y -= 0.02;
	if (pos.y < 0.2) VELOCITY.y += 0.02;
	
	pos += VELOCITY * DELTA;
	TRANSFORM[3].xyz = pos;
}
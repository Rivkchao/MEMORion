shader_type canvas_item;

uniform vec4 wire_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform bool is_powered = false;
uniform float current_speed : hint_range(0.0, 30.0) = 14.0;

// Fungsi pseudo-noise untuk petir organik
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

void fragment() {
    // 1. Shading 3D silinder kabel (gelap di tepi atas/bawah, terang di tengah)
    float dist_from_center = abs(UV.y - 0.5) * 2.0;
    float body_shade = cos(dist_from_center * 1.5707); // kurva silinder
    vec3 base_rgb = wire_color.rgb * (0.45 + 0.55 * body_shade);
    float base_a = wire_color.a;

    if (is_powered) {
        // 2. Kilatan petir meliuk sepanjang kabel
        vec2 noise_uv = vec2(UV.x * 12.0 - TIME * current_speed, UV.y * 2.0);
        float bolt_offset = (noise(noise_uv) - 0.5) * 0.45;
        
        float bolt_dist = abs(UV.y - 0.5 - bolt_offset);
        float bolt = 1.0 - smoothstep(0.0, 0.15, bolt_dist);
        
        // 3. Denyut energi neon
        float pulse = sin(TIME * 8.0 - UV.x * 6.0) * 0.2 + 0.8;
        vec3 neon_core = mix(wire_color.rgb * 1.8, vec3(1.0), 0.7);
        
        // Komposisi warna kabel + kilatan petir
        base_rgb = mix(base_rgb, neon_core, bolt * pulse);
        base_rgb += wire_color.rgb * 0.5 * pulse; // Aura glow luar
    }

    COLOR = vec4(base_rgb, base_a);
}
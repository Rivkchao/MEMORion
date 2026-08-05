shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.1, 0.4, 0.8, 0.7);
uniform vec4 shallow_color : source_color = vec4(0.2, 0.6, 0.9, 0.5);
uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wave_strength : hint_range(0.0, 0.1) = 0.02;
uniform float transparency : hint_range(0.0, 1.0) = 0.7;

void vertex() {
    float wave = sin(VERTEX.x * 2.0 + TIME * wave_speed) * wave_strength;
    wave += cos(VERTEX.z * 2.0 + TIME * wave_speed * 0.8) * wave_strength;
    VERTEX.y += wave;
}

void fragment() {
    ALBEDO = water_color.rgb;
    ALPHA = transparency;
    ROUGHNESS = 0.1;
    METALLIC = 0.3;
    SPECULAR = 0.8;
}
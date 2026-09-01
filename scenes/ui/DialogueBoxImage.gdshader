shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.5, 0.0, 1.0, 1.0); 
uniform float glow_intensity : hint_range(0.0, 10.0) = 2.0;
uniform float glow_radius : hint_range(0.0, 20.0) = 10.0;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    
    // Sampling transparansi di sekeliling pixel
    float alpha = 0.0;
    for (float x = -glow_radius; x <= glow_radius; x++) {
        for (float y = -glow_radius; y <= glow_radius; y++) {
            vec2 offset = vec2(x, y) * TEXTURE_PIXEL_SIZE;
            alpha += texture(TEXTURE, UV + offset).a;
        }
    }
    
    // Menghitung rerata transparansi
    float total_pixels = (2.0 * glow_radius + 1.0) * (2.0 * glow_radius + 1.0);
    alpha /= total_pixels;
    
    // Membuat glow hanya di area transparan di luar bentuk asli
    vec4 final_glow = glow_color * glow_intensity * alpha;
    final_glow.a = alpha * glow_color.a * (1.0 - col.a); // Glow tidak menimpa orang asli
    
    // Gabungkan orang asli dengan glow
    COLOR = mix(final_glow, col, col.a);
}
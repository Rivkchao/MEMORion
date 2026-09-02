shader_type spatial;

uniform sampler2D texture_albedo : source_color;
uniform vec4 rock_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 glow_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float night_glow_strength : hint_range(0.0, 5.0, 0.05) = 0.0;

void fragment() {
    vec4 tex = texture(texture_albedo, UV);
    ALBEDO = tex.rgb * rock_color.rgb;
    
    // Berpendar sesuai nilai night_glow_strength dari script siklus
    EMISSION = ALBEDO * glow_color.rgb * night_glow_strength;
}
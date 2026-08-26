shader_type spatial;

uniform vec4 path_base_color : source_color = vec4(0.2, 0.15, 0.1, 1.0);
uniform float path_glow_intensity : hint_range(0.0, 10.0) = 0.0;
uniform vec4 path_glow_color : source_color = vec4(0.2, 0.8, 1.0, 1.0);

void fragment() {
	ALBEDO = path_base_color.rgb;
	
	// Memberikan emisi cahaya sesuai intensitas malam
	EMISSION = path_glow_color.rgb * path_glow_intensity;
}
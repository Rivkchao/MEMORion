shader_type spatial;

render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float darkness : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = darkness;
}
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;

uniform vec4 color_core   : source_color = vec4(1.0, 0.92, 0.65, 1.0);
uniform vec4 color_mid    : source_color = vec4(0.9, 0.4, 0.05, 1.0);
uniform vec4 color_edge   : source_color = vec4(0.1, 0.6, 1.0, 0.9);
uniform float intensity   : hint_range(0.5, 20.0) = 3.0;

uniform float fade_power   : hint_range(0.1, 8.0) = 1.8;
uniform float uv_middle    : hint_range(-0.5, 0.5) = 0.0;
uniform float length_scale : hint_range(0.5, 16.0) = 4.0;  // stretch/compress flame

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 noise_scroll   = vec2(0.0, -1.2);
uniform vec2 noise_scale    = vec2(1.8, 0.16);
uniform float noise_strength: hint_range(0.0, 1.5) = 0.45;
uniform float noise_contrast: hint_range(0.5, 4.0) = 1.9;

uniform float fresnel_power : hint_range(0.5, 12.0) = 2.8;
uniform float fresnel_boost : hint_range(0.0, 3.0)  = 1.2;

uniform float core_boost    : hint_range(0.0, 4.0) = 1.6;
uniform float core_falloff  : hint_range(0.1, 6.0) = 3.2;

varying vec3 view_dir_model;

void vertex() {
    view_dir_model = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
}

void fragment() {
    // Base longitudinal gradient
    float along = (UV.y - uv_middle) * length_scale;
    float base_mask = pow(clamp(1.0 - along, 0.0, 1.0), fade_power);

    // Animated noise distortion
    vec2 noise_uv = (UV * noise_scale) + (noise_scroll * TIME);
    float n = texture(noise_tex, noise_uv).r;
    n = pow(n, noise_contrast);               // sharpen contrast
    n = (n - 0.5) * 2.0 * noise_strength;     // centered +- strength

    // distort the longitudinal coordinate
    float distorted_along = along + n * (1.0 + along * 0.8); // stronger noise farther out

    // recompute softened mask with noise influence
    float flame_mask = pow(clamp(1.0 - distorted_along, 0.0, 1.0), fade_power * 0.9);

    // Color gradient along length + noise
    vec3 col = color_edge.rgb;

    float t_mid  = smoothstep(0.35, 0.85, flame_mask);
    float t_core = smoothstep(0.78, 1.0, flame_mask);

    col = mix(col, color_mid.rgb,  t_mid);
    col = mix(col, color_core.rgb, t_core);

    // slight core boost near root
    float core = pow(flame_mask, core_falloff) * core_boost;
    col += (color_core.rgb - col) * core * 0.7;

    // Fresnel rim
    float VdotN = dot(normalize(NORMAL), normalize(VIEW));
    float fresnel = pow(1.0 - max(VdotN, 0.0), fresnel_power);
    fresnel *= fresnel_boost * (0.6 + 0.4 * flame_mask); // dimmer at tip

    // Final emission
    vec3 emission = col * base_mask * intensity;
    emission += col * fresnel * intensity;

    ALBEDO = emission;
    ALPHA = clamp(flame_mask * (1.0 + fresnel * 0.7), 0.0, 1.0);
}
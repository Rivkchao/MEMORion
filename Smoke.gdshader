shader_type spatial;

render_mode blend_mix, cull_disabled;


uniform float detail_strength = 1.0;
uniform float scroll_speed = -0.2; 
uniform float noise_scale = 1.5;   
uniform float shape_distortion : hint_range(0.0, 2.0) = 0.5; 
uniform float edge_softness : hint_range(0.01, 1.0) = 0.8; 
uniform float erosion_strength : hint_range(0.0, 1.0) = 0.3; 


uniform vec3 smoke_color_light : source_color = vec3(0.75, 0.75, 0.77);
uniform vec3 smoke_color_dark : source_color = vec3(0.15, 0.15, 0.17);

uniform float fake_volume_strength : hint_range(0.0, 2.0) = 1.5; 

varying float particle_age;


vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }
float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                       -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy) );
    vec2 x0 = v -   i + dot(i, C.xx);
    vec2 i1;
    i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289(i);
    vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
        + i.x + vec3(0.0, i1.x, 1.0 ));
    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m*m ;
    m = m*m ;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}
const mat2 M = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
float fbm(vec2 uv, float time, float detail, float speed) {
    vec2 uv0 = uv;
    uv = uv * vec2(5.0, 2.0) * (detail / 3.0) - vec2(-2.0, -0.25) - vec2(0.0, 3.1 * time * (speed / 1.2));
    
    float f = 1.0;
    float a = 0.5;
    float local_c = 2.5; 
    
    for(int i = 0; i < 5; ++i) {
        uv.x -= 0.15 * clamp(1.0 - pow(abs(uv0.y), 4.0), 0.0, 1.0) * snoise(local_c * (uv + float(i) * 0.612 + time * (speed / 1.2)));
        local_c *= 2.0;
        f += a * snoise(uv + float(i) * 0.415);
        a /= 2.0;
        uv *= M;
    }
    return f / 2.0;
}

void vertex() {
    particle_age = INSTANCE_CUSTOM.y;
}

void fragment() {
    float safe_time = mod(TIME, 3600.0); 
    
    
    vec2 noise_uv = (UV * noise_scale);
    float noise_val = fbm(noise_uv, safe_time, detail_strength, scroll_speed);
    
    
    vec2 center_uv = UV * 2.0 - 1.0;
    float dist = length(center_uv);
    float distorted_dist = dist + (noise_val - 0.5) * shape_distortion;
    float base_mask = 1.0 - smoothstep(1.0 - edge_softness, 1.0, distorted_dist);
    
    
    float eroded_mask = base_mask - (noise_val * erosion_strength);
    float final_alpha = clamp(eroded_mask, 0.0, 1.0);

    
    
    vec3 base_normal = normalize(vec3(center_uv.x, center_uv.y, 1.0 - dist));
    
    vec3 final_normal = normalize(base_normal + vec3(noise_val - 0.5) * fake_volume_strength);

    
    
    float distorted_age = clamp(particle_age + (noise_val - 0.5) * 0.3, 0.0, 1.0);
    vec3 current_color = mix(smoke_color_light, smoke_color_dark, smoothstep(0.1, 0.8, distorted_age));
    
    
    float lifetime_fade = smoothstep(0.0, 0.1, particle_age) * (1.0 - smoothstep(0.6, 1.0, particle_age));

    
    ALBEDO = current_color;
    NORMAL = final_normal; 
    EMISSION = vec3(0.0);  
    ALPHA = final_alpha * lifetime_fade; 
}
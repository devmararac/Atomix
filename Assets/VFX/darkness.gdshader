shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// --- MASTER CONTROLS ---
uniform float intensity : hint_range(0.0, 1.0) = 0.85;
uniform float fog_density : hint_range(0.0, 1.0) = 0.75;

// --- HORIZONTAL FADE ---
// 0.0 is the left edge, 1.0 is the right edge.
uniform float fade_start : hint_range(0.0, 1.0) = 0.0; 
// The script tweens this from 0.0 to 1.0
uniform float fade_end   : hint_range(0.0, 1.0) = 0.0;

// --- COLORS ---
uniform vec4 fog_color_dark : source_color = vec4(0.08, 0.04, 0.12, 1.0);
uniform vec4 fog_color_light : source_color = vec4(0.3, 0.25, 0.45, 1.0);

// --- MOVEMENT & SHAPE ---
uniform float fog_speed : hint_range(0.0, 0.5) = 0.08;
uniform float fog_scale : hint_range(1.0, 10.0) = 3.0;

// --- CREEP FACTOR ---
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.3;
uniform float vignette_radius   : hint_range(0.1, 1.5) = 0.55;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.04;

// --- NOISE FUNCTIONS ---
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.0;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec4 screen_col = texture(SCREEN_TEXTURE, SCREEN_UV);

    vec2 uv = UV;
    float t = TIME * fog_speed;

    // Domain warping for swirling fog.
    vec2 q = vec2(fbm(uv * fog_scale + t), fbm(uv * fog_scale - t));
    vec2 r = vec2(fbm(uv * fog_scale + 2.0 * q + vec2(1.7, 9.2) + t * 0.5),
                  fbm(uv * fog_scale + 2.0 * q + vec2(8.3, 2.8) - t * 0.5));
    float f = fbm(uv * fog_scale + 2.5 * r);

    // Thick rolling banks.
    float fog_mask = smoothstep(0.25, 0.9, f) * fog_density;

    vec3 fog_rgb = mix(fog_color_dark.rgb, fog_color_light.rgb, f);

    // Vignette.
    vec2 centered = uv - vec2(0.5);
    float dist = length(centered);
    float vig = smoothstep(vignette_radius, vignette_radius + 0.4, dist) * vignette_strength;

    // BASE FOG ALPHA
    float final_alpha = clamp(fog_mask + vig, 0.0, 1.0) * intensity;

    // --- SOFT, NOISY HORIZONTAL WIPE ---
    // 1. Create a wavy edge by distorting the horizontal coordinate with noise
    float edge_noise = fbm(uv * vec2(4.0, 8.0) + vec2(t * 0.3, 0.0)) - 0.5;
    float wobbled_x = uv.x + (edge_noise * 0.15);
    
    // 2. Define a very wide fade zone (70% of the screen width)
    float fade_center = clamp(fade_end, 0.0, 1.0);
    float fade_width = 0.7;
    
    // 3. Calculate the gradient
    float horizontal_fade = smoothstep(
        fade_center - (fade_width * 0.5),
        fade_center + (fade_width * 0.5),
        wobbled_x
    );
    
    // 4. Multiply the fog by the fade
    final_alpha *= (1.0 - horizontal_fade);

    // Blend fog into the scene.
    vec3 blended_color = mix(screen_col.rgb, fog_rgb, final_alpha);

    // Grain.
    float g = hash(uv * 500.0 + vec2(TIME * 5.0));
    blended_color += vec3(g) * grain_strength;

    COLOR = vec4(blended_color, 1.0);
}
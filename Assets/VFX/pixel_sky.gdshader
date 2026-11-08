
shader_type sky;

uniform vec3 sky_color : source_color = vec3(0.20, 0.55, 0.90);
uniform vec3 horizon_color : source_color = vec3(0.65, 0.82, 0.95);
uniform vec3 grass_horizon_color : source_color = vec3(0.25, 0.55, 0.20);
uniform float pixel_size = 0.035;

void sky() {
    vec2 uv = SKY_COORDS;

    // Quantize sky coordinates for a blocky pixel-art look.
    uv = floor(uv / pixel_size) * pixel_size;

    float horizon = smoothstep(-0.12, 0.18, uv.y);

    vec3 color = mix(horizon_color, sky_color, horizon);

    // A stylized green band along the horizon.
    float grass_band = 1.0 - smoothstep(0.0, 0.035, abs(uv.y + 0.02));
    color = mix(color, grass_horizon_color, grass_band);

    COLOR = color;
}

shader_type canvas_item;

// ================================
// FOG
// ================================

uniform vec4 fog_color : source_color = vec4(0.72, 0.78, 0.80, 1.0);

uniform float fog_strength : hint_range(0.0, 1.0) = 0.18;

uniform float fog_speed : hint_range(0.0, 1.0) = 0.08;


// ================================
// WIND
// ================================

uniform vec4 wind_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);

uniform float wind_strength : hint_range(0.0, 1.0) = 0.35;

uniform float wind_speed : hint_range(0.0, 5.0) = 0.7;

uniform float wind_density : hint_range(1.0, 30.0) = 12.0;

uniform float wind_thickness : hint_range(0.001, 0.2) = 0.035;


// ================================
// RANDOM
// ================================

float random(vec2 p)
{
    return fract(
        sin(dot(p, vec2(127.1, 311.7))) *
        43758.5453123
    );
}


// ================================
// WIND STREAK
// ================================

float wind_streak(vec2 uv)
{
    // Move wind from left → right
    float movement = TIME * wind_speed;

    vec2 p = uv;

    p.x += movement;

    // Divide screen into streaks
    float row = floor(p.y * wind_density);

    float row_random = random(vec2(row, 13.7));

    // Each row gets a slightly different movement
    p.x += row_random * 2.0;

    // Position inside the current streak
    float x = fract(p.x);

    // Random length
    float length = mix(0.08, 0.45, row_random);

    // Streak exists near the beginning of its cycle
    float streak = smoothstep(length, 0.0, x);

    // Make it thin vertically
    float row_center = fract(p.y * wind_density) - 0.5;

    float thickness = smoothstep(
        wind_thickness,
        0.0,
        abs(row_center)
    );

    // Fade some streaks out randomly
    float visibility = step(0.35, row_random);

    return streak * thickness * visibility;
}


// ================================
// MAIN
// ================================

void fragment()
{
    vec2 uv = SCREEN_UV;

    // --------------------------------
    // FOG
    // --------------------------------

    float fog_wave =
        sin(
            uv.x * 5.0 +
            TIME * fog_speed
        ) *
        0.5 +
        0.5;

    float fog_wave2 =
        sin(
            uv.y * 3.0 -
            TIME * fog_speed * 0.7
        ) *
        0.5 +
        0.5;

    float fog =
        (fog_wave * 0.6 + fog_wave2 * 0.4);

    // --------------------------------
    // WIND
    // --------------------------------

    float wind = wind_streak(uv);

    // Add another layer with different speed
    vec2 uv2 = uv;

    uv2.x -= TIME * wind_speed * 0.55;

    float wind2 = wind_streak(uv2);

    wind = max(wind, wind2 * 0.45);

    // --------------------------------
    // COMBINE
    // --------------------------------

    vec3 final_color = fog_color.rgb;

    float fog_alpha =
        fog * fog_strength;

    float wind_alpha =
        wind * wind_strength;

    // Fog
    COLOR = vec4(
        final_color,
        fog_alpha
    );

    // Wind
    COLOR.rgb =
        mix(
            COLOR.rgb,
            wind_color.rgb,
            wind_alpha
        );

    COLOR.a =
        max(
            fog_alpha,
            wind_alpha
        );
}
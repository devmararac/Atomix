shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);

uniform float brightness = 0.65;
uniform float edge_softness = 1.0;

// Ray settings
uniform float ray_length = 0.22;
uniform float ray_width = 0.08;
uniform float ray_strength = 0.30;


void fragment() {

    vec2 uv = UV;


    // =====================================================
    // SOFT SQUARE GLOW
    // =====================================================

    float edge_left   = uv.x;
    float edge_right  = 1.0 - uv.x;
    float edge_top    = uv.y;
    float edge_bottom = 1.0 - uv.y;

    float edge = min(
        min(edge_left, edge_right),
        min(edge_top, edge_bottom)
    );

    // Much softer edge transition
    float glow = smoothstep(
        0.0,
        edge_softness,
        edge
    );

    // Extra smoothing
    glow = pow(glow, 0.65);


    // =====================================================
    // DOWNWARD RAYS
    // =====================================================

    float bottom_area = smoothstep(
        0.62,
        0.92,
        uv.y
    );

    float center_distance = abs(uv.x - 0.5);


    // Main ray
    float ray1 = 1.0 - smoothstep(
        ray_width,
        ray_width + 0.06,
        center_distance
    );


    // Left ray
    float ray2 = 1.0 - smoothstep(
        ray_width * 1.8,
        ray_width * 1.8 + 0.07,
        abs(uv.x - 0.38)
    );


    // Right ray
    float ray3 = 1.0 - smoothstep(
        ray_width * 1.8,
        ray_width * 1.8 + 0.07,
        abs(uv.x - 0.62)
    );


    // Softer ray fade
    float ray_fade = 1.0 - smoothstep(
        0.72,
        1.0,
        uv.y
    );


    float rays =
        (ray1 * 0.7 +
         ray2 * 0.35 +
         ray3 * 0.35)
        * bottom_area
        * ray_fade
        * ray_strength;


    // =====================================================
    // FINAL LIGHT
    // =====================================================

    float alpha = (glow + rays) * brightness;

    COLOR = vec4(
        glow_color.rgb,
        alpha
    );
}
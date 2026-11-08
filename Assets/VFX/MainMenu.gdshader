shader_type canvas_item;

uniform vec4 leaf_color : source_color = vec4(0.6, 0.8, 0.3, 0.7); // Soft green/yellow
uniform float wind_speed = 1.0;
uniform float leaf_density = 0.6;
uniform float sway_strength = 0.05;

// Simple pseudo-random hash
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Rotate function
vec2 rotate(vec2 uv, float rotation, vec2 mid) {
    return vec2(
        cos(rotation) * (uv.x - mid.x) + sin(rotation) * (uv.y - mid.y) + mid.x,
        cos(rotation) * (uv.y - mid.y) - sin(rotation) * (uv.x - mid.x) + mid.y
    );
}

void fragment() {
    // Base UV
    vec2 uv = UV;
    
    // Create horizontal wind sway over time
    float time = TIME * wind_speed;
    uv.x += sin(uv.y * 3.0 + time * 2.0) * sway_strength;
    
    // Grid for leaves
    vec2 grid = vec2(4.0, 3.0);
    vec2 id = floor(uv * grid);
    vec2 gv = fract(uv * grid) - 0.5;
    
    // Leaf movement parameters based on cell ID
    float rnd = random(id);
    float speed = 0.1 + rnd * 0.2;
    float offset = rnd * 10.0;
    
    // Move leaves diagonally down and to the right
    vec2 leaf_pos = gv;
    leaf_pos.y += mod(TIME * speed + offset, 2.0) - 0.5;
    leaf_pos.x -= mod(TIME * speed * 0.5 + offset, 2.0) - 0.5;
    
    // Draw leaf shape (a squashed ellipse)
    float dist = length(leaf_pos * vec2(1.0, 2.5));
    float leaf = smoothstep(0.15, 0.1, dist);
    
    // Only show a fraction of the grid cells based on density
    if (rnd < (1.0 - leaf_density)) {
        leaf = 0.0;
    }

    // Subtle greenish tint overlay
    vec4 tint = vec4(0.1, 0.15, 0.05, 0.2);
    
    // Combine tint + leaves
    COLOR = mix(tint, leaf_color, leaf);
}
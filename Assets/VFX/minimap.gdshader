shader_type canvas_item;

void fragment() {
    vec2 uv = UV;

    vec2 center = vec2(0.5);
    float distance_from_center = distance(uv, center);

    if (distance_from_center > 0.5) {
        discard;
    }

    COLOR = texture(TEXTURE, uv);
}

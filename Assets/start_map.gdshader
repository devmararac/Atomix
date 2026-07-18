shader_type canvas_item;

void fragment() {
    vec2 uv = UV - vec2(0.5);
    if (length(uv) > 0.5) {
        discard;
    }
    COLOR = texture(TEXTURE, UV);
}
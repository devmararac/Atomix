shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_strength : hint_range(0.0, 5.0) = 0.0;

void fragment() {
	vec2 size = vec2(textureSize(screen_texture, 0));
	vec2 pixel = blur_strength / size;

	vec4 color = texture(screen_texture, SCREEN_UV);
	color += texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0));
	color += texture(screen_texture, SCREEN_UV - vec2(pixel.x, 0.0));
	color += texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y));
	color += texture(screen_texture, SCREEN_UV - vec2(0.0, pixel.y));

	COLOR = color / 5.0;
}
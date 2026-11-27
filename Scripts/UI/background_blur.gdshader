
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

uniform float blur_strength = 2.0;
uniform float darken_amount = 0.25;

void fragment() {
	vec2 pixel_size = SCREEN_PIXEL_SIZE * blur_strength;
	vec2 uv = SCREEN_UV;

	vec4 color = texture(screen_texture, uv) * 0.28;

	color += texture(screen_texture, uv + vec2(pixel_size.x, 0.0)) * 0.12;
	color += texture(screen_texture, uv - vec2(pixel_size.x, 0.0)) * 0.12;

	color += texture(screen_texture, uv + vec2(0.0, pixel_size.y)) * 0.12;
	color += texture(screen_texture, uv - vec2(0.0, pixel_size.y)) * 0.12;

	color += texture(screen_texture, uv + pixel_size) * 0.06;
	color += texture(screen_texture, uv - pixel_size) * 0.06;

	color += texture(screen_texture, uv + vec2(pixel_size.x, -pixel_size.y)) * 0.06;
	color += texture(screen_texture, uv + vec2(-pixel_size.x, pixel_size.y)) * 0.06;

	color.rgb *= 1.0 - darken_amount;

	COLOR = color;
}

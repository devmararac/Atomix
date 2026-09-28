shader_type canvas_item;

uniform float glow_strength = 1.0;
uniform float glow_radius = 4.0;
uniform float glow_falloff = 2.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	vec2 texel = TEXTURE_PIXEL_SIZE;

	vec3 glow_rgb = vec3(0.0);
	float glow_alpha = 0.0;

	const int SAMPLES = 16;

	for (int i = 0; i < SAMPLES; i++) {
		float angle = float(i) * 6.2831853 / float(SAMPLES);

		float distance_factor = 1.0 / float(i / 4 + 1);
		float distance_offset = max(1.0, glow_radius * distance_factor);

		vec2 offset = vec2(
			cos(angle),
			sin(angle)
		) * texel * distance_offset;

		vec4 sample_color = texture(TEXTURE, UV + offset);

		float distance_ratio = distance_offset / max(glow_radius, 0.001);
		float weight = pow(
			max(0.0, 1.0 - distance_ratio),
			glow_falloff
		);

		glow_rgb += sample_color.rgb * sample_color.a * weight;
		glow_alpha += sample_color.a * weight;
	}

	glow_rgb /= float(SAMPLES);
	glow_alpha /= float(SAMPLES);

	// Glow only appears outside the original sprite.
	glow_alpha *= 1.0 - base.a;

	// Keep the original sprite colors completely unchanged.
	COLOR.rgb = base.rgb + glow_rgb * glow_strength;
	COLOR.a = max(base.a, glow_alpha * glow_strength);
}
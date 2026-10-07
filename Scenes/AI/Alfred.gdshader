shader_type canvas_item;

uniform float star_density : hint_range(20.0, 250.0) = 110.0;
uniform float star_speed : hint_range(0.0, 2.0) = 0.35;
uniform float star_brightness : hint_range(0.0, 3.0) = 1.2;
uniform float streak_amount : hint_range(0.0, 0.5) = 0.08;
uniform float nebula_strength : hint_range(0.0, 1.0) = 0.18;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

float hash21(vec2 p)
{
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p)
{
	vec2 i = floor(p);
	vec2 f = fract(p);

	f = f * f * (3.0 - 2.0 * f);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(
		mix(a, b, f.x),
		mix(c, d, f.x),
		f.y
	);
}

void fragment()
{
	vec2 uv = UV;

	// Center coordinates.
	vec2 centered = uv - vec2(0.5);

	// Aspect correction.
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	// --------------------------------------------------------
	// DEEP SPACE
	// --------------------------------------------------------

	vec3 space = vec3(0.004, 0.006, 0.018);

	// --------------------------------------------------------
	// NEBULA
	// --------------------------------------------------------

	vec2 nebula_uv = centered * 2.2;

	float nebula_a = noise(nebula_uv + vec2(TIME * 0.015, 0.0));
	float nebula_b = noise(nebula_uv * 2.0 - vec2(TIME * 0.01, TIME * 0.008));

	float nebula = nebula_a * nebula_b;

	vec3 nebula_color = vec3(
		0.12,
		0.08,
		0.22
	);

	space += nebula_color * nebula * nebula_strength;

	// --------------------------------------------------------
	// MOVING STARS
	// --------------------------------------------------------

	vec2 star_uv = centered;

	// Slight perspective toward the center.
	float depth = 1.0 / max(abs(star_uv.x) + abs(star_uv.y), 0.15);

	star_uv *= depth;

	// Create star field layers.
	float total_stars = 0.0;

	for (int layer = 0; layer < 3; layer++)
	{
		float layer_float = float(layer);

		float scale = star_density * (0.55 + layer_float * 0.35);

		vec2 grid = star_uv * scale;

		// Move stars outward from center.
		vec2 movement = normalize(star_uv + vec2(0.001));

		grid += movement * TIME * star_speed * (0.5 + layer_float * 0.35);

		vec2 cell = floor(grid);
		vec2 local = fract(grid) - 0.5;

		float random = hash21(cell + layer_float * 17.31);

		// Only some cells contain stars.
		float star = smoothstep(0.035, 0.0, length(local));

		// Random star sizes.
		star *= smoothstep(0.25, 0.65, random);

		// Twinkle.
		float twinkle = 0.75 + 0.25 * sin(
			TIME * (2.0 + random * 5.0)
			+ random * 20.0
		);

		star *= twinkle;

		// Motion streak.
		float streak = smoothstep(
			streak_amount,
			0.0,
			abs(local.x + local.y * 0.2)
		);

		star += streak * star * 0.35;

		total_stars += star;
	}

	// --------------------------------------------------------
	// STAR COLOR
	// --------------------------------------------------------

	vec3 star_color = vec3(
		0.72,
		0.82,
		1.0
	);

	space += star_color * total_stars * star_brightness;

	// --------------------------------------------------------
	// BRIGHT CENTRAL GLOW
	// --------------------------------------------------------

	float center_glow = 1.0 - smoothstep(
		0.0,
		0.9,
		length(centered)
	);

	space += vec3(
		0.035,
		0.02,
		0.08
	) * center_glow;

	// --------------------------------------------------------
	// VIGNETTE
	// --------------------------------------------------------

	float vignette = 1.0 - smoothstep(
		0.25,
		0.85,
		length(uv - vec2(0.5))
	);

	space *= mix(
		1.0 - vignette_strength,
		1.0,
		vignette
	);

	COLOR = vec4(space, 1.0);
}
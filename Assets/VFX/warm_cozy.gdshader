shader_type canvas_item;

// ============================================================
// WARM COZY ATMOSPHERE
// ============================================================

uniform vec4 warm_color : source_color =
	vec4(1.0, 0.72, 0.38, 1.0);

uniform float warmth : hint_range(0.0, 1.0) = 0.07;


// ============================================================
// WIND
// ============================================================

uniform vec4 wind_color : source_color =
	vec4(1.0, 0.90, 0.68, 1.0);

uniform float wind_strength : hint_range(0.0, 1.0) = 0.28;

uniform float wind_speed : hint_range(0.0, 2.0) = 0.35;

uniform float wind_density : hint_range(1.0, 15.0) = 6.0;

uniform float wind_thickness : hint_range(0.01, 0.15) = 0.055;


// ============================================================
// LEAVES
// ============================================================

uniform vec4 leaf_color : source_color =
	vec4(0.35, 0.65, 0.20, 1.0);

uniform float leaf_amount : hint_range(0.0, 9.0) = 3.0;

uniform float leaf_speed : hint_range(0.0, 1.0) = 0.25;

uniform float leaf_size : hint_range(0.002, 0.02) = 0.006;


// ============================================================
// RANDOM
// ============================================================

float random(vec2 p)
{
	return fract(
		sin(
			dot(
				p,
				vec2(127.1, 311.7)
			)
		) * 43758.5453123
	);
}


// ============================================================
// WIND
// ============================================================

float wind_wisp(vec2 uv)
{
	float t = TIME * wind_speed;

	float wave =
		sin(
			uv.y * 12.0 +
			TIME * 0.7
		) * 0.025;

	vec2 p = uv;

	p.x += t * 0.18;

	p.x += wave;

	float band =
		floor(
			p.y * wind_density
		);

	float rnd =
		random(
			vec2(
				band,
				42.7
			)
		);

	p.x += rnd * 2.0;

	float x =
		fract(p.x);

	float length =
		mix(
			0.12,
			0.38,
			rnd
		);

	float streak =
		smoothstep(
			length,
			0.0,
			x
		);

	float y =
		fract(
			p.y * wind_density
		) - 0.5;

	float thickness =
		smoothstep(
			wind_thickness,
			0.0,
			abs(y)
		);

	float visibility =
		step(
			0.45,
			rnd
		);

	return (
		streak *
		thickness *
		visibility
	);
}


// ============================================================
// SHARP SMALL LEAF SHAPE
// ============================================================

float leaf_shape(vec2 p)
{
	// Leaf body
	// Using step() instead of smoothstep() makes the edges perfectly sharp
	float body =
		step(
			length(
				vec2(
					p.x * 1.5,
					p.y * 0.8
				)
			),
			0.8
		);

	// Pointed ends
	float point =
		step(
			abs(p.x),
			0.8
		);

	return body * point;
}


// ============================================================
// LEAVES
// ============================================================

float leaves(vec2 uv)
{
	float total = 0.0;

	for (int i = 0; i < 8; i++)
	{
		float id = float(i);

		float r1 = random(vec2(id, 11.13));
		float r2 = random(vec2(id, 27.41));
		float r3 = random(vec2(id, 53.82));
		float r4 = random(vec2(id, 91.17));

		vec2 start;
		vec2 direction;

		if (r1 < 0.65)
		{
			start = vec2(-0.06, r2);
			direction = normalize(vec2(1.0, (r3 - 0.5) * 0.30));
		}
		else if (r1 < 0.90)
		{
			start = vec2(r2, -0.06);
			direction = normalize(vec2(0.75, 1.0));
		}
		else
		{
			start = vec2(1.06, r2);
			direction = normalize(vec2(-0.7, (r3 - 0.5) * 0.25));
		}

		float speed = 0.025 + r4 * 0.025;
		float delay = r1 * 6.0;

		float age = TIME * leaf_speed - delay;
		float cycle = fract(age * 0.12);

		float active = smoothstep(0.02, 0.08, cycle);

		vec2 position =
			start +
			direction *
			speed *
			(cycle * 40.0);

		position.x += sin(TIME * 0.9 + id * 4.2) * 0.025;
		position.y += sin(TIME * 0.7 + id * 6.1) * 0.035;

		float angle = sin(TIME * 1.4 + id * 5.3) * 1.5;
		float s = sin(angle);
		float c = cos(angle);

		vec2 diff = uv - position;
		vec2 rotated = vec2(
			diff.x * c - diff.y * s,
			diff.x * s + diff.y * c
		);

		float leaf = leaf_shape(rotated / leaf_size);

		// Using step() here ensures the individual leaves don't have soft alpha fading
		leaf *= step(0.5, 0.65 + r4 * 0.35);

		total += leaf * active;
	}

	// Make the final output fully solid (no anti-aliasing blur)
	return step(0.5, total);
}


// ============================================================
// MAIN
// ============================================================

void fragment()
{
	vec2 uv = SCREEN_UV;

	float gradient = 1.0 - uv.y;

	float warm_alpha =
		warmth *
		(
			0.55 +
			gradient * 0.45
		);

	float wind = wind_wisp(uv);

	vec2 wind_uv = uv;
	wind_uv.x += 0.37;

	float wind2 = wind_wisp(wind_uv);

	wind = max(wind, wind2 * 0.30);

	float leaf = leaves(uv);

	COLOR = vec4(warm_color.rgb, warm_alpha);

	COLOR.rgb = mix(COLOR.rgb, wind_color.rgb, wind * wind_strength);
	COLOR.rgb = mix(COLOR.rgb, leaf_color.rgb, leaf);

	COLOR.a = max(warm_alpha, max(wind * wind_strength, leaf));
}
shader_type canvas_item;

uniform vec4 night_color : source_color = vec4(0.025, 0.055, 0.12, 1.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.72;

uniform float firefly_amount : hint_range(0.0, 1.0) = 0.65;
uniform float firefly_brightness : hint_range(0.0, 3.0) = 1.5;
uniform float firefly_size : hint_range(0.001, 0.03) = 0.008;
uniform float firefly_speed : hint_range(0.0, 2.0) = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float hash21(vec2 p) {
	return hash(p);
}

void fragment() {
	vec2 uv = UV;

	// --------------------------------------------------------
	// DARK NIGHT OVERLAY
	// --------------------------------------------------------

	vec3 base_color = night_color.rgb;

	COLOR = vec4(base_color, darkness);

	// --------------------------------------------------------
	// FIREFLIES
	// --------------------------------------------------------

	vec2 grid = vec2(18.0, 10.0);

	vec2 cell = floor(uv * grid);
	vec2 local_uv = fract(uv * grid);

	float id = hash(cell);

	// Random starting position inside each cell
	vec2 offset = vec2(
		hash(cell + 13.7),
		hash(cell + 42.3)
	);

	// Different movement for every firefly
	float speed = mix(0.35, 1.0, hash(cell + 71.4));

	float time = TIME * firefly_speed * speed;

	// Gentle floating movement
	vec2 movement;

	movement.x = sin(time * 1.3 + id * 20.0) * 0.22;
	movement.y = sin(time * 0.9 + id * 35.0) * 0.28;

	vec2 firefly_pos = offset + movement;

	// Distance from current pixel to firefly
	float dist = distance(local_uv, firefly_pos);

	// Soft glowing core
	float glow = 1.0 - smoothstep(
		firefly_size,
		firefly_size * 5.0,
		dist
	);

	// Randomly make some cells empty
	float visibility = step(0.70, id);

	// Gentle blinking
	float blink = 0.55 + 0.45 *
		sin(TIME * (1.5 + id * 2.0) + id * 30.0);

	glow *= visibility;
	glow *= blink;
	glow *= firefly_amount;

	// Warm yellow-green firefly light
	vec3 firefly_color = vec3(
		1.0,
		0.85,
		0.35
	);

	COLOR.rgb += firefly_color * glow * firefly_brightness;
}
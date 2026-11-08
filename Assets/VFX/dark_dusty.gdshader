shader_type canvas_item;

// ============================================================
// ATOMIX — DARK CAVE / PLAYER LIGHT ATMOSPHERE
// ============================================================
//
// Dark cave atmosphere with a light that follows the player.
// Dust particles float slowly and become brighter near the player.
// ============================================================

// ============================================================
// CAVE DARKNESS
// ============================================================

uniform vec4 cave_dark_color : source_color =
vec4(0.055, 0.065, 0.075, 1.0);

uniform float cave_darkness :
hint_range(0.0, 2.0) = 0.42;

// ============================================================
// PLAYER LIGHT
// ============================================================

uniform vec2 player_light_position =
vec2(0.5, 0.5);

uniform float player_light_strength :
hint_range(0.0, 2.0) = 0.85;

uniform float player_light_radius :
hint_range(0.05, 1.5) = 0.45;

// ============================================================
// DARK CAVE FOG
// ============================================================

uniform vec4 fog_color : source_color =
vec4(0.055, 0.065, 0.075, 1.0);

uniform float fog_strength :
hint_range(0.0, 1.0) = 0.32;

uniform float fog_speed :
hint_range(0.0, 0.5) = 0.035;

uniform float fog_density :
hint_range(1.0, 10.0) = 3.0;

// ============================================================
// DUST
// ============================================================

uniform vec4 dust_color : source_color =
vec4(0.82, 0.82, 0.70, 1.0);

uniform float dust_amount :
hint_range(0.0, 1.0) = 0.55;

uniform float dust_strength :
hint_range(0.0, 2.0) = 0.90;

uniform float dust_speed :
hint_range(0.0, 0.5) = 0.055;

uniform float dust_size :
hint_range(0.001, 0.015) = 0.003;

// ============================================================
// DUST LIGHT
// ============================================================

uniform float dust_light_radius :
hint_range(0.05, 1.5) = 0.65;

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
// DARK FOG
// ============================================================

float cave_fog(vec2 uv)
{
float t =
TIME * fog_speed;

float fog1 =
	sin(
		uv.x * fog_density +
		uv.y * 2.0 +
		t
	);

fog1 =
	fog1 * 0.5 +
	0.5;


float fog2 =
	sin(
		uv.x * 5.0 -
		uv.y * 2.5 -
		t * 0.7
	);

fog2 =
	fog2 * 0.5 +
	0.5;


float fog3 =
	sin(
		uv.y * 4.0 +
		t * 0.35
	);

fog3 =
	fog3 * 0.5 +
	0.5;


float fog =
	fog1 * 0.45 +
	fog2 * 0.35 +
	fog3 * 0.20;


return smoothstep(
	0.30,
	0.82,
	fog
);

}

// ============================================================
// DUST PARTICLES
// ============================================================

float cave_dust(vec2 uv)
{
float total = 0.0;

for (int i = 0; i < 26; i++)
{
	float id =
		float(i);


	// ----------------------------------------------------
	// RANDOM VALUES
	// ----------------------------------------------------

	float rx =
		random(
			vec2(id, 11.37)
		);

	float ry =
		random(
			vec2(id, 29.84)
		);

	float rs =
		random(
			vec2(id, 47.21)
		);

	float rd =
		random(
			vec2(id, 63.17)
		);

	float rb =
		random(
			vec2(id, 81.44)
		);


	// ----------------------------------------------------
	// MOVEMENT
	// ----------------------------------------------------

	float t =
		TIME * dust_speed;


	float x =
		rx;

	float y =
		ry;


	x +=
		sin(
			TIME * (0.20 + rs * 0.25) +
			id * 4.17
		) * 0.055;


	y +=
		sin(
			TIME * (0.16 + rd * 0.22) +
			id * 5.31
		) * 0.045;


	y +=
		t *
		(
			0.015 +
			rs * 0.025
		);


	x =
		fract(x);

	y =
		fract(y);


	vec2 position =
		vec2(x, y);


	// ----------------------------------------------------
	// DISTANCE TO PARTICLE
	// ----------------------------------------------------

	float dist =
		length(
			uv - position
		);


	// ----------------------------------------------------
	// PARTICLE
	// ----------------------------------------------------

	float particle =
		1.0 -
		smoothstep(
			dust_size * 0.15,
			dust_size,
			dist
		);


	// ----------------------------------------------------
	// RANDOM BRIGHTNESS
	// ----------------------------------------------------

	particle *=
		0.45 +
		rb * 0.55;


	// ----------------------------------------------------
	// PLAYER LIGHT
	// ----------------------------------------------------

	float player_dist =
		distance(
			position,
			player_light_position
		);


	float player_light_amount =
		1.0 -
		smoothstep(
			0.0,
			dust_light_radius,
			player_dist
		);


	float illuminated_dust =
		0.35 +
		player_light_amount *
		0.65;


	particle *=
		illuminated_dust;


	total +=
		particle;
}


return clamp(
	total,
	0.0,
	1.0
);

}

// ============================================================
// PLAYER LIGHT
// ============================================================

float player_light(vec2 uv)
{
float dist =
distance(
uv,
player_light_position
);


float light =
	1.0 -
	smoothstep(
		0.0,
		player_light_radius,
		dist
	);


return light *
	player_light_strength;

}

// ============================================================
// MAIN
// ============================================================

void fragment()
{
vec2 uv =
SCREEN_UV;

// ========================================================
// PLAYER LIGHT
// ========================================================

float light =
	player_light(
		uv
	);


// ========================================================
// CAVE DARKNESS
// ========================================================

float darkness =
	cave_darkness *
	(1.0 - light);


// ========================================================
// FOG
// ========================================================

float fog =
	cave_fog(
		uv
	);


float fog_amount =
	fog *
	fog_strength *
	(
		1.0 -
		light * 0.65
	);


// ========================================================
// DUST
// ========================================================

float dust =
	cave_dust(
		uv
	);


float dust_alpha =
	dust *
	dust_amount *
	dust_strength;


// ========================================================
// BASE
// ========================================================

vec3 final_color =
	cave_dark_color.rgb;


float final_alpha =
	darkness;


// ========================================================
// FOG
// ========================================================

final_color =
	mix(
		final_color,
		fog_color.rgb,
		fog_amount
	);


final_alpha =
	max(
		final_alpha,
		fog_amount
	);


// ========================================================
// DUST
// ========================================================

final_color =
	mix(
		final_color,
		dust_color.rgb,
		dust_alpha
	);


final_alpha =
	max(
		final_alpha,
		dust_alpha
	);


// ========================================================
// PLAYER LIGHT HAZE
// ========================================================

final_color +=
	vec3(
		0.10,
		0.09,
		0.07
	)
	*
	light
	*
	0.35;


// ========================================================
// FINAL
// ========================================================

COLOR =
	vec4(
		final_color,
		clamp(
			final_alpha,
			0.0,
			0.70
		)
	);

}

extends Control

@onready var overlay: ColorRect = $ScreenOverlayTransitions
@onready var main_scene_bg: Panel = $MainSceneBG
@onready var first_scenery: TextureRect = $MainSceneBG/FirstScenery
@onready var second_scenery: TextureRect = $MainSceneBG/SecondScenery
@onready var narrator1: Label = $MainSceneBG/Narrator
@onready var phantom_text: Label = $MainSceneBG/PhantomText
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var narrator_voice: AudioStreamPlayer2D = $NarratorVoice

@onready var jonas: TextureRect  = $MainSceneBG/Jonas
@onready var dianne: TextureRect = $MainSceneBG/Dianne
@onready var fred: TextureRect   = $MainSceneBG/Fred
@onready var phantom: TextureRect = $MainSceneBG/Phantom

# --- FOG REFERENCES ---
@onready var fog_rect: ColorRect = $MainSceneBG/ColorRect
@onready var fog_material: ShaderMaterial = fog_rect.material

const FADE_DURATION := 0.8
const NARRATOR_FADE_DURATION := 0.8
const SCENERY_FADE_DURATION := 1.5
const PHANTOM_FADE_DURATION := 2.5
const PHANTOM_FLOAT_AMPLITUDE := 12.0
const PHANTOM_FLOAT_SPEED := 2.4
const PHANTOM_SWAY_AMPLITUDE := 4.0
const PHANTOM_SWAY_SPEED := 3.1
const REFERENCE_RESOLUTION = Vector2(1980.0, 720.0)
var responsive_scale = 1.0

const NARRATOR_LINES: Array[Dictionary] = [
	{
		"text": "There was once a peaceful land where everyone lived as happily as could be...",
		"voice": "res://Assets/Music/VoiceOvers/Narrator/Narrator 1.mp3",
	},
	{
		"text": "Even so, the mortals never gave up hope.",
		"voice": "res://Assets/Music/VoiceOvers/Narrator/Narrator 7.mp3",
	},
	{
		"text": "They longed to restore their world to the way it once was,",
		"voice": "res://Assets/Music/VoiceOvers/Narrator/Narrator 8.mp3",
	},
	{
		"text": "patiently waiting for someone...",
		"voice": "res://Assets/Music/VoiceOvers/Narrator/Narrator 9.mp3",
	},
	{
		"text": "someone capable of bringing peace back to their land..",
		"voice": "res://Assets/Music/VoiceOvers/Narrator/Narrator 10.mp3",
	},
]

func _ready() -> void:
	var viewport_size = get_viewport_rect().size
	responsive_scale = min(viewport_size.x / REFERENCE_RESOLUTION.x, viewport_size.y / REFERENCE_RESOLUTION.y)

	overlay.color = Color(0, 0, 0, 1)
	overlay.visible = true
	main_scene_bg.visible = true

	first_scenery.visible = false
	first_scenery.modulate = Color(1, 1, 1, 0)

	second_scenery.visible = false
	second_scenery.modulate = Color(1, 1, 1, 0)

	for c in [jonas, dianne, fred]:
		c.visible = false
		c.modulate = Color(1, 1, 1, 0)

	phantom.visible = false
	phantom.modulate = Color(1, 1, 1, 0)
	
	phantom_text.add_theme_font_size_override("font_size", int(55 * responsive_scale))
	phantom_text.visible = false
	phantom_text.modulate = Color(1, 1, 1, 0)
	
	fog_rect.visible = true
	fog_rect.modulate.a = 1.0 
	fog_material.set_shader_parameter("fade_end", 0.0)

	narrator1.visible = false
	narrator1.modulate = Color(1, 1, 1, 0)

	await _fade_overlay_in()

	# ONLY play the first narrator line here (Narrator 1)
	await _play_narrator_line(NARRATOR_LINES[0])

	await _reveal_scenery()

	# --- Pause, then second dialogue with one VO and four captions ---
	await get_tree().create_timer(2.0).timeout

	_move_narrator_to(Vector2(633.0, 123.0), 1100.0, 180.0)

	await _play_narrator_segmented(
		[
			"Everyone lived together in harmony.",
			"They helped one another, shared what they had, and treated each other with kindness.",
			"No one was left behind,",
			"and everyone had a place in this wonderful land.",
		],
		"res://Assets/Music/VoiceOvers/Narrator/Narrator 2.mp3",
		[1.0, 4.5, 0.5, 2.5]
	)

	# --- Beat, fade to black, hide FirstScenery, show SecondScenery ---
	await get_tree().create_timer(1.0).timeout

	await _fade_overlay_out()

	first_scenery.visible = false
	second_scenery.visible = true
	second_scenery.modulate = Color(1, 1, 1, 0)

	_place_character(jonas,  Vector2(1335.0,       403.0),         Vector2(86.0, 87.0))
	_place_character(dianne, Vector2(1335.0 + 90.0, 403.0 + 10.0), Vector2(86.0, 87.0))
	_place_character(fred,   Vector2(1335.0 - 85.0, 403.0 + 15.0), Vector2(86.0, 87.0))

	for c in [jonas, dianne, fred]:
		c.visible = false
		c.modulate = Color(1, 1, 1, 0)

	await get_tree().process_frame

	for c in [jonas, dianne, fred]:
		c.pivot_offset = c.size / 2.0

	await _fade_overlay_in()

	# Fade SecondScenery in first.
	var scenery_tween := create_tween()
	scenery_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	scenery_tween.tween_property(second_scenery, "modulate:a", 1.0, SCENERY_FADE_DURATION)
	await scenery_tween.finished

	# Then reveal the characters on top of the finished scenery.
	for c in [jonas, dianne, fred]:
		c.visible = true

	var char_tween := create_tween()
	char_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	char_tween.tween_property(jonas,  "modulate:a", 1.0, SCENERY_FADE_DURATION)
	char_tween.parallel().tween_property(dianne, "modulate:a", 1.0, SCENERY_FADE_DURATION)
	char_tween.parallel().tween_property(fred,   "modulate:a", 1.0, SCENERY_FADE_DURATION)
	await char_tween.finished

	# --- Beat, then start Narrator 3; Phantom & Fog fade in during it ---
	await get_tree().create_timer(0.5).timeout

	_move_narrator_to(Vector2(114.0, 489.0), 1100.0, 180.0)

	# Phantom and Fog appear together
	_reveal_phantom()

	await _play_narrator_segmented(
		[
			"Alas, peace was never meant to last.",
			"One fateful day, a terrible disaster struck the once-happy land",
			"changing everything forever...",
		],
		"res://Assets/Music/VoiceOvers/Narrator/Narrator 3.mp3",
		[3.48, 5.59, 2.50]
	)
	
	# --- Phantom Speaks ---
	await get_tree().create_timer(1.5).timeout
	
	await _play_phantom_dialogue()


func _play_phantom_dialogue() -> void:
	var lines = [
		{
			"text": "Foolish mortals! Your peaceful days are over!",
			"voice": "res://Assets/Music/VoiceOvers/Phantom/Phantom 1.mp3"
		},
		{
			"text": "I shall shroud this world in darkness and turn every living thing into monsters!",
			"voice": "res://Assets/Music/VoiceOvers/Phantom/Phantom 2.mp3"
		},
		{
			"text": "But my power is not yet complete... So, I shall begin with something small.",
			"voice": "res://Assets/Music/VoiceOvers/Phantom/Phantom 3.mp3"
		},
		{
			"text": "The Elements themselves! Soon, even the building blocks of your world shall become my servants!",
			"voice": "res://Assets/Music/VoiceOvers/Phantom/Phantom 4.mp3"
		}
	]

	for i in lines.size():
		var line = lines[i]
		phantom_text.text = line["text"]
		phantom_text.visible = true
		
		# Sinister flicker effect
		var flicker := create_tween()
		flicker.set_trans(Tween.TRANS_LINEAR)
		flicker.tween_property(phantom_text, "modulate:a", 1.0, 0.05)
		flicker.tween_property(phantom_text, "modulate:a", 0.2, 0.05)
		flicker.tween_property(phantom_text, "modulate:a", 1.0, 0.05)
		flicker.tween_property(phantom_text, "modulate:a", 0.4, 0.1)
		flicker.tween_property(phantom_text, "modulate:a", 1.0, 0.15)
		await flicker.finished

		# Play the voiceover and wait for it to finish
		var stream := load(line["voice"]) as AudioStream
		if stream:
			narrator_voice.stream = stream
			narrator_voice.play()
			await narrator_voice.finished
		else:
			push_warning("Could not load VO: " + line["voice"])
			await get_tree().create_timer(3.0).timeout

		# Fade out into the fog
		var fade_out := create_tween()
		fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		fade_out.tween_property(phantom_text, "modulate:a", 0.0, NARRATOR_FADE_DURATION * 1.5)
		await fade_out.finished

		# --- FINAL TRANSITION AFTER PHANTOM 4 ---
		if i == 3:
			phantom_text.visible = false
			
			# 1. Fade to black, hide everything
			await _fade_overlay_out()
			
			phantom.visible = false
			fog_rect.visible = false
			second_scenery.visible = false
			jonas.visible = false
			dianne.visible = false
			fred.visible = false
			
			var third_scenery = $MainSceneBG/ThirdScenery
			var fourth_scenery = $MainSceneBG/FourthScenery
			third_scenery.visible = false
			fourth_scenery.visible = false
			
			# 2. Fade in (just black screen) and play Narrator 4
			await _fade_overlay_in()
			_reset_narrator_position()
			
			await _play_narrator_line({
				"text": "Just as the Phantom had promised, the Elements began transforming into monsters.",
				"voice": "res://Assets/Music/VoiceOvers/Narrator/Narrator 4.mp3",
			})
			
			# 3. Fade to black after Narrator 4
			await get_tree().create_timer(1.0).timeout
			await _fade_overlay_out()
			
			# 4. Setup ThirdScenery while black
			narrator1.visible = false
			third_scenery.visible = true
			fog_rect.visible = true
			fog_material.set_shader_parameter("fade_end", 0.0)
			
			# 5. Fade in ThirdScenery, play Narrator 5 with corrupt elements
			await _fade_overlay_in()
			
			_reset_narrator_position()
			narrator1.text = "Most became dangerous creatures, spreading fear and destruction wherever they went."
			narrator1.visible = true
			
			var text_fade5 := create_tween()
			text_fade5.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			text_fade5.tween_property(narrator1, "modulate:a", 1.0, NARRATOR_FADE_DURATION)
			
			var stream5 := load("res://Assets/Music/VoiceOvers/Narrator/Narrator 5.mp3") as AudioStream
			if stream5:
				narrator_voice.stream = stream5
				narrator_voice.play()
			
			var wipe_tween := create_tween()
			wipe_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			wipe_tween.tween_method(
				func(v: float): fog_material.set_shader_parameter("fade_end", v),
				0.0, 1.0, 4.0
			)
			
			var corrupt_elements = [
				$MainSceneBG/Element2, $MainSceneBG/Element6, $MainSceneBG/Element8,
				$MainSceneBG/Element9, $MainSceneBG/Element10
			]
			
			for el in corrupt_elements:
				el.visible = true
				_start_idle_wobble(el, 0.04, 0.5)
				await get_tree().create_timer(0.8).timeout
			
			if narrator_voice.playing:
				await narrator_voice.finished
				
			var text_fade_out5 := create_tween()
			text_fade_out5.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			text_fade_out5.tween_property(narrator1, "modulate:a", 0.0, NARRATOR_FADE_DURATION)
			await text_fade_out5.finished
			narrator1.visible = false
			
			# 6. Fade to black after Narrator 5
			await get_tree().create_timer(1.0).timeout
			await _fade_overlay_out()
			
			# 7. Setup FourthScenery while black (PEACEFUL)
			third_scenery.visible = false
			fourth_scenery.visible = true
			fog_rect.visible = false # <--- NO FOG HERE!
			
			# Hide the corrupt elements
			for el in corrupt_elements:
				el.visible = false
			
			# 8. Fade in FourthScenery, play Narrator 6 with remaining elements
			await _fade_overlay_in()
			
			_reset_narrator_position()
			narrator1.text = "But not all was lost... To everyone's surprise, some Elements remained peaceful and even learned to coexist with mortals."
			narrator1.visible = true
			
			var text_fade6 := create_tween()
			text_fade6.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			text_fade6.tween_property(narrator1, "modulate:a", 1.0, NARRATOR_FADE_DURATION)
			
			var stream6 := load("res://Assets/Music/VoiceOvers/Narrator/Narrator 6.mp3") as AudioStream
			if stream6:
				narrator_voice.stream = stream6
				narrator_voice.play()
			
			var peaceful_elements = [
				$MainSceneBG/Element, $MainSceneBG/Element3, $MainSceneBG/Element4,
				$MainSceneBG/Element5, $MainSceneBG/Element7
			]
			
			for el in peaceful_elements:
				el.visible = true
				_start_idle_wobble(el, 0.035, 0.6) # Calmer wobble
				await get_tree().create_timer(0.6).timeout
			
			if narrator_voice.playing:
				await narrator_voice.finished
				
			var text_fade_out6 := create_tween()
			text_fade_out6.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			text_fade_out6.tween_property(narrator1, "modulate:a", 0.0, NARRATOR_FADE_DURATION)
			await text_fade_out6.finished
			narrator1.visible = false
			
			# 9. Fade to black after Narrator 6
			await get_tree().create_timer(1.0).timeout
			await _fade_overlay_out()
			
			# 10. Hide the peaceful elements and FourthScenery entirely
			fourth_scenery.visible = false
			for el in peaceful_elements:
				el.visible = false
			
			# 11. Play Narrator 7, 8, 9, 10 on a pure black screen
			await _fade_overlay_in()
			_reset_narrator_position()
			
			# Slice the main array to get lines 1 through 4 (Narrator 7 to 10)
			for n_line in NARRATOR_LINES.slice(1, 5):
				await _play_narrator_line(n_line)
			
			# 12. Final pause, fade music, and change scene
			await get_tree().create_timer(2.0).timeout
			
			# Fade out the music smoothly
			var music_player = $AudioStreamPlayer2D
			if music_player:
				var music_tween := create_tween()
				music_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				music_tween.tween_property(music_player, "volume_db", -80.0, FADE_DURATION * 2.0) # Fades over 1.6 seconds
			
			await _fade_overlay_out()

			get_tree().change_scene_to_file(
				"res://Scenes/Cutscenes/classroom_cutscene.tscn"
			)

			return


func _reset_narrator_position() -> void:
	# Restores the center position from the .tscn
	narrator1.anchor_left   = 0.058000002
	narrator1.anchor_top    = 0.46500003
	narrator1.anchor_right  = 0.94200003
	narrator1.anchor_bottom = 0.535
	narrator1.offset_left   = 0.15999603 * responsive_scale
	narrator1.offset_top    = -0.3000183 * responsive_scale
	narrator1.offset_right  = 0.8399658 * responsive_scale
	narrator1.offset_bottom = 0.2999878 * responsive_scale
	
	narrator1.add_theme_font_size_override("font_size", int(50 * responsive_scale))
	narrator1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narrator1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _reveal_phantom() -> void:
	phantom.visible = true
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(phantom, "modulate:a", 1.0, PHANTOM_FADE_DURATION)
	
	fade.parallel().tween_method(
		func(v: float): fog_material.set_shader_parameter("fade_end", v),
		0.0, 1.0, PHANTOM_FADE_DURATION * 1.5
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await fade.finished

	var base_x := phantom.position.x
	var base_y := phantom.position.y
	var float_tween := phantom.create_tween().set_loops()

	float_tween.tween_property(phantom, "position:y", base_y - PHANTOM_FLOAT_AMPLITUDE, PHANTOM_FLOAT_SPEED)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.parallel().tween_property(phantom, "position:x", base_x - PHANTOM_SWAY_AMPLITUDE, PHANTOM_SWAY_SPEED)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	float_tween.tween_property(phantom, "position:y", base_y + PHANTOM_FLOAT_AMPLITUDE * 0.4, PHANTOM_FLOAT_SPEED)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.parallel().tween_property(phantom, "position:x", base_x + PHANTOM_SWAY_AMPLITUDE, PHANTOM_SWAY_SPEED)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	float_tween.tween_property(phantom, "position:y", base_y, PHANTOM_FLOAT_SPEED)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.parallel().tween_property(phantom, "position:x", base_x, PHANTOM_SWAY_SPEED)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _fade_overlay_in() -> void:
	overlay.visible = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(overlay, "color:a", 0.0, FADE_DURATION)
	await tween.finished
	overlay.visible = false

func _fade_overlay_out() -> void:
	overlay.visible = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(overlay, "color:a", 1.0, FADE_DURATION)
	await tween.finished

func _play_narrator_line(line: Dictionary) -> void:
	narrator1.text = line.get("text", "")

	narrator1.visible = true
	var fade_in := create_tween()
	fade_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_in.tween_property(narrator1, "modulate:a", 1.0, NARRATOR_FADE_DURATION)
	await fade_in.finished

	var voice_path: String = line.get("voice", "")
	if voice_path != "":
		var stream := load(voice_path) as AudioStream
		if stream:
			narrator_voice.stream = stream
			narrator_voice.play()
			await narrator_voice.finished
		else:
			push_warning("Could not load VO: " + voice_path)
			await get_tree().create_timer(3.0).timeout
	else:
		await get_tree().create_timer(3.0).timeout

	var fade_out := create_tween()
	fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(narrator1, "modulate:a", 0.0, NARRATOR_FADE_DURATION)
	await fade_out.finished
	narrator1.visible = false

func _play_narrator_segmented(segments: Array, voice_path: String, durations: Array) -> void:
	var stream := load(voice_path) as AudioStream
	if stream:
		narrator_voice.stream = stream
		narrator_voice.play()
	else:
		push_warning("Could not load VO: " + voice_path)

	for i in segments.size():
		narrator1.text = segments[i]
		narrator1.visible = true
		var fade_in := create_tween()
		fade_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade_in.tween_property(narrator1, "modulate:a", 1.0, NARRATOR_FADE_DURATION)
		await fade_in.finished

		var duration: float = (durations[i] if i < durations.size() else 2.0)
		await get_tree().create_timer(duration).timeout

		var fade_out := create_tween()
		fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade_out.tween_property(narrator1, "modulate:a", 0.0, NARRATOR_FADE_DURATION)
		await fade_out.finished

	narrator1.visible = false

func _reveal_scenery() -> void:
	first_scenery.visible = true
	for c in [jonas, dianne, fred]:
		c.visible = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(first_scenery, "modulate:a", 1.0, SCENERY_FADE_DURATION)
	tween.parallel().tween_property(jonas,  "modulate:a", 1.0, SCENERY_FADE_DURATION)
	tween.parallel().tween_property(dianne, "modulate:a", 1.0, SCENERY_FADE_DURATION)
	tween.parallel().tween_property(fred,   "modulate:a", 1.0, SCENERY_FADE_DURATION)
	await tween.finished

	_start_idle_wobble(jonas,  0.035, 0.6)
	_start_idle_wobble(dianne, 0.045, 0.9)
	_start_idle_wobble(fred,   0.030, 0.4)

func _start_idle_wobble(ctrl: Control, amplitude: float = 0.035, speed: float = 1.6) -> void:
	ctrl.pivot_offset = ctrl.size / 2.0
	var base_rotation := ctrl.rotation

	var tween := ctrl.create_tween().set_loops()
	tween.tween_callback(func(): ctrl.rotation = base_rotation - amplitude)
	tween.tween_interval(speed)
	tween.tween_callback(func(): ctrl.rotation = base_rotation + amplitude)
	tween.tween_interval(speed)

func _move_narrator_to(px: Vector2, width: float = 1100.0, height: float = 300.0) -> void:
	narrator1.anchor_left   = 0.0
	narrator1.anchor_top    = 0.0
	narrator1.anchor_right  = 0.0
	narrator1.anchor_bottom = 0.0
	
	narrator1.offset_left   = px.x * responsive_scale
	narrator1.offset_top    = px.y * responsive_scale
	narrator1.offset_right  = (px.x + width) * responsive_scale
	narrator1.offset_bottom = (px.y + height) * responsive_scale

	narrator1.add_theme_font_size_override("font_size", int(50 * responsive_scale))
	narrator1.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _place_character(ctrl: Control, px: Vector2, size_px: Vector2) -> void:
	ctrl.anchor_left   = 0.0
	ctrl.anchor_top    = 0.0
	ctrl.anchor_right  = 0.0
	ctrl.anchor_bottom = 0.0
	
	ctrl.offset_left   = px.x * responsive_scale
	ctrl.offset_top    = px.y * responsive_scale
	ctrl.offset_right  = (px.x + size_px.x) * responsive_scale
	ctrl.offset_bottom = (px.y + size_px.y) * responsive_scale
	ctrl.size = size_px * responsive_scale


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Cutscenes/classroom_cutscene.tscn") # Replace with function body.

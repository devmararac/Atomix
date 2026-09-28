extends Node2D
signal cutscene_finished

@onready var camera: Camera2D = $Camera2D
@onready var npc = $NpcBase
@onready var subtitles: Label = $CanvasLayer/Subtitle
@onready var target1 = $Target1
@onready var weird = $Effects/GlowingSprite
@onready var dot1 = $Effects/GlowingDots
@onready var dot2 = $Effects/GlowingDots2
@onready var dot3 = $Effects/GlowingDots3
@onready var dot4 = $Effects/GlowingDots4

@onready var camera_target_uno = $"Camera Targets/Target Uno"
@onready var camera_target_dos = $"Camera Targets/Target Dos"
@onready var camera_target_tres = $"Camera Targets/Target Tres"

@onready var House1 = $WindowGlows/House1Window
@onready var House2 = $WindowGlows/House2
@onready var House3 = $WindowGlows/House3
@onready var House4 = $WindowGlows/House4
@onready var House5 = $WindowGlows/House5

const NPC_START_POSITION := Vector2(1041, 267)

var camera_base_position: Vector2
var camera_shaking: bool = false
var camera_shake_strength: float = 4.0
var camera_follow_npc: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# =========================================================
	# INITIAL STATE
	# =========================================================
	
	# House Windows
	House1.visible = false
	House2.visible = false
	House3.visible = false
	House4.visible = false
	House5.visible = false
	
	# Glowing dots
	dot1.visible = false
	dot2.visible = false
	dot3.visible = false
	dot4.visible = false
	
	npc.visible = false
	npc.position = NPC_START_POSITION
	npc.velocity = Vector2.ZERO

	subtitles.text = ""
	subtitles.modulate.a = 0.0

	# Camera starts on NPC
	camera.position = npc.position

	# Start cinematic immediately
	await play_cutscene()

func _process(_delta: float) -> void:
	if camera_follow_npc:
		camera.global_position = npc.global_position

func play_cutscene() -> void:
	# ESTABLISH NIGHT SCENE
	await get_tree().create_timer(1.5).timeout
	SfxManager.night()

	# ANDREW APPEARS
	await get_tree().create_timer(1.5).timeout
	House5.visible = true
	await get_tree().create_timer(1.0).timeout
	
	npc.visible = true
	await get_tree().create_timer(2.0).timeout

	# FACE LEFT
	npc.sprite.flip_h = true

	# SLEEPY EMOTE
	npc.play_emote("sleepy", 1.0)

	# FIRST SUBTITLE
	await show_subtitle(
		"It was a peaceful night....",
		2.0
	)

	# ANDREW WALKS TO TARGET 1
	await move_npc_to(target1.global_position)

	# SECOND SUBTITLE
	await show_subtitle(
		"At least for a while....",
		2.0
	)

	# Sees something
	npc.play_emote("curious", 1.0)
	await get_tree().create_timer(0.5).timeout

	# Glowing Thing on Cave entrance
	var camera_tween = create_tween()

	camera_tween.tween_property(
		camera,
		"global_position",
		weird.global_position,
		5.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await camera_tween.finished

	# Third SUBTITLE
	await show_subtitle(
		"I saw this weird thing glowing infront of the cave entrance...",
		2.0
	)

	# CAMERA RETURNS TO ANDREW
	await pan_camera_to_npc(2.0)

	# Worried Emote
	npc.play_emote("worried", 1.0)
	await get_tree().create_timer(0.5).timeout
	await show_subtitle(
		"I got worried, I've never seen anything like it before..."
	)

	# =========================================================
	# EXPLOSION BUILDUP
	# =========================================================

	await get_tree().create_timer(0.4).timeout

	# Andrew reacts immediately
	npc.play_emote("shocked", 1.0)

	# =========================================================
	# PAN TO CAVE WHILE SHAKING
	# =========================================================

	await pan_camera_while_shaking(
		weird.global_position,
		2.5
	)

	# Camera has now reached the cave.
	# Start the glowing dots sequence.
	await play_glowing_dots()

	# BRIEF PAUSE
	await get_tree().create_timer(0.4).timeout
	await play_house_sequence()
	emit_signal("cutscene_finished")

	await get_tree().create_timer(0.5).timeout

	get_tree().paused = false

func pan_camera_to_npc(duration: float = 1.0) -> void:

	var tween := create_tween()

	tween.tween_property(
		camera,
		"position",
		npc.position,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

func pan_camera_while_shaking(target_position: Vector2, duration: float) -> void:

	var start_position = camera.global_position
	var elapsed = 0.0

	camera_shaking = true

	while elapsed < duration:

		var delta = get_process_delta_time()
		elapsed += delta

		var progress = clamp(elapsed / duration, 0.0, 1.0)

		# Smooth camera movement
		var base_position = start_position.lerp(
			target_position,
			progress
		)

		# Shake offset
		var shake_offset = Vector2(
			randf_range(
				-camera_shake_strength,
				camera_shake_strength
			),
			randf_range(
				-camera_shake_strength,
				camera_shake_strength
			)
		)

		camera.global_position = base_position + shake_offset

		await get_tree().process_frame

	camera_shaking = false
	camera.global_position = target_position
	
	await get_tree().create_timer(2.0).timeout

func move_npc_to(target_position: Vector2) -> void:
	var direction = target_position - npc.global_position

	# Face the direction of movement
	if direction.x != 0:
		npc.sprite.flip_h = direction.x < 0

	# Play walking animation
	if npc.sprite.sprite_frames != null and npc.sprite.sprite_frames.has_animation("walk"):
		npc.sprite.play("walk")

	# Calculate movement duration
	var distance = npc.global_position.distance_to(target_position)
	var speed: float = npc.data.move_speed
	var duration = distance / speed if speed > 0.0 else 1.0

	# Move NPC and camera together
	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		npc,
		"global_position",
		target_position,
		duration
	).set_trans(Tween.TRANS_LINEAR)

	tween.tween_property(
		camera,
		"global_position",
		target_position,
		duration
	).set_trans(Tween.TRANS_LINEAR)

	await tween.finished

	npc.velocity = Vector2.ZERO

	if npc.sprite.sprite_frames != null and npc.sprite.sprite_frames.has_animation("idle"):
		npc.sprite.play("idle")


func show_subtitle(text: String, duration: float = 2.5) -> void:

	subtitles.text = text

	var tween := create_tween()

	# Fade in
	tween.tween_property(
		subtitles,
		"modulate:a",
		1.0,
		0.35
	)

	# Stay visible
	tween.tween_interval(duration)

	# Fade out
	tween.tween_property(
		subtitles,
		"modulate:a",
		0.0,
		0.35
	)

	await tween.finished

func play_glowing_dots() -> void:

	# =========================================================
	# DOT 1
	# =========================================================

	dot1.visible = true
	dot1.play("default")

	await dot1.animation_finished

	dot1.visible = false


	# =========================================================
	# DOT 2
	# =========================================================

	dot2.visible = true
	dot2.play("default")

	await dot2.animation_finished

	dot2.visible = false


	# =========================================================
	# DOT 3
	# =========================================================

	dot3.visible = true
	dot3.play("default")

	await dot3.animation_finished

	dot3.visible = false


	# =========================================================
	# DOT 4
	# =========================================================

	dot4.visible = true
	dot4.play("default")

	await dot4.animation_finished

	dot4.visible = false

func play_house_sequence() -> void:
	# =========================================================
	# HOUSE 1
	# =========================================================
	camera.global_position = camera_target_uno.global_position
	await get_tree().create_timer(1.0).timeout
	House1.visible = true

	await get_tree().create_timer(1.0).timeout

	# =========================================================
	# HOUSE 2
	# =========================================================
	camera.global_position = camera_target_dos.global_position
	await get_tree().create_timer(1.0).timeout
	House2.visible = true
	
	await get_tree().create_timer(1.0).timeout

	# =========================================================
	# HOUSE 3 & 4
	# =========================================================
	camera.global_position = camera_target_tres.global_position
	await get_tree().create_timer(1.0).timeout
	House3.visible = true
	House4.visible = true

	await get_tree().create_timer(1.0).timeout
	# =========================================================
	# RETURN TO ANDREW
	# =========================================================

	camera.global_position = npc.global_position
	camera_follow_npc = true

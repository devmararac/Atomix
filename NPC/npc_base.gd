
extends CharacterBody2D
class_name NPCBase

var dialogue_active := false

@export var data: NPCData

@onready var quest: TextureRect = $Quest
@onready var emote: Sprite2D = $Emote
@onready var display_name = $NameContainer/Label
@onready var sprite = $NpcSprite
@onready var indicator = $NpcSprite/Indicator
@onready var BubbleMarker = $BubbleMarker
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

@export var show_navigation_path := false


# ============================================================
# MOVEMENT
# ============================================================

enum MovementMode {
	IDLE,
	WANDER
}

@export_category("NPC Movement")
@export var movement_mode: MovementMode = MovementMode.IDLE

@export var wander_speed: float = 30.0
@export var wander_wait_times: Array[float] = [0.5, 1.0, 1.5]


# ============================================================
# NPC PROXIMITY
# ============================================================

@export_category("NPC Proximity")
@export var stop_when_player_near: bool = true
@export var player_stop_distance: float = 45.0

var player_is_near := false


var quest_tween: Tween
var quest_indicator_visible := false
var quest_base_position := Vector2.ZERO

var wander_state := WanderState.IDLE
var wander_direction := Vector2.ZERO
var wander_timer: float = 0.0

enum WanderState {
	IDLE,
	NEW_DIRECTION,
	MOVE
}


# ============================================================
# EMOTES
# ============================================================

const ANGRY = preload("res://Assets/Emotes/angry.png")
const WORRIED = preload("res://Assets/Emotes/worried.png")
const WEIRDED = preload("res://Assets/Emotes/weirded.png")
const THANKFUL = preload("res://Assets/Emotes/thankful.png")
const SLEEPY = preload("res://Assets/Emotes/sleepy.png")
const SHOCKED = preload("res://Assets/Emotes/shocked.png")
const LOL = preload("res://Assets/Emotes/lol.png")
const KISS = preload("res://Assets/Emotes/kiss.png")
const HAPPY = preload("res://Assets/Emotes/happy.png")
const GIGGLE = preload("res://Assets/Emotes/giggle.png")
const CURIOUS = preload("res://Assets/Emotes/curious.png")
const CLOWN = preload("res://Assets/Emotes/clown.png")
const ANNOYED = preload("res://Assets/Emotes/annoyed.png")


# ============================================================
# GENERAL STATE
# ============================================================

signal destination_reached

var joystick_controlled := false
var is_moving := false
var debug_path: PackedVector2Array = []
var emote_tween: Tween


# ============================================================
# READY
# ============================================================

func _ready():
	quest.visible = false
	quest_indicator_visible = false
	quest_base_position = quest.position
	
	randomize()

	setup_npc()

	$Highlight.visible = false
	
	NpcManager.register_npc(self)
	NpcManager.refresh_quest_indicators()
	
	if movement_mode == MovementMode.WANDER:
		start_wandering()


# ============================================================
# DIALOGUE STATE
# ============================================================

func set_dialogue_active(active: bool) -> void:
	dialogue_active = active

	if active:
		velocity = Vector2.ZERO

		# Only set idle when dialogue starts.
		# DO NOT force idle every physics frame.
		# Cutscenes are allowed to control the animation afterward.
		if not is_moving:
			if sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")


func _exit_tree():
	NpcManager.unregister_npc(self)


# ============================================================
# NPC SETUP
# ============================================================

func setup_npc():

	if data == null:
		push_warning("NPCData missing.")
		return

	display_name.text = data.display_name

	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
		sprite.play("idle")

	sprite.flip_h = data.facing_direction == NPCData.FacingDirection.LEFT


# ============================================================
# INTERACTION
# ============================================================

func interact():
	print("[NPCBase] interact() called for: ", name)
	print("[NPCBase] NPC data: ", data)

	if data != null:
		print("[NPCBase] NPC ID: ", data.npc_id)
		print("[NPCBase] Dialogue data: ", data.dialogue_data)
		print("[NPCBase] Quests count: ", data.quests.size())

	var result = NpcManager.interact(self)

	print("[NPCBase] NpcManager.interact() returned: ", result)


func show_indicator():
	indicator.visible = true


func hide_indicator():
	indicator.visible = false


# ============================================================
# PLAYER PROXIMITY
# ============================================================

func is_player_near() -> bool:

	if global.player == null:
		return false

	var distance := global_position.distance_to(
		global.player.global_position
	)

	return distance <= player_stop_distance


func face_player() -> void:

	if global.player == null:
		return

	var direction := global.player.global_position - global_position

	if direction.x < 0:
		sprite.flip_h = true
	elif direction.x > 0:
		sprite.flip_h = false


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta):

	# ============================================================
	# NAVIGATION MOVEMENT
	# ============================================================
	# Navigation MUST be checked before player proximity.
	#
	# This allows:
	# professor.walk_to(...)
	#
	# to work even while Dialogic is active or while the player
	# is standing near the NPC.
	# ============================================================

	if is_moving:
		process_navigation_movement()
		return


	# ============================================================
	# PLAYER PROXIMITY
	# ============================================================
	# When the player gets close:
	# - Stop the NPC
	# - Face the player
	# - Play idle
	#
	# When the player walks away:
	# - Normal NPC behavior resumes
	# ============================================================

	if stop_when_player_near and is_player_near():

		player_is_near = true
		velocity = Vector2.ZERO

		# Face the player.
		face_player()

		# Stay in idle animation.
		if sprite.sprite_frames != null \
		and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

		return

	else:
		player_is_near = false


	# ============================================================
	# JOYSTICK CONTROL
	# ============================================================

	if joystick_controlled:
		is_moving = false

		var input_vector := Input.get_vector(
			"left",
			"right",
			"up",
			"down"
		)

		velocity = input_vector * data.move_speed

		if input_vector != Vector2.ZERO:

			if sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation("walk"):
				sprite.play("walk")
			else:
				sprite.play("idle")

			sprite.flip_h = input_vector.x < 0

		else:
			velocity = Vector2.ZERO

			if sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")

		move_and_collide(
			velocity * get_physics_process_delta_time()
		)

		return


	# ============================================================
	# DIALOGUE LOCK
	# ============================================================
	# Dialogue stops physical movement, but DOES NOT control
	# the animation anymore.
	#
	# Cutscenes can safely use:
	# sprite.play("walk")
	# sprite.play("doing")
	# sprite.play("idle")
	# etc.
	# ============================================================

	if dialogue_active:
		velocity = Vector2.ZERO
		return


	# ============================================================
	# RANDOM WANDERING
	# ============================================================

	if movement_mode == MovementMode.WANDER:
		process_wandering(delta)
		return


	# ============================================================
	# NORMAL IDLE
	# ============================================================
	# Do NOT play idle here.
	#
	# External/cutscene animation must be allowed to continue.
	# setup_npc() already starts normal NPCs in idle.
	# ============================================================

	velocity = Vector2.ZERO


# ============================================================
# NAVIGATION MOVEMENT
# ============================================================

func process_navigation_movement():

	if navigation_agent.is_navigation_finished():

		is_moving = false
		velocity = Vector2.ZERO

		if sprite.sprite_frames != null \
		and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

		destination_reached.emit()
		return


	var next_position = navigation_agent.get_next_path_position()

	debug_path = navigation_agent.get_current_navigation_path()

	if show_navigation_path:
		queue_redraw()

	var direction = (next_position - global_position).normalized()

	velocity = direction * data.move_speed

	move_and_slide()

	if sprite.sprite_frames != null \
	and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")
	else:
		sprite.play("idle")

	sprite.flip_h = velocity.x < 0


# ============================================================
# WALK TO
# ============================================================

func walk_to(target: Vector2):

	# Stop random wandering while navigating.
	is_moving = true

	navigation_agent.target_position = target


# ============================================================
# RANDOM WANDERING
# ============================================================

func start_wandering():

	wander_state = WanderState.IDLE
	wander_direction = Vector2.ZERO

	set_wander_timer()


func process_wandering(delta):

	# Don't wander while performing scripted movement.
	if is_moving:
		return

	match wander_state:

		WanderState.IDLE:

			velocity = velocity.move_toward(
				Vector2.ZERO,
				wander_speed * 2.0 * delta
			)

			if sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")

			wander_timer -= delta

			if wander_timer <= 0.0:
				wander_state = WanderState.NEW_DIRECTION


		WanderState.NEW_DIRECTION:

			wander_direction = choose_direction()

			wander_state = WanderState.MOVE

			set_wander_timer()


		WanderState.MOVE:

			velocity = wander_direction * wander_speed

			if sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation("walk"):
				sprite.play("walk")
			else:
				sprite.play("idle")

			if wander_direction.x < 0:
				sprite.flip_h = true
			elif wander_direction.x > 0:
				sprite.flip_h = false

			wander_timer -= delta

			if wander_timer <= 0.0:
				wander_state = WanderState.IDLE

	move_and_slide()


func choose_direction() -> Vector2:

	var directions := [
		Vector2.RIGHT,
		Vector2.UP,
		Vector2.LEFT,
		Vector2.DOWN
	]

	directions.shuffle()

	return directions.front()


func set_wander_timer():

	if wander_wait_times.is_empty():
		wander_timer = 1.0
		return

	wander_timer = wander_wait_times.pick_random()


# ============================================================
# DEBUG NAVIGATION PATH
# ============================================================

func _draw():

	if not show_navigation_path:
		return

	if debug_path.size() < 2:
		return

	for i in range(debug_path.size() - 1):

		draw_line(
			to_local(debug_path[i]),
			to_local(debug_path[i + 1]),
			Color.RED,
			2.0
		)

	for point in debug_path:

		draw_circle(
			to_local(point),
			4,
			Color.YELLOW
		)


# ============================================================
# EMOTES
# ============================================================

func show_emote(texture: Texture2D, duration: float = 2.5) -> void:

	if emote_tween:
		emote_tween.kill()

	emote.texture = texture
	emote.show()

	var base_position := emote.position

	emote.position = base_position + Vector2(0, 10)
	emote.scale = Vector2(0.8, 0.8)
	emote.modulate.a = 1.0

	emote_tween = create_tween()

	# Pop up
	emote_tween.set_trans(Tween.TRANS_BACK)
	emote_tween.set_ease(Tween.EASE_OUT)

	emote_tween.tween_property(
		emote,
		"position",
		base_position,
		0.35
	)

	# Scale up slightly
	emote_tween.parallel().tween_property(
		emote,
		"scale",
		Vector2.ONE,
		0.35
	)

	# Small bounce
	emote_tween.tween_property(
		emote,
		"position",
		base_position + Vector2(0, -5),
		0.12
	)

	emote_tween.tween_property(
		emote,
		"position",
		base_position,
		0.12
	)

	# Stay visible
	emote_tween.tween_interval(duration)

	# Fade out
	emote_tween.tween_property(
		emote,
		"modulate:a",
		0.0,
		0.25
	)

	# Hide and reset
	emote_tween.tween_callback(func():

		emote.hide()
		emote.texture = null
		emote.modulate.a = 1.0
		emote.scale = Vector2.ONE
		emote.position = base_position
	)


func show_quest_indicator() -> void:

	if quest_indicator_visible:
		return

	quest_indicator_visible = true
	quest.visible = true

	if quest_tween:
		quest_tween.kill()

	quest.position = quest_base_position
	quest.scale = Vector2.ONE

	quest_tween = create_tween()
	quest_tween.set_loops()

	quest_tween.tween_property(
		quest,
		"position:y",
		quest_base_position.y - 6.0,
		0.45
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	quest_tween.tween_property(
		quest,
		"position:y",
		quest_base_position.y,
		0.45
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func hide_quest_indicator() -> void:

	quest_indicator_visible = false

	if quest_tween:
		quest_tween.kill()
		quest_tween = null

	quest.visible = false
	quest.position = quest_base_position


func play_emote(emote_name: String, duration: float = 2.5) -> void:

	var texture: Texture2D

	match emote_name.to_lower():

		"angry":
			texture = ANGRY
			SfxManager.play_emote()

		"annoyed":
			texture = ANNOYED
			SfxManager.play_emote()

		"clown":
			texture = CLOWN
			SfxManager.play_emote()

		"curious":
			texture = CURIOUS
			SfxManager.play_emote()

		"giggle":
			texture = GIGGLE
			SfxManager.play_emote()

		"happy":
			texture = HAPPY
			SfxManager.play_emote()

		"kiss":
			texture = KISS
			SfxManager.play_emote()

		"lol":
			texture = LOL
			SfxManager.play_emote()

		"shocked":
			texture = SHOCKED
			SfxManager.play_emote()

		"sleepy":
			texture = SLEEPY
			SfxManager.play_emote()

		"thankful":
			texture = THANKFUL
			SfxManager.play_emote()

		"weirded":
			texture = WEIRDED
			SfxManager.play_emote()

		"worried":
			texture = WORRIED
			SfxManager.play_emote()

		_:
			push_warning("Unknown NPC emote: " + emote_name)
			return

	show_emote(texture, duration)

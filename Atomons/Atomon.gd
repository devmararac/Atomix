extends CharacterBody2D

@onready var cry_player: AudioStreamPlayer2D = $CryPlayer
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@export var min_cry_delay := 3.0
@export var max_cry_delay := 8.0
var cry_timer := 0.0
var cutscene_mode := false

@export var data: AtomonData

# Unique identity for this wild Atomon spawn point
@export var spawn_id: String = ""

var speed := 20
var player_chase := false
var player = null
var battle_started := false
var current_hp := 0
var recruited := false

@export var battle_mode := false

# ============================================================
# WILD ATOMON RESPAWN
# ============================================================

var is_defeated := false
var respawn_check_timer := 0.0
const RESPAWN_CHECK_INTERVAL := 1.0

var original_collision_layer: int
var original_collision_mask: int

func _ready() -> void:

	# Save original collision settings
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask

	if data != null:
		setup(data)

	randomize_cry_timer()

	# Check whether this spawn is currently on cooldown
	check_respawn_status()


# ============================================================
# CHECK ATOMON RESPAWN STATUS
# ============================================================

func check_respawn_status() -> void:

	var id := get_effective_spawn_id()

	if RespawnManager.can_spawn(id):

		is_defeated = false
		show_atomon()

	else:

		hide_atomon()


# ============================================================
# HIDE / SHOW WILD ATOMON
# ============================================================

func hide_atomon() -> void:

	is_defeated = true
	visible = false

	player_chase = false
	player = null
	velocity = Vector2.ZERO

	# Disable collision
	collision_layer = 0
	collision_mask = 0

	# Disable interaction Area2D
	if has_node("Area2D"):
		var area = get_node("Area2D")
		area.monitoring = false
		area.monitorable = false

	# Stop Atomon cry
	if cry_player.playing:
		cry_player.stop()


func show_atomon() -> void:

	is_defeated = false
	respawn_check_timer = 0.0
	visible = true

	# Restore original collision
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask

	# Re-enable interaction Area2D
	if has_node("Area2D"):
		var area = get_node("Area2D")
		area.monitoring = true
		area.monitorable = true

	velocity = Vector2.ZERO
	play_anim("idle")


func setup(atomon_data: AtomonData) -> void:
	data = atomon_data

	# Load sprite animations
	$AnimatedSprite2D.sprite_frames = data.sprite_frames

	# Dynamically calculate HP
	current_hp = StatCalculator.get_hp(data)

	# Overworld movement speed (not battle Speed stat)
	speed = data.move_speed

	play_anim("idle")

func get_effective_spawn_id() -> String:
	if not spawn_id.is_empty():
		return spawn_id

	var current_scene := get_tree().current_scene

	if current_scene:
		return current_scene.scene_file_path + "::" + str(get_path())

	return str(get_path())


func _physics_process(delta: float) -> void:

	# ========================================================
	# WILD ATOMON RESPAWN CHECK
	# ========================================================

	if is_defeated:

		respawn_check_timer += delta

		if respawn_check_timer >= RESPAWN_CHECK_INTERVAL:

			respawn_check_timer = 0.0
			check_respawn_status()

		# Stop normal processing while defeated
		if is_defeated:
			return

	# ========================================================
	# ORIGINAL CRY SYSTEM
	# ========================================================

	if screen_notifier.is_on_screen():
		cry_timer -= delta
		if cry_timer <= 0.0:
			play_cry()
			randomize_cry_timer()

	# ========================================================
	# ORIGINAL BATTLE CHECK
	# ========================================================

	if battle_mode:
		return

	# ========================================================
	# ORIGINAL MOVEMENT SYSTEM
	# ========================================================

	if player_chase:

		var distance = global_position.distance_to(player.global_position)

		if distance > 20:

			var dir = (player.global_position - global_position).normalized()

			velocity = dir * speed

			play_anim("walk")
			$AnimatedSprite2D.flip_h = dir.x < 0

		else:

			velocity = Vector2.ZERO
			play_anim("idle")

	else:

		velocity = Vector2.ZERO
		play_anim("idle")

	move_and_collide(velocity * delta)


func play_anim(anim: String):

	if $AnimatedSprite2D.sprite_frames == null:
		return

	if $AnimatedSprite2D.sprite_frames.has_animation(anim):
		$AnimatedSprite2D.play(anim)


func _on_area_2d_body_entered(body: Node2D) -> void:

	if body == null:
		return

	player = body
	player_chase = true


func recruit():

	if recruited:
		return

	recruited = true

	PartyManager.add_species(data)

	queue_free()


func _on_area_2d_body_exited(body: Node2D) -> void:

	player = null
	player_chase = false




func take_hit():

	if battle_started:
		return

	battle_started = true

	await get_tree().create_timer(0.7).timeout

	call_deferred("_start_battle")


func _start_battle():

	var current_scene := get_tree().current_scene

	if current_scene == null:
		push_error("Atomon: Current scene is null when starting battle.")
		return

	BattleManager.start_battle(
		data,
		current_scene.scene_file_path,
		global_position,
		get_effective_spawn_id()
	)

func randomize_cry_timer() -> void:
	cry_timer = randf_range(min_cry_delay, max_cry_delay)

func play_cry() -> void:
	if data == null:
		return

	if data.cry_sound == null:
		return

	cry_player.stream = data.cry_sound
	cry_player.play()

func start_cutscene_mode() -> void:
	cutscene_mode = true
	player_chase = false
	player = null
	velocity = Vector2.ZERO

func move_to_cutscene_target(target: Marker2D) -> void:
	if target == null:
		print("ERROR: Atomon target is NULL")
		return

	print("=== ATOMON CUTSCENE MOVEMENT ===")
	print("Starting position: ", global_position)
	print("Target position: ", target.global_position)

	start_cutscene_mode()

	while global_position.distance_to(target.global_position) > 5.0:
		var direction := global_position.direction_to(target.global_position)

		velocity = direction * speed

		play_anim("walk")
		$AnimatedSprite2D.flip_h = direction.x < 0

		var collision := move_and_collide(
			velocity * get_physics_process_delta_time()
		)

		if collision:
			print("ATOMON COLLISION: ", collision.get_collider())

		await get_tree().physics_frame

	velocity = Vector2.ZERO
	play_anim("idle")

	print("Atomon reached target!")
	print("Final position: ", global_position)

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	if cry_player.playing:
		cry_player.stop()

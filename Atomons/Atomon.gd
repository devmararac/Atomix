extends CharacterBody2D

@export var data: AtomonData

var speed := 20
var player_chase := false
var player = null
var battle_started := false
var current_hp := 0
var recruited := false

@export var battle_mode := false


func _ready() -> void:
	if data != null:
		setup(data)


func setup(atomon_data: AtomonData) -> void:
	data = atomon_data

	# Load sprite animations
	$AnimatedSprite2D.sprite_frames = data.sprite_frames

	# Dynamically calculate HP
	current_hp = StatCalculator.get_hp(data)

	# Overworld movement speed (not battle Speed stat)
	speed = data.move_speed

	play_anim("idle")


func _physics_process(delta: float) -> void:

	if battle_mode:
		return

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

	BattleManager.start_battle(data)

extends CharacterBody2D
class_name Player

@onready var footstep_sound = $FootstepSound
var footstep_timer := 0.0
@export var footstep_interval := 0.35

@export var dialogic_character: DialogicCharacter
@onready var bubble_marker = $BubbleMarker

@onready var attack_sound = $AttackSound
var cardinal_direction: Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO
var move_speed: float = 70.0
var state: String = "idle"
var can_use_doors: bool = false
var can_move = true
var highlighted_target: Node = null
var is_attacking = false
var is_cutscene_moving := false
var is_playing_cutscene_animation := false

@onready var sword_hitbox = $SwordHitbox
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast_2d = $RayCast2D


func _ready() -> void:
	call_deferred("apply_spawn")
	call_deferred("enable_doors")
	global.player = self
	sword_hitbox.monitoring = false
	Dialogic.timeline_ended.connect(_on_dialogue_finished)
	
	if SaveManager.save_data != null:
		global_position = SaveManager.save_data.player_position

func register_dialogic(layout):
	layout.register_character(dialogic_character, bubble_marker)

func _process(_delta: float) -> void:
	get_input()
	update_animation()
	update_interaction_highlight()
	play_footsteps(_delta)

func play_footsteps(delta):

	if (!can_move and !is_cutscene_moving) or is_attacking:
		footstep_timer = 0
		return

	if is_cutscene_moving:
		footstep_timer += delta

		if footstep_timer >= footstep_interval:
			footstep_timer = 0
			footstep_sound.play()

		return


	if direction == Vector2.ZERO:
		footstep_timer = 0
		return

	footstep_timer += delta

	if footstep_timer >= footstep_interval:
		footstep_timer = 0
		footstep_sound.play()

func play_cutscene_footstep():
	footstep_sound.play()

func _on_dialogue_finished():
	can_move = true

func _physics_process(_delta: float) -> void:
	if can_move:
		velocity = direction * move_speed
		move_and_slide()


func get_input() -> void:
	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	direction = direction.normalized()
	if velocity != Vector2.ZERO:
		ray_cast_2d.target_position = velocity.normalized() * 50

func update_animation() -> void:
	if is_attacking:
		return

	if is_cutscene_moving:
		return

	if is_playing_cutscene_animation:
		return

	# Update facing direction
	if direction.x < 0:
		anim.flip_h = true
	elif direction.x > 0:
		anim.flip_h = false

	# Update animation
	if direction == Vector2.ZERO:
		anim.play("idle")
	else:
		anim.play("walk")

func attack():

	if is_attacking or !can_move:
		return

	is_attacking = true
	can_move = false
	direction = Vector2.ZERO
	velocity = Vector2.ZERO
	
	sword_hitbox.monitoring = true
	attack_sound.play()
	anim.play("attack")

	await anim.animation_finished
	
	sword_hitbox.monitoring = false

	is_attacking = false
	can_move = true


func apply_spawn() -> void:
	if global.return_position != Vector2.ZERO:
		global_position = global.return_position
		global.return_position = Vector2.ZERO
		return
	
	if global.spawn_point_name == "":
		return

	var spawn = get_tree().current_scene.get_node_or_null(global.spawn_point_name)

	if spawn:
		global_position = spawn.global_position

func enable_doors() -> void:
	await get_tree().create_timer(0.3).timeout
	can_use_doors = true

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Action"):
		attack()

	if !can_move:
		return

	if event.is_action_pressed("Interact"):
		handle_interaction()

	if event.is_action_pressed("Quest"):
		get_tree().current_scene.get_node("HUD").show_hide_log()

func handle_interaction():
	var target = ray_cast_2d.get_collider()

	if target == null:
		return
	
	if target is NPCBase:
		can_move = false
		target.interact()
		QuestManager.notify(
			ObjectiveType.Type.TALK,
			target.data.npc_id
		)
	
	elif target.is_in_group("Atomons"):
		target.recruit()

	elif target.is_in_group("Items"):

		if target.data.quest_item:
			if QuestManager.is_item_needed(target.data.item_id):
				target.collect()
				QuestManager.notify(
					ObjectiveType.Type.COLLECTION,
					target.data.item_id,
					target.quantity
				)
			else:
				print("This quest item cannot be collected yet.")
		else:
			target.collect()

	elif target.is_in_group("QuestObjects"):
		target.interact()

func update_interaction_highlight():
	var target = ray_cast_2d.get_collider()

	# Nothing changed
	if target == highlighted_target:
		return

	# Hide previous highlight
	if highlighted_target and highlighted_target.has_node("Highlight"):
		highlighted_target.get_node("Highlight").visible = false

	highlighted_target = target

	# Show new highlight
	if highlighted_target and highlighted_target.has_node("Highlight"):
		var highlight = highlighted_target.get_node("Highlight")
		highlight.visible = true

		# If it's AnimatedSprite2D
		if highlight is AnimatedSprite2D:
			highlight.play()


func _on_sword_hitbox_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	if area.is_in_group("Enemy"):
		area.get_parent().take_hit()

func face_left():
	anim.flip_h = true

func face_right():
	anim.flip_h = false

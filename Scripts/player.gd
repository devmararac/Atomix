extends CharacterBody2D
class_name Player

const font = preload("res://Assets/Font/NicoPaint-Regular.woff")

const ARROW_DISTANCE := 5

const ARROW_POSITIONS = {
	"up": Vector2(0, -ARROW_DISTANCE),
}
@onready var footstep_sound = $FootstepSound
var footstep_timer := 0.0
const FOOTSTEP_INTERVAL := 0.35

@onready var attack_sound = $AttackSound
@onready var objective_arrow: AnimatedSprite2D = $Indicator
var cardinal_direction: Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO
var move_speed: float = 70.0
var state: String = "idle"
var can_use_doors: bool = false
var can_move = true
var highlighted_target: Node = null
var is_attacking = false

#Dialogue and Quest Vars
var selected_quest: Quest = null

@onready var sword_hitbox = $SwordHitbox
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast_2d = $RayCast2D
@onready var quest_tracker = $HUD/QuestTracker
@onready var title = $HUD/QuestTracker/Details/Title
@onready var objectives = $HUD/QuestTracker/Objectives
@onready var quest_manager = QuestManager

func _ready() -> void:
	call_deferred("apply_spawn")
	call_deferred("enable_doors")
	global.player = self
	quest_tracker.visible = false
	sword_hitbox.monitoring = false
	
	#Signal Connections
	quest_manager.quest_updated.connect(_on_quest_updated)
	quest_manager.objective_updated.connect(_on_objective_updated)

	Dialogic.timeline_ended.connect(_on_dialogue_finished)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	
	if QuestManager.selected_quest:
		update_quest_tracker(QuestManager.selected_quest)
	
	objective_arrow.visible = false
	
	if SaveManager.save_data != null:
		global_position = SaveManager.save_data.player_position

func _process(_delta: float) -> void:
	get_input()
	update_animation()
	update_objective_arrow()
	update_interaction_highlight()
	play_footsteps(_delta)

func play_footsteps(delta):

	if !can_move or is_attacking:
		footstep_timer = 0
		return

	if direction == Vector2.ZERO:
		footstep_timer = 0
		return

	footstep_timer += delta

	if footstep_timer >= FOOTSTEP_INTERVAL:
		footstep_timer = 0
		footstep_sound.play()

func _on_dialogic_signal(argument: String):

	if argument == "observe:hydrogen":
		check_quest_objectives("hydrogen", "observe")

func _on_dialogue_finished():
	can_move = true

func update_objective_arrow():

	var target = get_nearest_quest_target()

	if target == null:
		objective_arrow.visible = false
		return

	objective_arrow.visible = true
	
	if objective_arrow.animation != "up":
		objective_arrow.play("up")

	var dir = (target.global_position - global_position).normalized()

	var radius := 15.0

	objective_arrow.position = dir * radius

	# Arrow sprite points UP
	objective_arrow.rotation = dir.angle() + deg_to_rad(90)

func get_nearest_quest_target() -> Node:

	var quest = QuestManager.selected_quest

	if quest == null:
		return null

	# Find the first unfinished objective
	var objective = null

	for obj in quest.objectives:
		if !obj.is_completed:
			objective = obj
			break

	if objective == null:
		return null
	var group_name := ""

	match objective.target_type:
		"collection":
			group_name = "Items"

		"talk_to":
			group_name = "NPC"

		"observe":
			group_name = "QuestObjects"

		"battle":
			group_name = "Enemy"

		_:
			return null

	var closest = null
	var closest_distance := INF

	for node in get_tree().get_nodes_in_group(group_name):
		match objective.target_type:
			"collection":
				if node.data.item_id != objective.target_id:
					continue
			_:
				if node.target_id != objective.target_id:
					continue
		if objective.target_type == "observe":
			if node.is_objective_complete():
				continue

		var distance = global_position.distance_to(node.global_position)

		if distance < closest_distance:
			closest_distance = distance
			closest = node

	return closest

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

	if direction == Vector2.ZERO:
		anim.play("idle")
	else:
		anim.play("walk")

	if direction.x < 0:
		anim.flip_h = true
	elif direction.x > 0:
		anim.flip_h = false

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

	var spawn_name = global.spawn_point_name

	if spawn_name == "":
		return

	var spawn = get_tree().current_scene.get_node_or_null(spawn_name)

	if spawn:
		global_position = spawn.global_position

	if spawn_name == "":
		return


	if spawn:
		global_position = spawn.global_position

func enable_doors() -> void:
	await get_tree().create_timer(0.3).timeout
	can_use_doors = true


func set_direction() -> bool:
	return true


func set_state() -> bool:
	return true

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Action"):
		attack()

	if can_move:
		if event.is_action_pressed("Interact"):
			var target = ray_cast_2d.get_collider()

			if target != null:

				if target.is_in_group("NPC"):
					can_move = false
					target.start_dialouge()
					check_quest_objectives(target.target_id, "talk_to")

				elif target.is_in_group("Atomons"):
					target.recruit()

				elif target.is_in_group("Items"):

					# Quest Items
					if target.data.quest_item:
						if is_item_needed(target.data.item_id):
							target.collect()
							check_quest_objectives(
								target.data.item_id,
								"collection",
								target.quantity
							)
						else:
							print("This quest item cannot be collected yet.")

					# Normal Items
					else:
						target.collect()

				elif target.is_in_group("QuestObjects"):
					target.interact()

		if event.is_action_pressed("Quest"):
			quest_manager.show_hide_log()

#Check if quest item is needed
func is_item_needed(item_id: String) -> bool:
	var quest = QuestManager.selected_quest

	if quest == null:
		return false

	for objective in quest.objectives:
		if objective.target_id == item_id \
		and objective.target_type == "collection" \
		and not objective.is_completed:
			return true

	return false

#Checking quest objectives
func check_quest_objectives(target_id: String, target_type: String, quantity: int = 1):
	var quest = QuestManager.selected_quest

	if quest == null:
		return

	# Update objectives
	var objective_updated = false
	for objective in quest.objectives:
		if objective.target_id == target_id and objective.target_type == target_type and not objective.is_completed:
			quest.complete_objective(objective.id, quantity)
			objective_updated = true
			break

	# Provide rewards
	if objective_updated:
		if quest.is_completed():
			handle_quest_completion(quest)

		# Update UI
		update_quest_tracker(quest)
#Player Rewards
func handle_quest_completion(quest: Quest):
	for reward in quest.rewards:
		if reward.reward_type == "coins":
			CurrencyManager.add_coins(reward.reward_amount)
			print(CurrencyManager.coins)

	update_quest_tracker(quest)
	quest_manager.update_quest(quest.quest_id, "completed")
	
	
#Update tracker UI
func update_quest_tracker(quest: Quest):
	# if we have an active quest, populate tracker
	if quest:
		quest_tracker.visible = true
		title.text = quest.quest_name	

		for child in objectives.get_children():
			child.queue_free()

		for objective in quest.objectives:
			var label = Label.new()

			# Display progress for collection objectives
			if objective.required_quantity > 0:
				label.text = "%s (%d/%d)" % [
					objective.description,
					objective.collected_quantity,
					objective.required_quantity
				]
			else:
				label.text = objective.description

			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", 16)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			if objective.is_completed:
				label.add_theme_color_override("font_color", Color(0.4, 0.48, 0.139, 1.0))
			else:
				label.add_theme_color_override("font_color", Color(0.471, 0.353, 0.235, 1.0))

			objectives.add_child(label)

	# no active quest, hide tracker
	else:
		quest_tracker.visible = false


# Update tracker if quest is complete
func _on_quest_updated(quest_id: String):
	var quest = quest_manager.get_quest(quest_id)
	if quest == selected_quest:
		update_quest_tracker(quest)
	selected_quest = null
	
# Update tracker if objective is complete
func _on_objective_updated(quest_id: String, objective_id: String):


	if selected_quest and selected_quest.quest_id == quest_id:
		update_quest_tracker(selected_quest)
	selected_quest = null

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

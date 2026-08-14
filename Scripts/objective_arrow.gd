#OBJECTIVE_ARROW
extends AnimatedSprite2D

const ARROW_DISTANCE := 15.0

@onready var player: Player = get_parent() as Player

func _ready():
	visible = false

func _process(_delta):
	update_objective_arrow()

func update_objective_arrow():

	var target = get_nearest_quest_target()

	if target == null:
		visible = false
		return

	visible = true
	
	if animation != "up":
		play("up")

	var dir = (target.global_position - player.global_position).normalized()

	var radius := 15.0

	position = dir * radius

	# Arrow sprite points UP
	rotation = dir.angle() + deg_to_rad(90)

func get_nearest_quest_target() -> Node:

	var quest = QuestManager.tracked_quest

	if quest == null:
		return null

	# Find the first unfinished objective
	var objective = null

	for obj in quest.objectives:
		if obj.is_active and !obj.is_completed:
			objective = obj
			break

	if objective == null:
		return null
	var group_name := ""

	match objective.type:

		ObjectiveType.Type.COLLECTION:
			group_name = "Items"

		ObjectiveType.Type.TALK:
			group_name = "NPC"

		ObjectiveType.Type.OBSERVE:
			group_name = "QuestObjects"

		ObjectiveType.Type.BATTLE:
			group_name = "Enemy"

		ObjectiveType.Type.AREA:
			group_name = "QuestAreas"

		_:
			return null

	var closest = null
	var closest_distance := INF

	for node in get_tree().get_nodes_in_group(group_name):
		match objective.type:

			ObjectiveType.Type.COLLECTION:
				if node.data.item_id != objective.target_id:
					continue

			ObjectiveType.Type.TALK:
				if node.data.npc_id != objective.target_id:
					continue

			_:
				if node.target_id != objective.target_id:
					continue
				if node.target_id != objective.target_id:
					continue

		var distance = player.global_position.distance_to(node.global_position)

		if distance < closest_distance:
			closest_distance = distance
			closest = node

	return closest

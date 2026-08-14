extends Resource
class_name Quest

@export var quest_id: String
@export var quest_name: String
@export_multiline var quest_description: String

## Which quest becomes available after this one is completed.
@export var unlock_id: String = ""

## Objectives that make up this quest.
@export var objectives: Array[Objective] = []

## Rewards granted when the quest is completed.
@export var rewards: Array[Reward] = []

## Current quest state.
@export var state := QuestState.Type.NOT_STARTED


## Starts the quest.
func start() -> void:
	state = QuestState.Type.ACTIVE

	if objectives.is_empty():
		return

	objectives[0].is_active = true


## Returns the currently active objective.
func get_active_objective() -> Objective:
	for objective in objectives:
		if objective.is_active and !objective.is_completed:
			return objective

	return null


## Returns true if every objective has been completed.
func is_completed() -> bool:
	for objective in objectives:
		if !objective.is_completed:
			return false

	return true

func advance_objective() -> void:
	var current: Objective = get_active_objective()

	if current == null:
		return

	current.is_active = false
	current.is_completed = true

	var index := objectives.find(current)

	if index + 1 < objectives.size():
		objectives[index + 1].is_active = true
	else:
		state = QuestState.Type.COMPLETED

func notify(type: ObjectiveType.Type, target_id: String, amount: int = 1) -> bool:

	var objective: Objective = get_active_objective()

	if objective == null:
		return false

	if objective.type != type:
		return false

	if objective.target_id != target_id:
		return false


	objective.current_amount = min(
		objective.current_amount + amount,
		objective.required_amount
	)


	if objective.is_finished():
		advance_objective()


	return true

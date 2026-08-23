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

# ============================================================
# SAVE QUEST STATE
# ============================================================

func to_save_dict() -> Dictionary:

	var objective_data: Dictionary = {}

	for objective in objectives:

		if objective == null:
			continue

		objective_data[objective.id] = {
			"current_amount": objective.current_amount,
			"is_active": objective.is_active,
			"is_completed": objective.is_completed
		}

	return {
		"quest_id": quest_id,
		"state": int(state),
		"objectives": objective_data
	}


# ============================================================
# RESTORE QUEST STATE
# ============================================================

func apply_save_dict(saved_data: Dictionary) -> void:

	state = QuestState.Type.values()[clampi(
		int(saved_data.get(
			"state",
			QuestState.Type.NOT_STARTED
		)),
		0,
		QuestState.Type.size() - 1
	)]

	var saved_objectives: Dictionary = saved_data.get(
		"objectives",
		{}
	)

	for objective in objectives:

		if objective == null:
			continue

		if not saved_objectives.has(objective.id):
			continue

		var saved_objective: Dictionary = saved_objectives[objective.id]

		objective.current_amount = int(
			saved_objective.get("current_amount", 0)
		)

		objective.is_active = bool(
			saved_objective.get("is_active", false)
		)

		objective.is_completed = bool(
			saved_objective.get("is_completed", false)
		)

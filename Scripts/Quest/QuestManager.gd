extends Node2D

# -------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------

signal quest_updated(quest_id: String)
signal objective_updated(quest_id: String, objective_id: String)
signal quest_list_updated()
signal tracked_quest_changed(quest: Quest)
signal quest_completed(quest_id: String)

# -------------------------------------------------------------------
# Quest Database
# -------------------------------------------------------------------

var quest_database := {
	"quest_hydrogen_001": preload("res://Resources/Quest/quest_hydrogen_001.tres"),
	"quest_collect_iron": preload("res://Resources/Quest/quest_collect_iron.tres"),
	"story_quest_explore_dungeon": preload("res://Resources/Quest/explore_dungeon.tres")
}

# -------------------------------------------------------------------
# Runtime Quest Data
# -------------------------------------------------------------------

## Quests currently in progress.
var active_quests: Dictionary[String, Quest] = {}

## Finished quests.
var completed_quests: Dictionary[String, Quest] = {}

## Quest currently shown in the tracker.
var tracked_quest: Quest = null

#Add quest
func _ready():
	Dialogic.signal_event.connect(_on_dialogic_signal)

func _on_dialogic_signal(argument: String):

	if argument.begins_with("quest_accept:"):
		var quest_id = argument.get_slice(":", 1)
		accept_quest(quest_id)

func accept_quest(quest_id: String) -> void:

	# Already active?
	if active_quests.has(quest_id):
		return

	# Already completed?
	if completed_quests.has(quest_id):
		return

	# Doesn't exist?
	if !quest_database.has(quest_id):
		push_error("Quest '%s' not found!" % quest_id)
		return

	var quest: Quest = quest_database[quest_id].duplicate(true)

	quest.start()

	active_quests[quest.quest_id] = quest

	# Automatically track the first accepted quest.
	if tracked_quest == null:
		set_tracked_quest(quest)

	quest_updated.emit(quest.quest_id)
	quest_list_updated.emit()

func start_story_quest(quest_id: String) -> void:
	if active_quests.has(quest_id):
		return

	if completed_quests.has(quest_id):
		return

	accept_quest(quest_id)

#Get quest
func get_quest(quest_id: String) -> Quest:
	return active_quests.get(quest_id)

func is_objective_completed(quest_id: String, objective_id: String) -> bool:

	var quest = get_quest(quest_id)

	if quest == null:
		return false

	for objective in quest.objectives:
		if objective.id == objective_id:
			return objective.is_completed
	return false

#Update quest 
func update_quest(quest_id: String, state: QuestState.Type) -> void:
	var quest := get_quest(quest_id)

	if quest == null:
		return

	quest.state = state
	quest_updated.emit(quest_id)

#Get Selected Quest
func get_active_quests() -> Array[Quest]:
	return active_quests.values()


func debug_quests() -> void:
	print("=== Active Quests ===")

	if active_quests.is_empty():
		print("No active quests.")
		return

	for quest in active_quests.values():
		print(quest.quest_id, " State:", quest.state)

#Player Rewards
func handle_quest_completion(quest: Quest) -> void:

	# Give rewards
	for reward in quest.rewards:
		match reward.reward_type:
			"coins":
				CurrencyManager.add_coins(reward.reward_amount)

	# Mark as completed
	update_quest(quest.quest_id, QuestState.Type.COMPLETED)

	# Move from active -> completed
	active_quests.erase(quest.quest_id)
	completed_quests[quest.quest_id] = quest

	# If this quest was being tracked,
	# automatically track another active quest.
	if tracked_quest == quest:
		tracked_quest = null

		if active_quests.size() > 0:
			set_tracked_quest(active_quests.values()[0])
	quest_completed.emit(quest.quest_id)
	quest_list_updated.emit()

func set_tracked_quest(quest: Quest) -> void:
	if tracked_quest == quest:
		return

	tracked_quest = quest
	tracked_quest_changed.emit(quest)

func notify(type: ObjectiveType.Type, target_id: String, amount: int = 1) -> void:

	print("====================")
	print("QUEST EVENT:")
	print("Type:", type)
	print("Target:", target_id)
	print("Amount:", amount)

	print("ACTIVE QUESTS:")
	for quest in active_quests.values():
		print(
			"-",
			quest.quest_id,
			"| State:",
			quest.state
		)

		for objective in quest.objectives:
			print(
				"   Objective:",
				objective.id,
				"| Type:",
				objective.type,
				"| Target:",
				objective.target_id,
				"| Active:",
				objective.is_active,
				"| Completed:",
				objective.is_completed
			)

	print("====================")


	for quest in active_quests.values():

		if quest.notify(type, target_id, amount):

			var objective: Objective = quest.get_active_objective()

			if objective != null:
				objective_updated.emit(
					quest.quest_id,
					objective.id
				)

			if quest.is_completed():
				handle_quest_completion(quest)

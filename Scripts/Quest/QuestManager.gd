extends Node2D

@onready var quest_ui = $QuestUI

#Signals
signal quest_updated(quest_id: String)
signal objective_updated(quest_id: String, objective_id: String)
signal quest_list_updated()


var quest_database := {
	"quest_hydrogen_001": preload("res://Resources/Quest/quest_hydrogen_001.tres"),
	"quest_collect_iron": preload("res://Resources/Quest/quest_collect_iron.tres")
}

var quests = {}
var selected_quest: Quest = null

#Add quest
func _ready():
	Dialogic.signal_event.connect(_on_dialogic_signal)

func _on_dialogic_signal(argument: String):

	if argument.begins_with("quest_accept:"):
		var quest_id = argument.get_slice(":", 1)
		accept_quest(quest_id)

	elif argument.begins_with("objective:"):
		print(argument)
		var parts = argument.split(":")

		if parts.size() >= 3:
			complete_objective(parts[1], parts[2])

func accept_quest(quest_id: String):

	# Already accepted?
	if quests.has(quest_id):
		return

	# Exists?
	if !quest_database.has(quest_id):
		push_error("Quest '%s' not found!" % quest_id)
		return

	var quest: Quest = quest_database[quest_id].duplicate(true)
	quest.state = "in_progress"

	add_quest(quest)

func add_quest(quest: Quest):
	if quests.has(quest.quest_id):
		return
	debug_quests()

	quests[quest.quest_id] = quest
	quest_updated.emit(quest.quest_id)
	quest_list_updated.emit()

#Remove Quest
func remove_quest(quest_id: String):
	quests.erase(quest_id)
	quest_list_updated.emit()
 
#Get quest
func get_quest(quest_id: String) -> Quest:
	return quests.get(quest_id, null)

func is_objective_completed(quest_id: String, objective_id: String) -> bool:

	var quest = get_quest(quest_id)

	if quest == null:
		return false

	for objective in quest.objectives:
		if objective.id == objective_id:
			return objective.is_completed
	
	print(
	QuestManager.is_objective_completed(
		"quest_hydrogen_001",
		"observe_hydrogen"
	)
)

	return false

#Update quest 
func update_quest(quest_id: String, state: String):
	var quest = get_quest(quest_id)

	if quest:
		quest.state = state
		quest_updated.emit(quest_id)

#Get Selected Quest
func get_active_quests() -> Array:
	var active_quests = []
	for quest in quests.values():
		if quest.state == "in_progress":
			active_quests.append(quest)
	return active_quests

#Complete objective 
func complete_objective(quest_id: String, objective_id: String):
	var quest = get_quest(quest_id)

	if quest == null:
		return

	quest.complete_objective(objective_id)
	objective_updated.emit(quest_id, objective_id)

	# If every objective is complete, finish the quest.
	if quest.is_completed():
		update_quest(quest_id, "completed")

#Show/Hide Quest UI
func show_hide_log():
	quest_ui.show_hide_log()



# ... your existing code ...

func debug_quests():
	print("=== Active Quests ===")
	if quests.is_empty():
		print("No active quests.")
		return

	for quest in quests.values():
		print(quest.quest_id, " State:", quest.state)

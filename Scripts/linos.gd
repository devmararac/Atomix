extends CharacterBody2D

@export var npc_id: String
@export var npc_name: String
@export var target_id: String

@export var tutorial: DialogicTimeline
@export var dialogue_timeline: DialogicTimeline
@export var intro_timeline: DialogicTimeline
@export var hydrogen_in_progress_timeline: DialogicTimeline
@export var hydrogen_report_timeline: DialogicTimeline
@export var default_timeline: DialogicTimeline

#Quest Vars
@export var quests: Array[Quest] = []
var quest_manager: Node = null

func _physics_process(delta: float) -> void:
	$AnimatedSprite2D.play("idle")

func start_dialouge():

	global.player.can_move = false

	var timeline := get_current_timeline()
	print("Timeline selected: ", timeline)

	if timeline == null:
		push_warning("%s has no Dialogue Timeline assigned!" % npc_name)
		global.player.can_move = true
		return

	Dialogic.start(timeline)
	Dialogic.timeline_ended.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)

func get_current_timeline() -> DialogicTimeline:

	var quest := QuestManager.get_quest("quest_hydrogen_001")
	
	print("Quest = ", quest)

	# Never accepted
	if quest == null:
		return tutorial

	# Finished quest
	if quest.state == "completed":
		return default_timeline

	var observe = quest.objectives[0]
	var report = quest.objectives[1]

	# Still observing Hydrogen
	if !observe.is_completed:
		return hydrogen_in_progress_timeline

	# Ready to report
	if observe.is_completed and !report.is_completed:
		return hydrogen_report_timeline

	return default_timeline
	print("Returning default (fallback)")
	return default_timeline

func _on_dialogue_finished():
	pass

func _ready() -> void:

	#Get Quest Manager
	quest_manager = QuestManager
	print("NPC Ready. Quest Loaded: ", quests.size())
	$Highlight.visible = false

func offer_quest(quest_id: String):
	print("Attempting to offer quest:", quest_id)

	for quest in quests:
		if quest.quest_id == quest_id:

			if QuestManager.get_quest(quest_id):
				print("Player already has this quest.")
				return

			var runtime_quest = quest.duplicate(true)
			runtime_quest.state = "in_progress"

			QuestManager.add_quest(runtime_quest)
			return

	print("Quest not found")

func npc():
	pass

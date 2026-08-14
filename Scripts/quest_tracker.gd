extends NinePatchRect
class_name Tracker

const font = preload("res://Assets/Font/NicoPaint-Regular.woff")

@onready var title = $Details/Title
@onready var objectives = $Objectives

func _ready():
	print("Tracker ready")
	visible = false
	
	QuestManager.quest_updated.connect(_on_quest_updated)
	QuestManager.objective_updated.connect(_on_objective_updated)
	
	if QuestManager.tracked_quest:
		update_quest_tracker(QuestManager.tracked_quest)


#Update tracker UI
func update_quest_tracker(quest: Quest):
	# No tracked quest
	if quest == null:
		visible = false
		return

	# Quest is completed
	if quest.state == QuestState.Type.COMPLETED:
		visible = false
		return

	# Clear old objectives
	for child in objectives.get_children():
		child.queue_free()

	title.text = quest.quest_name

	var has_active_objective := false

	for objective in quest.objectives:
		if !objective.is_active:
			continue

		has_active_objective = true

		var label := Label.new()

		if objective.required_amount > 0:
			label.text = "%s (%d/%d)" % [
				objective.description,
				objective.current_amount,
				objective.required_amount
			]
		else:
			label.text = objective.description

		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 16)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if objective.is_completed:
			label.add_theme_color_override("font_color", Color(0.4, 0.48, 0.139))
		else:
			label.add_theme_color_override("font_color", Color(0.471, 0.353, 0.235))

		objectives.add_child(label)

	# Hide if nothing is left to track
	visible = has_active_objective


# Update tracker if quest is complete
func _on_quest_updated(quest_id: String):
	if QuestManager.tracked_quest \
	and QuestManager.tracked_quest.quest_id == quest_id:
		update_quest_tracker(QuestManager.tracked_quest)

# Update tracker if objective is complete
func _on_objective_updated(quest_id: String, objective_id: String):
	if QuestManager.tracked_quest \
	and QuestManager.tracked_quest.quest_id == quest_id:
		update_quest_tracker(QuestManager.tracked_quest)

func show_tracker(quest: Quest):
	update_quest_tracker(quest)

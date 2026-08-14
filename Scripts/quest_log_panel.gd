extends Panel

@onready var quest_list = $LeftPage/VBoxContainer/QuestList
@onready var quest_title = $"RightPage/VBoxContainer/Quest Title"
@onready var quest_description = $"RightPage/VBoxContainer/Quest Description"
@onready var quest_objectives = $"RightPage/VBoxContainer/Quest Objectives"
@onready var quest_rewards = $"RightPage/VBoxContainer/Quest Rewards"

var quest_manager

func _ready() -> void:
	hide()
	clear_quest_details()

	quest_manager = QuestManager
	quest_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	quest_manager.quest_updated.connect(_on_quest_updated)
	quest_manager.objective_updated.connect(_on_objectives_updated)
	quest_manager.quest_list_updated.connect(update_quest_list)

func show_hide_log() -> void:
	visible = !visible
	if visible:
		update_quest_list()
		if QuestManager.tracked_quest:
			_on_quest_selected(QuestManager.tracked_quest)

func update_quest_list() -> void:
	for child in quest_list.get_children():
		child.queue_free()

	var active_quests = quest_manager.get_active_quests()
	if active_quests.size() == 0:
		clear_quest_details()
		QuestManager.set_tracked_quest(null)
		return

	for quest in active_quests:
		var button = Button.new()
		button.add_theme_font_size_override("font_size", 20)
		button.text = quest.quest_name
		button.pressed.connect(_on_quest_selected.bind(quest))
		quest_list.add_child(button)

func _on_quest_selected(quest: Quest) -> void:
	QuestManager.set_tracked_quest(quest)

	quest_title.text = quest.quest_name
	quest_description.text = quest.quest_description
	
	var tracker = get_tree().current_scene.get_node("HUD/QuestTracker")
	tracker.show_tracker(quest)

	for child in quest_objectives.get_children():
		child.queue_free()

	for objective in quest.objectives:
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 20)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if objective.required_amount > 0:
			label.text = "%s (%d/%d)" % [
				objective.description,
				objective.current_amount,
				objective.required_amount
			]
		else:
			label.text = objective.description

		if objective.is_completed:
			label.add_theme_color_override("font_color", Color.GREEN)
		else:
			label.add_theme_color_override("font_color", Color.RED)

		quest_objectives.add_child(label)

	for child in quest_rewards.get_children():
		child.queue_free()

	for reward in quest.rewards:
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.8, 0.689, 0.166, 1.0))
		label.text = "Rewards: %s: %s" % [reward.reward_type.capitalize(), str(reward.reward_amount)]
		quest_rewards.add_child(label)

func clear_quest_details() -> void:
	quest_title.text = ""
	quest_description.text = ""

	for child in quest_objectives.get_children():
		child.queue_free()

	for child in quest_rewards.get_children():
		child.queue_free()

func _on_quest_updated(quest_id: String) -> void:
	if QuestManager.tracked_quest and QuestManager.tracked_quest.quest_id == quest_id:
		_on_quest_selected(QuestManager.tracked_quest)
	else:
		update_quest_list()
		QuestManager.set_tracked_quest(null)

func _on_objectives_updated(quest_id: String, objectives_id: String) -> void:
	if QuestManager.tracked_quest and QuestManager.tracked_quest.quest_id == quest_id:
		_on_quest_selected(QuestManager.tracked_quest)
	else:
		clear_quest_details()
		QuestManager.set_tracked_quest(null)

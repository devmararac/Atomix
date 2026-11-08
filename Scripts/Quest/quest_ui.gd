extends Control

@onready var panel = $CanvasLayer/Panel
@onready var quest_list = $CanvasLayer/Panel/LeftPage/VBoxContainer/QuestList
@onready var quest_title = $"CanvasLayer/Panel/RightPage/VBoxContainer/Quest Title"
@onready var quest_description = $"CanvasLayer/Panel/RightPage/VBoxContainer/Quest Description"
@onready var quest_objectives = $"CanvasLayer/Panel/RightPage/VBoxContainer/Quest Objectives"
@onready var quest_rewards = $"CanvasLayer/Panel/RightPage/VBoxContainer/Quest Rewards"

var quest_manager

func _ready() -> void:
	panel.visible = false
	clear_quest_details()
	#Quest Manager/UI Connection
	quest_manager = QuestManager
	quest_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_manager.quest_updated.connect(_on_quest_updated)
	quest_manager.objective_updated.connect(_on_objectives_updated)

#Show/Hide Quest Log
func show_hide_log():
	panel.visible = !panel.visible
	update_quest_list()
	if QuestManager.tracked_quest:
		_on_quest_selected(QuestManager.tracked_quest)

#Populate Quest List
func update_quest_list():
	
	#Remove all items
	for child in quest_list.get_children():
		quest_list.remove_child(child)

	#Populate with new items
	var active_quests = quest_manager.get_active_quests()
	if active_quests.size() == 0:
		clear_quest_details()
		QuestManager.set_tracked_quest(null)
	else:
		for quest in active_quests:
			var button = Button.new()
			button.add_theme_font_size_override("font_size", 20)
			button.text = quest.quest_name
			button.pressed.connect(_on_quest_selected.bind(quest))
			quest_list.add_child(button)

#On Quest Selected
func _on_quest_selected(quest: Quest):
	QuestManager.set_tracked_quest(quest)
	#Populate details
	quest_title.text = quest.quest_name
	quest_description.text = quest.quest_description
	
	#Populate objectives 
	for child in quest_objectives.get_children():
		quest_objectives.remove_child(child)
	
	for objective in quest.objectives:
		var label = Label.new()

		label.add_theme_font_size_override("font_size", 20)

		# NEW
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if objective.required_quantity > 0:
			label.text = "%s (%d/%d)" % [
				objective.description,
				objective.collected_quantity,
				objective.required_quantity
			]
		else:
			label.text = objective.description

		if objective.is_completed:
			label.add_theme_color_override("font_color", Color.GREEN)
		else:
			label.add_theme_color_override("font_color", Color.RED)

		quest_objectives.add_child(label)
		
	#Populate rewards
	for child in quest_rewards.get_children():
		quest_rewards.remove_child(child)
	
	for reward in quest.rewards:
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.8, 0.689, 0.166, 1.0))
		label.text = "Rewards: " + reward.reward_type.capitalize() + ": " + str(reward.reward_amount)
		quest_rewards.add_child(label)


#Trigger to clear quest details
func clear_quest_details():
	quest_title.text = ""
	quest_description.text = ""
	
	for child in quest_objectives.get_children():
		quest_objectives.remove_child(child)
		
	for child in quest_rewards.get_children():
		quest_rewards.remove_child(child)

#Trigger to update quest list
func _on_quest_updated(quest_id: String):
	if QuestManager.tracked_quest and QuestManager.tracked_quest.quest_id == quest_id:
		_on_quest_selected(QuestManager.tracked_quest)
	else: 
		update_quest_list()
		QuestManager.set_tracked_quest(null)

#Trigger to update quest details
func _on_objectives_updated(quest_id: String, objectives_id: String):
	if QuestManager.tracked_quest and QuestManager.tracked_quest.quest_id == quest_id:
		_on_quest_selected(QuestManager.tracked_quest)
	else: 
		clear_quest_details()
		QuestManager.set_tracked_quest(null)


func _on_close_button_pressed() -> void:
	show_hide_log()

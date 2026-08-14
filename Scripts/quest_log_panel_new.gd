extends Control

const QUEST_SLOT = preload("res://Scenes/UI/quest_slot.tscn")

@onready var quest_list: VBoxContainer = $"MainBG/BookBG/Left Page/ScrollContainer/QuestList"
@onready var quest_title: Label = $"MainBG/BookBG/Right Page/Title"
@onready var no_quest_label: Label = $"MainBG/BookBG/Left Page/No Quests"

@onready var objective: Label = $"MainBG/BookBG/Right Page/Objective Panel/Objective"
@onready var quest_description: RichTextLabel = $"MainBG/BookBG/Right Page/Description"
@onready var quest_reward_grid: GridContainer = $"MainBG/BookBG/Right Page/Rewards/GridContainer"

var quest_manager


func _ready() -> void:
	print("Quest Log Readya")
	quest_manager = QuestManager

	quest_manager.quest_updated.connect(_on_quest_updated)
	quest_manager.objective_updated.connect(_on_objectives_updated)
	quest_manager.quest_list_updated.connect(update_quest_list)

	no_quest_label.visible = true

	# Load quests that already exist
	update_quest_list()

	if QuestManager.tracked_quest:
		_on_quest_selected(QuestManager.tracked_quest)

func show_hide_log() -> void:
	visible = !visible

	if visible:
		update_quest_list()

		if QuestManager.tracked_quest:
			_on_quest_selected(QuestManager.tracked_quest)


# ============================================================
# QUEST LIST
# ============================================================

func update_quest_list() -> void:

	print("=== QUEST LOG UPDATE ===")
	print("Quest Log visible: ", visible)
	print("Quest List node: ", quest_list)

	var active_quests = quest_manager.get_active_quests()

	print("Active quest count: ", active_quests.size())

	for quest in active_quests:
		print("Quest found: ", quest.quest_id, " | ", quest.quest_name)

	for child in quest_list.get_children():
		child.queue_free()

	if active_quests.size() == 0:
		no_quest_label.visible = true
		return

	no_quest_label.visible = false

	for quest in active_quests:
		print("Creating slot for: ", quest.quest_name)

		var slot = QUEST_SLOT.instantiate()

		print("Slot instantiated: ", slot)

		quest_list.add_child(slot)

		print("Slot added. Children: ", quest_list.get_child_count())

		slot.set_quest(quest)
		slot.quest_clicked.connect(_on_quest_selected)

func _on_quest_selected(quest: Quest) -> void:
	if quest == null:
		return

	QuestManager.set_tracked_quest(quest)

	# --------------------------------------------------------
	# Quest title
	# --------------------------------------------------------

	quest_title.text = quest.quest_name

	# --------------------------------------------------------
	# Quest description
	# --------------------------------------------------------

	quest_description.text = quest.quest_description

	# --------------------------------------------------------
	# Current objective
	# --------------------------------------------------------

	var current_objective = quest.get_active_objective()

	if current_objective != null:

		if current_objective.required_amount > 0:
			objective.text = "%s (%d/%d)" % [
				current_objective.description,
				current_objective.current_amount,
				current_objective.required_amount
			]
		else:
			objective.text = current_objective.description

	else:
		objective.text = "Quest complete!"


	# --------------------------------------------------------
	# Rewards
	# --------------------------------------------------------

	update_rewards(quest)


# ============================================================
# REWARDS
# ============================================================

func update_rewards(quest: Quest) -> void:

	# Remove old reward entries.
	for child in quest_reward_grid.get_children():
		child.queue_free()

	# Add the rewards for this quest.
	for reward in quest.rewards:

		var label := Label.new()

		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override(
			"font_color",
			Color(0.8, 0.689, 0.166, 1.0)
		)

		label.text = "%s: %s" % [
			reward.reward_type.capitalize(),
			str(reward.reward_amount)
		]

		quest_reward_grid.add_child(label)


# ============================================================
# CLEAR DETAILS
# ============================================================

func clear_quest_details() -> void:

	quest_title.text = ""
	objective.text = ""
	quest_description.text = ""

	for child in quest_reward_grid.get_children():
		child.queue_free()


# ============================================================
# QUEST UPDATED
# ============================================================

func _on_quest_updated(quest_id: String) -> void:

	if QuestManager.tracked_quest \
	and QuestManager.tracked_quest.quest_id == quest_id:

		_on_quest_selected(QuestManager.tracked_quest)

	else:
		update_quest_list()


# ============================================================
# OBJECTIVE UPDATED
# ============================================================

func _on_objectives_updated(
	quest_id: String,
	objectives_id: String
) -> void:

	if QuestManager.tracked_quest \
	and QuestManager.tracked_quest.quest_id == quest_id:

		_on_quest_selected(QuestManager.tracked_quest)

	else:
		update_quest_list()

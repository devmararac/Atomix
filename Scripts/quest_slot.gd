extends TextureButton

signal quest_clicked(quest: Quest)

@onready var quest_name: Label = $QuestName

var quest: Quest


func set_quest(new_quest: Quest) -> void:
	quest = new_quest
	quest_name.text = quest.quest_name


func _pressed() -> void:
	if quest == null:
		return

	quest_clicked.emit(quest)

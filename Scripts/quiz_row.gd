extends PanelContainer

var quiz_data: Dictionary = {}


@onready var quiz_title: Label = $MarginContainer/VBoxContainer/QuizTitle
@onready var quiz_info: Label = $MarginContainer/VBoxContainer/QuizInfo
@onready var edit_button: Button = $MarginContainer/VBoxContainer/BottomRow/EditButton
@onready var delete_button: Button = $MarginContainer/VBoxContainer/BottomRow/DeleteButton


func _ready() -> void:
	edit_button.pressed.connect(_on_edit_pressed)
	delete_button.pressed.connect(_on_delete_pressed)


func setup_quiz(data: Dictionary) -> void:
	quiz_data = data

	quiz_title.text = data.get("title", "Untitled Quiz")

	var question_count: int = data.get("question_count", 0)
	var quiz_type: String = data.get("type", "Unknown")

	quiz_info.text = "%d Questions • %s" % [question_count, quiz_type]


func _on_edit_pressed() -> void:
	print("Edit quiz: ", quiz_data)


func _on_delete_pressed() -> void:
	print("Delete quiz: ", quiz_data)

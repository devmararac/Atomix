extends PanelContainer

signal assign_requested(quiz_data: Dictionary)
signal view_requested(quiz_data: Dictionary)
signal edit_requested(quiz_data: Dictionary)
signal delete_requested(quiz_data: Dictionary)

@onready var quiz_title: Label = \
	$MarginContainer/VBoxContainer/QuizTitle

@onready var quiz_info: Label = \
	$MarginContainer/VBoxContainer/QuizInfo

# These node names match your current quiz_card.tscn.
# Their visible button text is Assign, View, Edit, and Delete.
@onready var assign_button: Button = \
	$MarginContainer/VBoxContainer/HBoxContainer/ViewButton

@onready var view_button: Button = \
	$MarginContainer/VBoxContainer/HBoxContainer/ViewButton2

@onready var edit_button: Button = \
	$MarginContainer/VBoxContainer/HBoxContainer/ViewButton3

@onready var delete_button: Button = \
	$MarginContainer/VBoxContainer/HBoxContainer/ViewButton4

var quiz_data: Dictionary = {}


func _ready() -> void:
	assign_button.pressed.connect(_on_assign_pressed)
	view_button.pressed.connect(_on_view_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	delete_button.pressed.connect(_on_delete_pressed)


func setup_quiz(data: Dictionary) -> void:
	quiz_data = data.duplicate(true)

	quiz_title.text = str(
		quiz_data.get("title", "Untitled Quiz")
	)

	var question_count := int(
		quiz_data.get("question_count", 0)
	)

	var quiz_type := str(
		quiz_data.get("quiz_type", "Unknown")
	).replace("_", " ").capitalize()

	var question_text := "Questions"
	if question_count == 1:
		question_text = "Question"

	quiz_info.text = "%d %s • %s" % [
		question_count,
		question_text,
		quiz_type
	]


func _on_assign_pressed() -> void:
	print("[QuizCard] Assign pressed: ", quiz_data.get("title", "Untitled Quiz"))
	assign_requested.emit(quiz_data)


func _on_view_pressed() -> void:
	print("[QuizCard] View pressed: ", quiz_data.get("title", "Untitled Quiz"))
	view_requested.emit(quiz_data)


func _on_edit_pressed() -> void:
	print("[QuizCard] Edit pressed: ", quiz_data.get("title", "Untitled Quiz"))
	edit_requested.emit(quiz_data)


func _on_delete_pressed() -> void:
	print("[QuizCard] Delete pressed: ", quiz_data.get("title", "Untitled Quiz"))
	delete_requested.emit(quiz_data)

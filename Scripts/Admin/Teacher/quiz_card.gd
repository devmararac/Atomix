extends PanelContainer

signal quiz_selected(quiz_data: Dictionary)

@onready var quiz_title: Label = \
	$MarginContainer/VBoxContainer/QuizTitle

@onready var quiz_info: Label = \
	$MarginContainer/VBoxContainer/QuizInfo

@onready var view_button: Button = \
	$MarginContainer/VBoxContainer/ViewButton


var quiz_data: Dictionary = {}


func _ready() -> void:

	if not view_button.pressed.is_connected(
		_on_view_button_pressed
	):

		view_button.pressed.connect(
			_on_view_button_pressed
	)


func setup_quiz(data: Dictionary) -> void:

	quiz_data = data

	var title := str(
		data.get(
			"title",
			"Untitled Quiz"
		)
	)

	var question_count := int(
		data.get(
			"question_count",
			0
		)
	)

	var quiz_type := str(
		data.get(
			"quiz_type",
			"Unknown"
		)
	)


	quiz_title.text = title


	# --------------------------------------------------------
	# Format quiz type
	# --------------------------------------------------------

	var formatted_type := quiz_type.replace(
		"_",
		" "
	).capitalize()


	# --------------------------------------------------------
	# Format question count
	# --------------------------------------------------------

	var question_text := "Questions"

	if question_count == 1:
		question_text = "Question"


	quiz_info.text = (
		str(question_count)
		+ " "
		+ question_text
		+ " • "
		+ formatted_type
	)


func _on_view_button_pressed() -> void:

	print(
		"[QuizCard] View quiz pressed: ",
		quiz_data.get(
			"title",
			"Untitled Quiz"
		)
	)

	quiz_selected.emit(
		quiz_data
	)

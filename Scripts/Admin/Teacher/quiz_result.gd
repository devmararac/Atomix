extends Panel

@onready var name_label: Label = $HBoxContainer/Name
@onready var score_label: Label = $HBoxContainer/Score
@onready var percentage_label: Label = $HBoxContainer/Percentage


func setup_result(
	student_name: String,
	score: int,
	total_questions: int,
	percentage: float
) -> void:
	name_label.text = student_name
	score_label.text = str(score) + " / " + str(total_questions)
	percentage_label.text = "%.1f%%" % percentage


func setup_not_taken(student_name: String) -> void:
	name_label.text = student_name
	score_label.text = "Not Taken"
	percentage_label.text = "--"

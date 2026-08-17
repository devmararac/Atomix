extends Control

var student_data: Dictionary = {}


@onready var back_button: Button = $PageBackground/MarginContainer/VBoxContainer/Header/BackButton

@onready var student_name_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/StudentName
@onready var email_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/Email
@onready var status_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/Status
@onready var level_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/Level
@onready var rank_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/Rank
@onready var last_active_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/LastActive

@onready var elements_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ProgressPanel/MarginContainer/VBoxContainer/ElementsLabel
@onready var progress_bar: ProgressBar = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ProgressPanel/MarginContainer/VBoxContainer/ProgressBar
@onready var progress_text: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ProgressPanel/MarginContainer/VBoxContainer/ProgressText

@onready var modules_completed_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ModulesPanel/MarginContainer/VBoxContainer/ModulesCompleted
@onready var modules_progress: ProgressBar = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ModulesPanel/MarginContainer/VBoxContainer/ModulesProgress
@onready var modules_progress_text: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ModulesPanel/MarginContainer/VBoxContainer/ModulesProgressText

@onready var attempts_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/QuizzesPanel/MarginContainer/VBoxContainer/Attempts
@onready var average_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/QuizzesPanel/MarginContainer/VBoxContainer/Average

@onready var activity_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ActivityPanel/MarginContainer/VBoxContainer/Activity


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

	if not student_data.is_empty():
		display_student()


func set_student_data(data: Dictionary) -> void:
	student_data = data

	if is_node_ready():
		display_student()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(
		"res://Scenes/Admin/students.tscn"
	)


func display_student() -> void:
	# Basic information
	student_name_label.text = str(
		student_data.get("name", "Unknown Student")
	)

	email_label.text = str(
		student_data.get("email", "No email")
	)

	status_label.text = "● Active"

	level_label.text = str(
		student_data.get("level", 1)
	)

	rank_label.text = str(
		student_data.get("rank", "-")
	)

	last_active_label.text = str(
		student_data.get("last_active", "Recently")
	)

	# Element progress
	var progress_value = student_data.get("progress", {})

	if progress_value is Dictionary:
		var progress: Dictionary = progress_value

		var collected: int = int(
			progress.get("elements_collected", 0)
		)

		var total: int = int(
			progress.get("elements_total", 118)
		)

		if total <= 0:
			total = 118

		var percentage: float = clamp(
			float(collected) / float(total) * 100.0,
			0.0,
			100.0
		)

		elements_label.text = "Elements Collected: %d / %d" % [
			collected,
			total
		]

		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = percentage

		progress_text.text = "%d%%" % round(percentage)

	# Modules
	var modules_value = student_data.get("modules", {})

	if modules_value is Dictionary:
		var modules: Dictionary = modules_value

		var completed: int = int(
			modules.get("completed", 0)
		)

		var total_modules: int = int(
			modules.get("total", 8)
		)

		if total_modules <= 0:
			total_modules = 8

		var module_percentage: float = clamp(
			float(completed) / float(total_modules) * 100.0,
			0.0,
			100.0
		)

		modules_completed_label.text = "Modules Completed: %d / %d" % [
			completed,
			total_modules
		]

		modules_progress.min_value = 0
		modules_progress.max_value = 100
		modules_progress.value = module_percentage

		modules_progress_text.text = "%d%%" % round(
			module_percentage
		)

	# Quizzes
	var quiz_value = student_data.get("quizzes", {})

	if quiz_value is Dictionary:
		var quizzes: Dictionary = quiz_value

		var attempts: int = int(
			quizzes.get("attempts", 0)
		)

		var average: float = float(
			quizzes.get("average", 0.0)
		)

		attempts_label.text = "Attempts: %d" % attempts

		average_label.text = "Average Score: %d%%" % round(
			average
		)

	# Recent activity
	var activity_value = student_data.get(
		"recent_activity",
		"No recent activity."
	)

	if activity_value is Array:
		if activity_value.is_empty():
			activity_label.text = "No recent activity."
		else:
			var activity_text := ""

			for item in activity_value:
				activity_text += str(item) + "\n"

			activity_label.text = activity_text
	else:
		activity_label.text = str(activity_value)

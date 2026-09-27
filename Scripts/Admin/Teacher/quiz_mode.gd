extends Control


# ============================================================
# SCENES
# ============================================================

const QUIZ_MANAGEMENT = preload(
	"res://Scenes/Admin/Teacher/quiz_management.tscn"
)

const QUIZ_CHOICES = preload(
	"res://Scenes/Admin/Teacher/quiz_choises.tscn"
)

const GROUP_QUIZ = preload(
	"res://Scenes/Admin/Teacher/group_quiz.tscn"
)

# ============================================================
# SIGNALS
# ============================================================

signal back_pressed
signal solo_quiz_selected
signal group_quiz_selected
signal create_quiz_selected


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var back_button: TextureButton = \
	$ModePanel/MarginContainer/VBoxContainer/Header/BackButton

@onready var solo_quiz: TextureButton = \
	$ModePanel/MarginContainer/VBoxContainer/ModeCards/SoloQuiz

@onready var group_quiz: TextureButton = \
	$ModePanel/MarginContainer/VBoxContainer/ModeCards/GroupQuiz

@onready var create_quiz: TextureButton = \
	$ModePanel/MarginContainer/VBoxContainer/ModeCards/CreateQuiz


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	back_button.pressed.connect(
		_on_back_pressed
	)

	solo_quiz.pressed.connect(
		_on_solo_quiz_pressed
	)

	group_quiz.pressed.connect(
		_on_group_quiz_pressed
	)

	create_quiz.pressed.connect(
		_on_create_quiz_pressed
	)


# ============================================================
# BACK
# ============================================================

func _on_back_pressed() -> void:

	back_pressed.emit()


# ============================================================
# SOLO QUIZ
# ============================================================

func _on_solo_quiz_pressed() -> void:

	print(
		"[QuizMode] Solo Quiz selected."
	)

	solo_quiz_selected.emit()


	var dashboard := \
		get_parent().get_parent()


	if dashboard.has_method("show_page"):

		dashboard.show_page(
			QUIZ_MANAGEMENT
		)

	else:

		push_error(
			"[QuizMode] Dashboard not found."
		)


# ============================================================
# GROUP QUIZ
# ============================================================

func _on_group_quiz_pressed() -> void:

	print(
		"[QuizMode] Group Quiz selected."
	)

	group_quiz_selected.emit()

	var dashboard := \
		get_parent().get_parent()

	if dashboard.has_method("show_page"):

		dashboard.show_page(
			GROUP_QUIZ
		)

	else:

		push_error(
			"[QuizMode] Dashboard not found."
		)
# ============================================================
# CREATE QUIZ
# ============================================================

func _on_create_quiz_pressed() -> void:
	print("[QuizMode] Create Quiz selected.")

	create_quiz_selected.emit()

	var dashboard := get_parent().get_parent()

	if not is_instance_valid(dashboard):
		push_error("[QuizMode] Dashboard not found.")
		return

	var choices := QUIZ_CHOICES.instantiate()

	if choices == null:
		push_error("[QuizMode] Failed to instantiate Quiz Choices.")
		return

	dashboard.add_child(choices)

	var panel := choices.get_child(0) as Control

	if panel == null:
		push_error("[QuizMode] Quiz Choices Control not found.")
		return

	# Size of the sliding panel
	panel.size = Vector2(600, 720)

	# Start completely outside the left side
	panel.position = Vector2(-600, 0)

	# Smoothly slide into view
	var tween := create_tween()

	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		panel,
		"position:x",
		0.0,
		0.35
	)

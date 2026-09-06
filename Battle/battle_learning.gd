extends Control

signal learning_finished


@onready var title_label: Label = $Panel/VBoxContainer3/Title
@onready var lesson_label: Label = $Panel/VBoxContainer3/Lesson

@onready var question_label: Label = $Panel/VBoxContainer3/Question
@onready var feedback_label: Label = $Panel/VBoxContainer2/Feedback
@onready var continue_button: TextureButton = $Panel/VBoxContainer2/Continue

@onready var answer_1: TextureButton = $Panel/VBoxContainer2/Control/Answer
@onready var answer_2: TextureButton = $Panel/VBoxContainer2/Control/Answer2
@onready var answer_3: TextureButton = $Panel/VBoxContainer2/Control/Answer3
@onready var answer_4: TextureButton = $Panel/VBoxContainer2/Control/Answer4

@onready var answer_1_label: Label = $Panel/VBoxContainer2/Control/Answer/Label
@onready var answer_2_label: Label = $Panel/VBoxContainer2/Control/Answer2/Label
@onready var answer_3_label: Label = $Panel/VBoxContainer2/Control/Answer3/Label
@onready var answer_4_label: Label = $Panel/VBoxContainer2/Control/Answer4/Label


const CORRECT_ANSWER := 0

var answered := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	title_label.text = "BATTLE LEARNING"

	lesson_label.text = "During battle, your Atomon can gain Electron Energy.\n\nWhen an electron absorbs energy, it can move to a higher energy level. This produces an excited state."

	question_label.text = "What term describes an atom whose electron has absorbed energy and moved to a higher energy level?"

	answer_1_label.text = "Excited state"
	answer_2_label.text = "Ground state"
	answer_3_label.text = "Ion"
	answer_4_label.text = "Isotope"

	feedback_label.text = ""

	continue_button.disabled = true

	answer_1.disabled = false
	answer_2.disabled = false
	answer_3.disabled = false
	answer_4.disabled = false

	answer_1.pressed.connect(_on_answer_1_pressed)
	answer_2.pressed.connect(_on_answer_2_pressed)
	answer_3.pressed.connect(_on_answer_3_pressed)
	answer_4.pressed.connect(_on_answer_4_pressed)

	continue_button.pressed.connect(_on_continue_pressed)


func _on_answer_1_pressed() -> void:
	_answer_pressed(0)


func _on_answer_2_pressed() -> void:
	_answer_pressed(1)


func _on_answer_3_pressed() -> void:
	_answer_pressed(2)


func _on_answer_4_pressed() -> void:
	_answer_pressed(3)


func _answer_pressed(answer_index: int) -> void:
	if answered:
		return

	answered = true

	answer_1.disabled = true
	answer_2.disabled = true
	answer_3.disabled = true
	answer_4.disabled = true

	continue_button.disabled = false

	if answer_index == CORRECT_ANSWER:
		feedback_label.text = "Correct!\n\nAn excited state occurs when an electron absorbs energy and moves to a higher energy level."
	else:
		feedback_label.text = "Not quite.\n\nAn excited state occurs when an electron absorbs energy and moves to a higher energy level."


func _on_continue_pressed() -> void:
	learning_finished.emit()

extends Control

const DASHBOARD = preload("res://Scenes/Admin/dashboard.tscn")
const STUDENTS = preload("res://Scenes/Admin/students.tscn")
const QUIZ_MODE = preload("res://Scenes/Admin/quiz_management.tscn")

@onready var information_panel = $INFORMATIONPANEL
@onready var selector := $MenuPanel/ColorRect

var current_page: Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	selector.visible = false
	_on_dashboard_button_pressed()

func show_page(scene: PackedScene) -> void:
	var new_page = scene.instantiate()
	new_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	new_page.modulate.a = 0

	if current_page:
		var out = create_tween()
		out.tween_property(current_page, "modulate:a", 0.0, 0.08)
		await out.finished
		current_page.queue_free()

	current_page = new_page
	information_panel.add_child(current_page)

	var fade = create_tween()
	fade.tween_property(current_page, "modulate:a", 1.0, 0.08)

func move_selector(button: Control) -> void:
	selector.visible = true

	var target_y = button.position.y

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(selector, "position:y", target_y, 0.07)

func focus_button(button: Control) -> void:
	button.grab_focus()

func _on_close_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Cutscenes/classroom_cutscene.tscn")

func _on_dashboard_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/DashboardButton
	focus_button(button)
	move_selector($MenuPanel/VBoxContainer/DashboardButton)
	show_page(DASHBOARD)

func _on_students_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/StudentsButton
	focus_button(button)
	move_selector($MenuPanel/VBoxContainer/StudentsButton)
	show_page(STUDENTS)

func _on_quiz_mode_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/QuizModeButton
	focus_button(button)
	move_selector($MenuPanel/VBoxContainer/QuizModeButton)
	show_page(QUIZ_MODE)

extends Control

# Pages that can be displayed inside INFORMATIONPANEL.

const DASHBOARD = preload("res://Scenes/Admin/dashboard.tscn")
const TEACHERS = preload("res://Scenes/Admin/teacher_management.tscn")
const STUDENTS = preload("res://Scenes/Admin/students.tscn")
const QUIZ_MODE = preload("res://Scenes/Admin/quiz_management.tscn")

@onready var information_panel = $INFORMATIONPANEL
@onready var selector := $MenuPanel/ColorRect

var current_page: Control

func _ready() -> void:
	selector.visible = false

	# Automatically open Dashboard when Admin Dashboard loads.
	var dashboard_button: Control = $MenuPanel/VBoxContainer/DashboardButton

	focus_button(dashboard_button)
	move_selector(dashboard_button)
	show_page(DASHBOARD)


func show_page(scene: PackedScene) -> void:
	var new_page = scene.instantiate()


	new_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	new_page.modulate.a = 0

	# Remove the previous page after its fade-out.
	if current_page:
		var out = create_tween()
		out.tween_property(current_page, "modulate:a", 0.0, 0.08)
		await out.finished
		current_page.queue_free()

	# Store and display the new page.
	current_page = new_page
	information_panel.add_child(current_page)

	# Fade the new page in.
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
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

func _on_dashboard_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/DashboardButton


	focus_button(button)
	move_selector(button)
	show_page(DASHBOARD)


func _on_teachers_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/TeachersButton


	focus_button(button)
	move_selector(button)
	show_page(TEACHERS)


func _on_students_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/StudentsButton


	focus_button(button)
	move_selector(button)
	show_page(STUDENTS)


func _on_progress_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/ProgressButton


	focus_button(button)
	move_selector(button)


func _on_quiz_mode_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/QuizModeButton


	focus_button(button)
	move_selector(button)
	show_page(QUIZ_MODE)

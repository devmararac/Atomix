extends Control

const DASHBOARD = preload("res://Scenes/Admin/dashboard.tscn")
const STUDENTS = preload("res://Scenes/Admin/students.tscn")
const LESSONS = preload("res://Scenes/Admin/Teacher/lesson_management.tscn")
const QUIZ_MODE = preload("res://Scenes/Admin/Teacher/quiz_mode.tscn")
const SETTINGS = preload("res://Scenes/Admin/settings.tscn")

@onready var information_panel = $INFORMATIONPANEL
@onready var selector := $MenuPanel/ColorRect

var current_page: Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	selector.visible = false
	_on_dashboard_button_pressed()

func show_page(scene: PackedScene) -> void:
	print("========================================")
	print("[Dashboard] show_page()")
	print("[Dashboard] Scene: ", scene)

	if scene == null:
		push_error("[Dashboard] Scene is NULL.")
		return

	print("[Dashboard] Resource path: ", scene.resource_path)

	var new_page = scene.instantiate()

	if new_page == null:
		push_error(
			"[Dashboard] instantiate() returned NULL!"
		)
		return

	print(
		"[Dashboard] Successfully instantiated: ",
		new_page.name
	)

	if not new_page is Control:
		push_error(
			"[Dashboard] Root is not Control."
		)
		new_page.queue_free()
		return

	var page := new_page as Control

	page.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)

	page.modulate.a = 0.0

	if current_page and is_instance_valid(current_page):
		current_page.queue_free()

	current_page = page
	information_panel.add_child(current_page)

	page.modulate.a = 1.0

	print("[Dashboard] Page displayed: ", page.name)
	print("========================================")

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


func _on_lesson_button_pressed() -> void:
	
	var button = $MenuPanel/VBoxContainer/LessonButton
	focus_button(button)
	move_selector(
		$MenuPanel/VBoxContainer/LessonButton
	)
	show_page(LESSONS)


func _on_settings_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/Settings
	focus_button(button)
	move_selector(
		$MenuPanel/VBoxContainer/Settings
	)
	show_page(SETTINGS)

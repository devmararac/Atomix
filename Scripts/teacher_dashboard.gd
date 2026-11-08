extends Control

const DASHBOARD = preload("res://Scenes/Admin/Teacher/dashboard_t.tscn")
const STUDENTS = preload("res://Scenes/Admin/Teacher/students_t.tscn")
const LESSONS = preload("res://Scenes/Admin/Teacher/lesson_management.tscn")
const QUIZ_MODE = preload("res://Scenes/Admin/Teacher/quiz_management.tscn")
const SETTINGS = preload("res://Scenes/Admin/settings.tscn")
const NEED_ATTECNTION = preload("res://Scenes/Admin/needs_attention.tscn")

@onready var information_panel = $INFORMATIONPANEL
@onready var selector := $MenuPanel/ColorRect

var current_page: Control
var is_switching_page: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	selector.visible = false
	var dashboard_button: Control = $MenuPanel/VBoxContainer/DashboardButton

	focus_button(dashboard_button)
	await move_selector(dashboard_button)
	show_page(DASHBOARD)
	
func show_page(scene: PackedScene) -> void:
	# Ignore repeated clicks while a page transition is running.
	if is_switching_page:
		return

	# Avoid reloading the same page when its button is clicked again.
	if current_page != null:
		if current_page.scene_file_path == scene.resource_path:
			return

	is_switching_page = true

	# Fade out and remove the current page.
	if is_instance_valid(current_page):
		var old_page := current_page
		var fade_out := create_tween()
		fade_out.tween_property(old_page, "modulate:a", 0.0, 0.08)
		await fade_out.finished

		if is_instance_valid(old_page):
			old_page.queue_free()

		current_page = null

	# Create the selected page only after the old page is removed.
	var new_page := scene.instantiate() as Control

	if new_page == null:
		push_error("The selected page is not a Control scene.")
		is_switching_page = false
		return

	new_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	new_page.modulate.a = 0.0

	current_page = new_page
	information_panel.add_child(new_page)

	# Fade in the new page.
	var fade_in := create_tween()
	fade_in.tween_property(new_page, "modulate:a", 1.0, 0.08)
	await fade_in.finished

	is_switching_page = false

func move_selector(button: Control) -> void:
	await get_tree().process_frame

	if not is_instance_valid(button):
		return

	selector.visible = true

	# Get the center of the selected button in global coordinates.
	var button_rect: Rect2 = button.get_global_rect()
	var target_y: float = button_rect.get_center().y - (selector.size.y / 2.0)

	# Animate the selector using global coordinates.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		selector,
		"global_position:y",
		target_y,
		0.12
	)


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


func _on_needs_attention_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/NeedsAttention
	focus_button(button)
	move_selector($MenuPanel/VBoxContainer/NeedsAttention)
	show_page(NEED_ATTECNTION)


func _on_logout_button_pressed() -> void:
	AuthManager.logout()

	await get_tree().create_timer(0.2).timeout

	get_tree().change_scene_to_file(
		"res://Scenes/UI/MainMenu.tscn"
	)

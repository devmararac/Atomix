extends Control

# Pages that can be displayed inside INFORMATIONPANEL.

const DASHBOARD = preload("res://Scenes/Admin/dashboard.tscn")
const TEACHERS = preload("res://Scenes/Admin/HeadTeacher/teacher_management.tscn")
const STUDENTS = preload("res://Scenes/Admin/HeadTeacher/students_ht.tscn")
const SETTINGS = preload("res://Scenes/Admin/admin_settings.tscn")
const SECTION = preload("res://Scenes/Admin/HeadTeacher/school_year_sections.tscn")
const NEED_ATTECNTION = preload("res://Scenes/Admin/needs_attention.tscn")


@onready var information_panel = $INFORMATIONPANEL
@onready var selector := $MenuPanel/ColorRect

var current_page: Control
var is_switching_page: bool = false

const QUIZ_MODE = preload("res://Scenes/Admin/Teacher/quiz_management.tscn")

func _ready() -> void:
	selector.visible = false

	await SchoolYearManager.ensure_due_student_archives()

	if AuthManager.account_setup_required:
		print("[Admin Dashboard] Account setup required. Opening Settings.")

		var settings_button: Control = $MenuPanel/VBoxContainer/SettingsButton

		focus_button(settings_button)
		await move_selector(settings_button)
		show_page(SETTINGS)
	else:
		var dashboard_button: Control = $MenuPanel/VBoxContainer/DashboardButton

		focus_button(dashboard_button)
		await move_selector(dashboard_button)
		show_page(DASHBOARD)

func show_page(scene: PackedScene) -> void:
	

		# Prevent access to other pages until account setup is complete.
	if AuthManager.account_setup_required:
		if scene.resource_path != SETTINGS.resource_path:
			print("[Admin Dashboard] Access blocked. Complete account setup first.")
			_notify_setup_required()
			return
			
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


func _notify_setup_required() -> void:
	if is_instance_valid(current_page):
		if current_page.has_method("show_setup_required_message"):
			current_page.show_setup_required_message()

func move_selector(button: Control) -> void:

	if AuthManager.account_setup_required:
		if button != $MenuPanel/VBoxContainer/SettingsButton:
			print("[Admin Dashboard] Navigation blocked. Finish setting up your account first.")
			_notify_setup_required()
			return

	await get_tree().process_frame

	if not is_instance_valid(button):
		return

	selector.visible = true

	var button_rect: Rect2 = button.get_global_rect()
	var target_y: float = button_rect.get_center().y - (selector.size.y / 2.0)

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

	if AuthManager.account_setup_required:
		if button != $MenuPanel/VBoxContainer/SettingsButton:
			print("[Admin Dashboard] Navigation blocked. Account setup is required.")
			_notify_setup_required()
			return

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



# --- Merged from GroupMate ---
func _on_progress_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/ProgressButton


	focus_button(button)
	move_selector(button)


# --- Merged from GroupMate ---
func _on_quiz_mode_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/QuizModeButton


	focus_button(button)
	move_selector(button)
	show_page(QUIZ_MODE)


func _on_section_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/SectionButton


	focus_button(button)
	move_selector(button)
	show_page(SECTION)


func _on_settings_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/SettingsButton
	focus_button(button)
	move_selector($MenuPanel/VBoxContainer/SettingsButton)
	show_page(SETTINGS)


func _on_texture_button_pressed() -> void:
	var button = $MenuPanel/VBoxContainer/TextureButton
	focus_button(button)
	move_selector($MenuPanel/VBoxContainer/TextureButton)
	show_page(NEED_ATTECNTION)


func _on_logout_button_pressed() -> void:
	AuthManager.logout()

	await get_tree().create_timer(0.2).timeout

	get_tree().change_scene_to_file(
		"res://Scenes/UI/MainMenu.tscn"
	)

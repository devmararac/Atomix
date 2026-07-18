extends Control
@onready var auth_panel = $AuthPanel
@onready var buttons_start = $Panel/Start
@onready var buttons_mon = $Panel/Monitor

@onready var email_input = $AuthPanel/Email/EmailInput
@onready var password_input = $AuthPanel/Password/PasswordInput
@onready var status_label = $AuthPanel/StatusLabel

func _ready() -> void:
	buttons_start.hide()
	buttons_mon.hide()
	AuthManager.login_success.connect(_on_login_success)
	AuthManager.login_failed.connect(_on_login_failed)

	AuthManager.signup_success.connect(_on_signup_success)
	AuthManager.signup_failed.connect(_on_signup_failed)

func _on_login_success(auth_result):
	status_label.text = "Welcome!"
	auth_panel.hide()
	buttons_start.show()
	buttons_mon.show()
func _on_start_pressed() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://Scenes/Areas/start_map.tscn")

func _on_setting_pressed() -> void:
	pass

func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_monitor_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Admin/teacher_dashboard.tscn")


func _on_login_button_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text

	if email.is_empty():
		status_label.text = "Please enter your email."
		return

	if password.is_empty():
		status_label.text = "Please enter your password."
		return

	status_label.text = "Logging in..."

	AuthManager.login(email, password)

func _on_signup_button_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text

	if email.is_empty():
		status_label.text = "Please enter your email."
		return

	if password.is_empty():
		status_label.text = "Please enter your password."
		return

	if password.length() < 6:
		status_label.text = "Password must be at least 6 characters."
		return

	status_label.text = "Creating account..."

	AuthManager.signup(email, password)

func _on_login_failed(message):
	status_label.text = message


func _on_signup_failed(message):
	status_label.text = message


func _on_signup_success(auth_result):
	status_label.text = "Account created!"
	_on_login_success(auth_result)

extends Control

@onready var auth_panel = $AuthPanel
@onready var buttons_start = $Panel/Start
@onready var buttons_cont = $Panel/Continue

@onready var email_input = $AuthPanel/Email/EmailInput
@onready var password_input = $AuthPanel/Password/PasswordInput
@onready var status_label = $AuthPanel/StatusLabel
@onready var login_button = $AuthPanel/AuthButtons/LoginButton

var login_in_progress: bool = false


func _ready() -> void:
	buttons_start.hide()
	buttons_cont.hide()

	AuthManager.login_success.connect(_on_login_success)
	AuthManager.login_failed.connect(_on_login_failed)

	AuthManager.signup_success.connect(_on_signup_success)
	AuthManager.signup_failed.connect(_on_signup_failed)

	StudentDataManager.student_loaded.connect(_on_student_loaded)
	StudentDataManager.student_created.connect(_on_student_created)
	StudentDataManager.student_error.connect(_on_student_error)


func _on_login_success(auth_result):
	login_in_progress = false

	status_label.text = "Checking account..."

	print("[MainMenu] Firebase login successful.")
	print("[MainMenu] Checking user role...")

	call_deferred("_check_user_role")

func _check_user_role() -> void:
	print("[MainMenu] Getting user role...")

	var role: String = await AuthManager.get_user_role()

	print("[MainMenu] Role: ", role)

	match role:
		"student":
			status_label.text = "Loading student data..."
			_load_student_data()

		"teacher":
			status_label.text = "Opening teacher dashboard..."

			await get_tree().create_timer(0.3).timeout

			get_tree().change_scene_to_file(
				"res://Scenes/Admin/teacher_dashboard.tscn"
			)

		"admin":
			print("[MainMenu] Opening Admin Dashboard.")
			get_tree().change_scene_to_file("res://Scenes/Admin/admin_dashboard.tscn")

		_:
			status_label.text = "Account role could not be determined."
			print("[MainMenu] Unknown or missing role.")

func _load_student_data() -> void:
	print("[MainMenu] Loading student data...")
	StudentDataManager.load_student()


func _on_student_loaded(data: Dictionary) -> void:
	print("[MainMenu] Student data loaded.")
	print("[MainMenu] Student: ", data)

	status_label.text = "Welcome, " + str(data.get("name", "Student"))

	auth_panel.hide()
	buttons_start.show()
	buttons_cont.show()



func _on_student_created(data: Dictionary) -> void:
	print("[MainMenu] Student document does not exist yet.")
	print("[MainMenu] Student data: ", data)

	PartyManager.party.clear()
	PartyManager.active_index = 0

	status_label.text = "Welcome, Student!"

	auth_panel.hide()
	buttons_start.show()
	buttons_cont.show()


func _on_student_error(error) -> void:
	print("[MainMenu] Student data error: ", error)

	login_in_progress = false
	status_label.text = "Unable to load student data."


func _on_start_pressed() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file(
		"res://Scenes/Cutscenes/classroom_cutscene.tscn"
		
	)


func _on_setting_pressed() -> void:
	pass


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_continue_pressed() -> void:

	SfxManager.play_click()
	SaveManager.load_game()
	PartyManager.load_saved_party()
	var tracker = get_tree().get_first_node_in_group("QuestTracker")

	if tracker:
		tracker.refresh_from_quest_manager()


func _on_login_button_pressed():
	# Prevent multiple login requests.
	if login_in_progress:
		return

	var email = email_input.text.strip_edges()
	var password = password_input.text

	if email.is_empty():
		status_label.text = "Please enter your email."
		return

	if password.is_empty():
		status_label.text = "Please enter your password."
		return

	login_in_progress = true

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
	login_in_progress = false

	status_label.text = message


func _on_signup_failed(message):
	status_label.text = message


func _on_signup_success(auth_result):
	status_label.text = "Account created!"

	# Treat successful signup as a successful login.
	_on_login_success(auth_result)

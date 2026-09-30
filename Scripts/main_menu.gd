extends Control

const MINIGAMES_SCENE = preload("res://Scenes/UI/minigames.tscn")

@onready var auth_panel = $AuthPanel
@onready var buttons_start = $Panel/Start
@onready var buttons_cont = $Panel/Continue

@onready var atomix_keyboard = $AtomiXKeyboard
@onready var email_input = $AuthPanel/Email/EmailInput
@onready var password_input = $AuthPanel/Password/PasswordInput
@onready var status_label = $AuthPanel/StatusLabel
@onready var login_button = $AuthPanel/AuthButtons/LoginButton

var login_in_progress: bool = false
var role_check_in_progress: bool = false

# True only when Firebase restored an existing login session
# when the application started.
#
# False when the player manually enters their email/password
# and presses LOGIN.
var restored_session_on_startup: bool = false


func _ready() -> void:
	buttons_start.hide()
	buttons_cont.hide()

	AuthManager.login_success.connect(_on_login_success)
	AuthManager.login_failed.connect(_on_login_failed)
	AuthManager.session_restored.connect(_on_session_restored)

	AuthManager.signup_success.connect(_on_signup_success)
	AuthManager.signup_failed.connect(_on_signup_failed)

	StudentDataManager.student_loaded.connect(_on_student_loaded)
	StudentDataManager.student_created.connect(_on_student_created)
	StudentDataManager.student_error.connect(_on_student_error)

	# ------------------------------------------------------------
	# CHECK FOR AN ALREADY LOGGED-IN ACCOUNT
	# ------------------------------------------------------------
	#
	# This is the ONLY situation where the saved game should
	# automatically open.
	#
	# If the player manually logs in later, this remains false.
	# ------------------------------------------------------------
	if AuthManager.is_logged_in():
		restored_session_on_startup = true
		print("[MainMenu] Existing Firebase session detected.")
		print("[MainMenu] Automatic saved-game restore is allowed.")

		call_deferred("_check_user_role")
	else:
		restored_session_on_startup = false
		print("[MainMenu] No existing login session.")
		print("[MainMenu] Waiting for manual login.")

	# AtomiX custom keyboard
	email_input.focus_entered.connect(_on_email_input_focus_entered)
	password_input.focus_entered.connect(_on_password_input_focus_entered)


func _on_login_success(auth_result):
	login_in_progress = false

	# This is a REAL manual login.
	# Therefore Start / Continue must be shown.
	restored_session_on_startup = false

	status_label.text = "Checking account..."

	print("[MainMenu] Manual Firebase login successful.")
	print("[MainMenu] Start / Continue will be shown.")

	call_deferred("_check_user_role")

func _on_session_restored(auth_result) -> void:
	print("[MainMenu] Existing Firebase session restored.")
	print("[MainMenu] Automatic saved-game loading is allowed.")

	restored_session_on_startup = true

	call_deferred("_check_user_role")


func _on_email_input_focus_entered() -> void:
	atomix_keyboard.show_for(email_input)


func _on_password_input_focus_entered() -> void:
	atomix_keyboard.show_for(password_input)


func _check_user_role() -> void:
	if role_check_in_progress:
		return

	role_check_in_progress = true

	print("[MainMenu] Getting user role...")

	var role: String = await AuthManager.get_user_role()

	print("[MainMenu] Role: ", role)

	match role:
		"student":
			var status := await AuthManager.get_account_status()

			if status != "active":
				role_check_in_progress = false

				status_label.text = "This student account is archived. Please contact your teacher or administrator."

				return

			status_label.text = "Loading student data..."

			_load_student_data()

		"teacher":
			role_check_in_progress = false

			status_label.text = "Opening teacher dashboard..."

			await get_tree().create_timer(0.3).timeout

			get_tree().change_scene_to_file(
				"res://Scenes/Admin/Teacher/teacher_dashboard.tscn"
			)

		"admin":
			role_check_in_progress = false

			print("[MainMenu] Opening Admin Dashboard.")

			get_tree().change_scene_to_file(
				"res://Scenes/Admin/HeadTeacher/admin_dashboard.tscn"
			)

		_:
			role_check_in_progress = false

			status_label.text = "Account role could not be determined."

			print("[MainMenu] Unknown or missing role.")


func _load_student_data() -> void:
	print("[MainMenu] Loading student data...")

	StudentDataManager.load_student()


func _on_student_loaded(data: Dictionary) -> void:
	role_check_in_progress = false

	print("[MainMenu] Student data loaded.")
	print("[MainMenu] Student: ", data)

	# ============================================================
	# EXISTING SESSION
	# ============================================================
	if restored_session_on_startup:
		var game_state: Dictionary = data.get("game_state", {})
		var has_save: bool = bool(game_state.get("has_save", false))

		print("[MainMenu] Session was restored automatically.")
		print("[MainMenu] Has saved game: ", has_save)

		if has_save:
			print("[MainMenu] Automatically loading saved game.")

			auth_panel.hide()
			buttons_start.hide()
			buttons_cont.hide()
			atomix_keyboard.hide()

			await SaveManager.load_game()

			return

		# Existing account but no saved game yet.
		print("[MainMenu] No saved game found.")
		print("[MainMenu] Showing Start / Continue.")

		status_label.text = "Welcome, " + str(data.get("name", "Student"))

		auth_panel.hide()
		buttons_start.show()
		buttons_cont.show()

		return

	# ============================================================
	# MANUAL LOGIN
	# ============================================================
	#
	# NEVER automatically load the saved game here.
	#
	# The player must choose START or CONTINUE.
	# ============================================================

	print("[MainMenu] Student manually logged in.")
	print("[MainMenu] Showing Start / Continue.")

	status_label.text = "Welcome, " + str(data.get("name", "Student"))

	auth_panel.hide()
	buttons_start.show()
	buttons_cont.show()


func _on_student_created(data: Dictionary) -> void:
	role_check_in_progress = false

	print("[MainMenu] Student document does not exist yet.")
	print("[MainMenu] Student data: ", data)

	PartyManager.party.clear()
	PartyManager.active_index = 0

	status_label.text = "Welcome, Student!"

	auth_panel.hide()
	buttons_start.show()
	buttons_cont.show()


func _on_student_error(error) -> void:
	role_check_in_progress = false

	print("[MainMenu] Student data error: ", error)

	login_in_progress = false

	status_label.text = "Unable to load student data."


func _on_start_pressed() -> void:
	await get_tree().create_timer(0.5).timeout

	get_tree().change_scene_to_file(
		"res://Scenes/UI/CharacterSetup.tscn"
	)


func _on_setting_pressed() -> void:
	pass


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_continue_pressed() -> void:
	SfxManager.play_click()

	await SaveManager.load_game()


	var tracker = get_tree().get_first_node_in_group("QuestTracker")

	if tracker:
		tracker.refresh_from_quest_manager()


func _on_login_button_pressed():
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

	# ------------------------------------------------------------
	# This is a MANUAL login.
	# Make absolutely sure this login does not use the
	# automatic saved-game restore path.
	# ------------------------------------------------------------
	restored_session_on_startup = false

	login_in_progress = true

	status_label.text = "Logging in..."

	print("[MainMenu] Manual login started.")
	print("[MainMenu] Automatic saved-game restore disabled.")

	AuthManager.login(email, password)


func _on_login_failed(message):
	login_in_progress = false

	status_label.text = message


func _on_signup_failed(message):
	status_label.text = message


func _on_signup_success(auth_result):
	status_label.text = "Account created!"

	# A newly created account is also considered a normal
	# manual login, not an automatic session restore.
	restored_session_on_startup = false

	_on_login_success(auth_result)


func _input(event: InputEvent) -> void:
	if not atomix_keyboard.visible:
		return

	var tap_position := Vector2.ZERO

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return

		tap_position = event.position

	elif event is InputEventScreenTouch:
		if not event.pressed:
			return

		tap_position = event.position

	else:
		return

	if atomix_keyboard.get_global_rect().has_point(tap_position):
		return

	if email_input.get_global_rect().has_point(tap_position):
		return

	if password_input.get_global_rect().has_point(tap_position):
		return

	atomix_keyboard.hide_keyboard()


func _on_button_pressed() -> void:
	var minigames = MINIGAMES_SCENE.instantiate()

	add_child(minigames)

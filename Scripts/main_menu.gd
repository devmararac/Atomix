extends Control

const MINIGAMES_SCENE = preload("res://Scenes/UI/minigames.tscn")

# --- INTRO REFERENCES ---
@onready var intro_elements = $"Intro Elements"
@onready var intro_logo = $"Intro Elements/Atomix Logo"
@onready var intro_bg = $"Intro Elements/ColorRect"

@onready var touch_label = $"Intro Elements/TouchToContinue"
var waiting_for_intro_tap: bool = false

@onready var auth_panel = $AuthPanel
@onready var ui_panel = $Panel # The CenterContainer holding the buttons
@onready var buttons_start = $Panel/VBox/Start
@onready var buttons_cont  = $Panel/VBox/Continue

@onready var atomix_keyboard = $AtomiXKeyboard
@onready var email_input    = $AuthPanel/Margin/VBox/Email/EmailInput
@onready var password_input = $AuthPanel/Margin/VBox/Password/PasswordInput
@onready var status_label   = $AuthPanel/Margin/VBox/StatusLabel
@onready var login_button   = $AuthPanel/Margin/VBox/AuthButtons/LoginButton

@onready var loading_screen = $Loading

var login_in_progress: bool = false
var role_check_in_progress: bool = false

var restored_session_on_startup: bool = false


func _ready() -> void:
	# Hide the menus initially
	auth_panel.hide()
	ui_panel.hide()
	buttons_start.hide()
	buttons_cont.hide()
	
	
	# Play the intro only when there is no existing login session.
	if AuthManager.is_logged_in():
		intro_elements.hide()
		auth_panel.hide()
		ui_panel.hide()
		loading_screen.show_loading("RESTORING SESSION...")
	else:
		_play_intro()

	AuthManager.login_success.connect(_on_login_success)
	AuthManager.login_failed.connect(_on_login_failed)
	AuthManager.session_restored.connect(_on_session_restored)

	AuthManager.signup_success.connect(_on_signup_success)
	AuthManager.signup_failed.connect(_on_signup_failed)

	StudentDataManager.student_loaded.connect(_on_student_loaded)
	StudentDataManager.student_created.connect(_on_student_created)
	StudentDataManager.student_error.connect(_on_student_error)

	if AuthManager.is_logged_in():
		restored_session_on_startup = true
		print("[MainMenu] Existing Firebase session detected.")
		call_deferred("_check_user_role")
	else:
		restored_session_on_startup = false
		print("[MainMenu] No existing login session.")

	# AtomiX custom keyboard
	email_input.focus_entered.connect(_on_email_input_focus_entered)
	password_input.focus_entered.connect(_on_password_input_focus_entered)

# ==========================================
# ANIMATION HELPERS
# ==========================================

func _transition_to_game_menu(show_continue: bool) -> void:
	atomix_keyboard.hide_keyboard()
	
	# Fade and slide out the Auth Panel
	var tween_out = create_tween().set_parallel(true)
	tween_out.tween_property(auth_panel, "modulate:a", 0.0, 0.3)
	tween_out.tween_property(auth_panel, "position:x", auth_panel.position.x - 50, 0.3).set_trans(Tween.TRANS_SINE)
	
	await tween_out.finished
	auth_panel.hide()
	
	# Setup the Game Menu (Start/Continue)
	ui_panel.show()
	ui_panel.modulate.a = 0.0
	ui_panel.scale = Vector2(0.9, 0.9)
	
	if show_continue:
		buttons_cont.show()
	else:
		buttons_cont.hide()
	buttons_start.show()
	
	# Fade and pop in the Game Menu
	var tween_in = create_tween().set_parallel(true)
	tween_in.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
	tween_in.tween_property(ui_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await tween_in.finished

func _play_exit_animation() -> void:
	# Scale down and fade out the Start/Continue menu
	var tween = create_tween().set_parallel(true)
	tween.tween_property(ui_panel, "modulate:a", 0.0, 0.25)
	tween.tween_property(ui_panel, "scale", Vector2(0.8, 0.8), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	await tween.finished

# ==========================================
# AUTHENTICATION LOGIC
# ==========================================

func _on_login_success(auth_result):
	login_in_progress = false
	restored_session_on_startup = false
	status_label.text = "Checking account..."
	call_deferred("_check_user_role")

func _on_session_restored(auth_result) -> void:
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

	var role: String = await AuthManager.get_user_role()

	match role:
		"student":
			var status := await AuthManager.get_account_status()

			if status != "active":
				role_check_in_progress = false
				loading_screen.hide_loading() # <-- ADD THIS
				status_label.text = "This student account is archived. Please contact your teacher or administrator."
				return

			status_label.text = "Loading student data..."
			_load_student_data()

		"teacher":
			await _open_staff_dashboard(
		        "res://Scenes/Admin/Teacher/teacher_dashboard.tscn"
			)

		"admin":
			await _open_staff_dashboard(
		        "res://Scenes/Admin/HeadTeacher/admin_dashboard.tscn"
			)

		_:
			role_check_in_progress = false
			loading_screen.hide_loading() # <-- ADD THIS
			status_label.text = "Account role could not be determined."



func _open_staff_dashboard(scene_path: String) -> void:

	print("[MainMenu] Checking staff account setup requirements...")

	# Check whether the account must change its password.
	var must_change: bool = await AuthManager.needs_password_change()

	# Check the latest Firebase email verification status.
	var email_verified: bool = await AuthManager.check_email_verified()

	# Require Settings if either requirement is incomplete.
	AuthManager.account_setup_required = (
		must_change or not email_verified
	)

	print("[MainMenu] Must change password: ", must_change)
	print("[MainMenu] Email verified: ", email_verified)
	print(
		"[MainMenu] Account setup required: ",
		AuthManager.account_setup_required
	)

	role_check_in_progress = false

	loading_screen.show_loading("OPENING DASHBOARD...")
	await get_tree().create_timer(1.0).timeout

	get_tree().change_scene_to_file(scene_path)



func _load_student_data() -> void:
	StudentDataManager.load_student()

# ==========================================
# DATA LOADING LOGIC
# ==========================================

func _on_student_loaded(data: Dictionary) -> void:
	role_check_in_progress = false

	# Hide the loading screen now that data is here!
	loading_screen.hide_loading()

	# 1. Check if they have a save file
	var game_state: Dictionary = data.get("game_state", {})
	var has_save: bool = bool(game_state.get("has_save", false))

	# 2. AUTO-LOGIN LOGIC
	if restored_session_on_startup:
		if has_save:
			print("[MainMenu] Automatically loading saved game.")
			# Hide UI immediately and load game
			auth_panel.hide()
			ui_panel.hide()
			await SaveManager.load_game()
			return
		else:
			print("[MainMenu] No saved game found. Showing Start.")
			status_label.text = "Welcome, " + str(data.get("name", "Student"))
			_transition_to_game_menu(false) # false = don't show Continue
			return

	# 3. MANUAL LOGIN LOGIC
	print("[MainMenu] Student manually logged in.")
	status_label.text = "Welcome, " + str(data.get("name", "Student"))
	_transition_to_game_menu(has_save)


func _on_student_created(data: Dictionary) -> void:
	role_check_in_progress = false
	print("[MainMenu] Student document does not exist yet.")

	# Hide the loading screen
	loading_screen.hide_loading()

	PartyManager.party.clear()
	PartyManager.active_index = 0

	status_label.text = "Welcome, Student!"
	_transition_to_game_menu(false) # Brand new account, don't show Continue


func _on_student_error(error) -> void:
	role_check_in_progress = false
	login_in_progress = false
	status_label.text = "Unable to load student data."

# ==========================================
# BUTTON ACTIONS
# ==========================================

func _on_start_pressed() -> void:
	SfxManager.play_click()
	
	# 1. Play the exit animation (buttons shrink and fade out)
	await _play_exit_animation()
	
	# 2. Show the loading screen
	loading_screen.show_loading("STARTING NEW GAME...")
	
	# 3. Reset the game data
	var reset_success := await SaveManager.start_new_game()

	# 4. If it fails, hide loading and bring the menu back
	if not reset_success:
		loading_screen.hide_loading()
		status_label.text = "Unable to start a new game. Please try again."
		var tween = create_tween()
		tween.tween_property(ui_panel, "modulate:a", 1.0, 0.2)
		return

	# 5. Wait a tiny bit so the player sees the loading screen (optional)
	await get_tree().create_timer(0.5).timeout
	
	# 6. Change the scene!
	get_tree().change_scene_to_file("res://Scenes/UI/CharacterSetup.tscn") 


func _on_continue_pressed() -> void:
	SfxManager.play_click()
	
	# 1. Play the exit animation
	await _play_exit_animation()
	
	# 2. Show the loading screen
	loading_screen.show_loading("LOADING SAVE...")
	
	# 3. Load the game data
	await SaveManager.load_game()

	# 4. Refresh the quest tracker if it exists
	var tracker = get_tree().get_first_node_in_group("QuestTracker")
	if tracker:
		tracker.refresh_from_quest_manager()

# ==========================================
# LOGIN INPUT ACTIONS
# ==========================================

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

	restored_session_on_startup = false
	login_in_progress = true
	
	# 1. Hide the status label and show the loading screen
	status_label.text = ""
	loading_screen.show_loading("AUTHENTICATING...")
	
	# 2. Attempt login
	AuthManager.login(email, password)


func _on_login_failed(message):
	login_in_progress = false
	
	# Hide the loading screen on failure
	loading_screen.hide_loading()
	
	status_label.text = message


func _on_signup_failed(message):
	status_label.text = message


func _on_signup_success(auth_result):
	status_label.text = "Account created!"
	restored_session_on_startup = false
	_on_login_success(auth_result)


func _input(event: InputEvent) -> void:
	# 1. Handle the intro tap
	if waiting_for_intro_tap:
		var is_tap := false
		
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_tap = true
		elif event is InputEventScreenTouch and event.pressed:
			is_tap = true
			
		if is_tap:
			waiting_for_intro_tap = false
			# Play a click sound for the tap
			if SfxManager: SfxManager.play_click()
			# Consume the event so it doesn't accidentally click things beneath it
			get_viewport().set_input_as_handled()
			return

	# 2. Your existing keyboard logic
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

	if atomix_keyboard.get_global_rect().has_point(tap_position): return
	if email_input.get_global_rect().has_point(tap_position): return
	if password_input.get_global_rect().has_point(tap_position): return

	atomix_keyboard.hide_keyboard()

func _play_intro() -> void:
	if not is_inside_tree():
		return

	# 1. Setup initial states
	intro_elements.show()
	intro_bg.color.a = 1.0
	intro_logo.modulate.a = 0.0
	intro_logo.scale = Vector2(0.8, 0.8)
	touch_label.hide()

	# 2. Create the first half of the tween (Fade in)
	var tween_in = create_tween()

	tween_in.tween_property(
		intro_bg,
		"color:a",
		0.0,
		1.5
	).set_trans(Tween.TRANS_SINE)

	tween_in.parallel().tween_property(
		intro_logo,
		"modulate:a",
		1.0,
		1.0
	).set_delay(1.0)

	tween_in.parallel().tween_property(
		intro_logo,
		"scale",
		Vector2(1.0, 1.0),
		1.5
	).set_delay(1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween_in.finished

	# Stop if the MainMenu scene has been removed.
	if not is_inside_tree():
		return

	# 3. Show the pulsing "Touch to Continue" label
	touch_label.show()
	touch_label.modulate.a = 0.0

	var pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(
		touch_label,
		"modulate:a",
		1.0,
		1.0
	)
	pulse_tween.tween_property(
		touch_label,
		"modulate:a",
		0.2,
		1.0
	)

	# 4. Wait for the user to tap the screen
	waiting_for_intro_tap = true

	while waiting_for_intro_tap:
		if not is_inside_tree():
			pulse_tween.kill()
			return

		await get_tree().process_frame

	# Stop if the scene was changed.
	if not is_inside_tree():
		pulse_tween.kill()
		return

	# 5. The user tapped! Stop the pulse and finish the intro
	pulse_tween.kill()
	touch_label.hide()

	var tween_out = create_tween()

	tween_out.tween_property(
		intro_logo,
		"modulate:a",
		0.0,
		0.5
	)

	tween_out.tween_callback(intro_elements.hide)
	tween_out.tween_callback(_show_auth_panel)

	tween_out.tween_property(
		auth_panel,
		"modulate:a",
		1.0,
		0.5
	).set_trans(Tween.TRANS_SINE)
func _show_auth_panel() -> void:
	auth_panel.modulate.a = 0.0
	auth_panel.show()
	# The tween_out in _play_intro() will handle the fade to 1.0


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/GDMP/GDMPUi.tscn")

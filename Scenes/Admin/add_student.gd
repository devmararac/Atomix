
extends Control

signal student_created

@onready var name_input: LineEdit = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/NameInput
@onready var email_input: LineEdit = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/EmailInput
@onready var password_input: LineEdit = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/PasswordInput
@onready var confirm_password_input: LineEdit = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/ConfirmPasswordInput
@onready var status_label: Label = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var cancel_button: Button = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/Buttons/CancelButton
@onready var create_button: Button = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/Buttons/CreateButton


func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

	hide()


func _on_create_pressed() -> void:
	var student_name: String = name_input.text.strip_edges()
	var email: String = email_input.text.strip_edges()
	var password: String = password_input.text
	var confirm_password: String = confirm_password_input.text

	# -------------------------
	# VALIDATION
	# -------------------------

	if student_name.is_empty():
		show_status("Please enter the student's name.")
		return

	if email.is_empty():
		show_status("Please enter the student's email.")
		return

	if password.is_empty():
		show_status("Please enter a password.")
		return

	if password != confirm_password:
		show_status("Passwords do not match.")
		return

	if password.length() < 6:
		show_status("Password must be at least 6 characters.")
		return

	# -------------------------
	# UI STATE
	# -------------------------

	create_button.disabled = true
	cancel_button.disabled = true

	show_status("Creating student account...")

	print("[AddStudent] Student name: ", student_name)
	print("[AddStudent] Email: ", email)

	# -------------------------
	# CREATE FIREBASE AUTH USER
	# -------------------------

	var auth_result := await create_firebase_account(email, password)

	if auth_result.is_empty():
		create_button.disabled = false
		cancel_button.disabled = false
		return

	var new_student_uid: String = str(auth_result.get("localId", ""))

	if new_student_uid.is_empty():
		show_status("Firebase did not return a student UID.")

		create_button.disabled = false
		cancel_button.disabled = false
		return

	print("[AddStudent] New student UID: ", new_student_uid)

	# -------------------------
	# CREATE FIRESTORE DOCUMENT
	# -------------------------

	show_status("Creating student record...")

	var firestore_success := await create_student_document(
		new_student_uid,
		student_name,
		email
	)

	if not firestore_success:
		show_status("Account created, but student record could not be saved.")

		create_button.disabled = false
		cancel_button.disabled = false
		return

	# -------------------------
	# SUCCESS
	# -------------------------

	print("[AddStudent] Student created successfully.")
	print("[AddStudent] UID: ", new_student_uid)

	show_status("Student account created successfully!")

	await get_tree().create_timer(1.0).timeout

	student_created.emit()


# ============================================================
# FIREBASE AUTH
# ============================================================

func create_firebase_account(
	email: String,
	password: String
) -> Dictionary:

	var http := HTTPRequest.new()
	add_child(http)

	var url: String = (
		"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="
		+ FirebaseConfig.FIREBASE_API_KEY
	)

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var body := JSON.stringify({
		"email": email,
		"password": password,
		"returnSecureToken": true
	})

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		print("[AddStudent] HTTP request failed: ", error)

		show_status("Unable to connect to Firebase.")

		http.queue_free()
		return {}

	var response: Array = await http.request_completed

	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	var response_text := response_body.get_string_from_utf8()

	print("[AddStudent] Firebase Auth response code: ", response_code)

	var json := JSON.new()
	var parse_error := json.parse(response_text)

	if parse_error != OK:
		print("[AddStudent] Invalid Firebase response.")
		show_status("Invalid Firebase response.")

		http.queue_free()
		return {}

	var data = json.data

	if response_code != 200:
		print("[AddStudent] Firebase Auth error: ", data)

		var message := "Unable to create account."

		if data is Dictionary:
			if data.has("error"):
				var firebase_error: Dictionary = data["error"]

				if firebase_error.has("message"):
					message = str(firebase_error["message"])

		# Make Firebase error messages more understandable.
		if message == "EMAIL_EXISTS":
			message = "This email is already registered."
		elif message == "INVALID_EMAIL":
			message = "Invalid email address."
		elif message == "WEAK_PASSWORD : Password should be at least 6 characters":
			message = "Password must be at least 6 characters."

		show_status(message)

		http.queue_free()
		return {}

	http.queue_free()

	if data is Dictionary:
		return data

	return {}


# ============================================================
# FIRESTORE
# ============================================================

func create_student_document(
	uid: String,
	student_name: String,
	email: String
) -> bool:

	# ========================================================
	# USERS DOCUMENT
	# ========================================================

	var users = Firebase.Firestore.collection("users")

	var user_data := {
		"name": student_name,
		"email": email,
		"role": "student"
	}

	print("[AddStudent] Creating users document...")
	print("[AddStudent] Document ID: ", uid)

	var user_document: FirestoreDocument = await users.add(
		uid,
		user_data
	)

	if user_document == null:
		print("[AddStudent] Failed to create users document.")
		return false

	print("[AddStudent] Users document created.")


	# ========================================================
	# STUDENTS DOCUMENT
	# ========================================================

	var students = Firebase.Firestore.collection("students")


	var student_data := {

		# ----------------------------------------------------
		# BASIC STUDENT INFORMATION
		# ----------------------------------------------------
		"name": student_name,
		"email": email,
		"role": "student",

		# ----------------------------------------------------
		# STUDENT PROGRESS
		# ----------------------------------------------------
		"progress": {
			"elements_total": 118,
			"elements_collected": 0,
			"collected_elements": []
		},

		# ----------------------------------------------------
		# GAME STATE
		# ----------------------------------------------------
		"game_state": {
			# New account has no saved game yet.
			"has_save": false,

			# Default scene.
			"current_scene": "res://Scenes/Areas/start_map.tscn",

			# These are intentionally the scene's default starting coordinates.
			"player_position": {
				"x": 0.0,
				"y": 0.0
			},

			# Currency.
			"coins": 0,

			# Active battle-party slot.
			"active_index": 0,

			# ------------------------------------------------
			# PARTY
			# ------------------------------------------------
			"party": [],

			# ------------------------------------------------
			# INVENTORY
			# ------------------------------------------------
			"inventory": [],
			
			#------------------------------------------------
			# QUEST
			# ------------------------------------------------
			"quest_data": {}
		}
	}


	# ========================================================
	# CREATE STUDENT FIRESTORE DOCUMENT
	# ========================================================

	print("[AddStudent] Creating students document...")
	print("[AddStudent] Document ID: ", uid)
	print("[AddStudent] Game state initialized.")
	print("[AddStudent] Party initialized: 0/15")
	print("[AddStudent] Elements collected: 0/118")

	var student_document: FirestoreDocument = await students.add(
		uid,
		student_data
	)

	if student_document == null:

		print(
			"[AddStudent] Failed to create students document."
		)

		return false


	print(
		"[AddStudent] Students document created."
	)

	return true


# ============================================================
# CANCEL
# ============================================================

func _on_cancel_pressed() -> void:
	hide()


# ============================================================
# STATUS
# ============================================================

func show_status(message: String) -> void:
	status_label.text = message

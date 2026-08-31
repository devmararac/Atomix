
extends Control

# ============================================================
# ADD TEACHER
# ============================================================

@onready var name_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/NameInput
@onready var email_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/EmailInput
@onready var password_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/PasswordInput
@onready var school_year_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/SchoolYearInput
@onready var sections_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/SectionsInput

@onready var status_label: Label = $FormPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var create_button: Button = $FormPanel/MarginContainer/VBoxContainer/ButtonContainer/CreateButton
@onready var cancel_button: Button = $FormPanel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	print("[AddTeacher] Add Teacher form ready.")

	status_label.text = ""

	# Default school year
	if school_year_input.text.is_empty():
		school_year_input.text = "2026-2027"


# ============================================================
# CREATE TEACHER
# ============================================================

func _on_create_button_pressed() -> void:

	print("[AddTeacher] =================================")
	print("[AddTeacher] Creating teacher account")

	var teacher_name := name_input.text.strip_edges()
	var email := email_input.text.strip_edges()
	var password := password_input.text
	var school_year := school_year_input.text.strip_edges()
	var sections_text := sections_input.text.strip_edges()

	print("[AddTeacher] Name: ", teacher_name)
	print("[AddTeacher] Email: ", email)
	print("[AddTeacher] School Year: ", school_year)
	print("[AddTeacher] Sections: ", sections_text)
	print("[AddTeacher] =================================")

	# --------------------------------------------------------
	# Validate
	# --------------------------------------------------------

	if teacher_name.is_empty():
		_show_status("Please enter the teacher name.")
		return

	if email.is_empty():
		_show_status("Please enter the teacher email.")
		return

	if not _is_valid_email(email):
		_show_status("Please enter a valid email address.")
		return

	if password.is_empty():
		_show_status("Please enter a password.")
		return

	if password.length() < 6:
		_show_status("Password must be at least 6 characters.")
		return

	if school_year.is_empty():
		_show_status("Please enter the school year.")
		return

	if sections_text.is_empty():
		_show_status("Please assign at least one section.")
		return

	# --------------------------------------------------------
	# Disable button while creating
	# --------------------------------------------------------

	create_button.disabled = true
	cancel_button.disabled = true

	status_label.text = "Creating teacher account..."

	# --------------------------------------------------------
	# Convert sections
	# --------------------------------------------------------

	var assigned_sections: Array[String] = []

	for section in sections_text.split(","):
		var cleaned_section := section.strip_edges()

		if not cleaned_section.is_empty():
			assigned_sections.append(cleaned_section)

	if assigned_sections.is_empty():
		_show_status("Please enter at least one valid section.")
		create_button.disabled = false
		cancel_button.disabled = false
		return

	# --------------------------------------------------------
	# Create Firebase Authentication account
	#
	# We use the REST API here instead of Firebase.Auth.signup()
	# because the admin should remain logged in.
	# --------------------------------------------------------

	var auth_result := await _create_firebase_auth_account(
		email,
		password
	)

	if not auth_result.success:

		print(
			"[AddTeacher] Firebase Auth creation failed: ",
			auth_result.message
		)

		_show_status(
			"Failed to create teacher account:\n"
			+ auth_result.message
		)

		create_button.disabled = false
		cancel_button.disabled = false
		return

	var teacher_uid: String = auth_result.uid

	print("[AddTeacher] New teacher UID: ", teacher_uid)

	# --------------------------------------------------------
	# Create /users document
	# --------------------------------------------------------

	var users_created := await _create_users_document(
		teacher_uid,
		teacher_name,
		email
	)

	if not users_created:

		_show_status(
			"Teacher account was created, but the users document failed."
		)

		create_button.disabled = false
		cancel_button.disabled = false
		return

	print("[AddTeacher] Users document created.")

	# --------------------------------------------------------
	# Create /teachers document
	# --------------------------------------------------------

	var teacher_created := await _create_teachers_document(
		teacher_uid,
		teacher_name,
		email,
		school_year,
		assigned_sections
	)

	if not teacher_created:

		_show_status(
			"Teacher account was created, but the teachers document failed."
		)

		create_button.disabled = false
		cancel_button.disabled = false
		return

	print("[AddTeacher] Teacher document created.")
	print("[AddTeacher] Assigned sections: ", assigned_sections)
	print("[AddTeacher] Learning materials initialized.")
	print("[AddTeacher] Student list initialized.")

	print("[AddTeacher] =================================")
	print("[AddTeacher] Teacher created successfully!")
	print("[AddTeacher] UID: ", teacher_uid)
	print("[AddTeacher] =================================")

	status_label.text = "Teacher created successfully!"

	# --------------------------------------------------------
	# Notify TeacherManagement
	# --------------------------------------------------------

	var parent_node := get_parent()

	if parent_node != null:
		if parent_node.has_method("on_teacher_created"):
			parent_node.on_teacher_created()

		elif parent_node.has_method("_on_teacher_created"):
			parent_node._on_teacher_created()

		elif parent_node.has_signal("teacher_created"):
			parent_node.teacher_created.emit()

	# --------------------------------------------------------
	# Close after short delay
	# --------------------------------------------------------

	await get_tree().create_timer(1.0).timeout

	queue_free()


# ============================================================
# FIREBASE AUTH ACCOUNT
# ============================================================

func _create_firebase_auth_account(
	email: String,
	password: String
) -> Dictionary:

	var http := HTTPRequest.new()
	add_child(http)

	var api_key := _get_firebase_api_key()

	if api_key.is_empty():

		http.queue_free()

		return {
			"success": false,
			"uid": "",
			"message": "Firebase API key could not be found."
		}

	var url := (
		"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="
		+ api_key
	)

	var body := JSON.stringify({
		"email": email,
		"password": password,
		"returnSecureToken": true
	})

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:

		http.queue_free()

		return {
			"success": false,
			"uid": "",
			"message": "Unable to connect to Firebase Authentication."
		}

	var response: Array = await http.request_completed

	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	var response_text := response_body.get_string_from_utf8()

	http.queue_free()

	print(
		"[AddTeacher] Firebase Auth response: ",
		response_code
	)

	if response_code != 200:

		print(
			"[AddTeacher] Firebase Auth error: ",
			response_text
		)

		var error_message := _parse_firebase_error(
			response_text
		)

		return {
			"success": false,
			"uid": "",
			"message": error_message
		}

	var json := JSON.new()

	if json.parse(response_text) != OK:

		return {
			"success": false,
			"uid": "",
			"message": "Invalid Firebase Authentication response."
		}

	var data = json.data

	if not data is Dictionary:

		return {
			"success": false,
			"uid": "",
			"message": "Invalid Firebase Authentication response."
		}

	var uid := str(
		data.get(
			"localId",
			""
		)
	)

	if uid.is_empty():

		return {
			"success": false,
			"uid": "",
			"message": "Firebase did not return a teacher UID."
		}

	return {
		"success": true,
		"uid": uid,
		"message": ""
	}


# ============================================================
# CREATE USERS DOCUMENT
# ============================================================

func _create_users_document(
	uid: String,
	teacher_name: String,
	email: String
) -> bool:

	print("[AddTeacher] Creating users document...")

	var auth_data := await _get_firestore_auth()

	if auth_data.is_empty():
		print("[AddTeacher] Could not obtain Firestore authentication.")
		return false

	var project_id := _get_firebase_project_id()

	if project_id.is_empty():
		print("[AddTeacher] Firebase Project ID not found.")
		return false

	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+ project_id
		+ "/databases/(default)/documents/users/"
		+ uid
	)

	var fields := {
		"name": {
			"stringValue": teacher_name
		},
		"email": {
			"stringValue": email
		},
		"role": {
			"stringValue": "teacher"
		},
		"status": {
			"stringValue": "active"
		}
	}

	return await _send_firestore_document(
		url,
		fields,
		auth_data
	)


# ============================================================
# CREATE TEACHERS DOCUMENT
# ============================================================

func _create_teachers_document(
	uid: String,
	teacher_name: String,
	email: String,
	school_year: String,
	assigned_sections: Array[String]
) -> bool:

	print("[AddTeacher] Creating teachers document...")

	var auth_data := await _get_firestore_auth()

	if auth_data.is_empty():
		print("[AddTeacher] Could not obtain Firestore authentication.")
		return false

	var project_id := _get_firebase_project_id()

	if project_id.is_empty():
		print("[AddTeacher] Firebase Project ID not found.")
		return false

	var sections_values: Array = []

	for section in assigned_sections:
		sections_values.append({
			"stringValue": section
		})

	var fields := {
		"name": {
			"stringValue": teacher_name
		},

		"email": {
			"stringValue": email
		},

		"role": {
			"stringValue": "teacher"
		},

		"status": {
			"stringValue": "active"
		},

		"school_year": {
			"stringValue": school_year
		},

		"assigned_sections": {
			"arrayValue": {
				"values": sections_values
			}
		},

		"learning_materials": {
			"arrayValue": {
				"values": []
			}
		},

		"students": {
			"arrayValue": {
				"values": []
			}
		},

		"last_active": {
			"integerValue": "0"
		},

		"created_at": {
			"integerValue": str(
				Time.get_unix_time_from_system()
			)
		}
	}

	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+ project_id
		+ "/databases/(default)/documents/teachers/"
		+ uid
	)

	var success := await _send_firestore_document(
		url,
		fields,
		auth_data
	)

	if success:
		print("[AddTeacher] Teacher UID: ", uid)

	return success


# ============================================================
# FIRESTORE REQUEST
# ============================================================

func _send_firestore_document(
	url: String,
	fields: Dictionary,
	auth_data: Dictionary
) -> bool:

	var http := HTTPRequest.new()
	add_child(http)

	var headers := PackedStringArray([
		"Authorization: Bearer " + str(auth_data["idtoken"]),
		"Content-Type: application/json"
	])

	var body := JSON.stringify({
		"fields": fields
	})

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_PATCH,
		body
	)

	if error != OK:

		http.queue_free()

		return false

	var response: Array = await http.request_completed

	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	var response_text := response_body.get_string_from_utf8()

	http.queue_free()

	if response_code < 200 or response_code >= 300:

		print(
			"[AddTeacher] Firestore request failed: ",
			response_code
		)

		print(
			"[AddTeacher] Firestore error: ",
			response_text
		)

		return false

	return true


# ============================================================
# FIRESTORE AUTHENTICATION
# ============================================================

func _get_firestore_auth() -> Dictionary:

	var auth_data: Dictionary = Firebase.Firestore.auth

	if not auth_data.is_empty():
		if auth_data.has("idtoken"):
			return auth_data

	# Try Firebase Auth if Firestore auth is not ready
	if Firebase.Auth != null:

		var current_auth: Dictionary = Firebase.Firestore.auth

		if current_auth is Dictionary:

			if current_auth.has("idtoken"):
				return current_auth

	return {}


# ============================================================
# FIREBASE PROJECT ID
# ============================================================

func _get_firebase_project_id() -> String:

	if Firebase.Firestore._config.has("projectId"):

		return str(
			Firebase.Firestore._config["projectId"]
		)

	var config_script = FirebaseConfig

	if "FIREBASE_PROJECT_ID" in config_script:

		return str(
			config_script.FIREBASE_PROJECT_ID
		)

	if "PROJECT_ID" in config_script:

		return str(
			config_script.PROJECT_ID
		)

	print("[AddTeacher] Firebase Project ID not found.")

	return ""


# ============================================================
# FIREBASE API KEY
# ============================================================

func _get_firebase_api_key() -> String:

	var config_script = FirebaseConfig

	if "FIREBASE_API_KEY" in config_script:

		return str(
			config_script.FIREBASE_API_KEY
		)

	if "API_KEY" in config_script:

		return str(
			config_script.API_KEY
		)

	if Firebase.Firestore._config.has("apiKey"):

		return str(
			Firebase.Firestore._config["apiKey"]
		)

	print("[AddTeacher] Firebase API key not found.")

	return ""


# ============================================================
# FIREBASE ERROR PARSER
# ============================================================

func _parse_firebase_error(response_text: String) -> String:

	var json := JSON.new()

	if json.parse(response_text) != OK:
		return "Firebase Authentication request failed."

	var data = json.data

	if not data is Dictionary:
		return "Firebase Authentication request failed."

	var error_data = data.get(
		"error",
		{}
	)

	if not error_data is Dictionary:
		return "Firebase Authentication request failed."

	var message := str(
		error_data.get(
			"message",
			""
		)
	)

	match message:

		"EMAIL_EXISTS":
			return "That email address is already registered."

		"INVALID_EMAIL":
			return "The email address is invalid."

		"WEAK_PASSWORD":
			return "The password is too weak."

		"OPERATION_NOT_ALLOWED":
			return "Email/password authentication is disabled."

		_:
			if message.is_empty():
				return "Firebase Authentication request failed."

			return message


# ============================================================
# EMAIL VALIDATION
# ============================================================

func _is_valid_email(email: String) -> bool:

	var regex := RegEx.new()

	regex.compile(
		"^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
	)

	return regex.search(email) != null


# ============================================================
# STATUS
# ============================================================

func _show_status(message: String) -> void:

	status_label.text = message

	print(
		"[AddTeacher] ",
		message
	)


# ============================================================
# CANCEL
# ============================================================

func _on_cancel_button_pressed() -> void:

	print("[AddTeacher] Cancelled.")

	queue_free()

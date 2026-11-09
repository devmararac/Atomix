
extends Control


signal student_created

const FIRESTORE_PROJECT_ID := "atomix-f6c6b"
const FIRESTORE_BASE_URL := "https://firestore.googleapis.com/v1/projects/"
const AUTH_API_URL := "https://atomix-auth-api.atomix-auth.workers.dev"

@onready var student_id_input: LineEdit = $PageBackground/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer3/VBoxContainer2/StudentIDInput

@onready var first_name_input: LineEdit = $"PageBackground/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer3/HBoxContainer/FirstName/NameInput"
@onready var middle_initial_input: LineEdit = $"PageBackground/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer3/HBoxContainer/Middle Initial/NameInput"
@onready var last_name_input: LineEdit = $"PageBackground/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer3/HBoxContainer2/LastName/NameInput"
@onready var suffix_input: LineEdit = $"PageBackground/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer3/HBoxContainer2/Suffix/NameInput"

@onready var section_input: OptionButton = $PageBackground/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/VBoxContainer4/SectionInput
@onready var email_input: LineEdit = $PageBackground/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/VBoxContainer5/EmailInput
@onready var password_input: LineEdit = $PageBackground/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/VBoxContainer6/PasswordInput
@onready var status_label: Label = $PageBackground/Panel/MarginContainer/VBoxContainer/StatusLabel

@onready var email_generate_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/VBoxContainer5/EmailInput/Button
@onready var password_toggle_button: TextureButton = $PageBackground/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/VBoxContainer6/PasswordInput/HBoxContainer/TextureButton
@onready var password_generate_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/VBoxContainer6/PasswordInput/HBoxContainer/Button

@onready var cancel_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/Buttons/CancelButton
@onready var create_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/Buttons/CreateButton

var assigned_sections: Array = []
var current_teacher_uid: String = ""
var current_role: String = ""
var is_creating_student: bool = false

# Edit mode
var is_editing_student: bool = false
var editing_student_data: Dictionary = {}
var original_student_email: String = ""


func _ready() -> void:
	current_teacher_uid = AuthManager.get_uid()

	print("[AddStudent] Current UID: ", current_teacher_uid)

	email_generate_button.pressed.connect(_on_generate_email_pressed)
	password_generate_button.pressed.connect(_on_generate_password_pressed)
	password_toggle_button.pressed.connect(_on_toggle_password_visibility)

	password_input.secret = true
	
	# LRN: numbers only, maximum 12 digits.
	student_id_input.max_length = 11
	student_id_input.text_changed.connect(_on_lrn_text_changed)
	
	await _load_teacher_sections()

func setup_for_edit(student_data: Dictionary) -> void:
	is_editing_student = true
	editing_student_data = student_data.duplicate(true)

	# Keep the original UID and email for the existing account.
	original_student_email = str(student_data.get("email", "")).strip_edges()

	var full_name := str(student_data.get("name", "")).strip_edges()
	var name_parts := full_name.split(" ", false)

	# Fill the name fields from the saved full name.
	# If the database stores separate name fields, use those first.
	if student_data.has("first_name"):
		first_name_input.text = str(student_data.get("first_name", ""))
		middle_initial_input.text = str(student_data.get("middle_initial", ""))
		last_name_input.text = str(student_data.get("last_name", ""))
		suffix_input.text = str(student_data.get("suffix", ""))
	else:
		# The current create_student_document() stores only "name".
		# Use a basic fallback split for existing records.
		first_name_input.text = ""
		middle_initial_input.text = ""
		last_name_input.text = ""
		suffix_input.text = ""

		if name_parts.size() >= 2:
			first_name_input.text = name_parts[0]
			last_name_input.text = " ".join(name_parts.slice(1))
		elif name_parts.size() == 1:
			first_name_input.text = name_parts[0]

	student_id_input.text = str(
		student_data.get("student_id", student_data.get("lrn", ""))
	)

	email_input.text = original_student_email

	# Existing accounts should not need a new password.
	password_input.text = ""
	password_input.placeholder_text = "Leave blank to keep existing password"
	password_input.editable = false
	email_input.editable = false

	# Select the student's existing section.
	var saved_section := str(student_data.get("section", "")).strip_edges()
	var section_found := false

	for i in range(section_input.item_count):
		if section_input.get_item_text(i).strip_edges() == saved_section:
			section_input.select(i)
			section_found = true
			break

	if not section_found:
		push_warning("[AddStudent] Saved section was not found in the available sections: " + saved_section)

	create_button.text = "Save Changes"
	status_label.text = "Edit student details."
	show()
	move_to_front()

func _on_lrn_text_changed(new_text: String) -> void:
	var numbers_only := ""

	for character in new_text:
		if character >= "0" and character <= "9":
			numbers_only += character

	if new_text != numbers_only:
		var cursor_position := student_id_input.caret_column
		student_id_input.text = numbers_only
		student_id_input.caret_column = mini(cursor_position, numbers_only.length())

# ============================================================
# FORM VALIDATION
# ============================================================

func _validate_form() -> Dictionary:
	var first_name := first_name_input.text.strip_edges()
	var middle_initial := middle_initial_input.text.strip_edges()
	var last_name := last_name_input.text.strip_edges()
	var suffix := suffix_input.text.strip_edges()
	var lrn := student_id_input.text.strip_edges()
	var email := email_input.text.strip_edges().to_lower()
	var password := password_input.text

	if first_name.is_empty():
		return {"valid": false, "message": "Please enter the student's first name."}

	if not _is_valid_person_name(first_name):
		return {"valid": false, "message": "First name contains invalid characters."}

	if middle_initial.length() > 1:
		var cleaned_middle := middle_initial.replace(".", "")
		if cleaned_middle.length() > 1:
			return {"valid": false, "message": "Enter only one middle initial."}

	if not middle_initial.is_empty() and not _is_valid_person_name(middle_initial.replace(".", "")):
		return {"valid": false, "message": "Middle initial contains invalid characters."}

	if last_name.is_empty():
		return {"valid": false, "message": "Please enter the student's last name."}

	if not _is_valid_person_name(last_name):
		return {"valid": false, "message": "Last name contains invalid characters."}

	if not suffix.is_empty() and not _is_valid_person_name(suffix.replace(".", "")):
		return {"valid": false, "message": "Suffix contains invalid characters."}

	# Philippine Learner Reference Number: 12 digits.
	if not lrn.is_valid_int() or lrn.length() != 11:
		return {"valid": false, "message": "LRN must contain exactly 11 digits."}

	for character in lrn:
		if not character.is_valid_int():
			return {"valid": false, "message": "LRN must contain digits only."}

	if section_input.disabled or section_input.selected <= 0:
		return {"valid": false, "message": "Please select an assigned section."}

	if email.is_empty():
		return {"valid": false, "message": "Please enter or generate an email address."}

	if not _is_valid_email(email):
		return {"valid": false, "message": "Please enter a valid email address."}

	if password.is_empty():
		return {"valid": false, "message": "Please enter or generate a password."}

	if password.length() < 6:
		return {"valid": false, "message": "Password must be at least 6 characters."}

	if password.length() > 128:
		return {"valid": false, "message": "Password must not exceed 128 characters."}

	return {
		"valid": true,
		"message": "",
		"first_name": first_name,
		"middle_initial": middle_initial,
		"last_name": last_name,
		"suffix": suffix,
		"lrn": lrn,
		"email": email,
		"password": password,
		"section": section_input.get_item_text(section_input.selected).strip_edges()
	}


func _is_valid_person_name(value: String) -> bool:
	if value.is_empty():
		return false

	for character in value:
		if character == " " or character == "-" or character == "'" or character == ".":
			continue

		if not character.is_valid_identifier():
			return false

		if character.to_lower() == character.to_upper():
			return false

	return true


func _is_valid_email(value: String) -> bool:
	var at_position := value.find("@")
	if at_position <= 0:
		return false

	if at_position != value.rfind("@"):
		return false

	var domain := value.substr(at_position + 1)
	if domain.is_empty() or not domain.contains("."):
		return false

	if domain.begins_with(".") or domain.ends_with("."):
		return false

	if value.contains(" "):
		return false

	return true


func _build_student_name(form: Dictionary) -> String:
	var parts: Array[String] = []

	parts.append(str(form["first_name"]))

	var middle := str(form["middle_initial"]).strip_edges()
	if not middle.is_empty():
		middle = middle.trim_suffix(".")
		parts.append(middle + ".")

	parts.append(str(form["last_name"]))

	var suffix := str(form["suffix"]).strip_edges()
	if not suffix.is_empty():
		parts.append(suffix)

	return " ".join(parts)


# ============================================================
# EMAIL AND PASSWORD BUTTONS
# ============================================================

func _on_generate_email_pressed() -> void:
	var first_name := first_name_input.text.strip_edges().to_lower()
	var last_name := last_name_input.text.strip_edges().to_lower()

	if first_name.is_empty() or last_name.is_empty():
		show_status("Enter the first and last name before generating an email.")
		return

	first_name = _email_name_part(first_name)
	last_name = _email_name_part(last_name)

	if first_name.is_empty() or last_name.is_empty():
		show_status("The name cannot be used to generate an email.")
		return

	email_input.text = first_name + "." + last_name + "@gmail.com"
	show_status("Generated email. Check it before creating the account.")


func _email_name_part(value: String) -> String:
	var result := ""

	for character in value:
		var code := character.unicode_at(0)
		var is_letter := (
			(code >= 97 and code <= 122)
			or (code >= 48 and code <= 57)
		)

		if is_letter:
			result += character

	return result


func _on_generate_password_pressed() -> void:
	var lrn := student_id_input.text.strip_edges()
	var last_name := last_name_input.text.strip_edges()

	if lrn.length() < 4:
		status_label.text = "Enter at least 4 digits of the LRN first."
		return

	if last_name.is_empty():
		status_label.text = "Enter the student's last name first."
		return

	var generated_password := lrn.substr(0, 4) + last_name.replace(" ", "")
	password_input.text = generated_password
	password_input.secret = true


func _on_toggle_password_visibility() -> void:
	password_input.secret = not password_input.secret


# ============================================================
# FIREBASE AUTHENTICATION
# ============================================================

func create_firebase_account(email: String, password: String) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)

	var url := (
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

	var request_error := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if request_error != OK:
		push_error("[AddStudent] Could not start Authentication request: " + str(request_error))
		show_status("Unable to connect to Firebase.")
		http.queue_free()
		return {}

	var response: Array = await http.request_completed
	var response_code: int = int(response[1])
	var response_text: String = (response[3] as PackedByteArray).get_string_from_utf8()

	http.queue_free()

	var json := JSON.new()
	if json.parse(response_text) != OK:
		push_error("[AddStudent] Invalid Authentication response: " + response_text)
		show_status("Firebase returned an invalid response.")
		return {}

	var data: Variant = json.data

	if response_code < 200 or response_code >= 300:
		var message := "Unable to create account."

		if data is Dictionary and data.has("error"):
			var error_data: Dictionary = data["error"]
			message = str(error_data.get("message", message))

		match message:
			"EMAIL_EXISTS":
				message = "This email is already registered."
			"INVALID_EMAIL":
				message = "Please enter a valid email address."
			"WEAK_PASSWORD : Password should be at least 6 characters":
				message = "Password must be at least 6 characters."
			"OPERATION_NOT_ALLOWED":
				message = "Email/password sign-in is not enabled in Firebase."

		push_error("[AddStudent] Authentication failed: " + message)
		show_status(message)
		return {}

	if data is Dictionary:
		return data

	return {}


# ============================================================
# FIRESTORE REST API
# ============================================================

# ============================================================
# CLOUDFLARE D1 ACCOUNT REGISTRATION
# ============================================================

func register_account_in_d1(
	student_id: String,
	student_id_token: String
) -> bool:
	var teacher_token := _get_current_id_token()

	if teacher_token.is_empty():
		push_error("[AddStudent] Cannot register D1 mapping: teacher token is missing.")
		return false

	if student_id_token.is_empty():
		push_error("[AddStudent] Cannot register D1 mapping: student token is missing.")
		return false

	var request_body := {
		"callerIdToken": teacher_token,
		"accountIdToken": student_id_token,
		"idNumber": student_id,
		"accountType": "student"
	}

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var http := HTTPRequest.new()
	add_child(http)

	var request_error := http.request(
		AUTH_API_URL + "/register-account",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(request_body)
	)

	if request_error != OK:
		push_error("[AddStudent] Could not start D1 registration request: " + str(request_error))
		http.queue_free()
		return false

	var response: Array = await http.request_completed
	var result_code := int(response[1])
	var response_text := (response[3] as PackedByteArray).get_string_from_utf8()

	http.queue_free()

	var parsed = JSON.parse_string(response_text)

	if result_code != 200 or not parsed is Dictionary:
		push_error(
			"[AddStudent] D1 registration failed. HTTP "
			+ str(result_code)
			+ " | Response: "
			+ response_text
		)
		return false

	if not bool(parsed.get("success", false)):
		push_error(
			"[AddStudent] D1 rejected registration: "
			+ str(parsed.get("message", "Unknown error."))
		)
		return false

	print("[AddStudent] Student LRN successfully registered in D1: ", student_id)
	return true


func sync_existing_account_in_d1(account_uid: String) -> bool:
	var caller_token := _get_current_id_token()

	if caller_token.is_empty():
		push_error("[AddStudent] Cannot sync D1: caller token is missing.")
		return false

	if account_uid.is_empty():
		push_error("[AddStudent] Cannot sync D1: account UID is missing.")
		return false

	var request_body := {
		"callerIdToken": caller_token,
		"accountUid": account_uid,
		"accountType": "student"
	}

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var http := HTTPRequest.new()
	add_child(http)

	var request_error := http.request(
		AUTH_API_URL + "/admin-sync-account",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(request_body)
	)

	if request_error != OK:
		push_error(
			"[AddStudent] Could not start existing-account D1 sync: "
			+ str(request_error)
		)
		http.queue_free()
		return false

	var response: Array = await http.request_completed
	var response_code := int(response[1])
	var response_text := (response[3] as PackedByteArray).get_string_from_utf8()

	http.queue_free()

	var parsed = JSON.parse_string(response_text)

	if response_code != 200 or not parsed is Dictionary:
		push_error(
			"[AddStudent] Existing-account D1 sync failed. HTTP "
			+ str(response_code)
			+ " | Response: "
			+ response_text
		)
		return false

	if not bool(parsed.get("success", false)):
		push_error(
			"[AddStudent] Worker rejected existing-account sync: "
			+ str(parsed.get("message", "Unknown error."))
		)
		return false

	print(
		"[AddStudent] Existing student successfully synchronized with D1. UID: ",
		account_uid
	)

	return true


func _get_current_id_token() -> String:
	if Firebase.Auth == null:
		return ""

	var auth_data: Dictionary = Firebase.Auth.auth
	var token := str(auth_data.get("idtoken", ""))

	if token.is_empty():
		token = str(auth_data.get("idToken", ""))

	return token


func _to_firestore_value(value: Variant) -> Dictionary:
	if value == null:
		return {"nullValue": null}

	if value is bool:
		return {"booleanValue": value}

	if value is int:
		return {"integerValue": str(value)}

	if value is float:
		return {"doubleValue": value}

	if value is Dictionary:
		var fields: Dictionary = {}
		for key in value.keys():
			fields[str(key)] = _to_firestore_value(value[key])
		return {"mapValue": {"fields": fields}}

	if value is Array:
		var values: Array = []
		for item in value:
			values.append(_to_firestore_value(item))
		return {"arrayValue": {"values": values}}

	return {"stringValue": str(value)}


func _write_firestore_document(
	collection_name: String,
	document_id: String,
	data: Dictionary
) -> bool:
	var token := _get_current_id_token()

	if token.is_empty():
		push_error("[AddStudent] Firestore write cancelled: teacher ID token is empty.")
		return false

	var url := (
		FIRESTORE_BASE_URL
		+ FIRESTORE_PROJECT_ID
		+ "/databases/(default)/documents/"
		+ collection_name
		+ "/"
		+ document_id
	)

	var fields: Dictionary = {}
	for key in data.keys():
		fields[str(key)] = _to_firestore_value(data[key])

	var request_body := JSON.stringify({"fields": fields})
	var headers := PackedStringArray([
		"Authorization: Bearer " + token,
		"Content-Type: application/json"
	])

	var http := HTTPRequest.new()
	add_child(http)

	var request_error := http.request(
		url,
		headers,
		HTTPClient.METHOD_PATCH,
		request_body
	)

	if request_error != OK:
		push_error("[AddStudent] Could not start Firestore request: " + str(request_error))
		http.queue_free()
		return false

	var response: Array = await http.request_completed
	var response_code := int(response[1])
	var response_text := (response[3] as PackedByteArray).get_string_from_utf8()

	http.queue_free()

	if response_code < 200 or response_code >= 300:
		push_error(
			"[AddStudent] Firestore write failed for "
			+ collection_name + "/" + document_id
			+ " | HTTP " + str(response_code)
			+ " | Response: " + response_text
		)
		return false

	print("[AddStudent] Firestore write succeeded: ", collection_name, "/", document_id)
	return true

func _patch_firestore_fields(
	collection_name: String,
	document_id: String,
	data: Dictionary
) -> bool:
	var token := _get_current_id_token()

	if token.is_empty():
		push_error("[AddStudent] Cannot update Firestore: ID token is empty.")
		return false

	var url := (
		FIRESTORE_BASE_URL
		+ FIRESTORE_PROJECT_ID
		+ "/databases/(default)/documents/"
		+ collection_name
		+ "/"
		+ document_id
	)

	var mask_parts: PackedStringArray = []

	for field_name in data.keys():
		mask_parts.append(
			"updateMask.fieldPaths=" + str(field_name).uri_encode()
		)

	url += "?" + "&".join(mask_parts)

	var fields: Dictionary = {}
	for key in data.keys():
		fields[str(key)] = _to_firestore_value(data[key])

	var request_body := JSON.stringify({"fields": fields})
	var headers := PackedStringArray([
		"Authorization: Bearer " + token,
		"Content-Type: application/json"
	])

	var http := HTTPRequest.new()
	add_child(http)

	var request_error := http.request(
		url,
		headers,
		HTTPClient.METHOD_PATCH,
		request_body
	)

	if request_error != OK:
		push_error("[AddStudent] Could not start Firestore update: " + str(request_error))
		http.queue_free()
		return false

	var response: Array = await http.request_completed
	var response_code := int(response[1])
	var response_text := (response[3] as PackedByteArray).get_string_from_utf8()

	http.queue_free()

	if response_code < 200 or response_code >= 300:
		push_error(
			"[AddStudent] Update failed for "
			+ collection_name + "/" + document_id
			+ " | HTTP " + str(response_code)
			+ " | " + response_text
		)
		return false

	return true

# ============================================================
# CREATE FIRESTORE DOCUMENTS
# ============================================================

func create_student_document(
	uid: String,
	student_name: String,
	student_id: String,
	section: String,
	email: String
) -> bool:
	var timestamp := int(Time.get_unix_time_from_system())
	var current_school_year := SchoolYearManager.get_school_year_for_timestamp(timestamp)
	var archive_at := SchoolYearManager.get_archive_timestamp(timestamp)

	var user_data := {
		"name": student_name,
		"email": email,
		"role": "student",
		"status": "active",
		"school_year": current_school_year,
		"enrolled_at": timestamp,
		"archive_at": archive_at,
		"created_at": timestamp,
		"last_active": 0
	}

	var student_data := {
		"uid": uid,
		"name": student_name,
		"email": email,
		"role": "student",
		"student_id": student_id,
		"section": section,
		"teacher_id": current_teacher_uid,
		"school_year": current_school_year,
		"enrolled_at": timestamp,
		"archive_at": archive_at,
		"status": "active",
		"created_at": timestamp,
		"last_active": 0,
		"progress": {
			"elements_total": 118,
			"elements_collected": 0,
			"collected_elements": [],
			"overall_percentage": 0.0
		},
		"lesson_progress": {},
		"assessment": {
			"total_assessments": 0,
			"completed_assessments": 0,
			"average_score": 0.0,
			"latest_score": 0.0
		},
		"battle_stats": {
			"battles_played": 0,
			"battles_won": 0,
			"battles_lost": 0,
			"battles_escaped": 0
		},
		"academic_history": {},
		"game_state": {
			"has_save": false,
			"current_scene": "res://Scenes/Areas/start_map.tscn",
			"player_position": {"x": 0.0, "y": 0.0},
			"coins": 0,
			"active_index": 0,
			"party": [],
			"inventory": [],
			"quest_data": {}
		}
	}

	var leaderboard_data := {
		"uid": uid,
		"name": student_name,
		"section": section,
		"teacher_id": current_teacher_uid,
		"status": "active",
		"elements_collected": 0,
		"elements_total": 118,
		"battles_played": 0,
		"battles_won": 0,
		"battles_lost": 0,
		"battles_escaped": 0,
		"win_rate": 0.0,
		"average_quiz_score": 0.0,
		"completed_quizzes": 0,
		"total_quizzes": 0,
		"overall_score": 0.0
	}

	print("[AddStudent] Writing users document for UID: ", uid)
	if not await _write_firestore_document("users", uid, user_data):
		return false

	print("[AddStudent] Writing students document for UID: ", uid)
	if not await _write_firestore_document("students", uid, student_data):
		push_error("[AddStudent] Student account exists, but the students document failed.")
		return false

	print("[AddStudent] Writing leaderboard document for UID: ", uid)
	if not await _write_firestore_document("leaderboard", uid, leaderboard_data):
		push_warning("[AddStudent] Student records saved, but leaderboard creation failed.")
		# The primary account and student records exist.
		# Do not report total failure for a leaderboard-only issue.

	print("[AddStudent] Student Firestore records processed.")
	return true


# ============================================================
# CREATE STUDENT BUTTON
# ============================================================

func _on_create_button_pressed() -> void:
	if is_creating_student:
		return

	# Editing an existing student follows a separate save path.
	if is_editing_student:
		await _save_student_changes()
		return

	var form := _validate_form()

	if not bool(form.get("valid", false)):
		show_status(str(form.get("message", "Please check the form.")))
		return

	is_creating_student = true
	create_button.disabled = true
	cancel_button.disabled = true
	email_generate_button.disabled = true
	password_generate_button.disabled = true

	show_status("Creating student account...")

	var student_name := _build_student_name(form)
	var student_id := str(form["lrn"])
	var section := str(form["section"])
	var email := str(form["email"])
	var password := str(form["password"])

	print("[AddStudent] Creating student: ", student_name)
	print("[AddStudent] Email: ", email)

	var auth_result := await create_firebase_account(email, password)

	if auth_result.is_empty():
		_reset_form_buttons()
		return

	var new_student_uid := str(auth_result.get("localId", ""))

	if new_student_uid.is_empty():
		show_status("Firebase did not return a student UID.")
		_reset_form_buttons()
		return

	print("[AddStudent] Authentication succeeded. UID: ", new_student_uid)
	show_status("Saving student records...")

	var firestore_success := await create_student_document(
		new_student_uid,
		student_name,
		student_id,
		section,
		email
	)

	if not firestore_success:
		show_status(
			"Account created, but student records could not be saved. "
			+ "Check the debugger."
		)
		_reset_form_buttons()
		return
		
	# Register the verified student account in Cloudflare D1.
	show_status("Registering student LRN for login...")

	var student_token := str(auth_result.get("idToken", ""))

	var d1_success := await register_account_in_d1(
		student_id,
		student_token
	)

	if not d1_success:
		show_status(
			"Student account and Firestore records were created, "
			+ "but LRN login registration failed. Check the debugger."
		)
		_reset_form_buttons()
		return

	# Record successful student creation in the activity log.
	ActivityLogManager.log_activity(
		"Created Student Account",
		"Created student account for " + student_name
			+ " | Section: " + section
			+ " | Student ID: " + student_id,
		"Student Accounts",
		new_student_uid
	)

	print("[AddStudent] Student created successfully: ", new_student_uid)
	show_status("Student account created successfully!")

	await get_tree().create_timer(1.0).timeout
	student_created.emit()
	_reset_form_buttons()

func _save_student_changes() -> void:
	if editing_student_data.is_empty():
		show_status("No student is selected for editing.")
		return

	var uid := str(editing_student_data.get("uid", "")).strip_edges()

	if uid.is_empty():
		show_status("Cannot update this student because the UID is missing.")
		return

	var first_name := first_name_input.text.strip_edges()
	var middle_initial := middle_initial_input.text.strip_edges()
	var last_name := last_name_input.text.strip_edges()
	var suffix := suffix_input.text.strip_edges()
	var lrn := student_id_input.text.strip_edges()

	if first_name.is_empty() or last_name.is_empty():
		show_status("Please enter the student's first and last name.")
		return

	if not _is_valid_person_name(first_name) or not _is_valid_person_name(last_name):
		show_status("Please check the student's name fields.")
		return

	if lrn.length() != 11 or not lrn.is_valid_int():
		show_status("LRN must contain exactly 11 digits.")
		return

	if section_input.disabled or section_input.selected <= 0:
		show_status("Please select a section.")
		return

	var section := section_input.get_item_text(section_input.selected).strip_edges()

	var form_data := {
		"first_name": first_name,
		"middle_initial": middle_initial,
		"last_name": last_name,
		"suffix": suffix
	}

	var student_name := _build_student_name(form_data)

	is_creating_student = true
	create_button.disabled = true
	cancel_button.disabled = true

	show_status("Saving student changes...")

	# Update only the intended fields. Do not overwrite progress or game state.
	var student_update := {
		"name": student_name,
		"first_name": first_name,
		"middle_initial": middle_initial,
		"last_name": last_name,
		"suffix": suffix,
		"student_id": lrn,
		"section": section
	}

	var success := await _patch_firestore_fields("students", uid, student_update)

	if success:
		# Record successful student update in the activity log.
		ActivityLogManager.log_activity(
			"Updated Student Account",
			"Updated student details for " + student_name
				+ " | Section: " + section
				+ " | Student ID: " + lrn,
			"Student Accounts",
			uid
		)

		# Keep the display name consistent in the users document.
		var user_update := {
			"name": student_name
		}
		var user_success := await _patch_firestore_fields("users", uid, user_update)
		
		
				# Register or update the existing student's LRN mapping in D1.
		show_status("Synchronizing student login information...")

		var d1_success := await sync_existing_account_in_d1(uid)

		if not d1_success:
			push_warning(
				"[AddStudent] Firestore changes were saved, "
				+ "but the student's D1 login mapping was not synchronized."
			)
		
		# Update the leaderboard's name and section, if that record exists.
		var leaderboard_update := {
			"name": student_name,
			"section": section
		}
		var leaderboard_success := await _patch_firestore_fields("leaderboard", uid, leaderboard_update)

		if not user_success:
			push_warning("[AddStudent] Student details saved, but the users document name was not updated.")

		if not leaderboard_success:
			push_warning("[AddStudent] Student details saved, but the leaderboard was not updated.")

		if d1_success:
			show_status("Student details and login information updated successfully.")
		else:
			show_status(
				"Student details were saved, but login information "
				+ "could not be synchronized. Check the debugger."
			)
		_reset_form_buttons()

		await get_tree().create_timer(0.5).timeout
		student_created.emit()
		_reset_form_buttons()
		_reset_edit_mode()
	else:
		show_status("Could not update the student. Check the debugger.")
		_reset_form_buttons()

func _reset_edit_mode() -> void:
	is_editing_student = false
	editing_student_data.clear()
	original_student_email = ""

	create_button.text = "Create Student"
	email_input.editable = true
	password_input.editable = true
	password_input.placeholder_text = ""

	first_name_input.clear()
	middle_initial_input.clear()
	last_name_input.clear()
	suffix_input.clear()
	student_id_input.clear()
	email_input.clear()
	password_input.clear()

	if section_input.item_count > 0:
		section_input.select(0)

	hide()

func _reset_form_buttons() -> void:
	is_creating_student = false
	create_button.disabled = false
	cancel_button.disabled = false
	email_generate_button.disabled = false
	password_generate_button.disabled = false


# ============================================================
# LOAD TEACHER SECTIONS
# ============================================================

func _load_teacher_sections() -> void:
	print("[AddStudent] Loading teacher assigned sections...")

	current_role = str(await AuthManager.get_user_role())

	if current_role != "teacher":
		print("[AddStudent] Current user is not a teacher.")
		_configure_empty_sections()
		return

	current_teacher_uid = AuthManager.get_uid()

	if current_teacher_uid.is_empty():
		push_error("[AddStudent] Teacher UID is empty.")
		_configure_empty_sections()
		return

	assigned_sections = await TeacherDataManager.get_current_teacher_sections()

	print("[AddStudent] Assigned sections: ", assigned_sections)

	section_input.clear()
	section_input.add_item("Select Section")

	for section in assigned_sections:
		var section_name := str(section).strip_edges()

		if not section_name.is_empty():
			section_input.add_item(section_name)

	section_input.select(0)

	if section_input.item_count <= 1:
		_configure_empty_sections()


func _configure_empty_sections() -> void:
	section_input.clear()
	section_input.add_item("No Sections Assigned")
	section_input.select(0)
	section_input.disabled = true


# ============================================================
# STATUS AND CANCEL
# ============================================================

func show_status(message: String) -> void:
	status_label.text = message
	print("[AddStudent] ", message)


func _on_cancel_button_pressed() -> void:
	if is_creating_student:
		return

	if is_editing_student:
		_reset_edit_mode()
	else:
		hide()

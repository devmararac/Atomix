
extends Control

signal teacher_created

const PROJECT_ID := "atomix-f6c6b"
const FIRESTORE_BASE := "https://firestore.googleapis.com/v1/projects/"
const NORMAL_LABEL_COLOR := Color("#785A3C")
const ERROR_LABEL_COLOR := Color.RED
const ID_NUMBER_LENGTH := 11

enum FormMode {
	ADD,
	EDIT
}

@onready var id_input: LineEdit = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer2/VBoxContainer4/IDInput
@onready var first_name_input: LineEdit = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer2/FirstName/NameInput
@onready var middle_initial_input: LineEdit = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer2/MiddleInitial/NameInput
@onready var last_name_input: LineEdit = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer3/LastName/NameInput
@onready var suffix_input: LineEdit = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer3/Suffix/NameInput
@onready var email_input: LineEdit = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/EmailInput
@onready var password_input: LineEdit = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer2/PasswordInput

@onready var generate_email_button: Button = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/EmailInput/Button
@onready var generate_password_button: Button = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer2/PasswordInput/HBoxContainer/Button
@onready var hide_show_button: Button = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer2/PasswordInput/HBoxContainer/Hide_Show

@onready var create_button: Button = $PageBackground/FormPanel/VBoxContainer/ButtonContainer/CreateButton
@onready var cancel_button: Button = $PageBackground/FormPanel/VBoxContainer/ButtonContainer/CancelButton

@onready var id_label: Label = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer2/VBoxContainer4/IDLabel
@onready var first_name_label: Label = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer2/FirstName/NameLabel
@onready var last_name_label: Label = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer3/LastName/HBoxContainer/NameLabel
@onready var email_label: Label = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/EmailLabel
@onready var password_label: Label = $PageBackground/FormPanel/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer2/PasswordLabel
@onready var status_label: Label = get_node_or_null("PageBackground/FormPanel/VBoxContainer/StatusLabel")

var is_creating: bool = false
var form_mode: FormMode = FormMode.ADD
var editing_teacher: Dictionary = {}
var create_attempted: bool = false


func _ready() -> void:
	print("[AddTeacher] Teacher form ready.")

	id_input.max_length = ID_NUMBER_LENGTH

	id_input.text_changed.connect(_on_id_number_changed)
	first_name_input.text_changed.connect(_on_required_field_changed)
	last_name_input.text_changed.connect(_on_required_field_changed)
	email_input.text_changed.connect(_on_required_field_changed)
	password_input.text_changed.connect(_on_required_field_changed)

	generate_email_button.pressed.connect(_on_generate_email_pressed)
	generate_password_button.pressed.connect(_on_generate_password_pressed)
	hide_show_button.pressed.connect(_on_hide_show_pressed)

	if not create_button.pressed.is_connected(_on_create_button_pressed):
		create_button.pressed.connect(_on_create_button_pressed)

	if not cancel_button.pressed.is_connected(_on_cancel_button_pressed):
		cancel_button.pressed.connect(_on_cancel_button_pressed)

	hide_show_button.tooltip_text = "Show password"
	_update_required_field_labels()
	
	generate_email_button.pressed.connect(func():
		print("[AddTeacher] Generate Email button clicked.")
	)

	generate_password_button.pressed.connect(func():
		print("[AddTeacher] Generate Password button clicked.")
	)
	
	generate_email_button.button_down.connect(
	func():
		print("[TEST] Email Generate button DOWN")
)

	generate_email_button.button_up.connect(
		func():
			print("[TEST] Email Generate button UP")
	)

	generate_password_button.button_down.connect(
		func():
			print("[TEST] Password Generate button DOWN")
	)

	generate_password_button.button_up.connect(
		func():
			print("[TEST] Password Generate button UP")
	)
	
	print("[AddTeacher] Email button:")
	print("  Disabled: ", generate_email_button.disabled)
	print("  Visible: ", generate_email_button.is_visible_in_tree())
	print("  Mouse filter: ", generate_email_button.mouse_filter)
	print("  Global rect: ", generate_email_button.get_global_rect())

	print("[AddTeacher] Password button:")
	print("  Disabled: ", generate_password_button.disabled)
	print("  Visible: ", generate_password_button.is_visible_in_tree())
	print("  Mouse filter: ", generate_password_button.mouse_filter)
	print("  Global rect: ", generate_password_button.get_global_rect())

# ------------------------------------------------------------
# PASSWORD VISIBILITY
# ------------------------------------------------------------

func _on_hide_show_pressed() -> void:
	password_input.secret = not password_input.secret

	if password_input.secret:
		hide_show_button.tooltip_text = "Show password"
	else:
		hide_show_button.tooltip_text = "Hide password"


# ------------------------------------------------------------
# FIREBASE AUTHENTICATION TOKEN
# ------------------------------------------------------------

func _get_current_admin_id_token() -> String:
	if Firebase.Auth != null:
		var auth_data: Dictionary = Firebase.Auth.auth
		var token: String = str(auth_data.get("idtoken", ""))

		if token.is_empty():
			token = str(auth_data.get("idToken", ""))

		if not token.is_empty():
			return token

	if Firebase.Firestore != null:
		var firestore_auth: Variant = Firebase.Firestore.auth

		if firestore_auth is Dictionary:
			var auth_data: Dictionary = firestore_auth
			var token: String = str(auth_data.get("idtoken", ""))

			if token.is_empty():
				token = str(auth_data.get("idToken", ""))

			if not token.is_empty():
				return token

	return ""


func _firestore_url(path: String) -> String:
	return FIRESTORE_BASE + PROJECT_ID + path


func _firestore_headers() -> PackedStringArray:
	var token := _get_current_admin_id_token()

	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	])


# ------------------------------------------------------------
# FORM VALUES
# ------------------------------------------------------------

func _get_full_name() -> String:
	var parts: Array[String] = []

	var first_name := first_name_input.text.strip_edges()
	var middle_initial := middle_initial_input.text.strip_edges()
	var last_name := last_name_input.text.strip_edges()
	var suffix := suffix_input.text.strip_edges()

	if not first_name.is_empty():
		parts.append(first_name)

	if not middle_initial.is_empty():
		parts.append(middle_initial)

	if not last_name.is_empty():
		parts.append(last_name)

	if not suffix.is_empty():
		parts.append(suffix)

	return " ".join(parts)


# ------------------------------------------------------------
# VALIDATION
# ------------------------------------------------------------

func _on_id_number_changed(new_text: String) -> void:
	var digits_only := ""

	for character in new_text:
		if character >= "0" and character <= "9":
			digits_only += character

	if new_text != digits_only:
		var cursor_position := id_input.caret_column
		id_input.text = digits_only
		id_input.caret_column = min(cursor_position, digits_only.length())

	_update_required_field_labels()


func _on_required_field_changed(_new_text: String) -> void:
	_update_required_field_labels()

func _update_required_field_labels() -> void:
	var show_errors := create_attempted
	var id_number := id_input.text.strip_edges()
	var email := email_input.text.strip_edges()
	var password := password_input.text

	_set_label_error(
		id_label,
		show_errors and (
			id_number.length() != ID_NUMBER_LENGTH
			or not _contains_digits_only(id_number)
		)
	)

	_set_label_error(
		first_name_label,
		show_errors and first_name_input.text.strip_edges().is_empty()
	)

	_set_label_error(
		last_name_label,
		show_errors and last_name_input.text.strip_edges().is_empty()
	)

	_set_label_error(
		email_label,
		show_errors and not _is_valid_email(email)
	)

	_set_label_error(
		password_label,
		show_errors and password.is_empty()
	)


func _contains_digits_only(value: String) -> bool:
	if value.is_empty():
		return false

	for character in value:
		if character < "0" or character > "9":
			return false

	return true


func _set_label_error(label: Label, has_error: bool) -> void:
	label.add_theme_color_override(
		"font_color",
		ERROR_LABEL_COLOR if has_error else NORMAL_LABEL_COLOR
	)


func _is_valid_email(email: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")
	return regex.search(email) != null


func _validate_form() -> bool:
	var id_number := id_input.text.strip_edges()
	var first_name := first_name_input.text.strip_edges()
	var last_name := last_name_input.text.strip_edges()
	var email := email_input.text.strip_edges()
	var password := password_input.text

	if not _contains_digits_only(id_number) or id_number.length() != ID_NUMBER_LENGTH:
		_show_status("ID number/LRN must contain exactly 11 digits.")
		id_input.grab_focus()
		return false

	if first_name.is_empty():
		_show_status("Please enter the teacher's first name.")
		first_name_input.grab_focus()
		return false

	if last_name.is_empty():
		_show_status("Please enter the teacher's last name.")
		last_name_input.grab_focus()
		return false

	if not _is_valid_email(email):
		_show_status("Please enter a valid email address.")
		email_input.grab_focus()
		return false
	
	if password.is_empty():
		_show_status("Please generate or enter a password.")
		password_input.grab_focus()
		return false

	return true


# ------------------------------------------------------------
# GENERATE EMAIL
# ------------------------------------------------------------

func _on_generate_email_pressed() -> void:
	var first_name := first_name_input.text.strip_edges().to_lower()
	var last_name := last_name_input.text.strip_edges().to_lower()

	if first_name.is_empty() or last_name.is_empty():
		_show_status("Enter the teacher's first and last name first.")
		return

	email_input.text = (
		first_name.replace(" ", "")
		+ "."
		+ last_name.replace(" ", "")
		+ "@gmail.com"
	)

	_update_required_field_labels()
	_show_status("Email generated. Verify that the address is available before creating the account.")


# ------------------------------------------------------------
# GENERATE PASSWORD
# ------------------------------------------------------------

func _on_generate_password_pressed() -> void:
	var id_number := id_input.text.strip_edges()
	var last_name := last_name_input.text.strip_edges()

	if id_number.length() != ID_NUMBER_LENGTH or not _contains_digits_only(id_number):
		_show_status("Enter an ID number/LRN containing exactly 11 digits first.")
		id_input.grab_focus()
		return

	if last_name.is_empty():
		_show_status("Enter the teacher's last name first.")
		last_name_input.grab_focus()
		return

	# Password format: first 4 digits of ID/LRN + last name.
	password_input.text = id_number.substr(0, 4) + last_name
	password_input.secret = true
	hide_show_button.tooltip_text = "Show password"

	_update_required_field_labels()
	_show_status("Password generated. Use Show to check it before creating the account.")


# ------------------------------------------------------------
# ADD / EDIT FORM MODE
# ------------------------------------------------------------

func open_add_mode() -> void:
	form_mode = FormMode.ADD
	editing_teacher.clear()
	_reset_form()

	create_button.text = "Create Teacher"
	password_input.show()
	password_label.show()
	password_input.editable = true
	email_input.editable = true

	# Make sure all form buttons are enabled.
	_set_form_enabled(true)

	show()
	move_to_front()


func open_edit_mode(data: Dictionary) -> void:
	form_mode = FormMode.EDIT
	editing_teacher = data.duplicate(true)
	_reset_form()

	id_input.text = str(data.get("id_number", ""))
	first_name_input.text = str(data.get("first_name", ""))
	middle_initial_input.text = str(data.get("middle_initial", ""))
	last_name_input.text = str(data.get("last_name", ""))
	suffix_input.text = str(data.get("suffix", ""))
	email_input.text = str(data.get("email", ""))

	email_input.editable = false
	password_input.hide()
	password_label.hide()

	create_button.text = "Save Changes"

	_set_form_enabled(true)
	_update_required_field_labels()

	show()
	move_to_front()


func _reset_form() -> void:
	id_input.clear()
	first_name_input.clear()
	middle_initial_input.clear()
	last_name_input.clear()
	suffix_input.clear()
	email_input.clear()
	password_input.clear()

	password_input.secret = true
	hide_show_button.tooltip_text = "Show password"

	password_input.show()
	password_label.show()
	password_input.editable = true
	email_input.editable = true

	status_label_clear()
	create_attempted = false
	_update_required_field_labels()


func status_label_clear() -> void:
	if is_instance_valid(status_label):
		status_label.text = ""


# ------------------------------------------------------------
# CREATE TEACHER
# ------------------------------------------------------------

func _on_create_button_pressed() -> void:
	if form_mode == FormMode.EDIT:
		_on_save_teacher_changes_pressed()
		return

	if is_creating:
		return

	create_attempted = true
	_update_required_field_labels()

	if not _validate_form():
		_update_required_field_labels()
		return
	
	var id_number := id_input.text.strip_edges()

	if await _teacher_id_exists(id_number):
		_update_required_field_labels()
		return
		
	var first_name := first_name_input.text.strip_edges()
	var middle_initial := middle_initial_input.text.strip_edges()
	var last_name := last_name_input.text.strip_edges()
	var suffix := suffix_input.text.strip_edges()
	var full_name := _get_full_name()
	var email := email_input.text.strip_edges()
	var password := password_input.text

	is_creating = true
	_set_form_enabled(false)
	_show_status("Creating teacher account...")

	var auth_result: Dictionary = await _create_firebase_auth_account(
		email,
		password
	)

	if not auth_result.get("success", false):
		_finish_creation()
		_show_status(
			"Firebase Authentication failed:\n"
			+ str(auth_result.get("message", "Unknown error."))
		)
		return

	var teacher_uid := str(auth_result.get("uid", ""))

	if teacher_uid.is_empty():
		_finish_creation()
		_show_status("Firebase did not return a teacher UID.")
		return

	var user_data := {
		"uid": teacher_uid,
		"id_number": id_number,
		"name": full_name,
		"first_name": first_name,
		"middle_initial": middle_initial,
		"last_name": last_name,
		"suffix": suffix,
		"email": email,
		"role": "teacher",
		"status": "active"
	}

	var users_ok: bool = await _write_firestore_document(
		"users",
		teacher_uid,
		user_data
	)

	if not users_ok:
		_finish_creation()
		_show_status(
			"Authentication account created, but saving /users failed. "
			+ "Check Firestore rules and authentication."
		)
		return

	var teacher_data := {
		"uid": teacher_uid,
		"id_number": id_number,
		"name": full_name,
		"first_name": first_name,
		"middle_initial": middle_initial,
		"last_name": last_name,
		"suffix": suffix,
		"email": email,
		"role": "teacher",
		"status": "active",
		"created_at": Time.get_unix_time_from_system()
	}

	var teacher_ok: bool = await _write_firestore_document(
		"teachers",
		teacher_uid,
		teacher_data
	)

	if not teacher_ok:
		_finish_creation()
		_show_status(
			"Authentication and /users were created, but saving /teachers failed. "
			+ "Check Firestore rules."
		)
		return

	# Record the successful teacher account creation.
	ActivityLogManager.log_activity(
		"Created Teacher Account",
		"Created teacher account for: " + email,
		"Teacher Management",
		teacher_uid
	)

	_finish_creation()
	_show_status("Teacher created successfully!")
	teacher_created.emit()

	await get_tree().create_timer(1.0).timeout

	if is_inside_tree():
		queue_free()


# ------------------------------------------------------------
# FIREBASE AUTHENTICATION ACCOUNT
# ------------------------------------------------------------

func _create_firebase_auth_account(
	email: String,
	password: String
) -> Dictionary:
	var api_key := _get_firebase_api_key()

	if api_key.is_empty():
		return {
			"success": false,
			"uid": "",
			"message": "Firebase API key could not be found."
		}

	var http := HTTPRequest.new()
	add_child(http)

	var url := (
		"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="
		+ api_key
	)

	var request_body := JSON.stringify({
		"email": email,
		"password": password,
		"returnSecureToken": true
	})

	var error: int = http.request(
		url,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		request_body
	)

	if error != OK:
		http.queue_free()
		return {
			"success": false,
			"uid": "",
			"message": "Could not connect to Firebase Authentication."
		}

	var response: Array = await http.request_completed
	var response_code: int = response[1]
	var response_text: String = (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	http.queue_free()

	var parsed: Variant = JSON.parse_string(response_text)

	if response_code < 200 or response_code >= 300:
		var message := "Firebase Authentication request failed."

		if parsed is Dictionary:
			var error_data: Dictionary = parsed.get("error", {})
			message = str(error_data.get("message", message))

		return {
			"success": false,
			"uid": "",
			"message": message
		}

	if not parsed is Dictionary:
		return {
			"success": false,
			"uid": "",
			"message": "Invalid Firebase response."
		}

	return {
		"success": true,
		"uid": str(parsed.get("localId", "")),
		"message": ""
	}


# ------------------------------------------------------------
# FIRESTORE DOCUMENT WRITING
# ------------------------------------------------------------

func _write_firestore_document(
	collection: String,
	document_id: String,
	data: Dictionary
) -> bool:
	var token := _get_current_admin_id_token()

	if PROJECT_ID.is_empty() or token.is_empty():
		push_error(
			"Missing Firebase project ID or current user's ID token."
		)
		return false

	var url := (
		FIRESTORE_BASE
		+ PROJECT_ID
		+ "/databases/(default)/documents/"
		+ collection
		+ "/"
		+ document_id
	)

	var firestore_fields: Dictionary = {}

	for key in data.keys():
		firestore_fields[str(key)] = _to_firestore_value(data[key])

	var http := HTTPRequest.new()
	add_child(http)

	var request_body := JSON.stringify({
		"fields": firestore_fields
	})

	var headers := PackedStringArray([
		"Authorization: Bearer " + token,
		"Content-Type: application/json"
	])

	var error: int = http.request(
		url,
		headers,
		HTTPClient.METHOD_PATCH,
		request_body
	)

	if error != OK:
		http.queue_free()
		push_error("Could not start the Firestore write request.")
		return false

	var response: Array = await http.request_completed
	var response_code: int = response[1]
	var response_text: String = (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	http.queue_free()

	if response_code < 200 or response_code >= 300:
		push_error(
			"Firestore write failed for %s/%s (HTTP %d): %s"
			% [collection, document_id, response_code, response_text]
		)
		return false

	return true


func _teacher_id_exists(id_number: String) -> bool:
	var token := _get_current_admin_id_token()

	if token.is_empty():
		_show_status("Cannot check duplicate ID: admin authentication is missing.")
		return true

	var collections := ["teachers", "users"]

	for collection in collections:
		var url := (
			FIRESTORE_BASE
			+ PROJECT_ID
			+ "/databases/(default)/documents:runQuery"
		)

		var request_body := JSON.stringify({
			"structuredQuery": {
				"from": [{"collectionId": collection}],
				"where": {
					"fieldFilter": {
						"field": {"fieldPath": "id_number"},
						"op": "EQUAL",
						"value": {"stringValue": id_number}
					}
				},
				"limit": 1
			}
		})

		var http := HTTPRequest.new()
		add_child(http)

		var error := http.request(
			url,
			PackedStringArray([
				"Authorization: Bearer " + token,
				"Content-Type: application/json"
			]),
			HTTPClient.METHOD_POST,
			request_body
		)

		if error != OK:
			http.queue_free()
			_show_status("Could not check for duplicate IDs. Please try again.")
			return true

		var response: Array = await http.request_completed
		var response_code: int = response[1]
		var response_text: String = (
			(response[3] as PackedByteArray).get_string_from_utf8()
		)

		http.queue_free()

		if response_code < 200 or response_code >= 300:
			push_error(
				"[AddTeacher] Duplicate ID query failed for "
				+ collection + ": " + response_text
			)
			_show_status("Could not verify whether this ID is already used.")
			return true

		var parsed: Variant = JSON.parse_string(response_text)

		if not parsed is Array:
			_show_status("Could not read the duplicate ID check response.")
			return true

		for result in parsed:
			if result is Dictionary and result.has("document"):
				return true

	return false


func _to_firestore_value(value: Variant) -> Dictionary:
	if value is bool:
		return {"booleanValue": value}

	if value is int:
		return {"integerValue": str(value)}

	if value is float:
		return {"doubleValue": value}

	if value is Array:
		var values: Array = []

		for item in value:
			values.append(_to_firestore_value(item))

		return {"arrayValue": {"values": values}}

	if value == null:
		return {"nullValue": null}

	return {"stringValue": str(value)}


# ------------------------------------------------------------
# FIREBASE CONFIGURATION
# ------------------------------------------------------------

func _get_firebase_api_key() -> String:
	var key_value: Variant = FirebaseConfig.get("FIREBASE_API_KEY")

	if key_value != null and not str(key_value).strip_edges().is_empty():
		return str(key_value).strip_edges()

	if FirebaseConfig.has("API_KEY"):
		return str(FirebaseConfig.API_KEY).strip_edges()

	if Firebase.Firestore != null:
		if Firebase.Firestore._config is Dictionary:
			var config: Dictionary = Firebase.Firestore._config
			if config.has("apiKey"):
				return str(config["apiKey"]).strip_edges()

	return ""


# ------------------------------------------------------------
# UI HELPERS
# ------------------------------------------------------------

func _show_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message

	print("[AddTeacher] ", message)


func _set_form_enabled(enabled: bool) -> void:
	create_button.disabled = not enabled
	cancel_button.disabled = not enabled
	generate_email_button.disabled = not enabled
	generate_password_button.disabled = not enabled
	hide_show_button.disabled = not enabled


func _finish_creation() -> void:
	is_creating = false
	_set_form_enabled(true)


func _on_cancel_button_pressed() -> void:
	if is_creating:
		return

	var parent_node := get_parent()

	if parent_node != null and parent_node.has_method("close_add_teacher"):
		parent_node.call("close_add_teacher")
	else:
		hide()


# ------------------------------------------------------------
# EDIT MODE
# ------------------------------------------------------------


func _on_save_teacher_changes_pressed() -> void:
	if is_creating:
		return

	if editing_teacher.is_empty():
		_show_status("No teacher selected for editing.")
		return

	create_attempted = true
	_update_required_field_labels()

	# Validate the editable teacher details without requiring a password.
	var id_number := id_input.text.strip_edges()
	var first_name := first_name_input.text.strip_edges()
	var middle_initial := middle_initial_input.text.strip_edges()
	var last_name := last_name_input.text.strip_edges()
	var suffix := suffix_input.text.strip_edges()
	var email := email_input.text.strip_edges()

	if id_number.length() != ID_NUMBER_LENGTH or not _contains_digits_only(id_number):
		_show_status("ID number/LRN must contain exactly 11 digits.")
		id_input.grab_focus()
		return

	if first_name.is_empty():
		_show_status("Please enter the teacher's first name.")
		first_name_input.grab_focus()
		return

	if last_name.is_empty():
		_show_status("Please enter the teacher's last name.")
		last_name_input.grab_focus()
		return

	if not _is_valid_email(email):
		_show_status("Please enter a valid email address.")
		email_input.grab_focus()
		return

	# Use the existing Firestore document ID. Never create a new teacher.
	var teacher_uid := str(editing_teacher.get("uid", "")).strip_edges()

	if teacher_uid.is_empty():
		var document_path := str(editing_teacher.get("document_path", ""))
		if not document_path.is_empty():
			teacher_uid = document_path.get_file()

	if teacher_uid.is_empty():
		_show_status("Cannot edit teacher: the teacher UID is missing.")
		push_error("[AddTeacher] Editing teacher has no UID or document path.")
		return

	var full_name := _get_full_name()

	var updated_fields: Dictionary = {
		"id_number": id_number,
		"name": full_name,
		"first_name": first_name,
		"middle_initial": middle_initial,
		"last_name": last_name,
		"suffix": suffix
	}

	is_creating = true
	_set_form_enabled(false)
	_show_status("Saving teacher changes...")

	# Update the existing teachers document.
	var teacher_result: Dictionary = await _update_teacher_fields(
		"teachers",
		teacher_uid,
		updated_fields
	)

	if not bool(teacher_result.get("ok", false)):
		_finish_creation()
		_show_status(
			"Could not update teacher details:\n"
			+ str(teacher_result.get("error", "Unknown Firestore error."))
		)
		return

	# Keep the corresponding users profile in sync as well.
	var user_result: Dictionary = await _update_teacher_fields(
		"users",
		teacher_uid,
		updated_fields
	)

	if not bool(user_result.get("ok", false)):
		_finish_creation()
		_show_status(
			"Teacher details were updated, but the users profile could not "
			+ "be updated:\n"
			+ str(user_result.get("error", "Unknown Firestore error."))
		)
		return

	# Keep the local copy consistent with the saved values.
	for key in updated_fields:
		editing_teacher[key] = updated_fields[key]

	# Record the successful teacher account update.
	ActivityLogManager.log_activity(
		"Updated Teacher Account",
		"Updated teacher details for: " + full_name,
		"Teacher Management",
		teacher_uid
	)

	_finish_creation()
	_show_status("Teacher details updated successfully!")
	teacher_created.emit()


func _update_teacher_fields(
	collection: String,
	document_id: String,
	data: Dictionary
) -> Dictionary:
	var token := _get_current_admin_id_token()

	if token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	var url := (
		FIRESTORE_BASE
		+ PROJECT_ID
		+ "/databases/(default)/documents/"
		+ collection
		+ "/"
		+ document_id.uri_encode()
	)

	# Update only the supplied fields, preserving other document fields.
	var query_parts: PackedStringArray = []

	for key in data.keys():
		query_parts.append(
			"updateMask.fieldPaths=" + str(key).uri_encode()
		)

	url += "?" + "&".join(query_parts)

	var firestore_fields: Dictionary = {}

	for key in data.keys():
		firestore_fields[str(key)] = _to_firestore_value(data[key])

	var request_body := JSON.stringify({
		"fields": firestore_fields
	})

	var http := HTTPRequest.new()
	add_child(http)

	var headers := PackedStringArray([
		"Authorization: Bearer " + token,
		"Content-Type: application/json"
	])

	var request_error := http.request(
		url,
		headers,
		HTTPClient.METHOD_PATCH,
		request_body
	)

	if request_error != OK:
		http.queue_free()
		return {
			"ok": false,
			"error": "Could not start Firestore update request."
		}

	var response: Array = await http.request_completed
	var response_code: int = int(response[1])
	var response_text: String = (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	http.queue_free()

	if response_code < 200 or response_code >= 300:
		var message := response_text
		var parsed: Variant = JSON.parse_string(response_text)

		if parsed is Dictionary:
			var error_data: Variant = parsed.get("error", {})
			if error_data is Dictionary:
				message = str(error_data.get("message", response_text))

		push_error(
			"[AddTeacher] Firestore update failed for "
			+ collection + "/" + document_id
			+ " (HTTP " + str(response_code) + "): " + message
		)

		return {
			"ok": false,
			"error": message
		}

	return {"ok": true}

extends Control

const ACTIVITY_LOG_ROW := preload(
	"res://Scenes/Admin/activity_log_row.tscn"
)

const PROJECT_ID := "atomix-f6c6b"
const FIRESTORE_BASE := "https://firestore.googleapis.com/v1/projects/"

@onready var activity_log: Panel = $PageBackground/ActivityLogs

@onready var id_input: LineEdit = $PageBackground/VBoxContainer/HBoxContainer/VBoxContainer2/VBoxContainer4/IDInput

@onready var first_name_input: LineEdit = $PageBackground/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer2/FirstName/NameInput

@onready var middle_initial_input: LineEdit = $PageBackground/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer2/MiddleInitial/NameInput

@onready var last_name_input: LineEdit = $PageBackground/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer3/LastName/NameInput

@onready var suffix_input: LineEdit = $PageBackground/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer3/Suffix/NameInput

@onready var email_input: LineEdit = $PageBackground/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/EmailInput

@onready var password_input: LineEdit = $PageBackground/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer2/PasswordInput

@onready var edit_button: Button = $PageBackground/VBoxContainer/HBoxContainer2/Edit

@onready var update_button: Button = $PageBackground/VBoxContainer/HBoxContainer2/Update

@onready var verification_status: Label = $PageBackground/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/VerificationContainer/VerificationStatus

@onready var send_verification_button: Button = $PageBackground/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/VerificationContainer/SendVerificationButton

@onready var refresh_verification_button: Button = $PageBackground/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/VerificationContainer/RefreshVerificationButton

@onready var activity_rows: VBoxContainer = $PageBackground/ActivityLogs/VBoxContainer/ScrollContainer/CenterContainer/VBoxContainer

var current_profile: Dictionary = {}

var is_editing: bool = false
var is_saving: bool = false
var profile_loaded: bool = false

var current_role: String = ""
var current_uid: String = ""


func _ready() -> void:

	activity_log.hide()

	# Connect email verification signal.
	if not AuthManager.email_verification_status_received.is_connected(
		_on_email_verification_status_received
	):
		AuthManager.email_verification_status_received.connect(
			_on_email_verification_status_received
		)

	# Connect activity log signals.
	if not ActivityLogManager.activity_logs_loaded.is_connected(
		_on_activity_logs_loaded
	):
		ActivityLogManager.activity_logs_loaded.connect(
			_on_activity_logs_loaded
		)

	if not ActivityLogManager.activity_logs_failed.is_connected(
		_on_activity_logs_failed
	):
		ActivityLogManager.activity_logs_failed.connect(
			_on_activity_logs_failed
		)

	# Connect profile buttons.
	if not edit_button.pressed.is_connected(_on_edit_pressed):
		edit_button.pressed.connect(_on_edit_pressed)

	if not update_button.pressed.is_connected(_on_update_pressed):
		update_button.pressed.connect(_on_update_pressed)

	# Connect verification buttons.
	if not send_verification_button.pressed.is_connected(
		_on_send_verification_button_pressed
	):
		send_verification_button.pressed.connect(
			_on_send_verification_button_pressed
		)

	if not refresh_verification_button.pressed.is_connected(
		_on_refresh_verification_button_pressed
	):
		refresh_verification_button.pressed.connect(
			_on_refresh_verification_button_pressed
		)

	_set_profile_editable(false)

	update_button.hide()

	# Load the current account.
	await _load_profile()

	# Check Firebase Authentication email verification.
	if AuthManager.is_logged_in():
		AuthManager.refresh_email_verification_status()
	else:
		verification_status.text = "No authenticated account."


# ============================================================
# FIRESTORE AUTHENTICATION
# ============================================================

func _get_current_id_token() -> String:

	if Firebase.Auth != null:

		var auth_data: Dictionary = Firebase.Auth.auth

		var token := str(auth_data.get("idtoken", ""))

		if token.is_empty():
			token = str(auth_data.get("idToken", ""))

		if not token.is_empty():
			return token

	if Firebase.Firestore != null:

		var firestore_auth: Variant = Firebase.Firestore.auth

		if firestore_auth is Dictionary:

			var auth_data: Dictionary = firestore_auth

			var token := str(auth_data.get("idtoken", ""))

			if token.is_empty():
				token = str(auth_data.get("idToken", ""))

			if not token.is_empty():
				return token

	return ""


func _firestore_document_url(
	collection: String,
	document_id: String
) -> String:

	return (
		FIRESTORE_BASE
		+ PROJECT_ID
		+ "/databases/(default)/documents/"
		+ collection
		+ "/"
		+ document_id.uri_encode()
	)


func _firestore_headers() -> PackedStringArray:

	return PackedStringArray([
		"Authorization: Bearer " + _get_current_id_token(),
		"Content-Type: application/json"
	])


# ============================================================
# LOAD PROFILE
# ============================================================

func _load_profile() -> void:

	current_uid = AuthManager.get_uid()

	if current_uid.is_empty():
		_show_profile_status("No authenticated user.")
		return

	current_role = await AuthManager.get_user_role()
	current_role = current_role.strip_edges().to_lower()

	if current_role.is_empty():
		_show_profile_status("Unable to determine account role.")
		return

	print("[Settings] Loading profile for role: ", current_role)

	# Both admin and teacher profiles use users/{uid}.
	var response: Dictionary = await _firestore_get_user_profile()

	if not bool(response.get("ok", false)):
		_show_profile_status(
			"Unable to load profile: "
			+ str(response.get("error", "Unknown error."))
		)
		return

	current_profile = response.get("data", {})

	_populate_profile_fields()

	profile_loaded = true

	_set_profile_editable(false)

	edit_button.show()
	update_button.hide()

	print("[Settings] Profile loaded successfully.")


func _firestore_get_user_profile() -> Dictionary:

	var token := _get_current_id_token()

	if token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	var url := _firestore_document_url(
		"users",
		current_uid
	)

	var http := HTTPRequest.new()
	add_child(http)

	var request_error := http.request(
		url,
		_firestore_headers(),
		HTTPClient.METHOD_GET
	)

	if request_error != OK:
		http.queue_free()

		return {
			"ok": false,
			"error": "Could not start Firestore profile request."
		}

	var response: Array = await http.request_completed

	var response_code: int = int(response[1])

	var response_text := (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	http.queue_free()

	if response_code < 200 or response_code >= 300:

		return {
			"ok": false,
			"error": response_text
		}

	var parsed: Variant = JSON.parse_string(response_text)

	if not parsed is Dictionary:
		return {
			"ok": false,
			"error": "Invalid Firestore profile response."
		}

	return {
		"ok": true,
		"data": _decode_firestore_document(parsed)
	}


func _decode_firestore_document(document: Dictionary) -> Dictionary:

	var result: Dictionary = {}

	var fields: Dictionary = document.get("fields", {})

	for field_name in fields:

		result[str(field_name)] = _decode_firestore_value(
			fields[field_name]
		)

	return result


func _decode_firestore_value(value: Variant) -> Variant:

	if not value is Dictionary:
		return null

	if value.has("stringValue"):
		return str(value["stringValue"])

	if value.has("integerValue"):
		return int(value["integerValue"])

	if value.has("doubleValue"):
		return float(value["doubleValue"])

	if value.has("booleanValue"):
		return bool(value["booleanValue"])

	if value.has("nullValue"):
		return null

	return ""


# ============================================================
# POPULATE PROFILE FIELDS
# ============================================================

func _populate_profile_fields() -> void:

	first_name_input.text = str(
		current_profile.get("first_name", "")
	)

	middle_initial_input.text = str(
		current_profile.get("middle_initial", "")
	)

	last_name_input.text = str(
		current_profile.get("last_name", "")
	)

	suffix_input.text = str(
		current_profile.get("suffix", "")
	)

	email_input.text = str(
		current_profile.get("email", "")
	)

	id_input.text = str(
		current_profile.get("id_number", "")
	)

	# Admin accounts may not have an ID number.
	# Keep it visible only if the account already has one.
	id_input.editable = false


# ============================================================
# EDIT MODE
# ============================================================

func _on_edit_pressed() -> void:

	if not profile_loaded:
		return

	if is_saving:
		return

	is_editing = true

	_set_profile_editable(true)

	edit_button.hide()
	update_button.show()

	_show_profile_status("Editing profile.")


func _set_profile_editable(enabled: bool) -> void:

	first_name_input.editable = enabled
	middle_initial_input.editable = enabled
	last_name_input.editable = enabled
	suffix_input.editable = enabled

	# Email is managed by Firebase Authentication.
	email_input.editable = false

	# The admin's ID is not changed through this form.
	id_input.editable = false

	# Password changes are not handled by profile editing.
	password_input.editable = false


# ============================================================
# UPDATE PROFILE
# ============================================================

func _on_update_pressed() -> void:

	if not is_editing or is_saving:
		return

	var first_name := first_name_input.text.strip_edges()
	var middle_initial := middle_initial_input.text.strip_edges()
	var last_name := last_name_input.text.strip_edges()
	var suffix := suffix_input.text.strip_edges()

	if first_name.is_empty():
		_show_profile_status("First name is required.")
		first_name_input.grab_focus()
		return

	if last_name.is_empty():
		_show_profile_status("Last name is required.")
		last_name_input.grab_focus()
		return

	var full_name := _build_full_name(
		first_name,
		middle_initial,
		last_name,
		suffix
	)

	var updated_fields: Dictionary = {
		"first_name": first_name,
		"middle_initial": middle_initial,
		"last_name": last_name,
		"suffix": suffix,
		"name": full_name
	}

	is_saving = true
	update_button.disabled = true
	edit_button.disabled = true

	_show_profile_status("Saving profile...")

	var result: Dictionary = await _update_user_profile(
		updated_fields
	)

	is_saving = false
	update_button.disabled = false
	edit_button.disabled = false

	if not bool(result.get("ok", false)):

		_show_profile_status(
			"Profile update failed: "
			+ str(result.get("error", "Unknown error."))
		)

		return

	# Update the local profile copy.
	for key in updated_fields:
		current_profile[key] = updated_fields[key]

	# Record successful profile update.
	ActivityLogManager.log_activity(
		"Updated Profile",
		"Updated profile information: " + full_name,
		"Settings",
		current_uid
	)

	is_editing = false

	_set_profile_editable(false)

	edit_button.show()
	update_button.hide()

	_show_profile_status("Profile updated successfully.")

	print("[Settings] Profile updated: ", current_uid)


func _build_full_name(
	first_name: String,
	middle_initial: String,
	last_name: String,
	suffix: String
) -> String:

	var parts: Array[String] = []

	if not first_name.is_empty():
		parts.append(first_name)

	if not middle_initial.is_empty():
		parts.append(middle_initial)

	if not last_name.is_empty():
		parts.append(last_name)

	if not suffix.is_empty():
		parts.append(suffix)

	return " ".join(parts)


func _update_user_profile(data: Dictionary) -> Dictionary:

	var token := _get_current_id_token()

	if token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	var url := _firestore_document_url(
		"users",
		current_uid
	)

	# Update only the supplied fields.
	# Existing fields such as role and email remain untouched.
	var query_parts: PackedStringArray = []

	for key in data.keys():

		query_parts.append(
			"updateMask.fieldPaths=" + str(key).uri_encode()
		)

	url += "?" + "&".join(query_parts)

	var firestore_fields: Dictionary = {}

	for key in data.keys():
		firestore_fields[str(key)] = {
			"stringValue": str(data[key])
		}

	var request_body := JSON.stringify({
		"fields": firestore_fields
	})

	var http := HTTPRequest.new()
	add_child(http)

	var request_error := http.request(
		url,
		_firestore_headers(),
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

	var response_text := (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	http.queue_free()

	if response_code < 200 or response_code >= 300:

		var message := response_text

		var parsed: Variant = JSON.parse_string(response_text)

		if parsed is Dictionary:

			var error_data: Variant = parsed.get("error", {})

			if error_data is Dictionary:
				message = str(
					error_data.get("message", response_text)
				)

		return {
			"ok": false,
			"error": message
		}

	return {
		"ok": true
	}


# ============================================================
# EMAIL VERIFICATION
# ============================================================

func _on_send_verification_button_pressed() -> void:

	if not AuthManager.is_logged_in():
		verification_status.text = "Please log in first."
		return

	AuthManager.send_email_verification()

	verification_status.text = "Verification email requested."


func _on_refresh_verification_button_pressed() -> void:

	if not AuthManager.is_logged_in():
		verification_status.text = "Please log in first."
		return

	verification_status.text = "Checking email status..."

	AuthManager.refresh_email_verification_status()


func _on_email_verification_status_received(
	is_verified: bool
) -> void:

	if is_verified:

		verification_status.text = "Email: Verified"

		send_verification_button.hide()

	else:

		verification_status.text = "Email: Not Verified"

		send_verification_button.show()


# ============================================================
# ACTIVITY LOG
# ============================================================

func _on_activity_log_pressed() -> void:

	activity_log.show()

	_clear_activity_rows()

	_add_activity_placeholder("Loading activity logs...")

	ActivityLogManager.load_activity_logs(100)


func _on_close_log_button_pressed() -> void:

	activity_log.hide()


func _on_activity_logs_loaded(logs: Array) -> void:

	_clear_activity_rows()

	if logs.is_empty():
		_add_activity_placeholder("No activity records found.")
		return

	for i in range(logs.size()):

		var log: Dictionary = logs[i]

		var row := ACTIVITY_LOG_ROW.instantiate()

		activity_rows.add_child(row)

		row.get_node("HBoxContainer/Number").text = str(i + 1)

		row.get_node("HBoxContainer/Activity").text = str(
			log.get("action", "Unknown Activity")
		)

		row.get_node("HBoxContainer/Time").text = _format_log_time(
			str(log.get("timestamp", ""))
		)


func _on_activity_logs_failed(message: String) -> void:

	_clear_activity_rows()

	_add_activity_placeholder(message)

	push_warning("[Settings] Activity logs failed: " + message)


func _clear_activity_rows() -> void:

	for child in activity_rows.get_children():

		activity_rows.remove_child(child)
		child.queue_free()


func _add_activity_placeholder(message: String) -> void:

	var label := Label.new()

	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)

	activity_rows.add_child(label)


func _format_log_time(timestamp: String) -> String:

	if timestamp.is_empty():
		return "Unknown time"

	return timestamp.replace("T", " ").replace("Z", "")


# ============================================================
# STATUS
# ============================================================

func _show_profile_status(message: String) -> void:

	print("[Settings] ", message)


# ============================================================
# LOG OUT
# ============================================================

func _on_logout_button_pressed() -> void:

	AuthManager.logout()

	await get_tree().create_timer(0.2).timeout

	get_tree().change_scene_to_file(
		"res://Scenes/UI/MainMenu.tscn"
	)

extends Control

# ============================================================
# CONFIGURATION
# ============================================================

const PROJECT_ID := "atomix-f6c6b"
const FIRESTORE_BASE := "https://firestore.googleapis.com/v1/projects/"
const AUTH_API_URL := "https://atomix-auth-api.atomix-auth.workers.dev"

# ============================================================
# DISPLAY NODES
# ============================================================

@onready var display_panel: HBoxContainer = $PageBackground/Panel/MarginContainer/VBoxContainer/Display

@onready var display_lrn: Label = $PageBackground/Panel/MarginContainer/VBoxContainer/Display/VBoxContainer3/VBoxContainer2/StudentIDInput
@onready var display_first_name: Label = $PageBackground/Panel/MarginContainer/VBoxContainer/Display/VBoxContainer3/HBoxContainer/FirstName/NameInput
@onready var display_middle_initial: Label = $"PageBackground/Panel/MarginContainer/VBoxContainer/Display/VBoxContainer3/HBoxContainer/Middle Initial/NameInput"
@onready var display_last_name: Label = $PageBackground/Panel/MarginContainer/VBoxContainer/Display/VBoxContainer3/HBoxContainer2/LastName/NameInput
@onready var display_suffix: Label = $PageBackground/Panel/MarginContainer/VBoxContainer/Display/VBoxContainer3/HBoxContainer2/Suffix/NameInput

@onready var display_section: Label = $PageBackground/Panel/MarginContainer/VBoxContainer/Display/VBoxContainer2/VBoxContainer4/SectionInput
@onready var display_email: Label = $PageBackground/Panel/MarginContainer/VBoxContainer/Display/VBoxContainer2/VBoxContainer5/HBoxContainer/EmailInput
@onready var display_verified: TextureRect = $PageBackground/Panel/MarginContainer/VBoxContainer/Display/VBoxContainer2/VBoxContainer5/HBoxContainer/Verified
@onready var display_need_verification: TextureRect = $PageBackground/Panel/MarginContainer/VBoxContainer/Display/VBoxContainer2/VBoxContainer5/HBoxContainer/Need_Verification

# ============================================================
# EDIT NODES
# ============================================================

@onready var edit_panel: HBoxContainer = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit

@onready var student_id_input: LineEdit = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer3/VBoxContainer2/StudentIDInput
@onready var first_name_input: LineEdit = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer3/HBoxContainer/FirstName/NameInput
@onready var middle_initial_input: LineEdit = $"PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer3/HBoxContainer/Middle Initial/NameInput"
@onready var last_name_input: LineEdit = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer3/HBoxContainer2/LastName/NameInput
@onready var suffix_input: LineEdit = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer3/HBoxContainer2/Suffix/NameInput

@onready var section_input: OptionButton = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/VBoxContainer4/SectionInput
@onready var email_input: LineEdit = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/VBoxContainer5/EmailInput

@onready var verification_status: Label = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/VBoxContainer5/HBoxContainer/Verified
@onready var verification_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/VBoxContainer5/HBoxContainer/VerificationButton

@onready var change_password_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/ChangePasswordButton
@onready var edit_password_panel: Control = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/EditPasswordPanel

@onready var old_password_input: LineEdit = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/EditPasswordPanel/VBoxContainer/HBoxContainer/VBoxContainer2/PasswordInput
@onready var new_password_input: LineEdit = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/EditPasswordPanel/VBoxContainer/HBoxContainer/VBoxContainer3/PasswordInput

@onready var old_password_show_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/EditPasswordPanel/VBoxContainer/HBoxContainer/VBoxContainer2/PasswordInput/HBoxContainer/Show
@onready var old_password_hide_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/EditPasswordPanel/VBoxContainer/HBoxContainer/VBoxContainer2/PasswordInput/HBoxContainer/Hide

@onready var new_password_show_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/EditPasswordPanel/VBoxContainer/HBoxContainer/VBoxContainer3/PasswordInput/HBoxContainer/Show
@onready var new_password_hide_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/EditPasswordPanel/VBoxContainer/HBoxContainer/VBoxContainer3/PasswordInput/HBoxContainer/Hide

@onready var password_cancel_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/Edit/VBoxContainer2/EditPasswordPanel/VBoxContainer/Button

# ============================================================
# BUTTONS
# ============================================================

@onready var back_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/HBoxContainer/Button
@onready var edit_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/Buttons/EditButton
@onready var cancel_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/Buttons/CancelButton
@onready var save_button: Button = $PageBackground/Panel/MarginContainer/VBoxContainer/Buttons/UpdateButton
@onready var status_label: Label = $PageBackground/Panel/MarginContainer/VBoxContainer/StatusLabel

# ============================================================
# DATA
# ============================================================

var current_uid: String = ""
var current_profile: Dictionary = {}

var original_email: String = ""
var pending_email: String = ""

var is_saving: bool = false
var is_changing_password: bool = false
var is_changing_email: bool = false

# ============================================================
# READY
# ============================================================

func _ready() -> void:
	print("[StudentSettings] Initializing settings page.")

	display_panel.show()
	edit_panel.hide()

	edit_button.show()
	cancel_button.hide()
	save_button.hide()

	edit_password_panel.hide()

	# Student ID and Section are not editable.
	student_id_input.editable = false
	section_input.disabled = true

	# Email can be changed through the verification workflow.
	email_input.editable = true

	verification_button.hide()
	verification_status.hide()

	display_verified.hide()
	display_need_verification.hide()

	# Main buttons.
	back_button.pressed.connect(_on_back_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	verification_button.pressed.connect(_on_verification_pressed)

	# Password buttons.
	change_password_button.pressed.connect(_on_change_password_pressed)
	password_cancel_button.pressed.connect(_on_password_cancel_pressed)

	old_password_show_button.pressed.connect(
		func(): _set_password_visibility(old_password_input, old_password_show_button, old_password_hide_button, true)
	)
	old_password_hide_button.pressed.connect(
		func(): _set_password_visibility(old_password_input, old_password_show_button, old_password_hide_button, false)
	)
	new_password_show_button.pressed.connect(
		func(): _set_password_visibility(new_password_input, new_password_show_button, new_password_hide_button, true)
	)
	new_password_hide_button.pressed.connect(
		func(): _set_password_visibility(new_password_input, new_password_show_button, new_password_hide_button, false)
	)

	# AuthManager signals.
	if not AuthManager.email_verification_status_received.is_connected(_on_email_verification_status_received):
		AuthManager.email_verification_status_received.connect(_on_email_verification_status_received)

	if not AuthManager.account_data_received.is_connected(_on_account_data_received):
		AuthManager.account_data_received.connect(_on_account_data_received)

	await _load_profile()

	AuthManager.refresh_email_verification_status()


# ============================================================
# FIRESTORE AUTHENTICATION
# ============================================================

func _get_current_id_token() -> String:
	if Firebase.Auth.auth is Dictionary:
		var auth_data: Dictionary = Firebase.Auth.auth
		var token := str(auth_data.get("idtoken", auth_data.get("idToken", "")))

		if not token.is_empty():
			return token

	if Firebase.Firestore.auth is Dictionary:
		var firestore_auth: Dictionary = Firebase.Firestore.auth
		var token := str(firestore_auth.get("idtoken", firestore_auth.get("idToken", "")))

		if not token.is_empty():
			return token

	return ""


func _firestore_headers() -> PackedStringArray:
	return PackedStringArray([
		"Authorization: Bearer " + _get_current_id_token(),
		"Content-Type: application/json"
	])


func _firestore_document_url(collection: String, document_id: String) -> String:
	return FIRESTORE_BASE \
		+ PROJECT_ID \
		+ "/databases/(default)/documents/" \
		+ collection \
		+ "/" \
		+ document_id


# ============================================================
# LOAD STUDENT PROFILE
# ============================================================

func _load_profile() -> void:
	current_uid = AuthManager.get_uid()

	if current_uid.is_empty():
		_set_status("Unable to identify logged-in student.")
		push_error("[StudentSettings] Firebase UID is empty.")
		return

	print("[StudentSettings] Loading student:", current_uid)

	var result: Dictionary = await _firestore_get_document("students", current_uid)

	if not result.get("ok", false):
		_set_status("Unable to load student profile.")
		push_error("[StudentSettings] " + str(result.get("message", "Unknown error.")))
		return

	current_profile = result.get("data", {})
	_populate_profile()

	_set_status("Profile loaded successfully.")
	print("[StudentSettings] Profile loaded.")


func _firestore_get_document(collection: String, document_id: String) -> Dictionary:
	var token := _get_current_id_token()

	if token.is_empty():
		return {"ok": false, "message": "Firebase ID token is unavailable."}

	var http := HTTPRequest.new()
	add_child(http)

	var request_error := http.request(
		_firestore_document_url(collection, document_id),
		_firestore_headers(),
		HTTPClient.METHOD_GET
	)

	if request_error != OK:
		http.queue_free()
		return {"ok": false, "message": "Could not start Firestore request."}

	var response: Array = await http.request_completed
	http.queue_free()

	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	var json := JSON.new()
	var parse_error := json.parse(response_body.get_string_from_utf8())

	if parse_error != OK:
		return {"ok": false, "message": "Invalid Firestore response."}

	if response_code < 200 or response_code >= 300:
		return {"ok": false, "message": str(json.data)}

	return {
		"ok": true,
		"data": _decode_firestore_document(json.data)
	}


# ============================================================
# FIRESTORE DATA DECODING
# ============================================================

func _decode_firestore_document(document: Dictionary) -> Dictionary:
	var decoded: Dictionary = {}
	var fields: Dictionary = document.get("fields", {})

	for key in fields:
		decoded[key] = _decode_firestore_value(fields[key])

	return decoded


func _decode_firestore_value(value: Dictionary):
	if value.has("stringValue"):
		return value["stringValue"]

	if value.has("integerValue"):
		return int(value["integerValue"])

	if value.has("doubleValue"):
		return float(value["doubleValue"])

	if value.has("booleanValue"):
		return value["booleanValue"]

	if value.has("nullValue"):
		return null

	if value.has("mapValue"):
		return _decode_firestore_document(value["mapValue"].get("fields", {}))

	if value.has("arrayValue"):
		var decoded_array: Array = []

		for item in value["arrayValue"].get("values", []):
			decoded_array.append(_decode_firestore_value(item))

		return decoded_array

	return null


# ============================================================
# POPULATE PROFILE
# ============================================================

func _populate_profile() -> void:
	var full_name := str(current_profile.get("name", ""))
	var parsed_name := _parse_full_name(full_name)

	var first_name := str(current_profile.get("first_name", parsed_name.get("first_name", "")))
	var middle_initial := str(current_profile.get("middle_initial", parsed_name.get("middle_initial", "")))
	var last_name := str(current_profile.get("last_name", parsed_name.get("last_name", "")))
	var suffix := str(current_profile.get("suffix", parsed_name.get("suffix", "")))

	var student_id := str(current_profile.get("student_id", ""))
	var section := str(current_profile.get("section", ""))
	var email := str(current_profile.get("email", original_email))

	# Display values.
	display_lrn.text = student_id
	display_first_name.text = first_name
	display_middle_initial.text = middle_initial
	display_last_name.text = last_name
	display_suffix.text = suffix
	display_section.text = section
	display_email.text = email

	# Edit values.
	student_id_input.text = student_id
	first_name_input.text = first_name
	middle_initial_input.text = middle_initial
	last_name_input.text = last_name
	suffix_input.text = suffix

	email_input.text = email
	original_email = email


func _parse_full_name(full_name: String) -> Dictionary:
	var result := {
		"first_name": "",
		"middle_initial": "",
		"last_name": "",
		"suffix": ""
	}

	var parts := full_name.strip_edges().split(" ", false)

	if parts.is_empty():
		return result

	result["first_name"] = parts[0]

	if parts.size() >= 2:
		result["last_name"] = parts[parts.size() - 1]

	if parts.size() >= 3:
		result["middle_initial"] = parts[1]

	return result


func _select_section(section_name: String) -> void:
	for i in range(section_input.item_count):
		if section_input.get_item_text(i) == section_name:
			section_input.select(i)
			return


# ============================================================
# SAVE PROFILE
# ============================================================

func _on_save_pressed() -> void:
	if is_saving or is_changing_email or is_changing_password:
		return

	SfxManager.play_click()

	# If the password panel is open, Update handles
	# either a password change or an email-change request.
	if edit_password_panel.visible:
		if not new_password_input.text.is_empty():
			await _change_password()
			return

		if email_input.text.strip_edges().to_lower() != original_email.to_lower():
			await _request_email_change_verification()
			return

		_set_status("Enter a new password or change your email address.")
		return

	var first_name := first_name_input.text.strip_edges()
	var middle_initial := middle_initial_input.text.strip_edges()
	var last_name := last_name_input.text.strip_edges()
	var suffix := suffix_input.text.strip_edges()
	var requested_email := email_input.text.strip_edges().to_lower()

	if first_name.is_empty() or last_name.is_empty():
		_set_status("First name and last name are required.")
		return

	if not _is_valid_email(requested_email):
		_set_status("Please enter a valid email address.")
		return

	is_saving = true
	save_button.disabled = true
	_set_status("Saving profile...")

	var combined_name := _build_full_name(
		first_name,
		middle_initial,
		last_name,
		suffix
	)

	var student_updates := {
		"first_name": first_name,
		"middle_initial": middle_initial,
		"last_name": last_name,
		"suffix": suffix,
		"name": combined_name
	}

	var user_updates := {
		"name": combined_name
	}

	var student_result: Dictionary = await _firestore_patch_document(
		"students",
		current_uid,
		student_updates
	)

	if not student_result.get("ok", false):
		_finish_saving()
		_set_status("Failed to update student profile.")
		push_error(str(student_result.get("message", "Student update failed.")))
		return

	var user_result: Dictionary = await _firestore_patch_document(
		"users",
		current_uid,
		user_updates
	)

	if not user_result.get("ok", false):
		_finish_saving()
		_set_status("Student profile saved, but user profile update failed.")
		push_error(str(user_result.get("message", "User update failed.")))
		return

	current_profile.merge(student_updates, true)

	_finish_saving()

	# Refresh the saved name fields.
	_populate_profile()

	# Restore the requested email so the student can continue
	# the email verification process.
	email_input.text = requested_email

	# Request an email change only after profile data is saved.
	if requested_email != original_email.to_lower():
		_set_status("Profile saved. Enter your current password, then press Update to request an email change.")
		edit_password_panel.show()
		change_password_button.hide()
		return

	_show_display_mode()
	_set_status("Profile updated successfully.")
	print("[StudentSettings] Profile saved.")


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

	var result := " ".join(parts)

	if not suffix.is_empty():
		result += " " + suffix

	return result


func _is_valid_email(value: String) -> bool:
	var at_position := value.find("@")
	var dot_position := value.rfind(".")

	return at_position > 0 \
		and dot_position > at_position + 1 \
		and dot_position < value.length() - 1


# ============================================================
# FIRESTORE PATCH
# ============================================================

func _firestore_patch_document(
	collection: String,
	document_id: String,
	updates: Dictionary
) -> Dictionary:
	var token := _get_current_id_token()

	if token.is_empty():
		return {"ok": false, "message": "Firebase ID token is unavailable."}

	var url := _firestore_document_url(collection, document_id)
	var query_parameters: PackedStringArray = []
	var firestore_fields: Dictionary = {}

	for key in updates:
		query_parameters.append("updateMask.fieldPaths=" + str(key).uri_encode())

		var value = updates[key]

		if value is bool:
			firestore_fields[key] = {"booleanValue": value}
		elif value is int:
			firestore_fields[key] = {"integerValue": str(value)}
		elif value is float:
			firestore_fields[key] = {"doubleValue": value}
		elif value == null:
			firestore_fields[key] = {"nullValue": null}
		else:
			firestore_fields[key] = {"stringValue": str(value)}

	url += "?" + "&".join(query_parameters)

	var body := JSON.stringify({"fields": firestore_fields})
	var http := HTTPRequest.new()
	add_child(http)

	var request_error := http.request(
		url,
		_firestore_headers(),
		HTTPClient.METHOD_PATCH,
		body
	)

	if request_error != OK:
		http.queue_free()
		return {"ok": false, "message": "Could not start Firestore update."}

	var response: Array = await http.request_completed
	http.queue_free()

	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	var json := JSON.new()
	var parse_error := json.parse(response_body.get_string_from_utf8())

	if parse_error != OK:
		return {"ok": false, "message": "Invalid Firestore response."}

	if response_code < 200 or response_code >= 300:
		return {"ok": false, "message": str(json.data)}

	return {"ok": true, "data": json.data}


func _finish_saving() -> void:
	is_saving = false
	save_button.disabled = false


# ============================================================
# PASSWORD VISIBILITY
# ============================================================

func _set_password_visibility(
	password_input: LineEdit,
	show_button: Button,
	hide_button: Button,
	make_visible: bool
) -> void:
	password_input.secret = not make_visible
	show_button.visible = not make_visible
	hide_button.visible = make_visible


# ============================================================
# CHANGE PASSWORD
# ============================================================

func _on_change_password_pressed() -> void:
	SfxManager.play_click()

	edit_password_panel.show()
	change_password_button.hide()

	old_password_input.clear()
	new_password_input.clear()

	_set_status("Enter your current password and your new password.")


func _on_password_cancel_pressed() -> void:
	SfxManager.play_click()

	edit_password_panel.hide()
	change_password_button.show()

	old_password_input.clear()
	new_password_input.clear()

	_set_status("Password change cancelled.")


func _change_password() -> void:
	if is_changing_password:
		return

	var current_password := old_password_input.text
	var new_password := new_password_input.text

	if current_password.is_empty():
		_set_status("Enter your current password.")
		return

	if new_password.length() < 6:
		_set_status("New password must contain at least 6 characters.")
		return

	is_changing_password = true
	change_password_button.disabled = true
	_set_status("Verifying your current password...")

	var auth_user: Dictionary = Firebase.Auth.auth
	var auth_email := str(auth_user.get("email", original_email))

	Firebase.Auth.reauthenticate_user(auth_email, current_password)

	var reauth_result = await Firebase.Auth.reauthentication_completed

	if not _auth_operation_succeeded(reauth_result):
		is_changing_password = false
		change_password_button.disabled = false
		_set_status("Current password is incorrect or reauthentication failed.")
		push_warning("[StudentSettings] Reauthentication failed: " + str(reauth_result))
		return

	_set_status("Updating password...")

	Firebase.Auth.change_user_password(new_password)

	var password_result = await Firebase.Auth.password_change_completed

	if not _auth_operation_succeeded(password_result):
		is_changing_password = false
		change_password_button.disabled = false
		_set_status("Unable to change password. Please try again.")
		push_warning("[StudentSettings] Password update failed: " + str(password_result))
		return

	# Clear the first-login password requirement.
	var flag_result: Dictionary = await _firestore_patch_document(
		"students",
		current_uid,
		{"must_change_password": false}
	)

	var user_flag_result: Dictionary = await _firestore_patch_document(
		"users",
		current_uid,
		{"must_change_password": false}
	)

	if not flag_result.get("ok", false):
		push_warning("[StudentSettings] Could not update student must_change_password flag.")

	if not user_flag_result.get("ok", false):
		push_warning("[StudentSettings] Could not update user must_change_password flag.")

	_update_account_setup_state()

	old_password_input.clear()
	new_password_input.clear()

	edit_password_panel.hide()
	change_password_button.show()
	change_password_button.disabled = false

	is_changing_password = false

	_set_status("Password changed successfully.")
	print("[StudentSettings] Password changed.")


func _auth_operation_succeeded(result) -> bool:
	if result is bool:
		return result

	if result is Dictionary:
		if result.has("success"):
			return bool(result["success"])

		if result.has("ok"):
			return bool(result["ok"])

		if result.has("error"):
			return false

		if result.has("message") and str(result["message"]).to_lower().contains("error"):
			return false

		# Many Firebase plugin success responses contain a user or data field.
		return result.has("user") or result.has("data")

	if result is Array:
		if result.is_empty():
			return false

		return _auth_operation_succeeded(result[0])

	return false


func _update_account_setup_state() -> void:
	var verified := false

	if Firebase.Auth.auth is Dictionary:
		verified = bool(Firebase.Auth.auth.get("email_verified", false))

	AuthManager.account_setup_required = not verified


# ============================================================
# EMAIL VERIFICATION
# ============================================================
func _on_email_verification_status_received(is_verified: bool) -> void:
	if is_verified:
		# Show the verified logo.
		display_verified.show()
		display_need_verification.hide()

		verification_status.text = "Verified"
		verification_status.show()
		verification_button.hide()

	else:
		# Show the need verification logo.
		display_verified.hide()
		display_need_verification.show()

		verification_status.text = "Not Verified"
		verification_status.show()
		verification_button.show()

	print("[StudentSettings] Email verified: ", is_verified)


func _on_account_data_received(
	firebase_email: String,
	is_verified: bool
) -> void:
	# Firebase Authentication is the source of truth.
	if not firebase_email.is_empty():
		if not pending_email.is_empty() \
		and firebase_email.to_lower() == pending_email.to_lower() \
		and is_verified:
			_finish_email_change(firebase_email)
		elif pending_email.is_empty():
			original_email = firebase_email
			email_input.text = firebase_email
			display_email.text = firebase_email

	_on_email_verification_status_received(is_verified)
	AuthManager.account_setup_required = not is_verified


func _on_verification_pressed() -> void:
	SfxManager.play_click()

	verification_button.disabled = true
	_set_status("Sending verification email...")

	AuthManager.send_email_verification()

	await get_tree().create_timer(2.0).timeout

	verification_button.disabled = false
	_set_status("Check your email for the verification link.")


# ============================================================
# REQUEST EMAIL CHANGE
# ============================================================

func _request_email_change_verification() -> void:
	if is_changing_email:
		return

	var new_email := email_input.text.strip_edges().to_lower()
	var current_password := old_password_input.text

	if not _is_valid_email(new_email):
		_set_status("Enter a valid email address.")
		return

	if new_email == original_email.to_lower():
		_set_status("The email address has not changed.")
		return

	if current_password.is_empty():
		_set_status("Enter your current password in the Old Password field.")
		return

	is_changing_email = true
	save_button.disabled = true

	_set_status("Verifying your current password...")

	var auth_user: Dictionary = Firebase.Auth.auth
	var auth_email := str(auth_user.get("email", original_email))

	Firebase.Auth.reauthenticate_user(auth_email, current_password)

	var reauth_result = await Firebase.Auth.reauthentication_completed

	if not _auth_operation_succeeded(reauth_result):
		is_changing_email = false
		save_button.disabled = false
		_set_status("Current password is incorrect. Email was not changed.")
		push_warning("[StudentSettings] Email-change reauthentication failed: " + str(reauth_result))
		return

	_set_status("Sending email-change verification...")

	pending_email = new_email

	Firebase.Auth.send_email_change_verification(new_email)

	var email_result = await Firebase.Auth.credential_operation_completed

	if not _auth_operation_succeeded(email_result):
		pending_email = ""
		is_changing_email = false
		save_button.disabled = false
		_set_status("Could not send the email-change verification. Please try again.")
		push_warning("[StudentSettings] Email-change request failed: " + str(email_result))
		return

	is_changing_email = false
	save_button.disabled = false

	old_password_input.clear()
	edit_password_panel.hide()
	change_password_button.show()

	_set_status("Verification sent to " + new_email + ". Verify it, then return to the game.")
	print("[StudentSettings] Email-change verification requested for: ", new_email)


func _finish_email_change(firebase_email: String) -> void:
	if pending_email.is_empty():
		return

	var new_email := firebase_email.strip_edges().to_lower()

	_set_status("Email verified. Updating your account records...")

	var student_result: Dictionary = await _firestore_patch_document(
		"students",
		current_uid,
		{"email": new_email}
	)

	if not student_result.get("ok", false):
		_set_status("Email verified, but student record update failed.")
		push_error("[StudentSettings] Student email update failed: " + str(student_result.get("message", "")))
		return

	var user_result: Dictionary = await _firestore_patch_document(
		"users",
		current_uid,
		{"email": new_email}
	)

	if not user_result.get("ok", false):
		_set_status("Email verified, but user record update failed.")
		push_error("[StudentSettings] User email update failed: " + str(user_result.get("message", "")))
		return

	var worker_result: Dictionary = await _sync_own_email_with_worker()

	if not worker_result.get("ok", false):
		_set_status("Email updated in Firebase, but account lookup sync failed.")
		push_warning("[StudentSettings] Worker email sync failed: " + str(worker_result.get("message", "")))
		return

	original_email = new_email
	email_input.text = new_email
	display_email.text = new_email

	current_profile["email"] = new_email
	pending_email = ""

	_set_status("Email address updated successfully.")
	print("[StudentSettings] Email change completed.")


func _sync_own_email_with_worker() -> Dictionary:
	var token := _get_current_id_token()

	if token.is_empty():
		return {"ok": false, "message": "Firebase ID token is unavailable."}

	var http := HTTPRequest.new()
	add_child(http)

	var headers := PackedStringArray([
		"Authorization: Bearer " + token,
		"Content-Type: application/json"
	])

	var request_error := http.request(
		AUTH_API_URL + "/sync-own-email",
		headers,
		HTTPClient.METHOD_POST,
		"{}"
	)

	if request_error != OK:
		http.queue_free()
		return {"ok": false, "message": "Could not start Worker request."}

	var response: Array = await http.request_completed
	http.queue_free()

	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	var json := JSON.new()
	var parse_error := json.parse(response_body.get_string_from_utf8())

	if parse_error != OK:
		return {"ok": false, "message": "Invalid Worker response."}

	if response_code < 200 or response_code >= 300:
		return {"ok": false, "message": str(json.data)}

	if json.data is Dictionary and not bool(json.data.get("success", true)):
		return {"ok": false, "message": str(json.data.get("message", "Worker sync failed."))}

	return {"ok": true, "data": json.data}


# ============================================================
# CANCEL / NAVIGATION
# ============================================================

func _on_cancel_pressed() -> void:
	SfxManager.play_click()

	edit_password_panel.hide()
	old_password_input.clear()
	new_password_input.clear()

	pending_email = ""

	_populate_profile()
	_show_display_mode()

	_set_status("Changes cancelled.")
	print("[StudentSettings] Changes cancelled.")


func _show_display_mode() -> void:
	display_panel.show()
	edit_panel.hide()

	edit_button.show()
	cancel_button.hide()
	save_button.hide()


func _on_edit_pressed() -> void:
	SfxManager.play_click()

	display_panel.hide()
	edit_panel.show()

	edit_button.hide()
	cancel_button.show()
	save_button.show()

	edit_password_panel.hide()
	change_password_button.show()

	_populate_profile()

	_set_status("Edit your profile information.")
	print("[StudentSettings] Edit mode opened.")


func _on_back_pressed() -> void:
	SfxManager.play_click()

	if GameMenu.instance == null:
		push_error("[StudentSettings] GameMenu instance is unavailable.")
		return

	print("[StudentSettings] Returning to main settings page.")
	GameMenu.instance.open_settings_page()


# ============================================================
# STATUS
# ============================================================

func _set_status(message: String) -> void:
	status_label.text = message
	print("[StudentSettings] ", message)

extends Control

const ACTIVITY_LOG_ROW := preload(
	"res://Scenes/Admin/activity_log_row.tscn"
)

const PROJECT_ID := "atomix-f6c6b"
const FIRESTORE_BASE := "https://firestore.googleapis.com/v1/projects/"

# ============================================================
# NEW SCENE NODE REFERENCES
# ============================================================

@onready var display_container: HBoxContainer = $PageBackground/VBoxContainer/Display
@onready var edit_container: HBoxContainer = $PageBackground/VBoxContainer/Edit

# Display-only profile labels
@onready var display_id: Label = $PageBackground/VBoxContainer/Display/VBoxContainer2/Display/IDInput
@onready var display_first_name: Label = $PageBackground/VBoxContainer/Display/VBoxContainer2/HBoxContainer4/Display/FirstName/NameInput
@onready var display_middle_initial: Label = $PageBackground/VBoxContainer/Display/VBoxContainer2/HBoxContainer4/Display/MiddleInitial/NameInput
@onready var display_last_name: Label = $PageBackground/VBoxContainer/Display/VBoxContainer2/HBoxContainer2/Display/LastName/NameInput
@onready var display_suffix: Label = $PageBackground/VBoxContainer/Display/VBoxContainer2/HBoxContainer2/Display/Suffix/NameInput

@onready var display_email: Label = $PageBackground/VBoxContainer/Display/VBoxContainer/Display/HBoxContainer/EmailInput
@onready var display_verified_icon: TextureRect = $PageBackground/VBoxContainer/Display/VBoxContainer/Display/HBoxContainer/Verified
@onready var display_not_verified_icon: TextureRect = $PageBackground/VBoxContainer/Display/VBoxContainer/Display/HBoxContainer/NotVerified

# Editable profile fields
@onready var id_input: LineEdit = $PageBackground/VBoxContainer/Edit/VBoxContainer2/HBoxContainer/Edit/IDInput

@onready var first_name_input: LineEdit = $PageBackground/VBoxContainer/Edit/VBoxContainer2/Edit/FirstName/NameInput
@onready var middle_initial_input: LineEdit = $PageBackground/VBoxContainer/Edit/VBoxContainer2/Edit/MiddleInitial/NameInput
@onready var last_name_input: LineEdit = $PageBackground/VBoxContainer/Edit/VBoxContainer2/Edit2/LastName/NameInput
@onready var suffix_input: LineEdit = $PageBackground/VBoxContainer/Edit/VBoxContainer2/Edit2/Suffix/NameInput

@onready var email_input: LineEdit = $PageBackground/VBoxContainer/Edit/VBoxContainer/HBoxContainer/Edit/EmailInput

# Email verification
@onready var verification_status: Label = $PageBackground/VBoxContainer/Edit/VBoxContainer/HBoxContainer/Edit/VerificationContainer/Verified
@onready var send_verification_button: Button = $PageBackground/VBoxContainer/Edit/VBoxContainer/HBoxContainer/Edit/VerificationContainer/VerificationButton

# Password controls
@onready var change_password_button: Button = $PageBackground/VBoxContainer/Edit/VBoxContainer/ChangePasswordButton
@onready var password_panel: Panel = $PageBackground/VBoxContainer/Edit/VBoxContainer/EditPasswordPanel

@onready var old_password_input: LineEdit = $PageBackground/VBoxContainer/Edit/VBoxContainer/EditPasswordPanel/VBoxContainer/VBoxContainer2/PasswordInput
@onready var new_password_input: LineEdit = $PageBackground/VBoxContainer/Edit/VBoxContainer/EditPasswordPanel/VBoxContainer/VBoxContainer3/PasswordInput

@onready var old_password_show: Button = $PageBackground/VBoxContainer/Edit/VBoxContainer/EditPasswordPanel/VBoxContainer/VBoxContainer2/PasswordInput/HBoxContainer/Show
@onready var old_password_hide: Button = $PageBackground/VBoxContainer/Edit/VBoxContainer/EditPasswordPanel/VBoxContainer/VBoxContainer2/PasswordInput/HBoxContainer/Hide

@onready var new_password_show: Button = $PageBackground/VBoxContainer/Edit/VBoxContainer/EditPasswordPanel/VBoxContainer/VBoxContainer3/PasswordInput/HBoxContainer/Show
@onready var new_password_hide: Button = $PageBackground/VBoxContainer/Edit/VBoxContainer/EditPasswordPanel/VBoxContainer/VBoxContainer3/PasswordInput/HBoxContainer/Hide

@onready var password_cancel_button: Button = $PageBackground/VBoxContainer/Edit/VBoxContainer/EditPasswordPanel/VBoxContainer/Button

@onready var logout_panel: Panel = $PageBackground/Logout
@onready var logout_button: Button = $PageBackground/Logout/VBoxContainer/Button

# Main profile buttons
@onready var edit_button: Button = $PageBackground/VBoxContainer/HBoxContainer2/Edit
@onready var update_button: Button = $PageBackground/VBoxContainer/HBoxContainer2/Update
@onready var cancel_button: Button = $PageBackground/VBoxContainer/HBoxContainer2/Cancel



# Activity log
@onready var activity_log: Panel = $PageBackground/ActivityLogs
@onready var activity_log_button: TextureButton = $PageBackground/VBoxContainer/HBoxContainer3/ActivityLog
@onready var close_log_button: Button = $PageBackground/ActivityLogs/VBoxContainer/CloseLogButton

@onready var activity_rows: VBoxContainer = $PageBackground/ActivityLogs/VBoxContainer/ScrollContainer/CenterContainer/VBoxContainer

@onready var status_log: Label = $PageBackground/VBoxContainer/StatusLabel
# ============================================================
# ACCOUNT VARIABLES
# ============================================================

var current_profile: Dictionary = {}

var original_email: String = ""
var firebase_account_email: String = ""

var pending_email: String = ""
var must_change_password: bool = false
var email_change_in_progress: bool = false

var email_is_verified: bool = false

var is_editing: bool = false
var is_saving: bool = false
var profile_loaded: bool = false

var current_role: String = ""
var current_uid: String = ""


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	# Set the initial screen layout.
	display_container.show()
	edit_container.hide()

	activity_log.hide()
	password_panel.hide()
	change_password_button.show()

	update_button.hide()
	cancel_button.hide()
	
	# Email verification success panel.
	logout_panel.hide()
	logout_button.pressed.connect(_on_logout_button_pressed)
	
	# Connect authentication signals.
	if not AuthManager.email_verification_status_received.is_connected(
		_on_email_verification_status_received
	):
		AuthManager.email_verification_status_received.connect(
			_on_email_verification_status_received
		)

	if not AuthManager.account_data_received.is_connected(
		_on_account_data_received
	):
		AuthManager.account_data_received.connect(
			_on_account_data_received
		)

	if not Firebase.Auth.password_change_completed.is_connected(
		_on_password_change_completed
	):
		Firebase.Auth.password_change_completed.connect(
			_on_password_change_completed
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
	edit_button.pressed.connect(_on_edit_pressed)
	update_button.pressed.connect(_on_update_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

	# Connect email verification button.
	send_verification_button.pressed.connect(
		_on_send_verification_button_pressed
	)

	# Connect password controls.
	change_password_button.pressed.connect(
		_on_change_password_button_pressed
	)

	password_cancel_button.pressed.connect(
		_on_password_cancel_pressed
	)

	old_password_show.pressed.connect(
		_on_old_password_show_pressed
	)

	old_password_hide.pressed.connect(
		_on_old_password_hide_pressed
	)

	new_password_show.pressed.connect(
		_on_new_password_show_pressed
	)

	new_password_hide.pressed.connect(
		_on_new_password_hide_pressed
	)

	# Connect activity log controls.
	activity_log_button.pressed.connect(
		_on_activity_log_pressed
	)

	close_log_button.pressed.connect(
		_on_close_log_button_pressed
	)

	_set_profile_editable(false)

	# Load the account profile.
	await _load_profile()

	# Refresh Firebase email verification status.
	if AuthManager.is_logged_in():
		AuthManager.refresh_email_verification_status()
	else:
		verification_status.text = "Not authenticated."

	# Remind staff to finish account setup when Settings opens.
	if AuthManager.account_setup_required:
		show_setup_required_message()


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

	var response: Dictionary = await _firestore_get_user_profile()

	if not bool(response.get("ok", false)):
		_show_profile_status(
			"Unable to load profile: "
			+ str(response.get("error", "Unknown error."))
		)
		return

	current_profile = response.get("data", {})

	must_change_password = bool(
		current_profile.get("must_change_password", false)
	)

	_populate_profile_fields()

	profile_loaded = true

	_set_profile_editable(false)

	display_container.show()
	edit_container.hide()

	edit_button.show()
	update_button.hide()
	cancel_button.hide()

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
# POPULATE PROFILE
# ============================================================

func _populate_profile_fields() -> void:

	var first_name := str(current_profile.get("first_name", ""))
	var middle_initial := str(current_profile.get("middle_initial", ""))
	var last_name := str(current_profile.get("last_name", ""))
	var suffix := str(current_profile.get("suffix", ""))
	var id_number := str(current_profile.get("id_number", ""))

	# Populate editable fields.
	first_name_input.text = first_name
	middle_initial_input.text = middle_initial
	last_name_input.text = last_name
	suffix_input.text = suffix
	id_input.text = id_number

	# Populate display-only labels.
	display_first_name.text = first_name
	display_middle_initial.text = middle_initial
	display_last_name.text = last_name
	display_suffix.text = suffix
	display_id.text = id_number

	# Firebase Authentication is the source of truth for email.
	var firestore_email := str(
		current_profile.get("email", "")
	).strip_edges()

	if not firebase_account_email.is_empty():
		original_email = firebase_account_email
	else:
		original_email = firestore_email

	email_input.text = original_email
	display_email.text = original_email

	# Set email verification icons.
	_update_display_verification_icons(email_is_verified)


func _update_display_verification_icons(is_verified: bool) -> void:

	display_verified_icon.visible = is_verified
	display_not_verified_icon.visible = not is_verified


# ============================================================
# EDIT MODE
# ============================================================

func _on_edit_pressed() -> void:

	if not profile_loaded or is_saving:
		return

	is_editing = true

	_clear_password_fields()
	password_panel.hide()

	# Show the Change Password button whenever Edit mode opens.
	change_password_button.show()

	display_container.hide()
	edit_container.show()

	_set_profile_editable(true)

	edit_button.hide()
	update_button.show()
	cancel_button.show()

	if must_change_password:
		_show_profile_status(
			"Change your password first before changing your email."
		)
	else:
		_show_profile_status("Editing profile.")


func _on_cancel_pressed() -> void:

	if is_saving:
		return

	print("[Settings] Canceling profile edit.")

	# Restore the original profile values.
	_populate_profile_fields()

	_clear_password_fields()
	password_panel.hide()

	is_editing = false

	_set_profile_editable(false)

	# Return to display mode.
	edit_container.hide()
	display_container.show()

	edit_button.show()
	update_button.hide()
	cancel_button.hide()

	edit_button.disabled = false
	update_button.disabled = false
	cancel_button.disabled = false

	_show_profile_status("Changes discarded.")


func _set_profile_editable(enabled: bool) -> void:

	# Only admins may edit their LRN.
	id_input.editable = enabled and current_role == "admin"

	first_name_input.editable = enabled
	middle_initial_input.editable = enabled
	last_name_input.editable = enabled
	suffix_input.editable = enabled

	# Do not allow changing email while a previous change is pending.
	# Email changes are locked until the required password change is completed.
	email_input.editable = (
		enabled
		and not email_change_in_progress
		and not must_change_password
	)

	send_verification_button.disabled = (
		not enabled
		or must_change_password
		or email_change_in_progress
	)

	old_password_input.editable = enabled
	new_password_input.editable = enabled

	if not enabled:
		_clear_password_fields()


func _clear_password_fields() -> void:

	old_password_input.clear()
	new_password_input.clear()

	_set_password_visibility(false)


# ============================================================
# PASSWORD PANEL
# ============================================================

func _on_change_password_button_pressed() -> void:
	if not is_editing:
		return

	change_password_button.hide()
	password_panel.show()

func _on_password_cancel_pressed() -> void:
	_clear_password_fields()

	password_panel.hide()
	change_password_button.show()

func _set_password_visibility(show_password: bool) -> void:

	old_password_input.secret = not show_password
	old_password_show.visible = not show_password
	old_password_hide.visible = show_password

	new_password_input.secret = not show_password
	new_password_show.visible = not show_password
	new_password_hide.visible = show_password


func _on_old_password_show_pressed() -> void:

	old_password_input.secret = false
	old_password_show.hide()
	old_password_hide.show()


func _on_old_password_hide_pressed() -> void:

	old_password_input.secret = true
	old_password_show.show()
	old_password_hide.hide()


func _on_new_password_show_pressed() -> void:

	new_password_input.secret = false
	new_password_show.hide()
	new_password_hide.show()


func _on_new_password_hide_pressed() -> void:

	new_password_input.secret = true
	new_password_show.show()
	new_password_hide.hide()


func _on_password_change_completed(success: bool, result: Dictionary) -> void:

	if success:
		print("[Settings] Password changed successfully.")
	else:
		var error_message: String = str(
			result.get(
				"message",
				result.get("error", {}).get("message", "Unknown error.")
			)
		)

		push_error("[Settings] Password change failed: " + error_message)


# ============================================================
# SYNCHRONIZE EXISTING ACCOUNT EMAIL
# ============================================================

func _sync_existing_account_email() -> void:

	if is_saving:
		return

	if firebase_account_email.is_empty():
		push_warning("[Settings] Firebase email is unavailable.")
		return

	is_saving = true

	print("[Settings] Synchronizing account email...")

	var users_result := await _update_firestore_email(
		"users",
		current_uid,
		firebase_account_email
	)

	if not users_result.get("ok", false):
		push_error("[Settings] Failed to update users email.")
		is_saving = false
		return

	if current_role == "teacher":

		var teachers_result := await _update_firestore_email(
			"teachers",
			current_uid,
			firebase_account_email
		)

		if not teachers_result.get("ok", false):
			push_error("[Settings] Failed to update teachers email.")
			is_saving = false
			return

	var d1_result := await _sync_own_email_with_worker()

	if not d1_result.get("ok", false):
		push_error("[Settings] Failed to synchronize D1 email.")
		is_saving = false
		return

	original_email = firebase_account_email
	email_input.text = firebase_account_email
	display_email.text = firebase_account_email
	current_profile["email"] = firebase_account_email

	is_saving = false

	print("[Settings] Account email synchronization completed.")


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

	var requested_email := email_input.text.strip_edges()
	var new_password := new_password_input.text
	var password_changed := not new_password.is_empty()

	var email_changed := (
		requested_email.to_lower() != original_email.to_lower()
	)
	
	if must_change_password and email_changed:
		_show_profile_status(
			"Change your password first before changing your email."
		)
		return
	
	if email_changed:
		if not email_change_in_progress:
			_show_profile_status("Click Verify Email first.")
			return

		if requested_email.to_lower() != pending_email.to_lower():
			_show_profile_status("The email address differs from the verified request. Verify it again.")
			return

	if password_changed and old_password_input.text.strip_edges().is_empty():
		_show_profile_status("Enter your current password to change your password.")
		old_password_input.grab_focus()
		return

	if password_changed and new_password.length() < 6:
		_show_profile_status("New password must contain at least 6 characters.")
		new_password_input.grab_focus()
		return

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

	if current_role == "admin":
		var new_id_number := id_input.text.strip_edges()

		if new_id_number.is_empty():
			_show_profile_status("LRN is required.")
			id_input.grab_focus()
			return

		updated_fields["id_number"] = new_id_number

	is_saving = true
	update_button.disabled = true
	edit_button.disabled = true
	cancel_button.disabled = true
	var email_update_completed := false

	
	# Retrieve the latest Firebase account information.
	if email_changed:

		var account_result: Dictionary = await _get_latest_firebase_account_data()

		if not account_result.get("ok", false):
			_finish_profile_save()

			_show_profile_status(
				"Could not retrieve your latest Firebase account information. "
				+ str(account_result.get("message", "Please sign in again."))
			)
			return

		var latest_email: String = str(account_result.get("email", "")).strip_edges()
		var latest_verified: bool = account_result.get("verified", false)

		print("[Settings] Latest Firebase email: ", latest_email)
		print("[Settings] Latest verification status: ", latest_verified)

		# Firebase must already show the requested email.
		if latest_email.to_lower() != pending_email.to_lower():
			_finish_profile_save()

			verification_status.text = (
				"Waiting for email verification."
			)

			_show_profile_status(
				"Your email has not been updated by Firebase yet. "
				+ "Open the verification link. If your session expires, "
				+ "sign in again using your new email."
			)
			return

		# Firebase must report the new email as verified.
		if not latest_verified:
			_finish_profile_save()

			verification_status.text = (
				"The new email is not verified yet."
			)

			_show_profile_status(
				"Please verify your new email before updating."
			)
			return

		# Update the users collection first.
		_show_profile_status("Updating account email...")

		var users_result: Dictionary = await _update_firestore_email(
			"users",
			current_uid,
			pending_email
		)

		if not users_result.get("ok", false):
			_finish_profile_save()

			_show_profile_status(
				"Users email update failed: "
				+ str(users_result.get("error", "Unknown error"))
			)
			return

		# Teachers also have a separate teachers document.
		if current_role == "teacher":

			var teachers_result: Dictionary = await _update_firestore_email(
				"teachers",
				current_uid,
				pending_email
			)

			if not teachers_result.get("ok", false):
				_finish_profile_save()

				_show_profile_status(
					"Users email updated, but teachers email update failed: "
					+ str(teachers_result.get("error", "Unknown error"))
				)
				return

		# Synchronize Cloudflare D1 using the current ID token.
		_show_profile_status("Synchronizing Cloudflare account records...")

		var d1_result: Dictionary = await _sync_own_email_with_worker()

		if not d1_result.get("ok", false):
			_finish_profile_save()

			_show_profile_status(
				"Firestore updated, but D1 synchronization failed: "
				+ str(d1_result.get("error", "Unknown error"))
				+ ". Press Update again to retry."
			)
			return

		# Email synchronization succeeded.
		original_email = pending_email
		firebase_account_email = pending_email
		email_input.text = pending_email
		display_email.text = pending_email
		current_profile["email"] = pending_email

		pending_email = ""
		email_change_in_progress = false

		verification_status.text = "Email successfully updated."
		
		email_update_completed = true


	# Change password separately if requested.
	if password_changed:

		_show_profile_status("Changing password...")

		var password_result: Dictionary = await _request_password_change(
			new_password,
			old_password_input.text
		)

		if not bool(password_result.get("ok", false)):
			_finish_profile_save()

			_show_profile_status(
				"Password change failed: "
				+ str(password_result.get("message", "Unknown error."))
			)
			return

	# ============================================================
	# SAVE PROFILE TO USERS COLLECTION
	# ============================================================

	_show_profile_status("Saving profile...")

	print("[Settings] Name fields being saved: ", updated_fields)

	var result: Dictionary = await _update_user_profile(
		updated_fields,
		"users"
	)

	if not bool(result.get("ok", false)):
		_finish_profile_save()

		_show_profile_status(
			"Profile update failed: "
			+ str(result.get("error", "Unknown error."))
		)
		return


	# ============================================================
	# ALSO UPDATE TEACHERS COLLECTION (TEACHER ACCOUNTS ONLY)
	# ============================================================

	if current_role == "teacher":

		print("[Settings] Updating teachers collection...")

		var teacher_result: Dictionary = await _update_user_profile(
			updated_fields,
			"teachers"
		)

		if not bool(teacher_result.get("ok", false)):
			_finish_profile_save()

			_show_profile_status(
				"Users profile updated, but teachers profile failed: "
				+ str(teacher_result.get("error", "Unknown error."))
			)
			return

		print("[Settings] Teachers profile updated successfully.")

	# Clear temporary password requirement if applicable.
	if password_changed:

		print("[Settings] Clearing must_change_password flag...")

		var flag_result: Dictionary = await _update_must_change_password(false)

		if not bool(flag_result.get("ok", false)):
			_finish_profile_save()

			_show_profile_status(
				"Password and profile were updated, but account setup "
				+ "could not be completed: "
				+ str(flag_result.get("error", "Unknown error."))
			)
			return
		
		# Password requirement has now been cleared in Firestore.
		must_change_password = false

		print("[Settings] Password requirement cleared.")
		print("[Settings] Email changes are now enabled.")
		
		var email_verified: bool = await AuthManager.check_email_verified()

		AuthManager.account_setup_required = not email_verified

	# Update local profile data.
	for key in updated_fields:
		current_profile[key] = updated_fields[key]

	_populate_profile_fields()

	ActivityLogManager.log_activity(
		"Updated Profile",
		"Updated profile information: " + full_name,
		"Settings",
		current_uid
	)

	is_editing = false

	_set_profile_editable(false)

	edit_container.hide()
	display_container.show()

	edit_button.show()
	update_button.hide()
	cancel_button.hide()

	_finish_profile_save()

	if email_update_completed:

		print("[Settings] Email change completed successfully.")

		# Hide the normal settings interface.
		$PageBackground/VBoxContainer.hide()
		activity_log.hide()

		# Show the verification success panel.
		logout_panel.show()

	else:

		_show_profile_status("Profile updated successfully.")

	print("[Settings] Profile updated: ", current_uid)



func _get_latest_firebase_account_data() -> Dictionary:

	if not Firebase.Auth.is_logged_in():
		return {
			"ok": false,
			"message": "No active Firebase session. Please sign in again."
		}

	if Firebase.Auth.is_busy:
		return {
			"ok": false,
			"message": "Firebase is currently processing another request. Please wait and try again."
		}

	# ------------------------------------------------------------
	# STEP 1: REFRESH THE FIREBASE ID TOKEN
	# ------------------------------------------------------------

	print("[Settings] Refreshing Firebase ID token...")

	Firebase.Auth.refresh_auth_token()

	var refresh_result: Array = await Firebase.Auth.token_refresh_completed

	if refresh_result.size() < 2 or not bool(refresh_result[0]):

		var refresh_error: Dictionary = {}

		if refresh_result.size() >= 2 and refresh_result[1] is Dictionary:
			refresh_error = refresh_result[1]

		print("[Settings] Firebase token refresh failed: ", refresh_error)

		return {
			"ok": false,
			"message": (
				"Firebase session expired or could not be refreshed. "
				+ "Please sign in again using your current email address."
			)
		}

	print("[Settings] Firebase ID token refreshed successfully.")

	# ------------------------------------------------------------
	# STEP 2: RETRIEVE THE LATEST FIREBASE ACCOUNT INFORMATION
	# ------------------------------------------------------------

	if Firebase.Auth.is_busy:
		return {
			"ok": false,
			"message": "Firebase is busy. Please try again."
		}

	print("[Settings] Requesting latest Firebase account information...")

	Firebase.Auth.get_user_data()

	var account_result: Array = await Firebase.Auth.userdata_request_completed

	if account_result.size() < 2 or not bool(account_result[0]):

		var account_error: Dictionary = {}

		if account_result.size() >= 2 and account_result[1] is Dictionary:
			account_error = account_result[1]

		print("[Settings] Firebase account information request failed: ", account_error)

		return {
			"ok": false,
			"message": str(
				account_error.get(
					"message",
					"Unable to retrieve Firebase account information."
				)
			)
		}

	# AuthManager receives userdata_received before
	# userdata_request_completed is emitted.
	var latest_email := firebase_account_email.strip_edges()
	var latest_verified := email_is_verified

	print("[Settings] Latest Firebase email: ", latest_email)
	print("[Settings] Latest email verified: ", latest_verified)

	return {
		"ok": true,
		"email": latest_email,
		"verified": latest_verified
	}



func _finish_profile_save() -> void:
	is_saving = false
	update_button.disabled = false
	edit_button.disabled = false
	cancel_button.disabled = false



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


# ============================================================
# FIRESTORE PROFILE UPDATE
# ============================================================

func _update_user_profile(
	data: Dictionary,
	collection: String = "users"
) -> Dictionary:

	var token := _get_current_id_token()

	if token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	var url := _firestore_document_url(
		collection,
		current_uid
	)

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



func _update_must_change_password(required: bool) -> Dictionary:

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

	url += "?updateMask.fieldPaths=must_change_password"

	var request_body := JSON.stringify({
		"fields": {
			"must_change_password": {
				"booleanValue": required
			}
		}
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
			"error": "Could not start password requirement update."
		}

	var response: Array = await http.request_completed

	var response_code := int(response[1])
	var response_text := (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	http.queue_free()

	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"error": response_text
		}

	return {
		"ok": true
	}



func _update_firestore_email(
	collection: String,
	document_id: String,
	new_email: String
) -> Dictionary:

	var token := _get_current_id_token()

	if token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	var url := _firestore_document_url(collection, document_id)
	url += "?updateMask.fieldPaths=email"

	var request_body := JSON.stringify({
		"fields": {
			"email": {
				"stringValue": new_email
			}
		}
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
			"error": "Could not start Firestore email update."
		}

	var response: Array = await http.request_completed

	var response_code := int(response[1])

	var response_text := (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	http.queue_free()

	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"error": response_text
		}

	return {
		"ok": true
	}


# ============================================================
# CLOUDFLARE WORKER / D1 EMAIL SYNCHRONIZATION
# ============================================================

func _sync_own_email_with_worker() -> Dictionary:

	var token := _get_current_id_token()

	if token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	var url := "https://atomix-auth-api.atomix-auth.workers.dev/sync-own-email"

	var request_body := JSON.stringify({
		"idToken": token
	})

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var http := HTTPRequest.new()
	add_child(http)

	var request_error := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		request_body
	)

	if request_error != OK:

		http.queue_free()

		return {
			"ok": false,
			"error": "Could not start D1 synchronization request."
		}

	var response: Array = await http.request_completed

	var response_code := int(response[1])

	var response_text := (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	http.queue_free()

	var parsed: Variant = JSON.parse_string(response_text)

	if not parsed is Dictionary:
		return {
			"ok": false,
			"error": "Invalid response from the authentication server."
		}

	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"error": str(
				parsed.get("message", "D1 synchronization failed.")
			)
		}

	if not bool(parsed.get("success", false)):
		return {
			"ok": false,
			"error": str(
				parsed.get("message", "D1 synchronization failed.")
			)
		}

	return {
		"ok": true,
		"data": parsed
	}


# ============================================================
# REQUEST EMAIL CHANGE
# ============================================================

func _request_email_change_verification(new_email: String) -> Dictionary:
	new_email = new_email.strip_edges()

	if new_email.is_empty() or not new_email.contains("@"):
		return {
			"ok": false,
			"message": "Please enter a valid email address."
		}

	if new_email.to_lower() == original_email.to_lower():
		return {
			"ok": false,
			"message": "Please enter a different email address."
		}

	pending_email = new_email
	email_change_in_progress = true

	Firebase.Auth.send_email_change_verification(new_email)

	var result: Array = await Firebase.Auth.credential_operation_completed

	var operation: String = result[0]
	var success: bool = result[1]
	var response: Dictionary = result[2]

	if operation != "email_change" or not success:
		pending_email = ""
		email_change_in_progress = false

		return {
			"ok": false,
			"message": str(response)
		}

	return {
		"ok": true,
		"message": "Verification link sent to " + new_email
	}
# ============================================================
# REQUEST PASSWORD CHANGE
# ============================================================

func _request_password_change(
	new_password: String,
	current_password: String
) -> Dictionary:

	if new_password.length() < 6:
		return {
			"ok": false,
			"message": "New password must contain at least 6 characters."
		}

	if current_password.strip_edges().is_empty():
		return {
			"ok": false,
			"message": "Enter your current password."
		}

	# Reauthenticate before changing the password.
	Firebase.Auth.reauthenticate_user(
		original_email,
		current_password
	)

	var reauth_response: Array = await Firebase.Auth.reauthentication_completed

	var reauth_success: bool = bool(reauth_response[0])
	var reauth_result: Dictionary = reauth_response[1]

	if not reauth_success:
		return {
			"ok": false,
			"message": str(
				reauth_result.get(
					"message",
					"Current password is incorrect or reauthentication failed."
				)
			)
		}

	# Update Firebase password.
	Firebase.Auth.change_user_password(new_password)

	var password_response: Array = await Firebase.Auth.password_change_completed

	var password_success: bool = bool(password_response[0])
	var password_result: Dictionary = password_response[1]

	if not password_success:
		return {
			"ok": false,
			"message": str(
				password_result.get(
					"message",
					"Password change failed."
				)
			)
		}

	return {
		"ok": true,
		"message": "Password changed successfully."
	}


# ============================================================
# EMAIL VERIFICATION
# ============================================================
func _on_send_verification_button_pressed() -> void:
	
	if must_change_password:
		_show_profile_status(
			"Change your password first before changing your email."
		)
		return
	
	if not AuthManager.is_logged_in():
		_show_profile_status("You must be logged in to change your email.")
		return

	var new_email := email_input.text.strip_edges()

	if new_email.is_empty():
		_show_profile_status("Please enter your new email address.")
		return

	if new_email.to_lower() == original_email.to_lower():
		_show_profile_status("Please enter a different email address.")
		return

	send_verification_button.disabled = true

	_show_profile_status("Sending verification link...")

	var result: Dictionary = await _request_email_change_verification(new_email)

	send_verification_button.disabled = false

	if result.get("ok", false):
		_show_profile_status(
			"Verification link sent to " + new_email +
			". Check your inbox and verify the new address."
		)
	else:
		_show_profile_status(
			"Email verification failed: " + str(result.get("message", "Unknown error"))
		)


func _on_email_verification_status_received(
	is_verified: bool
) -> void:
	email_is_verified = is_verified
	
	if is_verified:

		verification_status.text = "Verified"
		send_verification_button.hide()

	else:

		verification_status.text = "Not Verified"
		send_verification_button.show()

	_update_display_verification_icons(is_verified)


func _on_account_data_received(
	firebase_email: String,
	is_verified: bool
) -> void:
	email_is_verified = is_verified

	print("[Settings] ===== EMAIL SYNC CHECK =====")
	print("[Settings] Firebase email: ", firebase_email)
	print("[Settings] Verified: ", is_verified)

	firebase_account_email = firebase_email.strip_edges()

	if firebase_account_email.is_empty():
		push_warning("[Settings] Received an empty Firebase email.")
		return

	_update_display_verification_icons(is_verified)

	# No email change is pending.
	if not email_change_in_progress:
		original_email = firebase_account_email
		email_input.text = firebase_account_email
		display_email.text = firebase_account_email

		var firestore_email := str(
			current_profile.get("email", "")
		).strip_edges()

		if profile_loaded and firestore_email != firebase_account_email:
			print("[Settings] Firestore email is outdated.")
			await _sync_existing_account_email()

		return

	# Firebase has not changed to the requested email yet.
	if firebase_account_email.to_lower() != pending_email.to_lower():
		print("[Settings] Waiting for verification at: ", pending_email)

		verification_status.text = (
			"Waiting for verification at " + pending_email
		)
		return

	# Firebase email matches, but verification is incomplete.
	if not is_verified:
		verification_status.text = "The new email is not verified yet."
		return

	# New email is verified. Wait for the Update button.
	verification_status.text = (
		"New email verified. Press Update to save your changes."
	)

	print("[Settings] New email verified. Waiting for Update button.")


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

	status_log.text = message


func show_setup_required_message() -> void:

	if not AuthManager.account_setup_required:
		return

	var message := (
        "Finish setting up your account first. "
		+ "Change your password and verify your email "
		+ "before accessing other pages."
	)

	_show_profile_status(message)

# ============================================================
# LOG OUT
# ============================================================

func _on_logout_button_pressed() -> void:

	AuthManager.logout()

	await get_tree().create_timer(0.2).timeout

	get_tree().change_scene_to_file(
		"res://Scenes/UI/MainMenu.tscn"
	)

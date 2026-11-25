
extends CanvasLayer

signal validation_completed

const PROJECT_ID := "atomix-f6c6b"
const FIRESTORE_BASE := "https://firestore.googleapis.com/v1/projects/"

@onready var password_panel: Panel = $ColorRect/PasswordPanel
@onready var old_password_input: LineEdit = $ColorRect/PasswordPanel/VBoxContainer/OldPassword/Password
@onready var new_password_input: LineEdit = $ColorRect/PasswordPanel/VBoxContainer/NewPassword/Password
@onready var update_password_button: Button = $ColorRect/PasswordPanel/VBoxContainer/HBoxContainer/UpdateButton
@onready var next_password_button: Button = $ColorRect/PasswordPanel/VBoxContainer/HBoxContainer/NextButton

@onready var password_status_label: Label = $ColorRect/PasswordPanel/VBoxContainer/StatusLabel
@onready var old_password_label: Label = $ColorRect/PasswordPanel/VBoxContainer/OldPassword/Label2
@onready var new_password_label: Label = $ColorRect/PasswordPanel/VBoxContainer/NewPassword/Label2

@onready var email_panel: Panel = $ColorRect/EmailPanel
@onready var email_input: LineEdit = $ColorRect/EmailPanel/VBoxContainer/Email/Email
@onready var resend_button: Button = $ColorRect/EmailPanel/VBoxContainer/HBoxContainer2/Button
@onready var verify_button: Button = $ColorRect/EmailPanel/VBoxContainer/HBoxContainer/VerifyButton

@onready var logout_panel: Panel = $ColorRect/LogoutPanel
@onready var logout_button: Button = $ColorRect/LogoutPanel/VBoxContainer/Button

var current_uid: String = ""
var current_email: String = ""
var pending_email: String = ""
var email_verified: bool = false

var password_change_required: bool = false
var validation_busy: bool = false

var email_change_in_progress: bool = false
var email_change_verified_ready: bool = false

func _ready() -> void:
	# Mask password fields.
	old_password_input.secret = true
	new_password_input.secret = true

	password_panel.hide()
	email_panel.hide()
	logout_panel.hide()
	next_password_button.hide()

	# Initial email verification button text.
	resend_button.text = "Send Link"

	update_password_button.pressed.connect(_on_update_password_pressed)
	next_password_button.pressed.connect(_on_next_password_pressed)

	resend_button.pressed.connect(_on_resend_pressed)
	verify_button.pressed.connect(_on_verify_pressed)

	logout_button.pressed.connect(_on_email_logout_pressed)

	if not AuthManager.account_data_received.is_connected(_on_account_data_received):
		AuthManager.account_data_received.connect(_on_account_data_received)

	if not AuthManager.email_verification_status_received.is_connected(_on_email_verification_status_received):
		AuthManager.email_verification_status_received.connect(_on_email_verification_status_received)

	current_uid = AuthManager.get_uid()

	if current_uid.is_empty():
		_show_message("Your session has expired. Please log in again.")
		return

	await _begin_validation()


# ============================================================
# START VALIDATION
# ============================================================

func _begin_validation() -> void:
	print("[AccountValidation] Checking password requirement...")

	password_panel.show()
	email_panel.hide()
	logout_panel.hide()

	password_status_label.show()
	password_status_label.text = "Checking your password..."

	var must_change: bool = await AuthManager.needs_password_change()
	password_change_required = must_change

	print("[AccountValidation] Must change password: ", must_change)

	if must_change:
		# Password change is required.
		old_password_label.show()
		new_password_label.show()

		old_password_input.show()
		new_password_input.show()

		update_password_button.show()
		update_password_button.disabled = false

		next_password_button.hide()

		password_status_label.text = "You must change your password before continuing."

	else:
		# Password is already changed.
		old_password_label.hide()
		new_password_label.hide()

		old_password_input.hide()
		new_password_input.hide()

		update_password_button.hide()

		next_password_button.show()
		next_password_button.disabled = false

		password_status_label.text = "Your password is already changed. Press Next to continue."

	print("[AccountValidation] Status message: ", password_status_label.text)


func _show_password_panel() -> void:
	password_panel.show()
	email_panel.hide()
	logout_panel.hide()

	old_password_input.clear()
	new_password_input.clear()

	old_password_label.show()
	new_password_label.show()

	old_password_input.show()
	new_password_input.show()

	update_password_button.show()
	update_password_button.disabled = false
	next_password_button.hide()

	password_change_required = true

	_show_message("You must change your password before continuing.")


# ============================================================
# PASSWORD CHANGE
# ============================================================

func _on_update_password_pressed() -> void:
	if validation_busy:
		return

	var old_password := old_password_input.text
	var new_password := new_password_input.text

	if old_password.is_empty():
		_show_message("Please enter your current password.")
		return

	if new_password.length() < 6:
		_show_message("New password must contain at least 6 characters.")
		return

	if old_password == new_password:
		_show_message("Your new password must be different from your current password.")
		return

	validation_busy = true
	update_password_button.disabled = true

	_show_message("Verifying your current password...")

	# Use the email retrieved from Firebase account information.
	current_email = current_email.strip_edges()

	if current_email.is_empty():
		validation_busy = false
		update_password_button.disabled = false
		_show_message("Unable to determine your account email. Please try logging in again.")
		push_error("[AccountValidation] Firebase account email is empty.")
		return

	print("[AccountValidation] Reauthenticating with email: ", current_email)

	Firebase.Auth.reauthenticate_user(current_email, old_password)

	var reauth_result = await Firebase.Auth.reauthentication_completed

	if not _auth_operation_succeeded(reauth_result):
		validation_busy = false
		update_password_button.disabled = false
		_show_message("Current password is incorrect. Please try again.")
		return

	_show_message("Updating your password...")

	Firebase.Auth.change_user_password(new_password)

	var password_result = await Firebase.Auth.password_change_completed

	if not _auth_operation_succeeded(password_result):
		validation_busy = false
		update_password_button.disabled = false
		_show_message("Unable to change password. Please try again.")
		return

	_show_message("Password updated. Updating account records...")

	# Clear the password requirement in the students document.
	var student_flag_result: Dictionary = await _firestore_patch_document(
		"students",
		current_uid,
		{"must_change_password": false}
	)

	# Clear the password requirement in the users document.
	var user_flag_result: Dictionary = await _firestore_patch_document(
		"users",
		current_uid,
		{"must_change_password": false}
	)

	if not student_flag_result.get("ok", false):
		validation_busy = false
		update_password_button.disabled = false
		_show_message("Password changed, but student account status failed to update. Please try again.")
		push_warning("[AccountValidation] Student password flag update failed.")
		return

	if not user_flag_result.get("ok", false):
		validation_busy = false
		update_password_button.disabled = false
		_show_message("Password changed, but account status failed to update. Please try again.")
		push_warning("[AccountValidation] User password flag update failed.")
		return

	# Password change is completed.
	old_password_input.clear()
	new_password_input.clear()

	password_change_required = false

	old_password_label.hide()
	new_password_label.hide()

	old_password_input.hide()
	new_password_input.hide()

	update_password_button.hide()

	next_password_button.show()
	next_password_button.disabled = false

	validation_busy = false

	_show_message("Password successfully updated. Press Next to continue.")


func _on_next_password_pressed() -> void:
	if validation_busy:
		return

	if password_change_required:
		_show_message("Please change your password before continuing.")
		return

	password_panel.hide()
	await _check_email_validation()


# ============================================================
# EMAIL VERIFICATION
# ============================================================
func _check_email_validation() -> void:
	password_panel.hide()
	email_panel.hide()
	logout_panel.hide()

	var refreshed: bool = await AuthManager.refresh_email_verification_status()

	if not refreshed:
		email_panel.hide()
		logout_panel.show()
		_show_message("Your session has expired. Please log out and sign in again.")
		return
	# If a new email change is already in progress,
	# do not bypass its verification.
	if email_change_in_progress:
		email_panel.show()

		if email_change_verified_ready:
			_show_message("Your new email is verified. Press Verify to continue.")
		else:
			_show_message("Please verify your new email to continue.")

		return

	# Do not automatically pass using the old email's verification.
	email_panel.show()

	_show_message("Please enter your new email and send the verification link.")

# Send Link / Resend Link button.
func _on_resend_pressed() -> void:

	if validation_busy:
		return

	var new_email := email_input.text.strip_edges().to_lower()


	if new_email.is_empty():
		_show_message("Please enter your new email address.")
		return

	if not _is_valid_email(new_email):
		_show_message("Please enter a valid email address.")
		return

	validation_busy = true
	resend_button.disabled = true
	resend_button.text = "Sending..."
	_show_message("Sending verification email to " + new_email + "...")

	var result: Dictionary = await AuthManager.send_email_change_verification(new_email)

	validation_busy = false
	resend_button.disabled = false

	if result.get("success", false):
		pending_email = new_email
		email_change_in_progress = true
		email_change_verified_ready = false

		resend_button.text = "Resend Link"
		_show_message("Verification link sent to " + new_email + ". Please check your inbox.")
	else:
		resend_button.text = "Send Link"
		_show_message("Unable to send verification email: " + str(result.get("error", "Unknown error.")))
func _on_verify_pressed() -> void:
	if validation_busy:
		return

	if not email_change_in_progress:
		_show_message("Please enter a new email and send the verification link first.")
		return

	if pending_email.is_empty():
		_show_message("No pending email address found.")
		return

	validation_busy = true
	verify_button.disabled = true
	_show_message("Checking your new email verification...")

	var refresh_success: bool = await AuthManager.refresh_email_verification_status()

	if not refresh_success:
		validation_busy = false
		verify_button.disabled = false

		password_panel.hide()
		email_panel.hide()
		logout_panel.show()

		logout_button.disabled = false

		_show_message(
	        "Your email verification process is complete or your session has expired. "
			+ "Please log out and sign in using your updated email."
		)

		print("[AccountValidation] Firebase refresh failed. Redirecting user to logout panel.")

		return

	validation_busy = false
	verify_button.disabled = false

	if not email_change_verified_ready:
		_show_message("Your new email is not verified yet. Please check your inbox and click the verification link.")
		return

	if current_email.to_lower() != pending_email.to_lower():
		_show_message("Your Firebase email does not match the new email you submitted.")
		return

	if not email_verified:
		_show_message("Your new email is not verified yet.")
		return

	_show_message("Email verified successfully!")
	_finish_validation()

func _on_account_data_received(
	firebase_email: String,
	is_verified: bool
) -> void:
	email_verified = is_verified
	current_email = firebase_email.strip_edges()

	print("[AccountValidation] Firebase email: ", current_email)
	print("[AccountValidation] Email verified: ", email_verified)

	# No new email verification is in progress.
	if not email_change_in_progress:
		return

	# Firebase has not switched to the pending email yet.
	if current_email.to_lower() != pending_email.to_lower():
		_show_message("Waiting for verification at " + pending_email)
		return

	# Firebase email matches the pending email, but isn't verified.
	if not email_verified:
		_show_message("The new email is not verified yet.")
		return

	# The new email has been changed and verified.
	email_change_verified_ready = true

	_show_message("New email verified successfully!")


func _on_email_verification_status_received(is_verified: bool) -> void:
	email_verified = is_verified


# ============================================================
# EMAIL SYNC WITH CLOUDFLARE WORKER
# ============================================================

func _sync_verified_email_with_worker() -> Dictionary:
	var id_token := _get_current_id_token()

	if id_token.is_empty():
		return {
			"success": false,
			"message": "Firebase ID token is unavailable."
		}

	var url := "https://atomix-auth-api.atomix-auth.workers.dev/sync-own-email"

	var http := HTTPRequest.new()
	add_child(http)

	var request_error := http.request(
		url,
		PackedStringArray([
			"Content-Type: application/json"
		]),
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"idToken": id_token
		})
	)

	if request_error != OK:
		http.queue_free()
		return {
			"success": false,
			"message": "Could not start email synchronization request."
		}

	var response: Array = await http.request_completed
	http.queue_free()

	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	var json := JSON.new()
	var parse_error := json.parse(
		response_body.get_string_from_utf8()
	)

	if parse_error != OK:
		return {
			"success": false,
			"message": "Invalid response from email synchronization server."
		}

	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"message": str(json.data.get("message", "Email synchronization failed."))
		}

	return json.data


# ============================================================
# VALIDATION COMPLETE
# ============================================================

func _finish_validation() -> void:
	validation_busy = true
	verify_button.disabled = true

	_show_message("Email verified. Synchronizing account records...")

	var sync_result: Dictionary = await _sync_verified_email_with_worker()

	validation_busy = false
	verify_button.disabled = false

	if not sync_result.get("success", false):
		email_panel.show()

		_show_message(
			"Email verified, but account synchronization failed: "
			+ str(sync_result.get("message", "Unknown error."))
		)

		push_warning("[AccountValidation] Email synchronization failed: " + str(sync_result))

		return

	password_panel.hide()
	email_panel.hide()
	logout_panel.hide()

	_show_message("Email verified and account records synchronized successfully.")

	print("[AccountValidation] Email verification and synchronization completed.")

	validation_completed.emit()

# ============================================================
# LOG OUT
# ============================================================

func _on_email_logout_pressed() -> void:
	AuthManager.logout()

	await get_tree().create_timer(0.2).timeout

	get_tree().change_scene_to_file(
		"res://Scenes/UI/MainMenu.tscn"
	)


# ============================================================
# FIRESTORE REST
# ============================================================

func _get_current_id_token() -> String:
	if Firebase.Auth.auth is Dictionary:
		var auth_data: Dictionary = Firebase.Auth.auth

		var token := str(
			auth_data.get(
				"idtoken",
				auth_data.get("idToken", "")
			)
		)

		if not token.is_empty():
			return token

	if Firebase.Firestore.auth is Dictionary:
		var firestore_auth: Dictionary = Firebase.Firestore.auth

		var token := str(
			firestore_auth.get(
				"idtoken",
				firestore_auth.get("idToken", "")
			)
		)

		if not token.is_empty():
			return token

	return ""


func _firestore_headers() -> PackedStringArray:
	return PackedStringArray([
		"Authorization: Bearer " + _get_current_id_token(),
		"Content-Type: application/json"
	])


func _firestore_document_url(
	collection: String,
	document_id: String
) -> String:
	return FIRESTORE_BASE \
		+ PROJECT_ID \
		+ "/databases/(default)/documents/" \
		+ collection \
		+ "/" \
		+ document_id.uri_encode()


func _firestore_patch_document(
	collection: String,
	document_id: String,
	updates: Dictionary
) -> Dictionary:
	var token := _get_current_id_token()

	if token.is_empty():
		return {
			"ok": false,
			"message": "Firebase ID token is unavailable."
		}

	var url := _firestore_document_url(collection, document_id)
	var query_parameters: PackedStringArray = []
	var firestore_fields: Dictionary = {}

	for key in updates:
		query_parameters.append(
			"updateMask.fieldPaths=" + str(key).uri_encode()
		)

		var value: Variant = updates[key]

		if value is bool:
			firestore_fields[key] = {
				"booleanValue": value
			}
		elif value is int:
			firestore_fields[key] = {
				"integerValue": str(value)
			}
		else:
			firestore_fields[key] = {
				"stringValue": str(value)
			}

	url += "?" + "&".join(query_parameters)

	var http := HTTPRequest.new()
	add_child(http)

	var request_error := http.request(
		url,
		_firestore_headers(),
		HTTPClient.METHOD_PATCH,
		JSON.stringify({"fields": firestore_fields})
	)

	if request_error != OK:
		http.queue_free()
		return {
			"ok": false,
			"message": "Could not start Firestore update."
		}

	var response: Array = await http.request_completed
	http.queue_free()

	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	var json := JSON.new()
	var parse_error := json.parse(response_body.get_string_from_utf8())

	if parse_error != OK:
		return {
			"ok": false,
			"message": "Invalid Firestore response."
		}

	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"message": str(json.data)
		}

	return {
		"ok": true,
		"data": json.data
	}


# ============================================================
# AUTH RESULT CHECK
# ============================================================

func _auth_operation_succeeded(result: Variant) -> bool:
	if result is bool:
		return result

	if result is Dictionary:
		if result.has("success"):
			return result["success"] == true

		if result.has("ok"):
			return result["ok"] == true

		if result.has("error"):
			return false

		if result.has("message") and str(result["message"]).to_lower().contains("error"):
			return false

		return result.has("user") or result.has("data")

	if result is Array:
		if result.is_empty():
			return false

		return _auth_operation_succeeded(result[0])

	return false


# ============================================================
# STATUS MESSAGE
# ============================================================

func _show_message(message: String) -> void:
	print("[AccountValidation] ", message)

	if is_instance_valid(password_status_label):
		password_status_label.show()
		password_status_label.text = message


func _is_valid_email(value: String) -> bool:
	var at_position := value.find("@")
	var dot_position := value.rfind(".")

	return at_position > 0 \
		and dot_position > at_position + 1 \
		and dot_position < value.length() - 1

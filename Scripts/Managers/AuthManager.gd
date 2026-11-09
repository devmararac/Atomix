extends Node

signal login_success(user_data)
signal login_failed(message)

signal signup_success(user_data)
signal signup_failed(message)

# Emitted ONLY when Firebase restores a previously saved
# authentication session.
signal session_restored(user_data)

signal email_verification_status_received(is_verified: bool)

var current_user: Dictionary = {}
var user_uid: String = ""
var current_role: String = ""

const AUTH_API_URL := "https://atomix-auth-api.atomix-auth.workers.dev"

var auth_api_request: HTTPRequest
var pending_login := false


func _ready() -> void:
	
	auth_api_request = HTTPRequest.new()
	auth_api_request.name = "AuthAPIRequest"
	add_child(auth_api_request)

	auth_api_request.request_completed.connect(_on_auth_api_request_completed)
	
	if Firebase.Auth == null:
		push_error("Firebase.Auth is null!")
		return

	if not Firebase.Auth.login_succeeded.is_connected(_on_login_success):
		Firebase.Auth.login_succeeded.connect(_on_login_success)

	if not Firebase.Auth.login_failed.is_connected(_on_login_failed):
		Firebase.Auth.login_failed.connect(_on_login_failed)

	if not Firebase.Auth.signup_succeeded.is_connected(_on_signup_success):
		Firebase.Auth.signup_succeeded.connect(_on_signup_success)

	if not Firebase.Auth.signup_failed.is_connected(_on_signup_failed):
		Firebase.Auth.signup_failed.connect(_on_signup_failed)

	if not Firebase.Auth.userdata_received.is_connected(_on_userdata_received):
		Firebase.Auth.userdata_received.connect(_on_userdata_received)

	if Firebase.Auth.has_signal("token_refresh_succeeded") and not Firebase.Auth.token_refresh_succeeded.is_connected(_on_token_refresh_succeeded):
		Firebase.Auth.token_refresh_succeeded.connect(_on_token_refresh_succeeded)

	if Firebase.Auth.has_signal("logged_out") and not Firebase.Auth.logged_out.is_connected(_on_logged_out):
		Firebase.Auth.logged_out.connect(_on_logged_out)
	
	

func login(identifier: String, password: String) -> void:
	if pending_login:
		return

	if identifier.strip_edges().is_empty() or password.is_empty():
		login_failed.emit("Please enter your email or LRN/ID and password.")
		return

	pending_login = true

	var request_body := {
		"identifier": identifier.strip_edges(),
		"password": password
	}

	var headers := [
		"Content-Type: application/json"
	]

	var body := JSON.stringify(request_body)

	var error := auth_api_request.request(
		AUTH_API_URL + "/login",
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		pending_login = false
		login_failed.emit("Unable to send login request.")


func signup(email: String, password: String) -> void:
	Firebase.Auth.signup_with_email_and_password(email, password)


func _on_login_success(auth_result: Dictionary) -> void:
	_set_auth_state(auth_result)
	Firebase.Auth.save_auth(auth_result)

	print("[AuthManager] Firebase login succeeded.")
	print("[AuthManager] UID: ", user_uid)

	# ------------------------------------------------------------
	# CHECK WHETHER THIS WAS A RESTORED SESSION
	# ------------------------------------------------------------
	if FirebaseManager.is_restoring_saved_session():
		print("[AuthManager] Existing session restored.")
		print("[AuthManager] Emitting session_restored.")

		session_restored.emit(auth_result)

		return

	# ------------------------------------------------------------
	# NORMAL MANUAL LOGIN
	# ------------------------------------------------------------
	print("[AuthManager] Manual login detected.")
	print("[AuthManager] Emitting login_success.")

	login_success.emit(auth_result)


func _on_login_failed(code, message) -> void:
	print("[AuthManager] Login failed: ", code, " - ", message)

	login_failed.emit(message)


func _on_signup_success(auth_result: Dictionary) -> void:
	_set_auth_state(auth_result)
	Firebase.Auth.save_auth(auth_result)

	print("[AuthManager] Signup successful")
	print("[AuthManager] UID: ", user_uid)

	signup_success.emit(auth_result)


func _on_signup_failed(code, message) -> void:
	print("[AuthManager] Signup failed: ", code, " - ", message)

	signup_failed.emit(message)


func _on_token_refresh_succeeded(auth_result: Dictionary) -> void:
	_set_auth_state(auth_result)
	Firebase.Auth.save_auth(auth_result)

	print("[AuthManager] Firebase token refreshed and saved.")

	var token := str(
		current_user.get(
			"idtoken",
			current_user.get("idToken", "")
		)
	)

	if not current_role.is_empty() and not token.is_empty():
		ActivityLogManager.initialize(
			user_uid,
			current_role,
			token
		)

func _on_logged_out() -> void:
	current_user.clear()
	user_uid = ""
	current_role = ""

	ActivityLogManager.initialize("", "", "")

	print("[AuthManager] Firebase logout completed.")


func _set_auth_state(auth_result: Dictionary) -> void:
	current_user = auth_result.duplicate(true)

	user_uid = str(
		auth_result.get(
			"localid",
			auth_result.get("localId", "")
		)
	)


func logout() -> void:
	if Firebase.Auth != null:
		Firebase.Auth.logout()
	else:
		current_user.clear()
		user_uid = ""


func get_uid() -> String:
	return user_uid


func is_logged_in() -> bool:
	return not user_uid.is_empty()

func get_user_role() -> String:
	var uid := get_uid()

	if uid.is_empty():
		print("[AuthManager] No UID available.")
		return ""

	var users = Firebase.Firestore.collection("users")
	var user_doc: FirestoreDocument = await users.get_doc(uid)

	if user_doc == null:
		print("[AuthManager] No user document found for UID: ", uid)
		return ""

	current_role = str(user_doc.get_value("role"))

	print("[AuthManager] User role: ", current_role)

	# Initialize ActivityLogManager after the role is retrieved.
	var token := str(
		current_user.get(
			"idtoken",
			current_user.get("idToken", "")
		)
	)

	if not current_role.is_empty() and not token.is_empty():
		ActivityLogManager.initialize(
			user_uid,
			current_role,
			token
		)
	else:
		push_warning(
			"[AuthManager] Activity logger not initialized. "
			+ "Role or Firebase token is missing."
		)

	return current_role


func get_account_status() -> String:
	var uid := get_uid()

	if uid.is_empty():
		return ""

	var users = Firebase.Firestore.collection("users")

	var user_doc: FirestoreDocument = await users.get_doc(uid)

	if user_doc == null:
		return ""

	return str(user_doc.get_value("status"))


func get_account_school_year() -> String:
	var uid := get_uid()

	if uid.is_empty():
		return ""

	var users = Firebase.Firestore.collection("users")

	var user_doc: FirestoreDocument = await users.get_doc(uid)

	if user_doc == null:
		return ""

	return str(user_doc.get_value("school_year"))


# Request the latest account information from Firebase.
func refresh_email_verification_status() -> void:

	if not is_logged_in():
		push_warning("[AuthManager] Cannot check email verification. No user logged in.")
		return

	Firebase.Auth.get_user_data()


# Receive the account information returned by Firebase.
func _on_userdata_received(userdata: FirebaseUserData) -> void:

	var is_verified: bool = userdata.email_verified

	print("[AuthManager] Email verified: ", is_verified)

	email_verification_status_received.emit(is_verified)


# Send a verification email to the current account.
func send_email_verification() -> void:

	if not is_logged_in():
		push_warning("[AuthManager] Cannot send verification email. No user logged in.")
		return

	Firebase.Auth.send_account_verification_email()


func _on_auth_api_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	pending_login = false

	# Check whether the HTTP request itself succeeded.
	if result != HTTPRequest.RESULT_SUCCESS:
		login_failed.emit("Unable to connect to the authentication server.")
		return

	# Convert the server response into a Dictionary.
	var response_text := body.get_string_from_utf8()
	var response_data = JSON.parse_string(response_text)

	if not response_data is Dictionary:
		login_failed.emit("Invalid response from authentication server.")
		return

	# Check the Worker's login result.
	if response_code != 200 or not response_data.get("success", false):
		login_failed.emit(
			str(response_data.get("message", "Invalid login credentials."))
		)
		return

	# Give the Firebase add-on the tokens returned by the Worker.
	var adopted: bool = Firebase.Auth.adopt_external_auth_result(response_data)

	if not adopted:
		login_failed.emit("Unable to establish the Firebase session.")

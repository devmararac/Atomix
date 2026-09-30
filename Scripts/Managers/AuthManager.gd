extends Node

signal login_success(user_data)
signal login_failed(message)

signal signup_success(user_data)
signal signup_failed(message)

# Emitted ONLY when Firebase restores a previously saved
# authentication session.
signal session_restored(user_data)

var current_user: Dictionary = {}
var user_uid: String = ""


func _ready() -> void:
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

	if Firebase.Auth.has_signal("token_refresh_succeeded") and not Firebase.Auth.token_refresh_succeeded.is_connected(_on_token_refresh_succeeded):
		Firebase.Auth.token_refresh_succeeded.connect(_on_token_refresh_succeeded)

	if Firebase.Auth.has_signal("logged_out") and not Firebase.Auth.logged_out.is_connected(_on_logged_out):
		Firebase.Auth.logged_out.connect(_on_logged_out)


func login(email: String, password: String) -> void:
	Firebase.Auth.login_with_email_and_password(email, password)


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


func _on_logged_out() -> void:
	current_user.clear()
	user_uid = ""

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

	var role := str(user_doc.get_value("role"))

	print("[AuthManager] User role: ", role)

	return role


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

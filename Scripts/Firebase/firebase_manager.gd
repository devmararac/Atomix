extends Node

signal user_logged_in(user_data)
signal user_session_restored(user_data)
signal user_logged_out

var auth_data: Dictionary = {}
var user_uid: String = ""
var is_logged_in: bool = false

# True only while Firebase is restoring a previously saved
# authentication session.
var restoring_saved_session: bool = false


func _ready() -> void:
	if Firebase.Auth == null:
		push_error("[FirebaseManager] Firebase.Auth is null!")
		return

	if not Firebase.Auth.login_succeeded.is_connected(_on_login_success):
		Firebase.Auth.login_succeeded.connect(_on_login_success)

	if Firebase.Auth.has_signal("token_refresh_succeeded") and not Firebase.Auth.token_refresh_succeeded.is_connected(_on_token_refresh_succeeded):
		Firebase.Auth.token_refresh_succeeded.connect(_on_token_refresh_succeeded)

	if Firebase.Auth.has_signal("logged_out") and not Firebase.Auth.logged_out.is_connected(_on_logged_out):
		Firebase.Auth.logged_out.connect(_on_logged_out)

	call_deferred("_restore_saved_session")


func _restore_saved_session() -> void:
	if Firebase.Auth.needs_login():
		print("[FirebaseManager] No saved Firebase session found.")
		return

	print("[FirebaseManager] Saved Firebase session found. Restoring...")

	# Mark this login_succeeded event as a SESSION RESTORE,
	# not a manual login.
	restoring_saved_session = true

	Firebase.Auth.check_auth_file()


func _on_login_success(result: Dictionary) -> void:
	_set_auth_state(result)
	Firebase.Auth.save_auth(result)

	print("[FirebaseManager] User logged in")
	print("[FirebaseManager] UID: ", user_uid)

	if restoring_saved_session:
		print("[FirebaseManager] This login was a restored Firebase session.")

		# Do NOT emit user_logged_in here.
		# This is handled separately as a restored session.
		user_session_restored.emit(result)

		# Keep the flag true long enough for AuthManager's
		# login_succeeded callback to identify this event too.
		call_deferred("_finish_session_restore")

		return

	# This is a normal/manual login.
	user_logged_in.emit(result)


func _finish_session_restore() -> void:
	restoring_saved_session = false

	print("[FirebaseManager] Session restoration completed.")


func _on_token_refresh_succeeded(result: Dictionary) -> void:
	_set_auth_state(result)
	Firebase.Auth.save_auth(result)

	print("[FirebaseManager] Token refreshed and saved.")


func _on_logged_out() -> void:
	auth_data.clear()
	user_uid = ""
	is_logged_in = false
	restoring_saved_session = false

	print("[FirebaseManager] User logged out")

	user_logged_out.emit()


func _set_auth_state(result: Dictionary) -> void:
	auth_data = result.duplicate(true)

	user_uid = str(
		result.get(
			"localid",
			result.get("localId", "")
		)
	)

	is_logged_in = not user_uid.is_empty()


func logout() -> void:
	if Firebase.Auth != null:
		Firebase.Auth.logout()
	else:
		_on_logged_out()


func get_uid() -> String:
	return user_uid


func is_authenticated() -> bool:
	return is_logged_in


func is_restoring_saved_session() -> bool:
	return restoring_saved_session


func get_auth_data() -> Dictionary:
	return auth_data

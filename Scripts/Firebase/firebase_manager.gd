extends Node

signal user_logged_in(user_data)
signal user_logged_out

var auth_data: Dictionary = {}
var user_uid: String = ""
var is_logged_in: bool = false


func _ready() -> void:
	if Firebase.Auth == null:
		push_error("[FirebaseManager] Firebase.Auth is null!")
		return

	if not Firebase.Auth.login_succeeded.is_connected(_on_login_success):
		Firebase.Auth.login_succeeded.connect(_on_login_success)


func _on_login_success(result: Dictionary) -> void:
	auth_data = result

	user_uid = str(result.get("localid", ""))

	is_logged_in = not user_uid.is_empty()

	print("[FirebaseManager] User logged in")
	print("[FirebaseManager] UID: ", user_uid)

	user_logged_in.emit(result)


func logout() -> void:
	auth_data.clear()
	user_uid = ""
	is_logged_in = false

	print("[FirebaseManager] User logged out")

	user_logged_out.emit()


func get_uid() -> String:
	return user_uid


func is_authenticated() -> bool:
	return is_logged_in


func get_auth_data() -> Dictionary:
	return auth_data

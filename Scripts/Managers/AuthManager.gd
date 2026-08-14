extends Node

signal login_success(user_data)
signal login_failed(message)

signal signup_success(user_data)
signal signup_failed(message)

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

func login(email:String, password:String):
	Firebase.Auth.login_with_email_and_password(email, password)

func signup(email:String, password:String):
	Firebase.Auth.signup_with_email_and_password(email, password)

func _on_login_success(auth_result):
	login_success.emit(auth_result)

func _on_login_failed(code, message):
	login_failed.emit(message)

func _on_signup_success(auth_result):
	signup_success.emit(auth_result)

func _on_signup_failed(code, message):
	signup_failed.emit(message)

extends Node

const TEST_EMAIL := "test_student@atomix.com"
const TEST_PASSWORD := "TestStudent123!"


func _ready() -> void:
	print("========== STUDENT DATA TEST ==========")

	if Firebase == null:
		print("[StudentDataTest] Firebase not found.")
		return

	if Firebase.Auth == null:
		print("[StudentDataTest] Firebase.Auth not found.")
		return

	if FirebaseManager == null:
		print("[StudentDataTest] FirebaseManager not found.")
		return

	if StudentDataManager == null:
		print("[StudentDataTest] StudentDataManager not found.")
		return

	print("[StudentDataTest] Firebase services found.")
	print("[StudentDataTest] Logging in...")

	Firebase.Auth.login_succeeded.connect(_on_login_success)
	Firebase.Auth.login_failed.connect(_on_login_failed)

	Firebase.Auth.login_with_email_and_password(
		TEST_EMAIL,
		TEST_PASSWORD
	)


func _on_login_success(auth_result: Dictionary) -> void:
	print("[StudentDataTest] LOGIN SUCCESS!")

	print("[StudentDataTest] UID: ", auth_result.get("localid", ""))

	StudentDataManager.student_loaded.connect(_on_student_loaded)
	StudentDataManager.student_created.connect(_on_student_created)
	StudentDataManager.student_error.connect(_on_student_error)

	print("[StudentDataTest] Loading student data...")

	StudentDataManager.load_student()


func _on_student_loaded(data: Dictionary) -> void:
	print("[StudentDataTest] STUDENT LOAD SUCCESS!")
	print("[StudentDataTest] Student data: ", data)


func _on_student_created(data: Dictionary) -> void:
	print("[StudentDataTest] STUDENT NOT FOUND.")
	print("[StudentDataTest] New student data: ", data)


func _on_student_error(error) -> void:
	print("[StudentDataTest] STUDENT DATA ERROR!")
	print("[StudentDataTest] Error: ", error)


func _on_login_failed(code, message) -> void:
	print("[StudentDataTest] LOGIN FAILED")
	print("[StudentDataTest] Code: ", code)
	print("[StudentDataTest] Message: ", message)

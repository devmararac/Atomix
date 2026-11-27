extends Node

func _ready() -> void:
	print("===== SCHOOL YEAR ACCESS TEST =====")

	# Wait for Firebase session restoration.
	while Firebase.Auth.auth.is_empty():
		await get_tree().create_timer(0.5).timeout

	# Wait until AuthManager has a UID.
	var student_uid := ""

	while student_uid.is_empty():
		var auth_data: Dictionary = Firebase.Auth.auth

		student_uid = str(auth_data.get("localid", ""))

		if student_uid.is_empty():
			student_uid = str(auth_data.get("localId", ""))

		if student_uid.is_empty():
			await get_tree().create_timer(0.5).timeout

	print("[TEST] Student UID: ", student_uid)
	print("[TEST] Checking school year access...")

	var result: Dictionary = await SchoolYearAccess.check_student_learning_access(student_uid)

	print("[TEST] Result: ", result)
	print("[TEST] Success: ", result.get("success", false))
	print("[TEST] Allowed: ", result.get("allowed", false))
	print("[TEST] Student School Year: ", result.get("student_school_year", ""))
	print("[TEST] Active School Year: ", result.get("active_school_year", ""))
	print("===== TEST FINISHED =====")

extends Node

signal student_loaded(data)
signal student_created(data)
signal student_error(error)

var student_data: Dictionary = {}


func get_student_uid() -> String:
	return FirebaseManager.get_uid()


func is_student_logged_in() -> bool:
	return FirebaseManager.is_authenticated()


func load_student() -> void:
	var uid := get_student_uid()

	if uid.is_empty():
		student_error.emit({
			"message": "No authenticated Firebase user."
		})
		return

	var query := FirestoreQuery.new()
	query.from("students")
	query.where(
		"uid",
		FirestoreQuery.OPERATOR.EQUAL,
		uid
	)

	var results: Array = await Firebase.Firestore.query(query)

	if results.is_empty():
		print("[StudentDataManager] Student document not found.")

		student_data = {
			"uid": uid
		}

		student_created.emit(student_data)
		return

	var document: FirestoreDocument = results[0]

	student_data = document.data

	print("[StudentDataManager] Student loaded.")
	print("[StudentDataManager] UID: ", uid)

	student_loaded.emit(student_data)

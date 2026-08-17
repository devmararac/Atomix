extends Node

signal students_loaded(students)
signal students_error(error)

var students_data: Array[Dictionary] = []


func load_students() -> void:
	print("[TeacherDataManager] Loading students from Firebase...")

	students_data.clear()

	var query = FirestoreQuery.new()

	# IMPORTANT:
	# false means query the "students" collection itself,
	# not all descendant collections/fields.
	query.from("students", false)

	print("[TeacherDataManager] Sending students query...")

	var documents: Array = await Firebase.Firestore.query(query)

	if documents == null:
		print("[TeacherDataManager] Firebase returned null.")
		students_error.emit({
			"message": "Unable to load students."
		})
		return

	print("[TeacherDataManager] Documents received: ", documents.size())

	for document in documents:
		if document == null:
			continue

		var data: Dictionary = {}

		# The query result can be a FirestoreDocument.
		if document is FirestoreDocument:
			data = document.get_unsafe_document()
			data["uid"] = document.doc_name
		elif document is Dictionary:
			data = document

		if not data.is_empty():
			students_data.append(data)

	print("[TeacherDataManager] Students loaded: ", students_data.size())

	students_loaded.emit(students_data)


func get_students() -> Array[Dictionary]:
	return students_data

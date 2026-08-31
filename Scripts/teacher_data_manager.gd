
extends Node


# ============================================================
# SIGNALS
# ============================================================

signal students_loaded(students)
signal students_error(error)

signal teachers_loaded(teachers)
signal teachers_error(error)

signal lessons_loaded(lessons)
signal lessons_error(error)


# ============================================================
# DATA
# ============================================================

var students_data: Array[Dictionary] = []
var teachers_data: Array[Dictionary] = []
var lessons_data: Array[Dictionary] = []


# ============================================================
# LOAD STUDENTS
# ============================================================

func load_students() -> void:

	print("[TeacherDataManager] Loading students from Firebase...")

	students_data.clear()

	var http := HTTPRequest.new()
	add_child(http)


	# ========================================================
	# AUTHENTICATION
	# ========================================================

	var auth_data: Dictionary = Firebase.Firestore.auth

	if auth_data.is_empty():

		print("[TeacherDataManager] No Firestore authentication.")
		print("[TeacherDataManager] Requesting anonymous authentication...")

		Firebase.Auth.login_anonymous()

		var auth_result: Array = await Firebase.Auth.auth_request

		if auth_result.is_empty() or auth_result[0] != 1:

			print(
				"[TeacherDataManager] Anonymous authentication failed."
			)

			http.queue_free()

			students_error.emit({
				"message": "Unable to authenticate with Firebase."
			})

			return

		auth_data = Firebase.Firestore.auth


	if not auth_data.has("idtoken"):

		print(
			"[TeacherDataManager] Firebase authentication has no idtoken."
		)

		http.queue_free()

		students_error.emit({
			"message": "Firebase authentication token is missing."
		})

		return


	# ========================================================
	# PROJECT ID
	# ========================================================

	var project_id := get_firebase_project_id()

	if project_id.is_empty():

		print(
			"[TeacherDataManager] Could not determine Firebase Project ID."
		)

		http.queue_free()

		students_error.emit({
			"message": "Firebase Project ID could not be determined."
		})

		return


	# ========================================================
	# CURRENT USER ROLE
	# ========================================================

	var user_role := ""

	if AuthManager:

		user_role = await AuthManager.get_user_role()

	print(
		"[TeacherDataManager] Current user role: ",
		user_role
	)


	# ========================================================
	# GET TEACHER ASSIGNED SECTIONS
	# ========================================================

	var assigned_sections: Array = []

	if user_role == "teacher":

		assigned_sections = await get_current_teacher_sections()

		print(
			"[TeacherDataManager] Teacher assigned sections: ",
			assigned_sections
		)

		if assigned_sections.is_empty():

			print(
				"[TeacherDataManager] Teacher has no assigned sections."
			)

			http.queue_free()

			students_loaded.emit(students_data)

			return


	# ========================================================
	# FIRESTORE STUDENTS URL
	# ========================================================

	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+
		project_id
		+
		"/databases/(default)/documents/students"
	)

	var headers := PackedStringArray([
		"Authorization: Bearer " + str(auth_data["idtoken"]),
		"Content-Type: application/json"
	])

	print(
		"[TeacherDataManager] Sending students REST request..."
	)


	# ========================================================
	# REQUEST
	# ========================================================

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:

		print(
			"[TeacherDataManager] Firestore REST request failed: ",
			error
		)

		http.queue_free()

		students_error.emit({
			"message": "Unable to connect to Firestore."
		})

		return


	var response: Array = await http.request_completed

	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	var response_text := response_body.get_string_from_utf8()

	http.queue_free()


	# ========================================================
	# RESPONSE
	# ========================================================

	print(
		"[TeacherDataManager] Firestore REST response: ",
		response_code
	)

	if response_code != 200:

		print(
			"[TeacherDataManager] Firestore REST error: ",
			response_text
		)

		students_error.emit({
			"message": "Unable to load students from Firestore."
		})

		return


	# ========================================================
	# PARSE JSON
	# ========================================================

	var json := JSON.new()

	var parse_error := json.parse(response_text)

	if parse_error != OK:

		print(
			"[TeacherDataManager] Invalid Firestore REST response."
		)

		students_error.emit({
			"message": "Invalid Firestore response."
		})

		return


	var data = json.data

	if not data is Dictionary:

		print(
			"[TeacherDataManager] Firestore response is not a Dictionary."
		)

		students_error.emit({
			"message": "Invalid Firestore response."
		})

		return


	var documents: Array = data.get(
		"documents",
		[]
	)

	print(
		"[TeacherDataManager] Documents received: ",
		documents.size()
	)


	# ========================================================
	# CONVERT DOCUMENTS
	# ========================================================

	for document in documents:

		if not document is Dictionary:
			continue


		var student: Dictionary = {}

		var fields = document.get(
			"fields",
			{}
		)


		if fields is Dictionary:

			for field_name in fields:

				student[field_name] = _decode_firestore_value(
					fields[field_name]
				)


		# ----------------------------------------------------
		# FIRESTORE DOCUMENT ID
		# ----------------------------------------------------

		var document_name: String = document.get(
			"name",
			""
		)

		if not document_name.is_empty():

			student["uid"] = document_name.get_file()


		# ----------------------------------------------------
		# FILTER STUDENTS FOR TEACHERS
		# ----------------------------------------------------

		if user_role == "teacher":

			var student_section := str(
				student.get(
					"section",
					""
				)
			)

			if student_section not in assigned_sections:

				print(
					"[TeacherDataManager] Skipping student: ",
					student.get("name", ""),
					" | Section: ",
					student_section
				)

				continue


		# ----------------------------------------------------
		# ADD STUDENT
		# ----------------------------------------------------

		if not student.is_empty():

			students_data.append(
				student
			)


	# ========================================================
	# RESULT
	# ========================================================

	print(
		"[TeacherDataManager] Students loaded after filtering: ",
		students_data.size()
	)

	students_loaded.emit(
		students_data
	)


# ============================================================
# GET CURRENT TEACHER ASSIGNED SECTIONS
# ============================================================

func get_current_teacher_sections() -> Array:

	var teacher_uid := ""


	# ========================================================
	# GET LOGGED-IN TEACHER UID
	# ========================================================

	if AuthManager:

		teacher_uid = AuthManager.get_uid()


	if teacher_uid.is_empty():

		print(
			"[TeacherDataManager] Could not get teacher UID."
		)

		return []


	print(
		"[TeacherDataManager] Getting assigned sections for teacher: ",
		teacher_uid
	)


	# ========================================================
	# AUTHENTICATION
	# ========================================================

	var auth_data: Dictionary = Firebase.Firestore.auth

	if auth_data.is_empty():

		print(
			"[TeacherDataManager] No Firestore authentication."
		)

		return []


	if not auth_data.has("idtoken"):

		print(
			"[TeacherDataManager] Firebase authentication has no idtoken."
		)

		return []


	# ========================================================
	# PROJECT ID
	# ========================================================

	var project_id := get_firebase_project_id()

	if project_id.is_empty():

		print(
			"[TeacherDataManager] Firebase Project ID not found."
		)

		return []


	# ========================================================
	# TEACHER DOCUMENT URL
	# ========================================================

	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+
		project_id
		+
		"/databases/(default)/documents/teachers/"
		+
		teacher_uid
	)


	var headers := PackedStringArray([
		"Authorization: Bearer " + str(auth_data["idtoken"]),
		"Content-Type: application/json"
	])


	var http := HTTPRequest.new()

	add_child(http)


	# ========================================================
	# REQUEST
	# ========================================================

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:

		print(
			"[TeacherDataManager] Teacher section request failed: ",
			error
		)

		http.queue_free()

		return []


	var response: Array = await http.request_completed

	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text := response_body.get_string_from_utf8()

	http.queue_free()


	# ========================================================
	# RESPONSE
	# ========================================================

	print(
		"[TeacherDataManager] Teacher document response: ",
		response_code
	)


	if response_code != 200:

		print(
			"[TeacherDataManager] Teacher document request failed: ",
			response_text
		)

		return []


	# ========================================================
	# PARSE
	# ========================================================

	var json := JSON.new()

	if json.parse(response_text) != OK:

		print(
			"[TeacherDataManager] Invalid teacher document response."
		)

		return []


	var data = json.data

	if not data is Dictionary:

		return []


	var fields = data.get(
		"fields",
		{}
	)


	if not fields is Dictionary:

		return []


	# ========================================================
	# ASSIGNED SECTIONS
	# ========================================================

	if not fields.has("assigned_sections"):

		print(
			"[TeacherDataManager] Teacher has no assigned_sections field."
		)

		return []


	var sections = _decode_firestore_value(
		fields["assigned_sections"]
	)


	if not sections is Array:

		print(
			"[TeacherDataManager] assigned_sections is not an Array."
		)

		return []


	print(
		"[TeacherDataManager] Assigned sections: ",
		sections
	)


	return sections


# ============================================================
# LOAD LESSONS
#
# Teachers only see lessons they uploaded.
# Admins see all lessons.
# ============================================================

func load_lessons() -> void:

	print(
		"[TeacherDataManager] Loading lessons from Firebase..."
	)

	lessons_data.clear()


	var http := HTTPRequest.new()

	add_child(http)


	# ========================================================
	# AUTHENTICATION
	# ========================================================

	var auth_data: Dictionary = Firebase.Firestore.auth

	if auth_data.is_empty():

		print(
			"[TeacherDataManager] No Firestore authentication."
		)

		http.queue_free()

		lessons_error.emit({
			"message": "Unable to authenticate with Firebase."
		})

		return


	if not auth_data.has("idtoken"):

		print(
			"[TeacherDataManager] Firebase authentication has no idtoken."
		)

		http.queue_free()

		lessons_error.emit({
			"message": "Firebase authentication token is missing."
		})

		return


	# ========================================================
	# PROJECT ID
	# ========================================================

	var project_id := get_firebase_project_id()

	if project_id.is_empty():

		print(
			"[TeacherDataManager] Firebase Project ID not found."
		)

		http.queue_free()

		lessons_error.emit({
			"message": "Firebase Project ID could not be determined."
		})

		return


	# ========================================================
	# CURRENT ROLE
	# ========================================================

	var user_role := ""

	if AuthManager:

		user_role = await AuthManager.get_user_role()


	print(
		"[TeacherDataManager] Loading lessons for role: ",
		user_role
	)


	# ========================================================
	# CURRENT TEACHER UID
	# ========================================================

	var current_teacher_uid := ""

	if user_role == "teacher":

		if AuthManager:

			current_teacher_uid = AuthManager.get_uid()


		if current_teacher_uid.is_empty():

			print(
				"[TeacherDataManager] Could not get teacher UID."
			)

			http.queue_free()

			lessons_error.emit({
				"message": "Teacher account UID could not be determined."
			})

			return


		print(
			"[TeacherDataManager] Current teacher UID: ",
			current_teacher_uid
		)


	# ========================================================
	# FIRESTORE LESSONS URL
	# ========================================================

	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+
		project_id
		+
		"/databases/(default)/documents/lessons"
	)


	var headers := PackedStringArray([
		"Authorization: Bearer " + str(auth_data["idtoken"]),
		"Content-Type: application/json"
	])


	print(
		"[TeacherDataManager] Sending lessons REST request..."
	)


	# ========================================================
	# REQUEST
	# ========================================================

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:

		print(
			"[TeacherDataManager] Lessons REST request failed: ",
			error
		)

		http.queue_free()

		lessons_error.emit({
			"message": "Unable to connect to Firestore."
		})

		return


	var response: Array = await http.request_completed

	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text := response_body.get_string_from_utf8()

	http.queue_free()


	# ========================================================
	# RESPONSE
	# ========================================================

	print(
		"[TeacherDataManager] Lessons REST response: ",
		response_code
	)


	if response_code != 200:

		print(
			"[TeacherDataManager] Firestore lessons error: ",
			response_text
		)

		lessons_error.emit({
			"message": "Unable to load lessons from Firestore."
		})

		return


	# ========================================================
	# PARSE JSON
	# ========================================================

	var json := JSON.new()

	var parse_error := json.parse(
		response_text
	)

	if parse_error != OK:

		print(
			"[TeacherDataManager] Invalid lessons response."
		)

		lessons_error.emit({
			"message": "Invalid Firestore response."
		})

		return


	var data = json.data

	if not data is Dictionary:

		print(
			"[TeacherDataManager] Lessons response is not Dictionary."
		)

		lessons_error.emit({
			"message": "Invalid Firestore response."
		})

		return


	var documents: Array = data.get(
		"documents",
		[]
	)


	print(
		"[TeacherDataManager] Lesson documents received: ",
		documents.size()
	)


	# ========================================================
	# CONVERT LESSON DOCUMENTS
	# ========================================================

	for document in documents:

		if not document is Dictionary:
			continue


		var lesson: Dictionary = {}


		var fields = document.get(
			"fields",
			{}
		)


		if fields is Dictionary:

			for field_name in fields:

				lesson[field_name] = _decode_firestore_value(
					fields[field_name]
				)


		# ----------------------------------------------------
		# FIRESTORE DOCUMENT ID
		# ----------------------------------------------------

		var document_name: String = document.get(
			"name",
			""
		)


		if not document_name.is_empty():

			lesson["lesson_id"] = document_name.get_file()


		# ----------------------------------------------------
		# TEACHER FILTER
		# ----------------------------------------------------

		if user_role == "teacher":

			var lesson_teacher_id := str(
				lesson.get(
					"teacher_id",
					""
				)
			)


			if lesson_teacher_id != current_teacher_uid:

				print(
					"[TeacherDataManager] Skipping lesson: ",
					lesson.get("title", ""),
					" | Uploaded by: ",
					lesson_teacher_id
				)

				continue


		# ----------------------------------------------------
		# ADD LESSON
		# ----------------------------------------------------

		if not lesson.is_empty():

			lessons_data.append(
				lesson
			)


	# ========================================================
	# RESULT
	# ========================================================

	print(
		"[TeacherDataManager] Lessons loaded after filtering: ",
		lessons_data.size()
	)


	lessons_loaded.emit(
		lessons_data
	)


# ============================================================
# LOAD TEACHERS
# ============================================================

func load_teachers() -> void:

	print(
		"[TeacherDataManager] Loading teachers from Firebase..."
	)

	teachers_data.clear()

	var http := HTTPRequest.new()
	add_child(http)


	# ========================================================
	# AUTHENTICATION
	# ========================================================

	var auth_data: Dictionary = Firebase.Firestore.auth

	if auth_data.is_empty():

		print(
			"[TeacherDataManager] No Firestore authentication."
		)

		print(
			"[TeacherDataManager] Requesting anonymous authentication..."
		)

		Firebase.Auth.login_anonymous()

		var auth_result: Array = await Firebase.Auth.auth_request

		if auth_result.is_empty() or auth_result[0] != 1:

			print(
				"[TeacherDataManager] Anonymous authentication failed."
			)

			http.queue_free()

			teachers_error.emit({
				"message": "Unable to authenticate with Firebase."
			})

			return

		auth_data = Firebase.Firestore.auth


	if not auth_data.has("idtoken"):

		print(
			"[TeacherDataManager] Firebase authentication has no idtoken."
		)

		http.queue_free()

		teachers_error.emit({
			"message": "Firebase authentication token is missing."
		})

		return


	# ========================================================
	# PROJECT ID
	# ========================================================

	var project_id := get_firebase_project_id()

	if project_id.is_empty():

		print(
			"[TeacherDataManager] Firebase Project ID not found."
		)

		http.queue_free()

		teachers_error.emit({
			"message": "Firebase Project ID could not be determined."
		})

		return


	# ========================================================
	# FIRESTORE TEACHERS COLLECTION
	# ========================================================

	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+
		project_id
		+
		"/databases/(default)/documents/teachers"
	)


	var headers := PackedStringArray([
		"Authorization: Bearer " + str(auth_data["idtoken"]),
		"Content-Type: application/json"
	])


	print(
		"[TeacherDataManager] Sending teachers REST request..."
	)


	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)


	if error != OK:

		print(
			"[TeacherDataManager] Teacher request failed: ",
			error
		)

		http.queue_free()

		teachers_error.emit({
			"message": "Unable to connect to Firestore."
		})

		return


	var response: Array = await http.request_completed

	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text := response_body.get_string_from_utf8()

	http.queue_free()


	# ========================================================
	# RESPONSE
	# ========================================================

	print(
		"[TeacherDataManager] Teachers REST response: ",
		response_code
	)


	if response_code != 200:

		print(
			"[TeacherDataManager] Firestore teacher error: ",
			response_text
		)

		teachers_error.emit({
			"message": "Unable to load teachers from Firestore."
		})

		return


	# ========================================================
	# PARSE JSON
	# ========================================================

	var json := JSON.new()

	var parse_error := json.parse(
		response_text
	)


	if parse_error != OK:

		print(
			"[TeacherDataManager] Invalid teachers response."
		)

		teachers_error.emit({
			"message": "Invalid Firestore response."
		})

		return


	var data = json.data

	if not data is Dictionary:

		print(
			"[TeacherDataManager] Teachers response is not Dictionary."
		)

		teachers_error.emit({
			"message": "Invalid Firestore response."
		})

		return


	var documents: Array = data.get(
		"documents",
		[]
	)


	print(
		"[TeacherDataManager] Teacher documents received: ",
		documents.size()
	)


	# ========================================================
	# CONVERT TEACHER DOCUMENTS
	# ========================================================

	for document in documents:

		if not document is Dictionary:
			continue


		var teacher: Dictionary = {}


		var fields = document.get(
			"fields",
			{}
		)


		if fields is Dictionary:

			for field_name in fields:

				teacher[field_name] = _decode_firestore_value(
					fields[field_name]
				)


		# ----------------------------------------------------
		# FIRESTORE DOCUMENT ID
		# ----------------------------------------------------

		var document_name: String = document.get(
			"name",
			""
		)


		if not document_name.is_empty():

			teacher["uid"] = document_name.get_file()


		# ----------------------------------------------------
		# ADD TEACHER
		# ----------------------------------------------------

		if not teacher.is_empty():

			teachers_data.append(
				teacher
			)


	# ========================================================
	# RESULT
	# ========================================================

	print(
		"[TeacherDataManager] Teachers loaded: ",
		teachers_data.size()
	)


	teachers_loaded.emit(
		teachers_data
	)


# ============================================================
# FIRESTORE VALUE DECODER
# ============================================================

func _decode_firestore_value(value: Dictionary):

	if value.has("stringValue"):

		return value["stringValue"]


	if value.has("integerValue"):

		return int(
			value["integerValue"]
		)


	if value.has("doubleValue"):

		return float(
			value["doubleValue"]
		)


	if value.has("booleanValue"):

		return value["booleanValue"]


	if value.has("timestampValue"):

		return value["timestampValue"]


	if value.has("nullValue"):

		return null


	if value.has("arrayValue"):

		var result: Array = []


		var values = value["arrayValue"].get(
			"values",
			[]
		)


		for item in values:

			result.append(
				_decode_firestore_value(
					item
				)
			)


		return result


	if value.has("mapValue"):

		var result: Dictionary = {}


		var fields = value["mapValue"].get(
			"fields",
			{}
		)


		for field_name in fields:

			result[field_name] = _decode_firestore_value(
				fields[field_name]
			)


		return result


	return null


# ============================================================
# FIREBASE PROJECT ID
# ============================================================

func get_firebase_project_id() -> String:

	if Firebase.Firestore._config.has("projectId"):

		return str(
			Firebase.Firestore._config["projectId"]
		)


	var config_script = FirebaseConfig


	if "FIREBASE_PROJECT_ID" in config_script:

		return str(
			config_script.FIREBASE_PROJECT_ID
		)


	if "PROJECT_ID" in config_script:

		return str(
			config_script.PROJECT_ID
		)


	print(
		"[TeacherDataManager] Firebase Project ID not found."
	)

	return ""


# ============================================================
# GET STUDENTS
# ============================================================

func get_students() -> Array[Dictionary]:

	return students_data


# ============================================================
# GET TEACHERS
# ============================================================

func get_teachers() -> Array[Dictionary]:

	return teachers_data


# ============================================================
# GET LESSONS
# ============================================================

func get_lessons() -> Array[Dictionary]:

	return lessons_data

extends Node

# ============================================================
# SIGNALS
# ============================================================

signal students_loaded(students)
signal students_error(error)

signal teachers_loaded(teachers)
signal teachers_error(error)


# ============================================================
# DATA
# ============================================================

var students_data: Array[Dictionary] = []
var teachers_data: Array[Dictionary] = []


# ============================================================
# LOAD STUDENTS
# ============================================================

func load_students() -> void:

	print("[TeacherDataManager] Loading students from Firebase...")

	students_data.clear()

	var http := HTTPRequest.new()
	add_child(http)

	# --------------------------------------------------------
	# Authentication
	# --------------------------------------------------------

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

	# --------------------------------------------------------
	# Project ID
	# --------------------------------------------------------

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

	# --------------------------------------------------------
	# Firestore URL
	# --------------------------------------------------------

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

	# --------------------------------------------------------
	# Parse
	# --------------------------------------------------------

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

	# --------------------------------------------------------
	# Convert documents
	# --------------------------------------------------------

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

		var document_name: String = document.get(
			"name",
			""
		)

		if not document_name.is_empty():

			student["uid"] = document_name.get_file()

		if not student.is_empty():

			students_data.append(
				student
			)

	print(
		"[TeacherDataManager] Students loaded: ",
		students_data.size()
	)

	students_loaded.emit(
		students_data
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

	# --------------------------------------------------------
	# Authentication
	# --------------------------------------------------------

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

	# --------------------------------------------------------
	# Project ID
	# --------------------------------------------------------

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

	# --------------------------------------------------------
	# Firestore teachers collection
	# --------------------------------------------------------

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

	# --------------------------------------------------------
	# Parse JSON
	# --------------------------------------------------------

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

	# --------------------------------------------------------
	# Convert Firestore documents
	# --------------------------------------------------------

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
		# Firestore document ID
		# ----------------------------------------------------

		var document_name: String = document.get(
			"name",
			""
		)

		if not document_name.is_empty():

			teacher["uid"] = document_name.get_file()

		if not teacher.is_empty():

			teachers_data.append(
				teacher
			)

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

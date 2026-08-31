extends Node

# ============================================================
# LESSON DATA MANAGER
# ============================================================
# Handles learning_materials documents in Firestore.
#
# This manager uses the Firestore REST API, just like the
# existing TeacherDataManager, so we do not depend on
# FirebaseFirestore.query().
# ============================================================


signal lessons_loaded(lessons)
signal lessons_error(error)
signal lesson_created(lesson_data)
signal lesson_updated(lesson_data)
signal lesson_deleted(lesson_id)


# ============================================================
# DATA
# ============================================================

var lessons_data: Array[Dictionary] = []


# ============================================================
# LOAD ALL LESSONS
# ============================================================

func load_lessons() -> void:

	print(
		"[LessonDataManager] Loading learning materials..."
	)

	lessons_data.clear()


	# --------------------------------------------------------
	# Authentication
	# --------------------------------------------------------

	var auth_data: Dictionary = Firebase.Firestore.auth

	if auth_data.is_empty():

		print(
			"[LessonDataManager] Firestore authentication missing."
		)

		lessons_error.emit({
			"message":
				"Firebase authentication is missing."
		})

		return


	if not auth_data.has("idtoken"):

		print(
			"[LessonDataManager] Firebase ID token missing."
		)

		lessons_error.emit({
			"message":
				"Firebase ID token is missing."
		})

		return


	var id_token: String = str(
		auth_data["idtoken"]
	)


	# --------------------------------------------------------
	# Project ID
	# --------------------------------------------------------

	var project_id: String = (
		get_firebase_project_id()
	)


	if project_id.is_empty():

		print(
			"[LessonDataManager] Firebase Project ID not found."
		)

		lessons_error.emit({
			"message":
				"Firebase Project ID could not be determined."
		})

		return


	# --------------------------------------------------------
	# Firestore URL
	# --------------------------------------------------------

	var url: String = (
		"https://firestore.googleapis.com/v1/projects/"
		+
		project_id
		+
		"/databases/(default)/documents/"
		+
		"learning_materials"
	)


	print(
		"[LessonDataManager] Requesting: ",
		url
	)


	# --------------------------------------------------------
	# HTTP REQUEST
	# --------------------------------------------------------

	var http := HTTPRequest.new()

	add_child(http)


	var headers := PackedStringArray([
		"Authorization: Bearer " + id_token,
		"Content-Type: application/json"
	])


	var error: int = http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)


	if error != OK:

		print(
			"[LessonDataManager] HTTP request failed: ",
			error
		)

		http.queue_free()

		lessons_error.emit({
			"message":
				"Unable to connect to Firestore."
		})

		return


	# --------------------------------------------------------
	# WAIT FOR RESPONSE
	# --------------------------------------------------------

	var response: Array = (
		await http.request_completed
	)


	var response_code: int = response[1]

	var response_body: PackedByteArray = (
		response[3]
	)


	var response_text: String = (
		response_body.get_string_from_utf8()
	)


	http.queue_free()


	print(
		"[LessonDataManager] Firestore response: ",
		response_code
	)


	# --------------------------------------------------------
	# ERROR RESPONSE
	# --------------------------------------------------------

	if response_code != 200:

		print(
			"[LessonDataManager] Firestore error: ",
			response_text
		)

		lessons_error.emit({
			"message":
				"Unable to load learning materials."
		})

		return


	# --------------------------------------------------------
	# PARSE JSON
	# --------------------------------------------------------

	var json := JSON.new()

	var parse_error: int = json.parse(
		response_text
	)


	if parse_error != OK:

		print(
			"[LessonDataManager] Invalid Firestore response."
		)

		lessons_error.emit({
			"message":
				"Invalid Firestore response."
		})

		return


	var data = json.data


	if not data is Dictionary:

		print(
			"[LessonDataManager] Response is not a Dictionary."
		)

		lessons_error.emit({
			"message":
				"Invalid Firestore response."
		})

		return


	# --------------------------------------------------------
	# DOCUMENTS
	# --------------------------------------------------------

	var documents: Array = (
		data.get(
			"documents",
			[]
		)
	)


	print(
		"[LessonDataManager] Lesson documents received: ",
		documents.size()
	)


	# --------------------------------------------------------
	# CONVERT DOCUMENTS
	# --------------------------------------------------------

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

				lesson[field_name] = (
					_decode_firestore_value(
						fields[field_name]
					)
				)


		# ----------------------------------------------------
		# Get Firestore document ID
		# ----------------------------------------------------

		var document_name: String = str(
			document.get(
				"name",
				""
			)
		)


		if not document_name.is_empty():

			lesson["id"] = (
				document_name.get_file()
			)


		if not lesson.is_empty():

			lessons_data.append(
				lesson
			)


	print(
		"[LessonDataManager] Lessons loaded: ",
		lessons_data.size()
	)


	lessons_loaded.emit(
		lessons_data
	)


# ============================================================
# GET LESSONS
# ============================================================

func get_lessons() -> Array[Dictionary]:

	return lessons_data


# ============================================================
# GET FIREBASE PROJECT ID
# ============================================================

func get_firebase_project_id() -> String:

	if Firebase.Firestore._config.has(
		"projectId"
	):

		return str(
			Firebase.Firestore._config[
				"projectId"
			]
		)


	# --------------------------------------------------------
	# Fallback
	# --------------------------------------------------------

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
		"[LessonDataManager] Firebase Project ID not found."
	)


	return ""


# ============================================================
# FIRESTORE VALUE DECODER
# ============================================================

func _decode_firestore_value(
	value: Dictionary
):

	if value.has("stringValue"):

		return str(
			value["stringValue"]
		)


	if value.has("integerValue"):

		return int(
			value["integerValue"]
		)


	if value.has("doubleValue"):

		return float(
			value["doubleValue"]
		)


	if value.has("booleanValue"):

		return bool(
			value["booleanValue"]
		)


	if value.has("timestampValue"):

		return str(
			value["timestampValue"]
		)


	if value.has("nullValue"):

		return null


	# --------------------------------------------------------
	# Array
	# --------------------------------------------------------

	if value.has("arrayValue"):

		var result: Array = []


		var array_data = value[
			"arrayValue"
		]


		if array_data is Dictionary:

			var values = array_data.get(
				"values",
				[]
			)


			if values is Array:

				for item in values:

					if item is Dictionary:

						result.append(
							_decode_firestore_value(
								item
							)
						)


		return result


	# --------------------------------------------------------
	# Map
	# --------------------------------------------------------

	if value.has("mapValue"):

		var result: Dictionary = {}


		var map_data = value[
			"mapValue"
		]


		if map_data is Dictionary:

			var fields = map_data.get(
				"fields",
				{}
			)


			if fields is Dictionary:

				for field_name in fields:

					if fields[field_name] is Dictionary:

						result[field_name] = (
							_decode_firestore_value(
								fields[field_name]
							)
						)


		return result


	return null

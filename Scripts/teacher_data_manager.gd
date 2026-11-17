
extends Node

# ============================================================
# SIGNALS
# ============================================================

signal students_loaded(students)
signal students_error(error)

signal teachers_loaded(teachers)
signal teachers_error(error)

signal users_loaded(users)
signal users_error(error)

signal lessons_loaded(lessons)
signal lessons_error(error)

signal school_years_loaded(school_years)
signal school_years_error(error)

signal sections_loaded(sections)
signal sections_error(error)

signal quizzes_loaded(quizzes)
signal quizzes_error(error)

# ============================================================
# DATA
# ============================================================

var students_data: Array[Dictionary] = []
func get_students() -> Array[Dictionary]:
	return students_data
var teachers_data: Array[Dictionary] = []
var lessons_data: Array[Dictionary] = []
var quizzes_data: Array[Dictionary] = []

var school_years_data: Array[Dictionary] = []
var sections_data: Array[Dictionary] = []

# These IDs are Firestore document IDs, not school-year display names.
var active_school_year_id: String = ""
var selected_school_year_id: String = ""


# ============================================================
# FIRESTORE AUTHENTICATION
# ============================================================

func _get_firestore_token() -> String:
	if not Firebase.Firestore.auth is Dictionary:
		return ""

	var auth_data: Dictionary = Firebase.Firestore.auth

	if auth_data.has("idtoken"):
		return str(auth_data["idtoken"])

	if auth_data.has("idToken"):
		return str(auth_data["idToken"])

	return ""


func _get_current_uid() -> String:
	if AuthManager:
		return str(AuthManager.get_uid())

	return ""


func _get_current_role() -> String:
	if AuthManager:
		return str(await AuthManager.get_user_role()).to_lower()

	return ""


func get_firebase_project_id() -> String:
	# Prefer the project's configured Firestore project ID.
	var firestore_config: Variant = Firebase.Firestore.get("_config")

	if firestore_config is Dictionary:
		var project_id: String = str(
			firestore_config.get("projectId", "")
		)

		if not project_id.is_empty():
			return project_id

	# Fallback to the project's FirebaseConfig autoload.
	var firebase_config: Variant = get_node_or_null("/root/FirebaseConfig")

	if firebase_config != null:
		var config_value: Variant = firebase_config.get(
			"FIREBASE_PROJECT_ID"
		)

		if config_value != null and not str(config_value).is_empty():
			return str(config_value)

		config_value = firebase_config.get("PROJECT_ID")

		if config_value != null and not str(config_value).is_empty():
			return str(config_value)

	push_error("[TeacherDataManager] Firebase Project ID not found.")
	return ""


# ============================================================
# FIRESTORE REST HELPERS
# ============================================================

# Reads a Firestore collection/document path relative to:
# databases/(default)/documents/
#
# Example:
# school_years
# school_years/2026_2027/sections
# teachers/teacher_uid
func _firestore_get(path: String) -> Dictionary:
	var token: String = _get_firestore_token()
	if token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	var project_id: String = get_firebase_project_id()
	if project_id.is_empty():
		return {
			"ok": false,
			"error": "Firebase Project ID could not be determined."
		}

	var url: String = (
		"https://firestore.googleapis.com/v1/projects/"
		+ project_id
		+ "/databases/(default)/documents/"
		+ path
	)

	var http := HTTPRequest.new()
	add_child(http)

	var headers := PackedStringArray([
		"Authorization: Bearer " + token,
		"Content-Type: application/json"
	])

	var request_error: Error = http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if request_error != OK:
		http.queue_free()
		return {
			"ok": false,
			"error": "Unable to start Firestore request: %s" % request_error
		}

	var response: Array = await http.request_completed
	http.queue_free()

	var response_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]
	var response_text: String = response_body.get_string_from_utf8()

	if response_code < 200 or response_code >= 300:
		var message: String = response_text

		var error_json: Variant = JSON.parse_string(response_text)
		if error_json is Dictionary:
			var error_data: Variant = error_json.get("error", {})
			if error_data is Dictionary:
				message = str(error_data.get("message", response_text))

		return {
			"ok": false,
			"code": response_code,
			"error": message
		}

	var parsed: Variant = JSON.parse_string(response_text)
	if not parsed is Dictionary:
		return {
			"ok": false,
			"error": "Firestore returned invalid JSON."
		}

	return {
		"ok": true,
		"data": parsed
	}


func _decode_firestore_value(value: Variant) -> Variant:
	if not value is Dictionary:
		return null

	if value.has("stringValue"):
		return str(value["stringValue"])

	if value.has("integerValue"):
		return int(value["integerValue"])

	if value.has("doubleValue"):
		return float(value["doubleValue"])

	if value.has("booleanValue"):
		return bool(value["booleanValue"])

	if value.has("timestampValue"):
		return str(value["timestampValue"])

	if value.has("nullValue"):
		return null

	if value.has("arrayValue"):
		var result: Array = []
		var values: Variant = value["arrayValue"].get("values", [])

		if values is Array:
			for item in values:
				result.append(_decode_firestore_value(item))

		return result

	if value.has("mapValue"):
		var result: Dictionary = {}
		var fields: Variant = value["mapValue"].get("fields", {})

		if fields is Dictionary:
			for field_name in fields:
				result[str(field_name)] = _decode_firestore_value(
					fields[field_name]
				)

		return result

	return null


func _decode_document(document: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var fields: Variant = document.get("fields", {})

	if fields is Dictionary:
		for field_name in fields:
			result[str(field_name)] = _decode_firestore_value(
				fields[field_name]
			)

	# Extract the actual Firestore document ID.
	var document_path: String = str(document.get("name", ""))
	if not document_path.is_empty():
		result["uid"] = document_path.get_file()
		result["document_path"] = document_path

	return result


func _get_collection_documents(path: String) -> Dictionary:
	var response: Dictionary = await _firestore_get(path)

	if not bool(response.get("ok", false)):
		return response

	var data: Variant = response.get("data", {})
	if not data is Dictionary:
		return {
			"ok": false,
			"error": "Invalid Firestore collection response."
		}

	var documents: Array[Dictionary] = []
	var raw_documents: Variant = data.get("documents", [])

	if raw_documents is Array:
		for raw_document in raw_documents:
			if raw_document is Dictionary:
				documents.append(_decode_document(raw_document))

	return {
		"ok": true,
		"documents": documents
	}


# ============================================================
# SCHOOL YEARS
# ============================================================

func load_school_years() -> void:
	print("[TeacherDataManager] Loading school years...")

	school_years_data.clear()

	var response: Dictionary = await _get_collection_documents(
		"school_years"
	)

	if not bool(response.get("ok", false)):
		var message: String = str(response.get("error", "Unable to load school years."))
		school_years_error.emit({"message": message})
		return

	var documents: Array = response.get("documents", [])

	for item in documents:
		if item is Dictionary:
			school_years_data.append(item)

	active_school_year_id = ""

	for year_data in school_years_data:
		if bool(year_data.get("active", false)):
			active_school_year_id = str(year_data.get("uid", ""))
			break

	# Use the active year by default, unless the UI selected a year already.
	if selected_school_year_id.is_empty():
		selected_school_year_id = active_school_year_id

	print(
		"[TeacherDataManager] School years loaded: ",
		school_years_data.size(),
		" | Active ID: ",
		active_school_year_id
	)

	school_years_loaded.emit(school_years_data)


func set_selected_school_year(school_year_id: String) -> void:
	selected_school_year_id = school_year_id


func get_selected_school_year_id() -> String:
	if not selected_school_year_id.is_empty():
		return selected_school_year_id

	return active_school_year_id


func get_active_school_year_id() -> String:
	return active_school_year_id


# ============================================================
# SECTIONS FOR A SCHOOL YEAR
# ============================================================

func load_sections(school_year_id: String = "") -> void:
	var year_id: String = school_year_id.strip_edges()

	if year_id.is_empty():
		year_id = get_selected_school_year_id()

	sections_data.clear()

	if year_id.is_empty():
		sections_error.emit({
			"message": "No school year is selected."
		})
		return

	selected_school_year_id = year_id

	var path: String = (
		"school_years/"
		+ year_id.uri_encode()
		+ "/sections"
	)

	print("[TeacherDataManager] Loading sections from: ", path)

	var response: Dictionary = await _get_collection_documents(path)

	if not bool(response.get("ok", false)):
		var message: String = str(response.get("error", "Unable to load sections."))
		sections_error.emit({"message": message})
		return

	var documents: Array = response.get("documents", [])

	for section_data in documents:
		if section_data is Dictionary:
			sections_data.append(section_data)

	print(
		"[TeacherDataManager] Sections loaded for year ",
		year_id,
		": ",
		sections_data.size()
	)

	sections_loaded.emit(sections_data)


func get_sections() -> Array[Dictionary]:
	return sections_data


# ============================================================
# LOAD TEACHERS
# ============================================================

func load_teachers() -> void:
	print("[TeacherDataManager] Loading teachers from Firestore...")

	teachers_data.clear()

	var response: Dictionary = await _get_collection_documents("teachers")

	if not bool(response.get("ok", false)):
		var message: String = str(response.get("error", "Unable to load teachers."))
		teachers_error.emit({"message": message})
		return

	var documents: Array = response.get("documents", [])

	for teacher in documents:
		if not teacher is Dictionary:
			continue

		# Normalize name for older teacher documents.
		if not teacher.has("first_name"):
			teacher["first_name"] = ""

		if not teacher.has("last_name"):
			teacher["last_name"] = ""

		if not teacher.has("name") or str(teacher.get("name", "")).strip_edges().is_empty():
			teacher["name"] = (
				str(teacher.get("first_name", "")).strip_edges()
				+ " "
				+ str(teacher.get("last_name", "")).strip_edges()
			).strip_edges()

		if not teacher.has("assigned_sections"):
			teacher["assigned_sections"] = []

		if not teacher.has("status"):
			teacher["status"] = "inactive"

		teachers_data.append(teacher)

	print("[TeacherDataManager] Teachers loaded: ", teachers_data.size())
	teachers_loaded.emit(teachers_data)

# ============================================================
# LOAD ALL USER ACCOUNTS FOR DASHBOARD ROLE COUNTS
# ============================================================

func load_users() -> void:
	print("[TeacherDataManager] Loading user accounts from Firestore...")

	var response: Dictionary = await _get_collection_documents("users")

	if not bool(response.get("ok", false)):
		var message: String = str(
			response.get("error", "Unable to load user accounts.")
		)
		users_error.emit({"message": message})
		return

	var documents: Array = response.get("documents", [])
	var users: Array[Dictionary] = []

	for user in documents:
		if not user is Dictionary:
			continue

		var role := str(user.get("role", "")).strip_edges().to_lower()

		if role in ["admin", "headteacher", "head_teacher", "head teacher"]:
			role = "admin"
		elif role == "teacher":
			role = "teacher"
		elif role == "student":
			role = "student"
		else:
			continue

		user["role"] = role
		users.append(user)

	print("[TeacherDataManager] User accounts loaded: ", users.size())
	users_loaded.emit(users)

# ============================================================
# UPDATE TEACHER STATUS
# ============================================================

func update_teacher_status(teacher_uid: String, new_status: String) -> Dictionary:
	teacher_uid = teacher_uid.strip_edges()
	new_status = new_status.strip_edges().to_lower()

	if teacher_uid.is_empty():
		return {
			"ok": false,
			"error": "Teacher UID is missing."
		}

	if not ["active", "inactive", "archived"].has(new_status):
		return {
			"ok": false,
			"error": "Invalid teacher status."
		}

	var caller_token: String = _get_firestore_token()

	if caller_token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	var http := HTTPRequest.new()
	add_child(http)

	var url := "https://atomix-auth-api.atomix-auth.workers.dev/admin-update-teacher-status"

	var headers := [
		"Content-Type: application/json"
	]

	var body := {
		"callerIdToken": caller_token,
		"teacherUid": teacher_uid,
		"status": new_status
	}

	var request_error := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if request_error != OK:
		http.queue_free()

		return {
			"ok": false,
			"error": "Could not send teacher status update request."
		}

	var response: Array = await http.request_completed
	http.queue_free()

	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	var response_text := response_body.get_string_from_utf8()
	var response_data = JSON.parse_string(response_text)

	if response_code != 200:
		var error_message := "Worker request failed. HTTP " + str(response_code)

		if response_data is Dictionary:
			error_message = str(
				response_data.get("message", error_message)
			)

		return {
			"ok": false,
			"error": error_message,
			"response": response_data
		}

	if not response_data is Dictionary:
		return {
			"ok": false,
			"error": "Invalid response received from Worker."
		}

	if not bool(response_data.get("success", false)):
		return {
			"ok": false,
			"error": str(
				response_data.get("message", "Teacher status update failed.")
			),
			"response": response_data
		}

	print(
		"[TeacherDataManager] Teacher status updated: ",
		teacher_uid,
		" -> ",
		new_status
	)

	return {
		"ok": true,
		"status": new_status,
		"response": response_data
	}




# ============================================================
# DELETE TEACHER FIRESTORE DOCUMENT
# ============================================================

func delete_teacher(teacher_uid: String) -> Dictionary:
	teacher_uid = teacher_uid.strip_edges()

	if teacher_uid.is_empty():
		return {
			"ok": false,
			"error": "Teacher UID is missing."
		}

	# Get the currently logged-in administrator's Firebase ID token.
	var token: String = _get_firestore_token()

	if token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	# Prepare the Cloudflare Worker request.
	var url := (
		"https://atomix-auth-api.atomix-auth.workers.dev"
		+ "/admin-delete-teacher"
	)

	var request_body := {
		"callerIdToken": token,
		"teacherUid": teacher_uid
	}

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var http := HTTPRequest.new()
	add_child(http)

	var request_error: Error = http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(request_body)
	)

	if request_error != OK:
		http.queue_free()

		return {
			"ok": false,
			"error": "Unable to start teacher deletion: %s" % request_error
		}

	# Wait for the Worker response.
	var response: Array = await http.request_completed
	http.queue_free()

	var request_result: int = int(response[0])
	var response_code: int = int(response[1])

	var response_text: String = (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	# Check whether the HTTP request itself succeeded.
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"error": "Unable to connect to the teacher deletion server."
		}

	# Parse the Worker's JSON response.
	var parsed_response: Variant = JSON.parse_string(response_text)

	if not parsed_response is Dictionary:
		return {
			"ok": false,
			"code": response_code,
			"error": "The deletion server returned an invalid response."
		}

	var response_data: Dictionary = parsed_response

	# The Worker must explicitly confirm successful deletion.
	if response_code < 200 or response_code >= 300:
		var error_message := str(
			response_data.get(
				"message",
				"Teacher deletion failed."
			)
		)

		push_error(
			"[TeacherDataManager] Worker deletion failed: "
			+ error_message
		)

		return {
			"ok": false,
			"code": response_code,
			"error": error_message
		}

	if not bool(response_data.get("success", false)):
		return {
			"ok": false,
			"code": response_code,
			"error": str(
				response_data.get(
					"message",
					"Worker did not confirm teacher deletion."
				)
			)
		}

	# Only update the local cache after confirmed server success.
	for i in range(teachers_data.size() - 1, -1, -1):
		if str(teachers_data[i].get("uid", "")) == teacher_uid:
			teachers_data.remove_at(i)

	print(
		"[TeacherDataManager] Teacher account permanently deleted: ",
		teacher_uid
	)

	return {
		"ok": true,
		"uid": teacher_uid
	}



func check_teacher(teacher_uid: String) -> Dictionary:
	teacher_uid = teacher_uid.strip_edges()

	if teacher_uid.is_empty():
		return {
			"ok": false,
			"error": "Teacher UID is missing."
		}

	# Get the currently logged-in administrator's Firebase ID token.
	var token: String = _get_firestore_token()

	if token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	# Prepare the read-only Cloudflare Worker request.
	var url := (
		"https://atomix-auth-api.atomix-auth.workers.dev"
		+ "/admin-check-teacher"
	)

	var request_body := {
		"callerIdToken": token,
		"teacherUid": teacher_uid
	}

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var http := HTTPRequest.new()
	add_child(http)

	var request_error: Error = http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(request_body)
	)

	if request_error != OK:
		http.queue_free()

		return {
			"ok": false,
			"error": "Unable to start teacher verification: %s" % request_error
		}

	# Wait for the Worker response.
	var response: Array = await http.request_completed
	http.queue_free()

	var request_result: int = int(response[0])
	var response_code: int = int(response[1])

	var response_text: String = (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"error": "Unable to connect to the teacher verification server."
		}

	# Parse the Worker's JSON response.
	var parsed_response: Variant = JSON.parse_string(response_text)

	if not parsed_response is Dictionary:
		return {
			"ok": false,
			"code": response_code,
			"error": "The verification server returned an invalid response."
		}

	var response_data: Dictionary = parsed_response

	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"code": response_code,
			"error": str(
				response_data.get(
					"message",
					"Teacher verification failed."
				)
			)
		}

	if not bool(response_data.get("success", false)):
		return {
			"ok": false,
			"code": response_code,
			"error": str(
				response_data.get(
					"message",
					"Worker did not confirm the teacher account."
				)
			)
		}

	print(
		"[TeacherDataManager] Teacher account verified: ",
		teacher_uid
	)

	return {
		"ok": true,
		"uid": teacher_uid,
		"role": str(response_data.get("role", ""))
	}



func get_teachers() -> Array[Dictionary]:
	return teachers_data


# ============================================================
# CURRENT TEACHER'S ASSIGNED SECTIONS
# ============================================================

func get_current_teacher_sections() -> Array:
	var teacher_uid: String = _get_current_uid()

	if teacher_uid.is_empty():
		push_warning("[TeacherDataManager] Current user UID is missing.")
		return []

	var response: Dictionary = await _firestore_get(
		"teachers/" + teacher_uid.uri_encode()
	)

	if not bool(response.get("ok", false)):
		push_warning(
			"[TeacherDataManager] Unable to load current teacher: "
			+ str(response.get("error", "Unknown error"))
		)
		return []

	var document: Variant = response.get("data", {})
	if not document is Dictionary:
		return []

	var teacher_data: Dictionary = _decode_document(document)
	var sections: Variant = teacher_data.get("assigned_sections", [])

	if sections is Array:
		return sections

	if sections is String and not sections.strip_edges().is_empty():
		return [sections.strip_edges()]

	return []



# ============================================================
# CURRENT TEACHER'S ASSIGNED SCHOOL YEAR
# ============================================================

func get_current_teacher_school_year_id() -> String:
	var teacher_uid: String = _get_current_uid()

	if teacher_uid.is_empty():
		push_warning("[TeacherDataManager] Current teacher UID is missing.")
		return ""

	var response: Dictionary = await _firestore_get(
		"teachers/" + teacher_uid.uri_encode()
	)

	if not bool(response.get("ok", false)):
		push_warning(
			"[TeacherDataManager] Unable to load teacher school year: "
			+ str(response.get("error", "Unknown error"))
		)
		return ""

	var document: Variant = response.get("data", {})

	if not document is Dictionary:
		return ""

	var teacher_data: Dictionary = _decode_document(document)

	var school_year_id: String = str(
		teacher_data.get("school_year_id", "")
	).strip_edges()

	if school_year_id.is_empty():
		push_warning(
			"[TeacherDataManager] Current teacher has no assigned school year."
		)
		return ""

	print(
		"[TeacherDataManager] Current teacher school year ID: ",
		school_year_id
	)

	return school_year_id
	


# ============================================================
# LOAD STUDENTS
# ============================================================

func load_students() -> void:
	print("[TeacherDataManager] Loading students from Firestore...")

	students_data.clear()

	var role: String = await _get_current_role()
	role = role.strip_edges().to_lower()

	# Normalize headteacher role names.
	if role in ["headteacher", "head_teacher", "head teacher"]:
		role = "admin"

	if role.is_empty():
		students_error.emit({
			"message": "Unable to determine the current user's role."
		})
		return

	var assigned_sections: Array = []

	# Only teachers are restricted by assigned sections here.
	if role == "teacher":
		assigned_sections = await get_current_teacher_sections()

		if assigned_sections.is_empty():
			print(
				"[TeacherDataManager] Teacher has no assigned sections."
			)
			students_loaded.emit(students_data)
			return

	var response: Dictionary = await _get_collection_documents(
		"students"
	)

	if not bool(response.get("ok", false)):
		var message: String = str(
			response.get("error", "Unable to load students.")
		)

		students_error.emit({
			"message": message
		})
		return

	var documents: Array = response.get("documents", [])

	for student in documents:
		if not student is Dictionary:
			continue

		# Teachers see students from their assigned sections.
		if role == "teacher":
			var section_value: Variant = student.get("section", "")
			var student_sections: Array = []

			if section_value is Array:
				student_sections = section_value
			elif not str(section_value).strip_edges().is_empty():
				student_sections = [str(section_value).strip_edges()]

			var has_assigned_section: bool = false

			for section in student_sections:
				if assigned_sections.has(section):
					has_assigned_section = true
					break

			if not has_assigned_section:
				continue

		# Headteachers/admins retain all student records.
		students_data.append(student)

	print(
		"[TeacherDataManager] Role: ",
		role,
		" | Students loaded: ",
		students_data.size()
	)

	students_loaded.emit(students_data)
	

# ============================================================
# UPDATE STUDENT STATUS
# ============================================================


func update_student_status(
	student_uid: String,
	new_status: String
) -> Dictionary:
	student_uid = student_uid.strip_edges()
	new_status = new_status.strip_edges().to_lower()

	# 1. Validate student UID.
	if student_uid.is_empty():
		return {
			"ok": false,
			"error": "Student UID is missing."
		}

	# 2. Only allow active and inactive.
	if new_status not in ["active", "inactive"]:
		return {
			"ok": false,
			"error": "Only active and inactive statuses are allowed."
		}

	# 3. Get the current teacher's Firebase ID token.
	var token: String = _get_firestore_token()

	if token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	# 4. Prepare the Cloudflare Worker request.
	var url := (
		"https://atomix-auth-api.atomix-auth.workers.dev"
		+ "/teacher-update-student-status"
	)

	var request_body := {
		"callerIdToken": token,
		"studentUid": student_uid,
		"status": new_status
	}

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var http := HTTPRequest.new()
	add_child(http)

	var request_error: Error = http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(request_body)
	)

	if request_error != OK:
		http.queue_free()

		return {
			"ok": false,
			"error": "Unable to start student status update: %s" % request_error
		}

	# 5. Wait for the Worker response.
	var response: Array = await http.request_completed
	http.queue_free()

	var request_result: int = int(response[0])
	var response_code: int = int(response[1])

	var response_text: String = (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	# 6. Check network request result.
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"code": response_code,
			"error": "Unable to connect to the student status server."
		}

	# 7. Parse the Worker response.
	var parsed_response: Variant = JSON.parse_string(response_text)

	if not parsed_response is Dictionary:
		return {
			"ok": false,
			"code": response_code,
			"error": "The student status server returned an invalid response."
		}

	var response_data: Dictionary = parsed_response

	# 8. Check HTTP response.
	if response_code < 200 or response_code >= 300:
		var error_message := str(
			response_data.get(
				"message",
				"Student status update failed."
			)
		)

		push_error(
			"[TeacherDataManager] Student status update failed: "
			+ error_message
		)

		return {
			"ok": false,
			"code": response_code,
			"error": error_message,
			"response": response_data
		}

	# 9. Require explicit confirmation from the Worker.
	if not bool(response_data.get("success", false)):
		return {
			"ok": false,
			"code": response_code,
			"error": str(
				response_data.get(
					"message",
					"Worker did not confirm the student status update."
				)
			),
			"response": response_data
		}

	# 10. Update the local cache only after confirmed success.
	for i in range(students_data.size()):
		if str(students_data[i].get("uid", "")) == student_uid:
			students_data[i]["status"] = new_status
			break

	print(
		"[TeacherDataManager] Student status successfully updated: ",
		student_uid,
		" -> ",
		new_status
	)

	return {
		"ok": true,
		"uid": student_uid,
		"status": new_status,
		"response": response_data
	}



# ============================================================
# DELETE STUDENT FIRESTORE DOCUMENT
# ============================================================

func delete_student(student_uid: String) -> Dictionary:
	student_uid = student_uid.strip_edges()

	if student_uid.is_empty():
		return {
			"ok": false,
			"error": "Student UID is missing."
		}

	var token: String = _get_firestore_token()

	if token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	var url: String = (
		"https://atomix-auth-api.atomix-auth.workers.dev"
		+ "/admin-delete-student"
	)

	var request_body: Dictionary = {
		"callerIdToken": token,
		"studentUid": student_uid
	}

	var http := HTTPRequest.new()
	add_child(http)

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var request_error: Error = http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(request_body)
	)

	if request_error != OK:
		http.queue_free()
		return {
			"ok": false,
			"error": "Unable to start permanent student deletion: %s" % request_error
		}

	var response: Array = await http.request_completed
	http.queue_free()

	var result_code: int = int(response[0])
	var response_code: int = int(response[1])

	var response_text: String = (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"code": response_code,
			"error": "Network error while contacting the deletion service."
		}

	var parsed_response: Variant = JSON.parse_string(response_text)

	if not parsed_response is Dictionary:
		return {
			"ok": false,
			"code": response_code,
			"error": "The deletion service returned an invalid response."
		}

	var response_data: Dictionary = parsed_response

	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"code": response_code,
			"error": str(
				response_data.get(
					"message",
					"Permanent student deletion failed."
				)
			)
		}

	if not bool(response_data.get("success", false)):
		return {
			"ok": false,
			"code": response_code,
			"error": str(
				response_data.get(
					"message",
					"Permanent student deletion was not confirmed."
				)
			)
		}

	# Remove the deleted student from the local cache.
	for i in range(students_data.size() - 1, -1, -1):
		if str(students_data[i].get("uid", "")) == student_uid:
			students_data.remove_at(i)

	print(
		"[TeacherDataManager] Student account permanently deleted: ",
		student_uid
	)

	return {
		"ok": true,
		"uid": student_uid
	}


func check_student(student_uid: String) -> Dictionary:
	student_uid = student_uid.strip_edges()

	if student_uid.is_empty():
		return {
			"ok": false,
			"error": "Student UID is missing."
		}

	var token: String = _get_firestore_token()

	if token.is_empty():
		return {
			"ok": false,
			"error": "Firebase authentication token is missing."
		}

	var url: String = (
		"https://atomix-auth-api.atomix-auth.workers.dev"
		+ "/admin-check-student"
	)

	var request_body: Dictionary = {
		"callerIdToken": token,
		"studentUid": student_uid
	}

	var http := HTTPRequest.new()
	add_child(http)

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var request_error: Error = http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(request_body)
	)

	if request_error != OK:
		http.queue_free()
		return {
			"ok": false,
			"error": "Unable to start student verification."
		}

	var response: Array = await http.request_completed
	http.queue_free()

	var response_code: int = int(response[1])
	var response_text: String = (
		(response[3] as PackedByteArray).get_string_from_utf8()
	)

	var parsed: Variant = JSON.parse_string(response_text)

	if not parsed is Dictionary:
		return {
			"ok": false,
			"error": "Invalid verification response."
		}

	var data: Dictionary = parsed

	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"error": str(data.get("message", "Student verification failed."))
		}

	return {
		"ok": bool(data.get("success", false)),
		"data": data
	}


# ============================================================
# LOAD LESSONS
# ============================================================

func load_lessons() -> void:
	print("[TeacherDataManager] Loading lessons from Firestore...")

	lessons_data.clear()

	var role: String = await _get_current_role()
	var current_uid: String = _get_current_uid()

	if role == "teacher" and current_uid.is_empty():
		lessons_error.emit({
			"message": "Teacher account UID could not be determined."
		})
		return

	var response: Dictionary = await _get_collection_documents("lessons")

	if not bool(response.get("ok", false)):
		var message: String = str(response.get("error", "Unable to load lessons."))
		lessons_error.emit({"message": message})
		return

	var documents: Array = response.get("documents", [])

	for lesson in documents:
		if not lesson is Dictionary:
			continue

		# Teachers see only their own lessons.
		if role == "teacher":
			var owner_uid: String = str(
				lesson.get("teacher_id", "")
			)

			if owner_uid != current_uid:
				continue

		lessons_data.append(lesson)

	print("[TeacherDataManager] Lessons loaded: ", lessons_data.size())
	lessons_loaded.emit(lessons_data)


func get_lessons() -> Array[Dictionary]:
	return lessons_data
	
# ------------------------------------------------------------
# QUIZ DATA
# ------------------------------------------------------------

func load_quizzes() -> void:
	print("[TeacherDataManager] Loading quizzes from Firestore...")

	quizzes_data.clear()

	var response: Dictionary = await _get_collection_documents("quizzes")

	if not bool(response.get("ok", false)):
		var message: String = str(
			response.get("error", "Unable to load quizzes.")
		)

		push_error("[TeacherDataManager] " + message)
		quizzes_error.emit({"message": message})
		return

	var documents: Array = response.get("documents", [])

	for quiz in documents:
		if not quiz is Dictionary:
			continue

		var quiz_data: Dictionary = quiz.duplicate(true)

		# Use the Firestore document ID if quiz_id is missing.
		if str(quiz_data.get("quiz_id", "")).is_empty():
			quiz_data["quiz_id"] = str(quiz_data.get("uid", ""))

		quizzes_data.append(quiz_data)

	print(
		"[TeacherDataManager] Quizzes loaded: ",
		quizzes_data.size()
	)

	quizzes_loaded.emit(quizzes_data)


func get_quizzes() -> Array[Dictionary]:
	return quizzes_data

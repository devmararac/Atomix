extends Node
class_name SchoolYearAccessManager

const PROJECT_ID := "atomix-f6c6b"
const FIRESTORE_BASE_URL := "https://firestore.googleapis.com/v1/projects/"
const SCHOOL_YEARS_PATH := "/databases/(default)/documents/school_years"
const STUDENTS_PATH := "/databases/(default)/documents/students/"

var http: HTTPRequest


func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)


# =========================================================
# MAIN ACCESS CHECK
# =========================================================

func check_student_learning_access(student_uid: String) -> Dictionary:
	if student_uid.strip_edges().is_empty():
		return {
			"success": false,
			"allowed": false,
			"message": "Student UID is empty."
		}

	var token := _get_id_token()

	if token.is_empty():
		return {
			"success": false,
			"allowed": false,
			"message": "Firebase authentication token not found."
		}

	# 1. Get the active school year.
	var active_year_result := await _get_active_school_year(token)

	if not active_year_result.get("success", false):
		return {
			"success": false,
			"allowed": false,
			"message": active_year_result.get("message", "Failed to retrieve active school year.")
		}

	var active_year_id: String = active_year_result.get("year_id", "")

	# 2. Get the student's school year.
	var student_result := await _get_student_school_year(student_uid, token)

	if not student_result.get("success", false):
		return {
			"success": false,
			"allowed": false,
			"message": student_result.get("message", "Failed to retrieve student information.")
		}

	var student_year_id: String = student_result.get("school_year", "")

	# 3. Compare school year IDs.
	var allowed := (
		not active_year_id.is_empty()
		and not student_year_id.is_empty()
		and student_year_id == active_year_id
	)

	print("[SchoolYearAccess] Student UID: ", student_uid)
	print("[SchoolYearAccess] Student year: ", student_year_id)
	print("[SchoolYearAccess] Active year: ", active_year_id)
	print("[SchoolYearAccess] Learning access: ", allowed)

	return {
		"success": true,
		"allowed": allowed,
		"student_school_year": student_year_id,
		"active_school_year": active_year_id,
		"message": "Access granted." if allowed else "This school year is inactive. Game-only access."
	}


# =========================================================
# GET ACTIVE SCHOOL YEAR
# =========================================================

func _get_active_school_year(token: String) -> Dictionary:
	var url := (
		FIRESTORE_BASE_URL
		+ PROJECT_ID
		+ SCHOOL_YEARS_PATH
	)

	var result := await _firestore_get(url, token)

	if not result.get("success", false):
		return result

	var response: Dictionary = result.get("data", {})
	var documents: Array = response.get("documents", [])

	for document in documents:
		if not document is Dictionary:
			continue

		var fields: Dictionary = document.get("fields", {})
		var active := _get_bool_field(fields, "active")
		var archived := _get_bool_field(fields, "archived")

		if active and not archived:
			var full_name := str(document.get("name", ""))
			var parts := full_name.split("/", false)

			if parts.is_empty():
				continue

			var year_id := str(parts[parts.size() - 1])

			if not year_id.is_empty():
				return {
					"success": true,
					"year_id": year_id
				}

	return {
		"success": false,
		"year_id": "",
		"message": "No active school year was found."
	}


# =========================================================
# GET STUDENT SCHOOL YEAR
# =========================================================

func _get_student_school_year(
	student_uid: String,
	token: String
) -> Dictionary:
	var url := (
		FIRESTORE_BASE_URL
		+ PROJECT_ID
		+ STUDENTS_PATH
		+ student_uid.uri_encode()
	)

	var result := await _firestore_get(url, token)

	if not result.get("success", false):
		return result

	var response: Dictionary = result.get("data", {})
	var fields: Dictionary = response.get("fields", {})

	var student_year := _get_string_field(fields, "school_year")

	return {
		"success": true,
		"school_year": student_year
	}


# =========================================================
# FIRESTORE GET REQUEST
# =========================================================

func _firestore_get(url: String, token: String) -> Dictionary:
	if not is_instance_valid(http):
		return {
			"success": false,
			"message": "HTTPRequest node is invalid."
		}

	# Prevent overlapping requests on the same HTTPRequest.
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return {
			"success": false,
			"message": "Another request is currently running."
		}

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	])

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		return {
			"success": false,
			"message": "Failed to start Firestore request. Error: " + str(error)
		}

	var result = await http.request_completed

	var request_result: int = result[0]
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]

	var response_text := response_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_text)

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"message": "Network request failed."
		}

	if response_code < 200 or response_code >= 300:
		push_error("[SchoolYearAccess] Firestore HTTP error: " + response_text)

		return {
			"success": false,
			"message": "Firestore returned HTTP " + str(response_code)
		}

	if not parsed is Dictionary:
		return {
			"success": false,
			"message": "Invalid Firestore response."
		}

	return {
		"success": true,
		"data": parsed
	}


# =========================================================
# FIRESTORE FIELD HELPERS
# =========================================================

func _get_string_field(fields: Dictionary, field_name: String) -> String:
	if not fields.has(field_name):
		return ""

	var field: Dictionary = fields[field_name]

	return str(field.get("stringValue", ""))


func _get_bool_field(fields: Dictionary, field_name: String) -> bool:
	if not fields.has(field_name):
		return false

	var field: Dictionary = fields[field_name]

	return bool(field.get("booleanValue", false))


# =========================================================
# FIREBASE AUTH
# =========================================================

func _get_id_token() -> String:
	if Firebase.Auth == null:
		return ""

	var auth_data: Dictionary = Firebase.Auth.auth

	var token := str(auth_data.get("idtoken", ""))

	if token.is_empty():
		token = str(auth_data.get("idToken", ""))

	return token

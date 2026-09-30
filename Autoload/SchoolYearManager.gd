extends Node

# ============================================================
# ENROLLMENT / ONE-YEAR ARCHIVE MANAGEMENT
# ============================================================
#
# Each student gets a one-year enrollment period.
#
# Example:
#   enrolled_at = July 10, 2026
#   archive_at  = July 10, 2027
#
# The archive date is stored on the student's Firestore document,
# so the system does NOT assume that a school year always starts
# in June or ends in May.
#
# Archiving is performed when the Admin Dashboard checks for due
# students. Firebase Authentication accounts are NOT deleted.
# A later student import/re-enrollment can reactivate the same UID
# and start a new one-year period.
# ============================================================

var archive_in_progress := false


# ============================================================
# DATE HELPERS
# ============================================================

func get_current_timestamp() -> int:
	return int(Time.get_unix_time_from_system())


func get_school_year_for_timestamp(timestamp: int) -> String:
	var date := Time.get_datetime_dict_from_unix_time(timestamp)
	var start_year := int(date.get("year", 0))

	# This is only a label for reporting/history. It is NOT used
	# to determine when the student's one-year enrollment ends.
	if int(date.get("month", 1)) < 6:
		start_year -= 1

	return "%d-%d" % [start_year, start_year + 1]


func get_archive_timestamp(enrolled_timestamp: int) -> int:
	var date := Time.get_datetime_dict_from_unix_time(enrolled_timestamp)

	var next_year_date := {
		"year": int(date.get("year", 0)) + 1,
		"month": int(date.get("month", 1)),
		"day": int(date.get("day", 1)),
		"hour": int(date.get("hour", 0)),
		"minute": int(date.get("minute", 0)),
		"second": int(date.get("second", 0))
	}

	# February 29 does not exist in a non-leap year.
	# Move Feb 29 enrollments to Feb 28 in the following year.
	if next_year_date["month"] == 2 and next_year_date["day"] == 29:
		if not is_leap_year(next_year_date["year"]):
			next_year_date["day"] = 28

	return int(Time.get_unix_time_from_datetime_dict(next_year_date))


func is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)


# ============================================================
# ADMIN ARCHIVE CHECK
# ============================================================

func ensure_due_student_archives() -> bool:
	if archive_in_progress:
		return false

	archive_in_progress = true

	var auth_data: Dictionary = Firebase.Firestore.auth
	if auth_data.is_empty() or not auth_data.has("idtoken"):
		print("[SchoolYearManager] Missing Firebase authentication token.")
		archive_in_progress = false
		return false

	var project_id := get_firebase_project_id()
	if project_id.is_empty():
		archive_in_progress = false
		return false

	var documents := await fetch_collection_documents(
		"students",
		project_id,
		str(auth_data["idtoken"])
	)

	if documents.is_empty():
		print("[SchoolYearManager] No student documents found.")
		archive_in_progress = false
		return true

	var now := get_current_timestamp()
	var archived_count := 0

	for raw_document in documents:
		var student := decode_firestore_document(raw_document)
		if student.is_empty():
			continue

		if str(student.get("status", "")) != "active":
			continue

		var archive_at := int(student.get("archive_at", 0))
		if archive_at <= 0:
			# Older student records may not have the new fields yet.
			# Do not guess an archive date from the old school-year label.
			# They can be given an enrollment date during re-import.
			continue

		if archive_at > now:
			continue

		var uid := str(student.get("uid", ""))
		if uid.is_empty():
			continue

		if await archive_student(uid, student):
			archived_count += 1

	print("[SchoolYearManager] Students archived this check: ", archived_count)

	archive_in_progress = false
	return true


# ============================================================
# ARCHIVE ONE STUDENT
# ============================================================

func archive_student(uid: String, student: Dictionary) -> bool:
	var students = Firebase.Firestore.collection("students")
	var document: FirestoreDocument = await students.get_doc(uid)
	if document == null:
		return false

	var history: Dictionary = document.get_unsafe_document().get("academic_history", {})
	if not history is Dictionary:
		history = {}

	var enrolled_at := int(student.get("enrolled_at", 0))
	var archive_at := int(student.get("archive_at", get_current_timestamp()))
	var history_key := str(student.get("school_year", ""))
	if history_key.is_empty():
		history_key = "enrollment_%d" % enrolled_at

	# Keep a complete academic snapshot for the finished period.
	history[history_key] = {
		"section": str(student.get("section", "")),
		"school_year": str(student.get("school_year", "")),
		"enrolled_at": enrolled_at,
		"archive_at": archive_at,
		"archived_at": get_current_timestamp(),
		"progress": duplicate_dictionary(student.get("progress", {})),
		"lesson_progress": duplicate_dictionary(student.get("lesson_progress", {})),
		"assessment": duplicate_dictionary(student.get("assessment", {})),
		"battle_stats": duplicate_dictionary(student.get("battle_stats", {})),
		"game_state": duplicate_dictionary(student.get("game_state", {}))
	}

	# Keep the Firebase UID and identity fields, but mark the current
	# enrollment as archived. The teacher can re-enroll the same account
	# later through the import/student-management workflow.
	document.add_or_update_field("academic_history", history)
	document.add_or_update_field("status", "archived")
	document.add_or_update_field("last_archived_at", get_current_timestamp())

	# These are reset so a later re-enrollment starts with clean current data.
	document.add_or_update_field("progress", {
		"elements_total": 118,
		"elements_collected": 0,
		"collected_elements": [],
		"overall_percentage": 0.0
	})
	document.add_or_update_field("lesson_progress", {})
	document.add_or_update_field("assessment", {
		"total_assessments": 0,
		"completed_assessments": 0,
		"average_score": 0.0,
		"latest_score": 0.0
	})
	document.add_or_update_field("battle_stats", {
		"battles_played": 0,
		"battles_won": 0,
		"battles_lost": 0,
		"battles_escaped": 0
	})
	document.add_or_update_field("game_state", {
		"has_save": false,
		"current_scene": "res://Scenes/Areas/start_map.tscn",
		"player_position": {"x": 0.0, "y": 0.0},
		"coins": 0,
		"active_index": 0,
		"party": [],
		"carried_party": [],
		"inventory": [],
		"quest_data": {}
	})

	var result: FirestoreDocument = await students.update(document)
	if result == null:
		return false

	# Keep the users document in sync so login can block archived accounts.
	var users = Firebase.Firestore.collection("users")
	var user_document: FirestoreDocument = await users.get_doc(uid)
	if user_document != null:
		user_document.add_or_update_field("status", "archived")
		user_document.add_or_update_field("last_archived_at", get_current_timestamp())
		await users.update(user_document)

	return true


func duplicate_dictionary(value) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


# ============================================================
# FIRESTORE REST HELPERS
# ============================================================

func fetch_collection_documents(collection_name: String, project_id: String, id_token: String) -> Array:
	var base_url := (
		"https://firestore.googleapis.com/v1/projects/"
		+ project_id
		+ "/databases/(default)/documents/"
		+ collection_name
		+ "?pageSize=300"
	)

	var all_documents: Array = []
	var next_page_token := ""

	while true:
		var url := base_url
		if not next_page_token.is_empty():
			url += "&pageToken=" + next_page_token.uri_encode()

		var http := HTTPRequest.new()
		add_child(http)

		var headers := PackedStringArray([
			"Authorization: Bearer " + id_token,
			"Content-Type: application/json"
		])

		var error := http.request(url, headers, HTTPClient.METHOD_GET)
		if error != OK:
			http.queue_free()
			return []

		var response: Array = await http.request_completed
		var code: int = response[1]
		var body: PackedByteArray = response[3]
		http.queue_free()

		if code != 200:
			print("[SchoolYearManager] REST fetch failed: ", code)
			return []

		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) != OK:
			return []

		var data = json.data
		if not data is Dictionary:
			return []

		all_documents.append_array(data.get("documents", []))
		next_page_token = str(data.get("nextPageToken", ""))

		if next_page_token.is_empty():
			break

	return all_documents


func get_firebase_project_id() -> String:
	if Firebase.Firestore._config.has("projectId"):
		return str(Firebase.Firestore._config["projectId"])

	if "FIREBASE_PROJECT_ID" in FirebaseConfig:
		return str(FirebaseConfig.FIREBASE_PROJECT_ID)

	if "PROJECT_ID" in FirebaseConfig:
		return str(FirebaseConfig.PROJECT_ID)

	return ""


func decode_firestore_document(document: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var fields = document.get("fields", {})

	if fields is Dictionary:
		for field_name in fields:
			result[field_name] = _decode_firestore_value(fields[field_name])

	var name := str(document.get("name", ""))
	if not name.is_empty():
		result["uid"] = name.get_file()

	return result


func _decode_firestore_value(value: Dictionary):
	if value.has("stringValue"):
		return value["stringValue"]
	if value.has("integerValue"):
		return int(value["integerValue"])
	if value.has("doubleValue"):
		return float(value["doubleValue"])
	if value.has("booleanValue"):
		return value["booleanValue"]
	if value.has("timestampValue"):
		return value["timestampValue"]
	if value.has("nullValue"):
		return null
	if value.has("arrayValue"):
		var result: Array = []
		for item in value["arrayValue"].get("values", []):
			result.append(_decode_firestore_value(item))
		return result
	if value.has("mapValue"):
		var result: Dictionary = {}
		for field_name in value["mapValue"].get("fields", {}):
			result[field_name] = _decode_firestore_value(value["mapValue"]["fields"][field_name])
		return result
	return null

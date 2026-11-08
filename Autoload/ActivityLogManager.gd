
extends Node

signal activity_logs_loaded(logs: Array)
signal activity_logs_failed(message: String)

const PROJECT_ID := "atomix-f6c6b"
const ACTIVITY_LOGS_PATH := "activity_logs"

var current_uid: String = ""
var current_role: String = ""
var auth_token: String = ""


# Call this after Firebase authentication and role loading.
func initialize(uid: String, role: String, token: String) -> void:
	current_uid = uid
	current_role = role
	auth_token = token

	print("[ActivityLogManager] Initialized for: ", current_uid)


# Call this after an action succeeds.
func log_activity(
	action: String,
	details: String,
	module: String = "",
	target_id: String = ""
) -> void:

	if current_uid.is_empty():
		push_warning("[ActivityLogManager] Missing user UID.")
		return

	if auth_token.is_empty():
		push_warning("[ActivityLogManager] Missing Firebase token.")
		return

	var request := HTTPRequest.new()
	add_child(request)

	request.request_completed.connect(
		_on_log_request_completed.bind(request, action)
	)

	var timestamp := Time.get_datetime_string_from_system(true) + "Z"

	var document_id := "%s_%s_%s" % [
		current_uid,
		str(Time.get_unix_time_from_system()),
		str(Time.get_ticks_usec())
	]

	var document_path := (
		"activity_logs/" + document_id
	)

	var fields := {
		"user_id": {"stringValue": current_uid},
		"role": {"stringValue": current_role},
		"action": {"stringValue": action},
		"details": {"stringValue": details},
		"module": {"stringValue": module},
		"target_id": {"stringValue": target_id},
		"timestamp": {"timestampValue": timestamp}
	}

	var body := {
		"fields": fields
	}

	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/(default)/documents/"
		+ document_path
	)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + auth_token
	])

	var error := request.request(
		url,
		headers,
		HTTPClient.METHOD_PATCH,
		JSON.stringify(body)
	)

	if error != OK:
		push_error(
			"[ActivityLogManager] Request error: " + str(error)
		)
		request.queue_free()


func _on_log_request_completed(
	result: int,
	response_code: int,
	_response_headers: PackedStringArray,
	body: PackedByteArray,
	request: HTTPRequest,
	action: String
) -> void:

	if (
		result != HTTPRequest.RESULT_SUCCESS
		or response_code < 200
		or response_code >= 300
	):
		push_error(
			"[ActivityLogManager] Failed to record '%s'. HTTP: %d | %s"
			% [
				action,
				response_code,
				body.get_string_from_utf8()
			]
		)
	else:
		print(
			"[ActivityLogManager] Recorded activity: ",
			action
		)

	request.queue_free()

# Retrieve the current user's activity logs from Firestore.
func load_activity_logs(limit: int = 100) -> void:

	if current_uid.is_empty():
		activity_logs_failed.emit("No user is currently logged in.")
		return

	if auth_token.is_empty():
		activity_logs_failed.emit("Firebase authentication token is missing.")
		return

	var request := HTTPRequest.new()
	add_child(request)

	request.request_completed.connect(
		_on_activity_logs_loaded.bind(request)
	)

	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/(default)/documents:runQuery"
	)

	var query_body := {
		"structuredQuery": {
			"from": [
				{"collectionId": ACTIVITY_LOGS_PATH}
			],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "user_id"},
					"op": "EQUAL",
					"value": {"stringValue": current_uid}
				}
			},
			"orderBy": [
				{
					"field": {"fieldPath": "timestamp"},
					"direction": "DESCENDING"
				}
			],
			"limit": clampi(limit, 1, 500)
		}
	}

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + auth_token
	])

	var error := request.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(query_body)
	)

	if error != OK:
		activity_logs_failed.emit(
			"Could not send activity-log request. Error: " + str(error)
		)
		request.queue_free()


func _on_activity_logs_loaded(
	result: int,
	response_code: int,
	_response_headers: PackedStringArray,
	body: PackedByteArray,
	request: HTTPRequest
) -> void:

	if result != HTTPRequest.RESULT_SUCCESS:
		activity_logs_failed.emit("Could not connect to Firestore.")
		request.queue_free()
		return

	if response_code < 200 or response_code >= 300:
		activity_logs_failed.emit(
			"Firestore error (" + str(response_code) + "): "
			+ body.get_string_from_utf8()
		)
		request.queue_free()
		return

	var response = JSON.parse_string(body.get_string_from_utf8())

	if not response is Array:
		activity_logs_failed.emit("Invalid activity-log response.")
		request.queue_free()
		return

	var logs: Array = []

	for entry in response:
		if not entry is Dictionary:
			continue

		if not entry.has("document"):
			continue

		var document: Dictionary = entry["document"]
		var fields: Dictionary = document.get("fields", {})

		logs.append({
			"action": _get_log_string(fields, "action"),
			"details": _get_log_string(fields, "details"),
			"module": _get_log_string(fields, "module"),
			"target_id": _get_log_string(fields, "target_id"),
			"role": _get_log_string(fields, "role"),
			"timestamp": _get_log_string(fields, "timestamp")
		})

	request.queue_free()

	activity_logs_loaded.emit(logs)


func _get_log_string(fields: Dictionary, field_name: String) -> String:

	var field: Dictionary = fields.get(field_name, {})

	if field.has("stringValue"):
		return str(field["stringValue"])

	if field.has("timestampValue"):
		return str(field["timestampValue"])

	return ""

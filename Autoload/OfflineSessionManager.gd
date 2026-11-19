
extends Node

const SESSION_FILE := "user://offline_student_session.json"
const SESSION_VERSION := 1


# ============================================================
# SAVE OFFLINE STUDENT SESSION
# ============================================================

func save_student_session(
	uid: String,
	student_data: Dictionary
) -> bool:

	if uid.is_empty():
		push_error("[OfflineSessionManager] Cannot save empty UID.")
		return false

	if student_data.get("uid", uid) != uid:
		push_error("[OfflineSessionManager] Student UID mismatch.")
		return false

	# Cache only the information needed for offline gameplay.
	var cached_student_data := {
		"uid": uid,
		"name": str(student_data.get("name", "Student")),
		"display_name": str(student_data.get("display_name", "")),
		"character_id": str(student_data.get("character_id", "")),
		"progress": student_data.get("progress", {}),
		"game_state": student_data.get("game_state", {})
	}

	var session_record := {
		"version": SESSION_VERSION,
		"uid": uid,
		"role": "student",
		"saved_at": Time.get_unix_time_from_system(),
		"student_data": cached_student_data
	}

	var file := FileAccess.open(SESSION_FILE, FileAccess.WRITE)

	if file == null:
		push_error("[OfflineSessionManager] Could not create session file.")
		return false

	file.store_string(JSON.stringify(session_record, "\t"))

	var file_error := file.get_error()
	file.close()

	if file_error != OK:
		push_error("[OfflineSessionManager] Failed to write session.")
		return false

	print("[OfflineSessionManager] Student session saved.")
	return true


# ============================================================
# LOAD OFFLINE STUDENT SESSION
# ============================================================

func load_student_session() -> Dictionary:

	if not FileAccess.file_exists(SESSION_FILE):
		return {}

	var file := FileAccess.open(SESSION_FILE, FileAccess.READ)

	if file == null:
		push_error("[OfflineSessionManager] Could not read session file.")
		return {}

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)

	if not parsed is Dictionary:
		push_error("[OfflineSessionManager] Invalid session file.")
		return {}

	var record: Dictionary = parsed

	if int(record.get("version", 0)) != SESSION_VERSION:
		push_warning("[OfflineSessionManager] Unsupported session version.")
		return {}

	if str(record.get("role", "")) != "student":
		push_warning("[OfflineSessionManager] Offline staff access rejected.")
		return {}

	var uid := str(record.get("uid", ""))

	if uid.is_empty():
		return {}

	var student_data: Variant = record.get("student_data", {})

	if not student_data is Dictionary:
		return {}

	if str(student_data.get("uid", "")) != uid:
		push_error("[OfflineSessionManager] Student UID mismatch.")
		return {}

	return record


# ============================================================
# CHECK EXISTING OFFLINE SESSION
# ============================================================

func has_offline_session() -> bool:
	return not load_student_session().is_empty()


# ============================================================
# CLEAR OFFLINE SESSION
# ============================================================

func clear_offline_session() -> void:

	if FileAccess.file_exists(SESSION_FILE):
		var error := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(SESSION_FILE)
		)

		if error != OK:
			push_error("[OfflineSessionManager] Could not remove session file.")
			return

	print("[OfflineSessionManager] Offline session cleared.")

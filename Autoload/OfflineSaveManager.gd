
extends Node

const SAVE_DIRECTORY := "user://offline_saves"
const ACCOUNT_DIRECTORY := "user://offline_accounts"
const SAVE_VERSION := 1


# =========================================================
# SAVE LOCAL GAME
# =========================================================

func save_local_game(uid: String, game_data: Dictionary) -> bool:
	if uid.is_empty():
		push_error("[OfflineSaveManager] Cannot save: UID is empty.")
		return false

	var save_path := _get_save_path(uid)

	if save_path.is_empty():
		push_error("[OfflineSaveManager] Invalid UID.")
		return false

	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(SAVE_DIRECTORY)
	)

	if directory_error != OK:
		push_error("[OfflineSaveManager] Could not create save directory.")
		return false

	var save_record := {
		"schema_version": SAVE_VERSION,
		"uid": uid,
		"updated_at": Time.get_unix_time_from_system(),
		"pending_sync": true,
		"game_data": game_data
	}

	var file := FileAccess.open(save_path, FileAccess.WRITE)

	if file == null:
		push_error("[OfflineSaveManager] Could not open local save file.")
		return false

	file.store_string(JSON.stringify(save_record, "\t"))

	var file_error := file.get_error()
	file.close()

	if file_error != OK:
		push_error("[OfflineSaveManager] Failed to write local save.")
		return false

	print("[OfflineSaveManager] Local save completed for UID: ", uid)
	return true


# =========================================================
# LOAD LOCAL GAME
# =========================================================

func load_local_game(uid: String) -> Dictionary:
	var record := load_local_record(uid)

	if record.is_empty():
		return {}

	var game_data: Variant = record.get("game_data", {})

	if typeof(game_data) != TYPE_DICTIONARY:
		push_error("[OfflineSaveManager] Invalid game data.")
		return {}

	print("[OfflineSaveManager] Local save loaded for UID: ", uid)

	return game_data


# =========================================================
# LOAD COMPLETE SAVE RECORD
# =========================================================

func load_local_record(uid: String) -> Dictionary:
	if uid.is_empty():
		return {}

	var save_path := _get_save_path(uid)

	if save_path.is_empty():
		return {}

	if not FileAccess.file_exists(save_path):
		return {}

	var file := FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		push_error("[OfflineSaveManager] Could not read local save.")
		return {}

	var json_text := file.get_as_text()
	file.close()

	var parsed_data: Variant = JSON.parse_string(json_text)

	if typeof(parsed_data) != TYPE_DICTIONARY:
		push_error("[OfflineSaveManager] Local save contains invalid JSON.")
		return {}

	var record: Dictionary = parsed_data

	# Prevent another student's save from being loaded.
	if record.get("uid", "") != uid:
		push_error("[OfflineSaveManager] UID mismatch. Save rejected.")
		return {}

	return record


# =========================================================
# CHECK LOCAL SAVE
# =========================================================

func has_local_save(uid: String) -> bool:
	var save_path := _get_save_path(uid)

	if save_path.is_empty():
		return false

	return FileAccess.file_exists(save_path)


# =========================================================
# PENDING CLOUD SYNCHRONIZATION
# =========================================================

func has_pending_sync(uid: String) -> bool:
	var record := load_local_record(uid)

	if record.is_empty():
		return false

	return record.get("pending_sync", false)


func set_pending_sync(uid: String, pending: bool) -> bool:
	var record := load_local_record(uid)

	if record.is_empty():
		return false

	record["pending_sync"] = pending
	record["updated_at"] = Time.get_unix_time_from_system()

	return _write_record(uid, record)


# =========================================================
# INTERNAL HELPERS
# =========================================================

func _get_save_path(uid: String) -> String:
	if uid.is_empty():
		return ""

	var safe_uid := uid.validate_filename()

	if safe_uid.is_empty():
		return ""

	return SAVE_DIRECTORY + "/" + safe_uid + ".json"


func _write_record(uid: String, record: Dictionary) -> bool:
	var save_path := _get_save_path(uid)

	if save_path.is_empty():
		return false

	var file := FileAccess.open(save_path, FileAccess.WRITE)

	if file == null:
		push_error("[OfflineSaveManager] Could not update save record.")
		return false

	file.store_string(JSON.stringify(record, "\t"))

	var file_error := file.get_error()
	file.close()

	return file_error == OK


func save_account_stats(uid: String, battle_stats: Dictionary) -> bool:

	if uid.is_empty():
		return false

	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(ACCOUNT_DIRECTORY)
	)

	if directory_error != OK:
		push_error("[OfflineSaveManager] Could not create account directory.")
		return false

	var safe_uid := uid.validate_filename()

	if safe_uid.is_empty():
		return false

	var account_record := {
		"uid": uid,
		"updated_at": Time.get_unix_time_from_system(),
		"battle_stats": battle_stats.duplicate(true)
	}

	var save_path := ACCOUNT_DIRECTORY + "/" + safe_uid + ".json"

	var file := FileAccess.open(save_path, FileAccess.WRITE)

	if file == null:
		push_error("[OfflineSaveManager] Could not save account statistics.")
		return false

	file.store_string(JSON.stringify(account_record, "\t"))

	var file_error := file.get_error()
	file.close()

	return file_error == OK


func load_account_stats(uid: String) -> Dictionary:

	if uid.is_empty():
		return {}

	var safe_uid := uid.validate_filename()

	if safe_uid.is_empty():
		return {}

	var save_path := ACCOUNT_DIRECTORY + "/" + safe_uid + ".json"

	if not FileAccess.file_exists(save_path):
		return {}

	var file := FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		return {}

	var json_text := file.get_as_text()
	file.close()

	var parsed_data: Variant = JSON.parse_string(json_text)

	if not parsed_data is Dictionary:
		return {}

	if parsed_data.get("uid", "") != uid:
		push_error("[OfflineSaveManager] Account UID mismatch.")
		return {}

	var battle_stats: Variant = parsed_data.get("battle_stats", {})

	if not battle_stats is Dictionary:
		return {}

	return battle_stats.duplicate(true)



func update_local_progress(uid: String, progress: Dictionary) -> bool:

	var record := load_local_record(uid)

	if record.is_empty():
		push_error("[OfflineSaveManager] Cannot update progress: local save not found.")
		return false

	var game_data: Variant = record.get("game_data", {})

	if not game_data is Dictionary:
		push_error("[OfflineSaveManager] Invalid local game data.")
		return false

	game_data["progress"] = progress.duplicate(true)

	record["game_data"] = game_data
	record["pending_sync"] = true
	record["updated_at"] = Time.get_unix_time_from_system()

	return _write_record(uid, record)

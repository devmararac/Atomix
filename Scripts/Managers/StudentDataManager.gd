extends Node

signal student_loaded(data)
signal student_created(data)
signal student_error(error)
signal progress_updated(progress)
signal progress_loaded(progress)

const TOTAL_ELEMENTS := 118

var student_data: Dictionary = {}

# True only when a previously validated student is using an offline session.
var offline_session_active: bool = false

# IMPORTANT:
# This contains ONLY the progress currently loaded into the game.
# It should NOT automatically contain Firebase data just because the student logged in.
var collected_elements: Array[String] = []

# True only after the player explicitly presses LOAD.
var progress_is_loaded: bool = false


# ============================================================
# AUTHENTICATION
# ============================================================

func get_student_uid() -> String:

	if FirebaseManager.is_authenticated():
		return FirebaseManager.get_uid()

	if offline_session_active:
		return str(student_data.get("uid", ""))

	return ""


func is_student_logged_in() -> bool:

	return (
		FirebaseManager.is_authenticated()
		or offline_session_active
	)


func is_offline_student() -> bool:
	return offline_session_active


# ============================================================
# ACTIVATE OFFLINE STUDENT SESSION
# ============================================================

func activate_offline_session() -> bool:

	# Never replace an existing Firebase session with an offline one.
	if FirebaseManager.is_authenticated():
		return false

	var session_record: Dictionary = (
		OfflineSessionManager.load_student_session()
	)

	if session_record.is_empty():
		return false

	var cached_data: Variant = session_record.get(
		"student_data",
		{}
	)

	if not cached_data is Dictionary:
		return false

	var uid := str(session_record.get("uid", ""))

	if uid.is_empty() or str(cached_data.get("uid", "")) != uid:
		return false

	student_data = cached_data.duplicate(true)
	
	# Load the latest locally saved player profile.
	var uid_safe := uid.validate_filename()

	if not uid_safe.is_empty():
		var profile_path := (
			"user://offline_accounts/"
			+ uid_safe
			+ "_profile.json"
		)

		if FileAccess.file_exists(profile_path):
			var profile_file := FileAccess.open(
				profile_path,
				FileAccess.READ
			)

			if profile_file != null:
				var profile_data: Variant = JSON.parse_string(
					profile_file.get_as_text()
				)
				profile_file.close()

				if profile_data is Dictionary:
					if str(profile_data.get("uid", "")) == uid:
						var saved_display_name := str(
							profile_data.get("display_name", "")
						).strip_edges()

						var saved_character_id := str(
							profile_data.get("character_id", "")
						).strip_edges()

						if not saved_display_name.is_empty():
							student_data["display_name"] = saved_display_name

						if not saved_character_id.is_empty():
							student_data["character_id"] = saved_character_id

						print(
							"[StudentDataManager] Offline player profile loaded: ",
							student_data.get("display_name", "")
						)

	# Apply the loaded offline profile to PlayerManager.
	PlayerManager.set_player_data(student_data)

	print(
		"[StudentDataManager] PlayerManager display name: ",
		PlayerManager.display_name
	)

	offline_session_active = true

	# Do not automatically load collected elements.
	clear_runtime_progress()

	print("[StudentDataManager] Offline student session activated.")

	return true


# ============================================================
# DEACTIVATE OFFLINE STUDENT SESSION
# ============================================================

func deactivate_offline_session() -> void:

	offline_session_active = false
	student_data.clear()

	clear_runtime_progress()


# ============================================================
# LOAD STUDENT ACCOUNT
# ============================================================

func load_student() -> void:

	var uid := get_student_uid()

	if uid.is_empty():
		student_error.emit({
			"message": "No authenticated Firebase user."
		})
		return

	# ========================================================
	# OFFLINE STUDENT
	# ========================================================

	if is_offline_student() and not FirebaseManager.is_authenticated():

		if student_data.is_empty():
			student_error.emit({
				"message": "No cached student account is available."
			})
			return

		student_data["uid"] = uid

		if not student_data.has("progress"):
			student_data["progress"] = {
				"elements_total": TOTAL_ELEMENTS,
				"elements_collected": 0,
				"collected_elements": []
			}

		clear_runtime_progress()

		print("[StudentDataManager] Cached offline student loaded.")

		student_loaded.emit(student_data)
		return

	print("[StudentDataManager] Loading student: ", uid)

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	# ========================================================
	# STUDENT DOES NOT EXIST YET
	# ========================================================

	if document == null:
	
		if FirebaseManager.is_authenticated() and offline_session_active:
			student_error.emit({
				"message": "Could not verify the student account online. Offline session remains active."
			})
			return
	
		print(
			"[StudentDataManager] Student document not found."
		)

		student_data = {
			"uid": uid,
			"progress": {
				"elements_total": TOTAL_ELEMENTS,
				"elements_collected": 0,
				"collected_elements": []
			}
		}

		# IMPORTANT:
		# Start with NO runtime progress.
		clear_runtime_progress()

		student_created.emit(student_data)
		return
	
	
	# Verify that the restored Firebase account matches
	# the student who was using the offline session.
	var transitioning_from_offline := false

	if offline_session_active:
		var cached_uid := str(student_data.get("uid", ""))

		if cached_uid != uid:
			student_error.emit({
				"message": "Firebase account does not match the offline student."
			})
			return

		transitioning_from_offline = true
	
	
	# ========================================================
	# LOAD STUDENT ACCOUNT DATA
	# ========================================================

	student_data = document.get_unsafe_document()
	
	if transitioning_from_offline:
		offline_session_active = false
		print("[StudentDataManager] Offline session transitioned to online.")
	
	# Always make sure UID exists locally.
	student_data["uid"] = uid

	# ========================================================
	# MAKE SURE PROGRESS EXISTS IN LOCAL STUDENT DATA
	# ========================================================

	if not student_data.has("progress"):

		student_data["progress"] = {
			"elements_total": TOTAL_ELEMENTS,
			"elements_collected": 0,
			"collected_elements": []
		}

	var progress: Dictionary = student_data["progress"]

	if not progress.has("elements_total"):
		progress["elements_total"] = TOTAL_ELEMENTS

	if not progress.has("elements_collected"):
		progress["elements_collected"] = 0

	if not progress.has("collected_elements"):
		progress["collected_elements"] = []

	student_data["progress"] = progress

	# ========================================================
	# DO NOT LOAD SAVED ELEMENTS HERE
	# ========================================================

	clear_runtime_progress()

	print("[StudentDataManager] Student account loaded.")
	print("[StudentDataManager] UID: ", uid)
	print("[StudentDataManager] Student data loaded.")
	print(
		"[StudentDataManager] Runtime collected elements: ",
		collected_elements
	)
	print(
		"[StudentDataManager] Progress loaded: ",
		progress_is_loaded
	)

	await update_last_active()
	student_loaded.emit(student_data)

	# Start syncing only after the online student account
	# has been successfully verified and loaded.
	if FirebaseManager.is_authenticated() and not is_offline_student():
		print("[StudentDataManager] Online account ready. Checking pending synchronization.")
		SyncManager.call_deferred("sync_pending_save")


# ============================================================
# CLEAR RUNTIME PROGRESS
# ============================================================

func clear_runtime_progress() -> void:

	collected_elements.clear()

	progress_is_loaded = false

	print(
		"[StudentDataManager] Runtime progress cleared."
	)

	print(
		"[StudentDataManager] Saved Firebase progress has NOT been deleted."
	)


# ============================================================
# LOAD SAVED PROGRESS
# ============================================================

func load_saved_progress() -> bool:

	var uid := get_student_uid()

	if uid.is_empty():
		student_error.emit({
			"message": "No authenticated student account."
		})
		return false

	var progress: Dictionary = {}

	# ========================================================
	# OFFLINE: LOAD PROGRESS FROM LOCAL SAVE
	# ========================================================

	if is_offline_student():

		print("[StudentDataManager] Loading offline saved progress.")

		var local_record: Dictionary = (
			OfflineSaveManager.load_local_record(uid)
		)

		if local_record.is_empty():
			clear_runtime_progress()
			progress_is_loaded = false
			return false

		var game_data: Variant = local_record.get(
			"game_data",
			{}
		)

		if not game_data is Dictionary:
			clear_runtime_progress()
			progress_is_loaded = false
			return false

		# Do not treat a New Game reset as an existing playthrough.
		if not bool(game_data.get("has_save", false)):
			clear_runtime_progress()
			progress_is_loaded = false
			return false

		var saved_progress: Variant = game_data.get(
			"progress",
			{}
		)

		if saved_progress is Dictionary:
			progress = saved_progress.duplicate(true)

	# ========================================================
	# ONLINE: LOAD PROGRESS FROM FIRESTORE
	# ========================================================

	else:

		print(
			"[StudentDataManager] Loading SAVED progress for: ",
			uid
		)

		var students: FirestoreCollection = (
			Firebase.Firestore.collection("students")
		)

		var document: FirestoreDocument = (
			await students.get_doc(uid)
		)

		if document == null:
			print(
				"[StudentDataManager] Student document does not exist."
			)
			clear_runtime_progress()
			progress_is_loaded = false
			return false

		var data: Dictionary = (
			document.get_unsafe_document()
		)

		var saved_progress: Variant = data.get(
			"progress",
			{}
		)

		if saved_progress is Dictionary:
			progress = saved_progress.duplicate(true)

	# ========================================================
	# MAKE SURE PROGRESS EXISTS
	# ========================================================

	if not progress.has("elements_total"):
		progress["elements_total"] = TOTAL_ELEMENTS

	if not progress.has("elements_collected"):
		progress["elements_collected"] = 0

	if not progress.has("collected_elements"):
		progress["collected_elements"] = []

	# ========================================================
	# LOAD ELEMENTS INTO RUNTIME
	# ========================================================

	collected_elements.clear()

	var saved_elements: Variant = progress.get(
		"collected_elements",
		[]
	)

	if saved_elements is Array:
		for symbol in saved_elements:

			var element_symbol := str(symbol).strip_edges()

			if element_symbol.is_empty():
				continue

			if not collected_elements.has(element_symbol):
				collected_elements.append(element_symbol)

	# ========================================================
	# SYNCHRONIZE COUNT
	# ========================================================

	progress["elements_collected"] = collected_elements.size()

	student_data["progress"] = progress

	# ========================================================
	# MARK SAVED PROGRESS AS LOADED
	# ========================================================

	progress_is_loaded = true

	print("[StudentDataManager] SAVED PROGRESS LOADED.")
	print(
		"[StudentDataManager] Elements loaded: ",
		collected_elements.size(),
		"/",
		TOTAL_ELEMENTS
	)

	progress_loaded.emit(progress)

	return true


# ============================================================
# CHECK WHETHER SAVED PROGRESS HAS BEEN LOADED
# ============================================================

func is_progress_loaded() -> bool:

	return progress_is_loaded


# ============================================================
# GET CURRENT PROGRESS
# ============================================================

func get_elements_collected() -> int:

	return collected_elements.size()


func get_elements_total() -> int:

	return TOTAL_ELEMENTS


func get_collected_elements() -> Array[String]:

	return collected_elements.duplicate()


# ============================================================
# CHECK IF ELEMENT IS COLLECTED
# ============================================================

func has_collected_element(symbol: String) -> bool:

	# IMPORTANT:
	# If LOAD has not been pressed, nothing from Firebase
	# should be treated as collected.

	if not progress_is_loaded:
		return false

	var clean_symbol := symbol.strip_edges()

	if clean_symbol.is_empty():
		return false

	return collected_elements.has(
		clean_symbol
	)


# ============================================================
# COLLECT ONE ELEMENT
# ============================================================
# IMPORTANT:
# This function still exists for systems that legitimately
# want to save student progress.
#
# CraftingUI should NOT call this anymore.
# ============================================================

func collect_element(symbol: String) -> void:

	var clean_symbol := (
		symbol.strip_edges()
	)

	if clean_symbol.is_empty():

		print(
			"[StudentDataManager] Cannot collect empty element symbol."
		)

		return

	# Already collected.
	if collected_elements.has(clean_symbol):

		print(
			"[StudentDataManager] Element already collected: ",
			clean_symbol
		)

		return

	# Maximum reached.
	if collected_elements.size() >= TOTAL_ELEMENTS:

		print(
			"[StudentDataManager] All elements already collected."
		)

		return

	collected_elements.append(
		clean_symbol
	)

	# Once a progress-changing action happens, the runtime
	# now has active progress.
	progress_is_loaded = true

	print(
		"[StudentDataManager] Element collected: ",
		clean_symbol
	)

	print(
		"[StudentDataManager] Collected elements: ",
		collected_elements
	)

	await save_progress()


# ============================================================
# SAVE PROGRESS
# ============================================================

func save_progress() -> void:

	var uid: String = get_student_uid()

	if uid.is_empty():
		student_error.emit({
			"message": "No authenticated student account."
		})
		return

	var progress: Dictionary = {
		"elements_total": TOTAL_ELEMENTS,
		"elements_collected": collected_elements.size(),
		"collected_elements": collected_elements.duplicate()
	}

	print("[StudentDataManager] Saving progress for: ", uid)
	print(
		"[StudentDataManager] Elements: ",
		collected_elements.size(),
		"/",
		TOTAL_ELEMENTS
	)

	# ========================================================
	# OFFLINE: SAVE PROGRESS LOCALLY
	# ========================================================

	if is_offline_student():

		var local_success: bool = (
			OfflineSaveManager.update_local_progress(
				uid,
				progress
			)
		)

		if not local_success:
			student_error.emit({
				"message": "Unable to save offline student progress."
			})
			return

		student_data["progress"] = progress
		progress_is_loaded = true

		print("[StudentDataManager] Offline progress saved.")

		progress_updated.emit(progress)
		return

	# ========================================================
	# ONLINE: SAVE PROGRESS TO FIRESTORE
	# ========================================================

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = (
		await students.get_doc(uid)
	)

	if document == null:
		student_error.emit({
			"message": "Student document does not exist."
		})
		return

	document.add_or_update_field(
		"progress",
		progress
	)

	var result: FirestoreDocument = (
		await students.update(document)
	)

	if result == null:
		student_error.emit({
			"message": "Unable to save student progress."
		})
		return

	# ========================================================
	# UPDATE LOCAL RUNTIME DATA
	# ========================================================

	student_data["progress"] = progress
	progress_is_loaded = true

	print("[StudentDataManager] Online progress saved.")

	progress_updated.emit(progress)



# ============================================================
# SET PROGRESS COUNT
# ============================================================

func set_progress(elements_collected: int) -> void:

	elements_collected = clamp(
		elements_collected,
		0,
		TOTAL_ELEMENTS
	)

	# Keep this function for compatibility.
	# The actual element list remains the source of truth.
	await save_progress()


# ============================================================
# REMOVE ONE ELEMENT
# ============================================================

func remove_element(symbol: String) -> void:

	var clean_symbol := (
		symbol.strip_edges()
	)

	if clean_symbol.is_empty():
		return

	if not collected_elements.has(clean_symbol):

		print(
			"[StudentDataManager] Element not collected: ",
			clean_symbol
		)

		return

	collected_elements.erase(
		clean_symbol
	)

	print(
		"[StudentDataManager] Removed element: ",
		clean_symbol
	)

	print(
		"[StudentDataManager] Collected elements: ",
		collected_elements
	)

	await save_progress()


# ============================================================
# REMOVE ALL ELEMENTS
# ============================================================

func clear_collected_elements() -> void:

	collected_elements.clear()

	print(
		"[StudentDataManager] All collected elements cleared."
	)

	await save_progress()


func update_last_active() -> void:
	var uid := get_student_uid()

	if uid.is_empty():
		return

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		print("[StudentDataManager] Cannot update last active. Student not found.")
		return

	var timestamp := int(
		Time.get_unix_time_from_system()
	)

	document.add_or_update_field(
		"last_active",
		timestamp
	)

	var result: FirestoreDocument = await students.update(document)

	if result == null:
		print("[StudentDataManager] Failed to update last active.")
		return

	student_data["last_active"] = timestamp

	print(
		"[StudentDataManager] Last active updated: ",
		timestamp
	)

# ============================================================
# SAVE PLAYER PROFILE
# ============================================================
# Saves the player's in-game display name and selected
# character to the student's Firestore document.
#
# IMPORTANT:
# This does NOT modify:
# - progress
# - game_state
# - assessment
# - lesson_progress
# - student name
# - email
#
# It only updates:
# - display_name
# - character_id
# ============================================================

func save_player_profile(
	new_display_name: String,
	new_character_id: String
) -> bool:

	var uid := get_student_uid()

	if uid.is_empty():
		student_error.emit({
			"message": "No student account is available."
		})
		return false

	var clean_display_name := new_display_name.strip_edges()
	var clean_character_id := new_character_id.strip_edges()

	if clean_display_name.is_empty():
		student_error.emit({
			"message": "Display name cannot be empty."
		})
		return false

	if clean_character_id.is_empty():
		student_error.emit({
			"message": "Character ID cannot be empty."
		})
		return false

	# ========================================================
	# SAVE PROFILE LOCALLY FIRST
	# ========================================================

	student_data["display_name"] = clean_display_name
	student_data["character_id"] = clean_character_id

	var profile_record := {
		"uid": uid,
		"display_name": clean_display_name,
		"character_id": clean_character_id,
		"updated_at": Time.get_unix_time_from_system(),
		"pending_sync": true
	}

	var directory_path := "user://offline_accounts"
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory_path)
	)

	if directory_error != OK:
		student_error.emit({
			"message": "Unable to save player profile locally."
		})
		return false

	var safe_uid := uid.validate_filename()

	if safe_uid.is_empty():
		return false

	var profile_path := directory_path + "/" + safe_uid + "_profile.json"

	var file := FileAccess.open(profile_path, FileAccess.WRITE)

	if file == null:
		student_error.emit({
			"message": "Unable to save player profile locally."
		})
		return false

	file.store_string(JSON.stringify(profile_record, "\t"))

	var file_error := file.get_error()
	file.close()

	if file_error != OK:
		student_error.emit({
			"message": "Unable to finish saving player profile."
		})
		return false

	# ========================================================
	# OFFLINE: KEEP PROFILE PENDING FOR LATER SYNC
	# ========================================================

	if is_offline_student():
		print("[StudentDataManager] Player profile saved locally.")
		return true

	# ========================================================
	# ONLINE: UPDATE FIRESTORE
	# ========================================================

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		print("[StudentDataManager] Student document unavailable. Profile remains pending sync.")
		return true

	document.add_or_update_field(
		"display_name",
		clean_display_name
	)

	document.add_or_update_field(
		"character_id",
		clean_character_id
	)

	var result: FirestoreDocument = await students.update(document)

	if result == null:
		print("[StudentDataManager] Cloud profile update failed. Profile remains pending sync.")
		return true

	# Mark the local profile as synchronized.
	profile_record["pending_sync"] = false

	var update_file := FileAccess.open(profile_path, FileAccess.WRITE)

	if update_file != null:
		update_file.store_string(JSON.stringify(profile_record, "\t"))
		update_file.close()

	print("[StudentDataManager] Player profile saved locally and to Firestore.")

	return true



func sync_pending_player_profile() -> bool:

	var uid := get_student_uid()

	if uid.is_empty() or is_offline_student():
		return false

	var safe_uid := uid.validate_filename()

	if safe_uid.is_empty():
		return false

	var profile_path := (
		"user://offline_accounts/"
		+ safe_uid
		+ "_profile.json"
	)

	if not FileAccess.file_exists(profile_path):
		return true

	var file := FileAccess.open(profile_path, FileAccess.READ)

	if file == null:
		return false

	var parsed_data: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed_data is Dictionary:
		return false

	if parsed_data.get("uid", "") != uid:
		push_error("[StudentDataManager] Profile UID mismatch.")
		return false

	if not bool(parsed_data.get("pending_sync", false)):
		return true

	var display_name := str(parsed_data.get("display_name", "")).strip_edges()
	var character_id := str(parsed_data.get("character_id", "")).strip_edges()

	if display_name.is_empty() or character_id.is_empty():
		return false

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		return false

	document.add_or_update_field("display_name", display_name)
	document.add_or_update_field("character_id", character_id)

	var result: FirestoreDocument = await students.update(document)

	if result == null:
		return false

	parsed_data["pending_sync"] = false

	var update_file := FileAccess.open(profile_path, FileAccess.WRITE)

	if update_file == null:
		return false

	update_file.store_string(JSON.stringify(parsed_data, "\t"))

	var write_error := update_file.get_error()
	update_file.close()

	if write_error != OK:
		return false

	student_data["display_name"] = display_name
	student_data["character_id"] = character_id

	print("[StudentDataManager] Pending player profile synchronized.")

	return true


func start_pending_sync() -> void:
	if not FirebaseManager.is_authenticated():
		return

	if is_offline_student():
		return

	if not ConnectionManager.is_connected_to_internet:
		return

	await SyncManager.sync_pending_save()

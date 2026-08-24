extends Node

signal student_loaded(data)
signal student_created(data)
signal student_error(error)
signal progress_updated(progress)
signal progress_loaded(progress)

const TOTAL_ELEMENTS := 118

var student_data: Dictionary = {}

# IMPORTANT:
# This contains ONLY the progress currently loaded into the game.
# It should NOT automatically contain Firebase data just because
# the student logged in.
var collected_elements: Array[String] = []

# True only after the player explicitly presses LOAD.
var progress_is_loaded: bool = false


# ============================================================
# AUTHENTICATION
# ============================================================

func get_student_uid() -> String:
	return FirebaseManager.get_uid()


func is_student_logged_in() -> bool:
	return FirebaseManager.is_authenticated()


# ============================================================
# LOAD STUDENT ACCOUNT
# ============================================================
# IMPORTANT:
# This loads the student's account/profile information.
#
# It DOES NOT load saved game progress into the runtime.
#
# This means:
# LOGIN -> student account loaded
# START -> fresh runtime progress
# LOAD -> saved progress explicitly loaded
# ============================================================

func load_student() -> void:

	var uid := get_student_uid()

	if uid.is_empty():
		student_error.emit({
			"message": "No authenticated Firebase user."
		})
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

	# ========================================================
	# LOAD STUDENT ACCOUNT DATA
	# ========================================================

	student_data = document.get_unsafe_document()

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
	#
	# This is the important change.
	#
	# The Firebase progress remains inside student_data,
	# but collected_elements stays empty until LOAD is pressed.
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


# ============================================================
# CLEAR RUNTIME PROGRESS
# ============================================================
# Used when starting a NEW game/session.
#
# This does NOT delete anything from Firebase.
# It only clears what the current game session is allowed
# to see/use.
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
# This should ONLY be called when the player presses LOAD.
#
# This retrieves the saved progress from Firebase and places
# it into the runtime collected_elements array.
# ============================================================

func load_saved_progress() -> bool:

	var uid := get_student_uid()

	if uid.is_empty():

		student_error.emit({
			"message": "No authenticated Firebase user."
		})

		return false

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

		return false

	var data: Dictionary = (
		document.get_unsafe_document()
	)

	# ========================================================
	# MAKE SURE PROGRESS EXISTS
	# ========================================================

	var progress: Dictionary = data.get(
		"progress",
		{}
	)

	if not progress is Dictionary:
		progress = {}

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

	var saved_elements = (
		progress.get(
			"collected_elements",
			[]
		)
	)

	if saved_elements is Array:

		for symbol in saved_elements:

			var element_symbol := (
				str(symbol).strip_edges()
			)

			if element_symbol.is_empty():
				continue

			if not collected_elements.has(element_symbol):

				collected_elements.append(
					element_symbol
				)

	# ========================================================
	# SYNCHRONIZE COUNT
	# ========================================================

	progress["elements_collected"] = (
		collected_elements.size()
	)

	student_data["progress"] = progress

	# ========================================================
	# MARK SAVED PROGRESS AS LOADED
	# ========================================================

	progress_is_loaded = true

	print(
		"[StudentDataManager] SAVED PROGRESS LOADED."
	)

	print(
		"[StudentDataManager] Elements loaded: ",
		collected_elements.size(),
		"/",
		TOTAL_ELEMENTS
	)

	print(
		"[StudentDataManager] Collected elements: ",
		collected_elements
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
			"message": "No authenticated Firebase user."
		})

		return

	var elements_collected := (
		collected_elements.size()
	)

	print(
		"[StudentDataManager] Saving progress for: ",
		uid
	)

	print(
		"[StudentDataManager] Elements: ",
		elements_collected,
		"/",
		TOTAL_ELEMENTS
	)

	print(
		"[StudentDataManager] Collected elements: ",
		collected_elements
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

		student_error.emit({
			"message": "Student document does not exist."
		})

		return

	# ========================================================
	# CREATE PROGRESS DATA
	# ========================================================

	var progress: Dictionary = {

		"elements_total":
			TOTAL_ELEMENTS,

		"elements_collected":
			elements_collected,

		"collected_elements":
			collected_elements.duplicate()
	}

	# ========================================================
	# UPDATE FIRESTORE
	# ========================================================

	document.add_or_update_field(
		"progress",
		progress
	)

	print(
		"[StudentDataManager] Updating Firestore document..."
	)

	print(
		"[StudentDataManager] Progress: ",
		progress
	)

	var result: FirestoreDocument = (
		await students.update(document)
	)

	if result == null:

		print(
			"[StudentDataManager] Failed to save progress."
		)

		student_error.emit({
			"message": "Unable to save student progress."
		})

		return

	# ========================================================
	# UPDATE LOCAL DATA
	# ========================================================

	student_data["progress"] = progress

	progress_is_loaded = true

	print(
		"[StudentDataManager] Progress saved successfully."
	)

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

extends Node

signal student_loaded(data)
signal student_created(data)
signal student_error(error)
signal progress_updated(progress)

const TOTAL_ELEMENTS := 118

var student_data: Dictionary = {}
var collected_elements: Array[String] = []


# ============================================================
# AUTHENTICATION
# ============================================================

func get_student_uid() -> String:
	return FirebaseManager.get_uid()


func is_student_logged_in() -> bool:
	return FirebaseManager.is_authenticated()


# ============================================================
# LOAD STUDENT
# ============================================================

func load_student() -> void:
	var uid := get_student_uid()

	if uid.is_empty():
		student_error.emit({
			"message": "No authenticated Firebase user."
		})
		return

	print("[StudentDataManager] Loading student: ", uid)

	var students = Firebase.Firestore.collection("students")

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		print("[StudentDataManager] Student document not found.")

		student_data = {
			"uid": uid,
			"progress": {
				"elements_total": TOTAL_ELEMENTS,
				"elements_collected": 0,
				"collected_elements": []
			}
		}

		collected_elements.clear()

		student_created.emit(student_data)
		return

	student_data = document.get_unsafe_document()

	# Always make sure UID exists locally.
	student_data["uid"] = uid


	# ========================================================
	# MAKE SURE PROGRESS EXISTS
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


	# ========================================================
	# LOAD COLLECTED ELEMENTS INTO MEMORY
	# ========================================================

	collected_elements.clear()

	var saved_elements = progress["collected_elements"]

	if saved_elements is Array:
		for symbol in saved_elements:
			var element_symbol := str(symbol).strip_edges()

			# Do not load empty symbols.
			if element_symbol.is_empty():
				continue

			# Avoid duplicates.
			if not collected_elements.has(element_symbol):
				collected_elements.append(element_symbol)


	# Keep the count synchronized with the actual array.
	progress["elements_collected"] = collected_elements.size()
	student_data["progress"] = progress


	print("[StudentDataManager] Student loaded.")
	print("[StudentDataManager] UID: ", uid)
	print("[StudentDataManager] Data: ", student_data)
	print("[StudentDataManager] Collected elements: ", collected_elements)

	student_loaded.emit(student_data)


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
	var clean_symbol := symbol.strip_edges()

	if clean_symbol.is_empty():
		return false

	return collected_elements.has(clean_symbol)


# ============================================================
# COLLECT ONE ELEMENT
# ============================================================

func collect_element(symbol: String) -> void:

	var clean_symbol := symbol.strip_edges()

	if clean_symbol.is_empty():
		print("[StudentDataManager] Cannot collect empty element symbol.")
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
		print("[StudentDataManager] All elements already collected.")
		return

	# Add the actual element symbol.
	collected_elements.append(clean_symbol)

	print(
		"[StudentDataManager] Element collected: ",
		clean_symbol
	)

	print(
		"[StudentDataManager] Collected elements: ",
		collected_elements
	)

	# Save count + array.
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

	var elements_collected := collected_elements.size()

	print("[StudentDataManager] Saving progress for: ", uid)
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


	var students: FirestoreCollection = Firebase.Firestore.collection(
		"students"
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		print("[StudentDataManager] Student document does not exist.")

		student_error.emit({
			"message": "Student document does not exist."
		})
		return


	# ========================================================
	# CREATE PROGRESS DATA
	# ========================================================

	var progress: Dictionary = {
		"elements_total": TOTAL_ELEMENTS,
		"elements_collected": elements_collected,
		"collected_elements": collected_elements.duplicate()
	}


	# ========================================================
	# UPDATE FIRESTORE
	# ========================================================

	document.add_or_update_field(
		"progress",
		progress
	)

	print("[StudentDataManager] Updating Firestore document...")
	print("[StudentDataManager] Progress: ", progress)


	var result: FirestoreDocument = await students.update(document)

	if result == null:
		print("[StudentDataManager] Failed to save progress.")

		student_error.emit({
			"message": "Unable to save student progress."
		})
		return


	# ========================================================
	# UPDATE LOCAL DATA
	# ========================================================

	student_data["progress"] = progress

	print("[StudentDataManager] Progress saved successfully.")

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

	# This function should only be used if you specifically
	# want to change the count. Normally use collect_element().
	await save_progress()


# ============================================================
# REMOVE ONE ELEMENT
# ============================================================

func remove_element(symbol: String) -> void:

	var clean_symbol := symbol.strip_edges()

	if clean_symbol.is_empty():
		return

	if not collected_elements.has(clean_symbol):
		print(
			"[StudentDataManager] Element not collected: ",
			clean_symbol
		)
		return

	collected_elements.erase(clean_symbol)

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

	print("[StudentDataManager] All collected elements cleared.")

	await save_progress()

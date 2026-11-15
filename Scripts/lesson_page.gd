
extends Control


# ============================================================
# CONFIGURATION
# ============================================================

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

const LESSON_CARD_SCENE: PackedScene = preload(
	"res://Scenes/UI/Student/lesson_card_student.tscn"
)

var firestore_url: String


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var lesson_list: GridContainer = $MarginContainer/VBoxContainer/QuizScroll/CenterContainer/LessonList

@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

@onready var search_bar: LineEdit = $MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SearchPanel/SearchBar

@onready var filter_button: OptionButton = $MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/FilterPanel/FilterButton


@onready var preview_panel: Panel = $Preview

@onready var preview_title_input: Label = $Preview/VBoxContainer/VBoxContainer/VBoxContainer/TitleInput

@onready var preview_subject_input: Label = $Preview/VBoxContainer/VBoxContainer/VBoxContainer2/SubjectInput

@onready var preview_description_input: Label = $Preview/VBoxContainer/VBoxContainer2/DescriptionInput

@onready var close_preview_button: Button = $Preview/VBoxContainer/ClosePreviewButton

# ============================================================
# LESSON DATA
# ============================================================

var lesson_records: Array[Dictionary] = []

var student_section := ""


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[LessonPage] Learning Materials opened.")

	firestore_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/lessons"
	)

	_setup_filters()

	search_bar.text_changed.connect(
		_on_search_text_changed
	)

	filter_button.item_selected.connect(
		_on_filter_selected
	)

	close_preview_button.pressed.connect(
		_on_close_preview_pressed
	)

	preview_panel.hide()

	load_lessons()


# ============================================================
# FILTER SETUP
# ============================================================

func _setup_filters() -> void:

	filter_button.clear()

	filter_button.add_item("Sort by")
	filter_button.add_item("A-Z")
	filter_button.add_item("Z-A")

	filter_button.select(0)


# ============================================================
# LOAD LESSONS
# ============================================================

func load_lessons() -> void:

	print("[LessonPage] Loading lessons from Firestore...")

	status_label.text = "Loading lessons..."

	lesson_records.clear()

	_clear_lesson_cards()


	# --------------------------------------------------------
	# Get Firebase ID token
	# --------------------------------------------------------

	var id_token := _get_id_token()

	if id_token.is_empty():

		print("[LessonPage] ERROR: Firebase ID token is empty.")

		status_label.text = (
			"Unable to connect to learning materials."
		)

		return


	print("[LessonPage] Firebase ID token obtained.")


	# --------------------------------------------------------
	# Create HTTP request
	# --------------------------------------------------------

	var http := HTTPRequest.new()

	add_child(http)

	http.request_completed.connect(
		_on_lessons_request_completed.bind(http)
	)

	var headers := PackedStringArray([
		"Authorization: Bearer " + id_token
	])

	print("[LessonPage] Request URL: ", firestore_url)
	print("[LessonPage] Sending authenticated GET request...")


	var error := http.request(
		firestore_url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:

		print(
			"[LessonPage] Failed to send request: ",
			error
		)

		status_label.text = (
			"Could not load learning materials."
		)

		http.queue_free()


# ============================================================
# FIRESTORE RESPONSE
# ============================================================

func _on_lessons_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:

	var response_text := body.get_string_from_utf8()

	http.queue_free()

	print(
		"[LessonPage] Firestore response: ",
		response_code
	)


	# --------------------------------------------------------
	# Check response
	# --------------------------------------------------------

	if response_code != 200:

		print("[LessonPage] ERROR LOADING LESSONS")
		print(response_text)

		status_label.text = (
			"Unable to load learning materials."
		)

		return


	# --------------------------------------------------------
	# Parse JSON
	# --------------------------------------------------------

	var json := JSON.new()

	var parse_result := json.parse(response_text)

	if parse_result != OK:

		print(
			"[LessonPage] Failed to parse Firestore response."
		)

		status_label.text = (
			"Invalid response from server."
		)

		return


	var data = json.data

	if not data is Dictionary:

		status_label.text = (
			"No learning materials found."
		)

		return


	var documents: Array = data.get(
		"documents",
		[]
	)


	# --------------------------------------------------------
	# No lessons
	# --------------------------------------------------------

	if documents.is_empty():

		print("[LessonPage] No lessons found.")

		status_label.text = (
			"No learning materials available."
		)

		return


	# --------------------------------------------------------
	# Get student's section
	# --------------------------------------------------------

	student_section = await _get_student_section()

	print(
		"[LessonPage] Student section: ",
		student_section
	)


	if student_section.is_empty():

		print(
			"[LessonPage] ERROR: Student section is empty."
		)

		status_label.text = (
			"Unable to determine your assigned section."
		)

		return


	# --------------------------------------------------------
	# Collect matching lessons
	# --------------------------------------------------------

	for document in documents:

		var fields: Dictionary = document.get(
			"fields",
			{}
		)

		var title := get_firestore_string(
			fields,
			"title",
			"Untitled Lesson"
		)

		var assigned_sections := _get_lesson_assigned_sections(fields)

		print("--------------------------------")
		print("[LessonPage] Found lesson: ", title)
		print("[LessonPage] Assigned sections: ", assigned_sections)
		print("[LessonPage] Student section: ", student_section)

		var is_assigned := false

		for assigned_section in assigned_sections:

			if _section_matches(
				assigned_section,
				student_section
			):
				is_assigned = true
				break

		if not is_assigned:
			print("[LessonPage] Skipping: not assigned to this section.")
			continue

		print("[LessonPage] Lesson accepted.")

		var extracted_lesson := _extract_lesson_data(document)
		lesson_records.append(extracted_lesson)


	# --------------------------------------------------------
	# Display lessons
	# --------------------------------------------------------

	_apply_lesson_filters()

	print(
		"[LessonPage] Matching lessons found: ",
		lesson_records.size()
	)


# ============================================================
# EXTRACT LESSON DATA
# ============================================================

func _extract_lesson_data(
	document: Dictionary
) -> Dictionary:

	var fields: Dictionary = document.get(
		"fields",
		{}
	)

	return {
		"document": document,

		"document_name": str(
			document.get("name", "")
		),

		"title": get_firestore_string(
			fields,
			"title",
			"Untitled Lesson"
		),

		"description": get_firestore_string(
			fields,
			"description",
			"No description available."
		),

		"subject": get_firestore_string(
			fields,
			"subject",
			""
		),

		"section": get_firestore_string(
			fields,
			"section",
			""
		),

		"school_year": get_firestore_string(
			fields,
			"school_year",
			""
		),

		"file_url": get_firestore_string(
			fields,
			"file_url",
		    ""
		),

		"file_extension": get_firestore_string(
			fields,
			"file_extension",
			""
		)
	}


# ============================================================
# APPLY SEARCH AND SORT
# ============================================================

func _apply_lesson_filters() -> void:

	_clear_lesson_cards()

	var search_text := search_bar.text.strip_edges().to_lower()

	var filtered_lessons: Array[Dictionary] = []


	# --------------------------------------------------------
	# Search lessons
	# --------------------------------------------------------

	for lesson in lesson_records:

		var title := str(lesson.get("title", "")).to_lower()
		var description := str(lesson.get("description", "")).to_lower()
		var subject := str(lesson.get("subject", "")).to_lower()
		var file_name := str(lesson.get("file_name", "")).to_lower()

		var matches_search := (
			search_text.is_empty()
			or title.contains(search_text)
			or description.contains(search_text)
			or subject.contains(search_text)
			or file_name.contains(search_text)
		)

		if matches_search:
			filtered_lessons.append(lesson)


	# --------------------------------------------------------
	# Sort lessons
	# --------------------------------------------------------

	match filter_button.selected:

		1:
			filtered_lessons.sort_custom(
				_sort_lessons_ascending
			)

		2:
			filtered_lessons.sort_custom(
				_sort_lessons_descending
			)


	# --------------------------------------------------------
	# Create lesson cards
	# --------------------------------------------------------

	for lesson in filtered_lessons:

		create_lesson_card(lesson)


	# --------------------------------------------------------
	# Update status
	# --------------------------------------------------------

	if lesson_records.is_empty():

		status_label.text = (
			"No learning materials assigned to your section."
		)

	elif filtered_lessons.is_empty():

		status_label.text = (
			"No lessons match your search."
		)

	else:

		status_label.text = (
			str(filtered_lessons.size())
			+ " lesson(s) available."
		)


	print(
		"[LessonPage] Displayed lesson cards: ",
		filtered_lessons.size()
	)


# ============================================================
# SORT FUNCTIONS
# ============================================================

func _sort_lessons_ascending(
	a: Dictionary,
	b: Dictionary
) -> bool:

	return str(a.get("title", "")).to_lower() < str(
		b.get("title", "")
	).to_lower()


func _sort_lessons_descending(
	a: Dictionary,
	b: Dictionary
) -> bool:

	return str(a.get("title", "")).to_lower() > str(
		b.get("title", "")
	).to_lower()


# ============================================================
# SEARCH AND FILTER SIGNALS
# ============================================================

func _on_search_text_changed(_new_text: String) -> void:

	_apply_lesson_filters()


func _on_filter_selected(_index: int) -> void:

	_apply_lesson_filters()


# ============================================================
# CLEAR LESSON CARDS
# ============================================================

func _clear_lesson_cards() -> void:

	for child in lesson_list.get_children():

		child.queue_free()


# ============================================================
# CREATE LESSON CARD
# ============================================================

func create_lesson_card(
	lesson_data: Dictionary
) -> void:

	var card := LESSON_CARD_SCENE.instantiate()

	lesson_list.add_child(card)


	# --------------------------------------------------------
	# Get card nodes
	# --------------------------------------------------------

	var title_label: Label = card.get_node(
	    "VBoxContainer/QuizTitle"
	)

	var status: Label = card.get_node(
	    "VBoxContainer/HBoxContainer/Status"
	)

	var read_button: Button = card.get_node(
	    "VBoxContainer/HBoxContainer2/Button"
	)

	var preview_button: Button = card.get_node(
	    "VBoxContainer/HBoxContainer2/Button2"
	)


	# --------------------------------------------------------
	# Set lesson information
	# --------------------------------------------------------

	title_label.text = str(
		lesson_data.get(
			"title",
			"Untitled Lesson"
		)
	)

	status.text = "Available"

	read_button.text = "Read"


	# --------------------------------------------------------
	# Connect Read button
	# --------------------------------------------------------

	read_button.pressed.connect(
		_on_read_pressed.bind(lesson_data)
	)
	
	preview_button.pressed.connect(
		_on_preview_pressed.bind(lesson_data)
	)


# ============================================================
# READ LESSON
# ============================================================
# ============================================================
# READ LESSON
# ============================================================

func _on_read_pressed(
	lesson_data: Dictionary
) -> void:

	var lesson_title := str(
		lesson_data.get(
			"title",
            "Untitled Lesson"
		)
	)

	var file_url := str(
		lesson_data.get(
			"file_url",
            ""
		)
	).strip_edges()

	print(
		"[LessonPage] Read button pressed: ",
		lesson_title
	)

	print(
		"[LessonPage] File URL: ",
		file_url
	)

	# Check whether a file URL exists.

	if file_url.is_empty():

		status_label.text = (
            "This lesson has no uploaded file."
		)

		print(
            "[LessonPage] ERROR: File URL is empty."
		)

		return

	# Check whether the URL is valid.

	if not file_url.begins_with("https://"):

		status_label.text = (
            "Invalid learning material URL."
		)

		print(
            "[LessonPage] ERROR: Invalid file URL."
		)

		return

	# Open the file using the device's default application.

	var error := OS.shell_open(file_url)

	if error != OK:

		status_label.text = (
            "Unable to open the learning material."
		)

		print(
			"[LessonPage] ERROR opening file: ",
			error
		)

		return

	print(
        "[LessonPage] Learning material opened successfully."
	)


# ============================================================
# PREVIEW LESSON
# ============================================================

func _on_preview_pressed(
	lesson_data: Dictionary
) -> void:

	print(
		"[LessonPage] Preview button pressed: ",
		lesson_data.get("title", "Untitled Lesson")
	)

	# Populate lesson information.

	preview_title_input.text = str(
		lesson_data.get(
			"title",
            "Untitled Lesson"
		)
	)

	preview_subject_input.text = str(
		lesson_data.get(
			"subject",
            "No subject"
		)
	)

	preview_description_input.text = str(
		lesson_data.get(
			"description",
            "No description available."
		)
	)

	# Show preview panel.

	preview_panel.show()


# ============================================================
# CLOSE LESSON PREVIEW
# ============================================================

func _on_close_preview_pressed() -> void:

	preview_panel.hide()

	print("[LessonPage] Lesson preview closed.")

# ============================================================
# GET FIRESTORE STRING
# ============================================================

func get_firestore_string(
	fields: Dictionary,
	field_name: String,
	default_value: String
) -> String:

	if not fields.has(field_name):
		return default_value

	var field_data = fields[field_name]

	if not field_data is Dictionary:
		return default_value

	if field_data.has("stringValue"):

		return str(
			field_data["stringValue"]
		)

	return default_value


# ============================================================
# GET ASSIGNED LESSON SECTIONS
# ============================================================

func _get_lesson_assigned_sections(
	fields: Dictionary
) -> Array[String]:

	var result: Array[String] = []

	var assigned_data: Variant = fields.get(
		"assigned_sections",
		{}
	)

	# --------------------------------------------------------
	# New format: Firestore arrayValue
	# --------------------------------------------------------

	if assigned_data is Dictionary:

		var array_data: Variant = assigned_data.get(
			"arrayValue",
			{}
		)

		if array_data is Dictionary:

			var values: Variant = array_data.get(
				"values",
				[]
			)

			if values is Array:

				for value in values:

					var section_name := ""

					if value is Dictionary:

						section_name = str(
							value.get("stringValue", "")
						).strip_edges()

					elif value is String:

						section_name = value.strip_edges()

					if (
						not section_name.is_empty()
						and not result.has(section_name)
					):
						result.append(section_name)

	# --------------------------------------------------------
	# Legacy format: direct array
	# --------------------------------------------------------

	elif assigned_data is Array:

		for value in assigned_data:

			var section_name := str(value).strip_edges()

			if (
				not section_name.is_empty()
				and not result.has(section_name)
			):
				result.append(section_name)

	# --------------------------------------------------------
	# Backward compatibility: old section field
	# --------------------------------------------------------

	if result.is_empty():

		var old_section := get_firestore_string(
			fields,
			"section",
			""
		).strip_edges()

		if not old_section.is_empty():
			result.append(old_section)

	return result


# ============================================================
# GET FIREBASE ID TOKEN
# ============================================================

func _get_id_token() -> String:

	if not Firebase.Auth:

		print(
			"[LessonPage] Firebase.Auth is unavailable."
		)

		return ""


	var auth_data = Firebase.Auth.auth

	if auth_data is Dictionary:

		if auth_data.has("idtoken"):

			var token := str(
				auth_data["idtoken"]
			)

			if not token.is_empty():
				return token


		if auth_data.has("idToken"):

			var token := str(
				auth_data["idToken"]
			)

			if not token.is_empty():
				return token


	print(
		"[LessonPage] Could not find Firebase ID token."
	)

	return ""


# ============================================================
# GET STUDENT SECTION
# ============================================================

func _get_student_section() -> String:

	var uid := ""


	# --------------------------------------------------------
	# Get student UID
	# --------------------------------------------------------

	if AuthManager:

		uid = AuthManager.get_uid()


	if uid.is_empty():

		print(
			"[LessonPage] Could not determine student UID."
		)

		return ""


	print(
		"[LessonPage] Loading student record: ",
		uid
	)


	# --------------------------------------------------------
	# Get ID token
	# --------------------------------------------------------

	var id_token := _get_id_token()

	if id_token.is_empty():
		return ""


	# --------------------------------------------------------
	# Student document URL
	# --------------------------------------------------------

	var student_url := (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/students/"
		+ uid
	)


	# --------------------------------------------------------
	# HTTP request
	# --------------------------------------------------------

	var http := HTTPRequest.new()

	add_child(http)


	var headers := PackedStringArray([
		"Authorization: Bearer " + id_token
	])


	var error := http.request(
		student_url,
		headers,
		HTTPClient.METHOD_GET
	)


	if error != OK:

		http.queue_free()

		print(
			"[LessonPage] Failed to request student record."
		)

		return ""


	var result_data = await http.request_completed

	http.queue_free()


	# --------------------------------------------------------
	# Check response
	# --------------------------------------------------------

	var response_code: int = result_data[1]

	var body: PackedByteArray = result_data[3]


	if response_code != 200:

		print(
			"[LessonPage] Student request failed: ",
			response_code
		)

		return ""


	# --------------------------------------------------------
	# Parse response
	# --------------------------------------------------------

	var response_text := body.get_string_from_utf8()

	var json := JSON.new()

	if json.parse(response_text) != OK:

		print(
			"[LessonPage] Failed to parse student record."
		)

		return ""


	var data = json.data

	if not data is Dictionary:
		return ""


	var fields: Dictionary = data.get(
		"fields",
		{}
	)
	
	print(
		"[LessonPage] Student teacher ID: ",
		get_firestore_string(fields, "teacher_id", "")
	)

	print(
		"[LessonPage] Student school year: ",
		get_firestore_string(fields, "school_year", "")
	)


	# --------------------------------------------------------
	# Get section
	# --------------------------------------------------------

	var section := get_firestore_string(
		fields,
		"section",
		""
	)

	return section


# ============================================================
# SECTION MATCHING
# ============================================================

func _section_matches(
	lesson_section: String,
	target_section: String
) -> bool:

	if lesson_section.is_empty():
		return false

	if student_section.is_empty():
		return false


	var lesson_normalized := (
		lesson_section.strip_edges().to_upper()
	)

	var student_normalized := (
		student_section.strip_edges().to_upper()
	)


	# Exact match.

	if lesson_normalized == student_normalized:
		return true


	# Example:
	# Lesson = 11-A
	# Student = A

	if lesson_normalized.ends_with(
		"-" + student_normalized
	):

		return true


	# Example:
	# Lesson = A
	# Student = 11-A

	if student_normalized.ends_with(
		"-" + lesson_normalized
	):

		return true


	return false

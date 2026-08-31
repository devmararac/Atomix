extends Control

signal lesson_created


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var title_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/TitleInput
@onready var description_input: TextEdit = $FormPanel/MarginContainer/VBoxContainer/DescriptionInput
@onready var subject_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/SubjectInput
@onready var section_input: OptionButton = $FormPanel/MarginContainer/VBoxContainer/SectionInput
@onready var school_year_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/SchoolYearInput

@onready var file_dialog: FileDialog = $FileDialog
@onready var file_name_label: Label = $FormPanel/MarginContainer/VBoxContainer/FileNameLabel

@onready var create_button: Button = $FormPanel/MarginContainer/VBoxContainer/ButtonContainer/CreateButton
@onready var cancel_button: Button = $FormPanel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton

@onready var status_label: Label = $FormPanel/MarginContainer/VBoxContainer/StatusLabel


# ============================================================
# FIRESTORE
# ============================================================

var firestore_request: HTTPRequest


# ============================================================
# SELECTED FILE
# ============================================================

var selected_file_path: String = ""


# ============================================================
# TEACHER DATA
# ============================================================

var assigned_sections: Array = []


# ============================================================
# SUPPORTED LESSON FILE TYPES
# ============================================================

const SUPPORTED_FILE_TYPES := [
	"*.pdf",
	"*.doc",
	"*.docx",
	"*.ppt",
	"*.pptx",
	"*.xls",
	"*.xlsx",
	"*.csv",
	"*.txt",
	"*.png",
	"*.jpg",
	"*.jpeg",
	"*.webp"
]


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[AddLesson] Add Lesson form opened.")

	# --------------------------------------------------------
	# Create HTTPRequest for Firestore
	# --------------------------------------------------------

	firestore_request = HTTPRequest.new()
	add_child(firestore_request)

	firestore_request.request_completed.connect(
		_on_firestore_request_completed
	)

	# --------------------------------------------------------
	# Load teacher assigned sections
	# --------------------------------------------------------

	await _load_teacher_sections()

	# --------------------------------------------------------
	# Configure file picker
	# --------------------------------------------------------

	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Select Lesson Material"

	file_dialog.clear_filters()

	file_dialog.add_filter(
		"*.pdf, *.doc, *.docx, *.ppt, *.pptx, *.xls, *.xlsx, *.csv, *.txt, *.png, *.jpg, *.jpeg, *.webp",
		"Lesson Materials"
	)

	file_dialog.add_filter(
		"*.pdf",
		"PDF Documents"
	)

	file_dialog.add_filter(
		"*.doc, *.docx",
		"Word Documents"
	)

	file_dialog.add_filter(
		"*.ppt, *.pptx",
		"PowerPoint Presentations"
	)

	file_dialog.add_filter(
		"*.xls, *.xlsx, *.csv",
		"Spreadsheet Files"
	)

	file_dialog.add_filter(
		"*.txt",
		"Text Files"
	)

	file_dialog.add_filter(
		"*.png, *.jpg, *.jpeg, *.webp",
		"Image Files"
	)

	# --------------------------------------------------------
	# Connect file-selected signal
	# --------------------------------------------------------

	if not file_dialog.file_selected.is_connected(
		_on_file_selected
	):

		file_dialog.file_selected.connect(
			_on_file_selected
		)

	# --------------------------------------------------------
	# Initial UI state
	# --------------------------------------------------------

	if file_name_label:
		file_name_label.text = "No file selected."

	if status_label:
		status_label.text = ""

	print("[AddLesson] File picker configured.")


# ============================================================
# LOAD TEACHER ASSIGNED SECTIONS
# ============================================================

func _load_teacher_sections() -> void:

	var role = await AuthManager.get_user_role()

	print("[AddLesson] Current user role: ", role)

	if role != "teacher":

		print(
			"[AddLesson] Current user is not a teacher."
		)

		_configure_default_sections()

		return


	print(
		"[AddLesson] Teacher detected. Loading assigned sections."
	)

	var uid := AuthManager.get_uid()

	if uid.is_empty():

		print(
			"[AddLesson] ERROR: Teacher UID is empty."
		)

		_configure_default_sections()

		return


	print(
		"[AddLesson] Getting assigned sections for teacher: ",
		uid
	)

	assigned_sections = await TeacherDataManager.get_current_teacher_sections()

	print(
		"[AddLesson] Teacher assigned sections: ",
		assigned_sections
	)


	# --------------------------------------------------------
	# Configure dropdown
	# --------------------------------------------------------

	section_input.clear()

	section_input.add_item("Select Section")


	if assigned_sections.is_empty():

		print(
			"[AddLesson] No assigned sections found."
		)

	else:

		for section in assigned_sections:

			var section_name := str(section).strip_edges()

			if section_name.is_empty():
				continue

			# ------------------------------------------------
			# Convert A -> 11-A
			# Convert B -> 11-B
			# Convert C -> 11-C
			# ------------------------------------------------

			var display_section := section_name

			if not section_name.begins_with("11-"):

				display_section = "11-" + section_name


			section_input.add_item(
				display_section
			)

	section_input.select(0)


# ============================================================
# DEFAULT SECTIONS
# ============================================================

func _configure_default_sections() -> void:

	section_input.clear()

	section_input.add_item("Select Section")
	section_input.add_item("11-A")
	section_input.add_item("11-B")
	section_input.add_item("11-C")

	section_input.select(0)


# ============================================================
# CHOOSE FILE BUTTON
# ============================================================

func _on_choose_file_button_pressed() -> void:

	print("[AddLesson] Choose File button pressed.")

	status_label.text = ""

	file_dialog.popup_centered_ratio(0.7)


# ============================================================
# FILE SELECTED
# ============================================================

func _on_file_selected(path: String) -> void:

	print(
		"[AddLesson] Selected file: ",
		path
	)

	selected_file_path = path

	var file_name: String = path.get_file()

	file_name_label.text = file_name

	status_label.text = (
		"File selected: "
		+ file_name
	)

	print(
		"[AddLesson] File name: ",
		file_name
	)

	print(
		"[AddLesson] File extension: ",
		path.get_extension()
	)


# ============================================================
# CHECK FILE TYPE
# ============================================================

func is_supported_file(path: String) -> bool:

	var extension := path.get_extension().to_lower()

	var supported_extensions := [
		"pdf",
		"doc",
		"docx",
		"ppt",
		"pptx",
		"xls",
		"xlsx",
		"csv",
		"txt",
		"png",
		"jpg",
		"jpeg",
		"webp"
	]

	return extension in supported_extensions


# ============================================================
# CREATE LESSON
# ============================================================

func _on_create_button_pressed() -> void:

	# --------------------------------------------------------
	# Prevent duplicate clicks
	# --------------------------------------------------------

	create_button.disabled = true

	status_label.text = "Saving lesson..."


	# ========================================================
	# GET FORM DATA
	# ========================================================

	var lesson_title: String = (
		title_input.text.strip_edges()
	)

	var description: String = (
		description_input.text.strip_edges()
	)

	var subject: String = (
		subject_input.text.strip_edges()
	)

	var section: String = ""

	if section_input.selected > 0:

		section = section_input.get_item_text(
			section_input.selected
		).strip_edges()


	var school_year: String = (
		school_year_input.text.strip_edges()
	)


	# ========================================================
	# VALIDATION
	# ========================================================

	if lesson_title.is_empty():

		status_label.text = (
			"Please enter a lesson title."
		)

		create_button.disabled = false

		return


	if subject.is_empty():

		status_label.text = (
			"Please enter the subject."
		)

		create_button.disabled = false

		return


	if section.is_empty():

		status_label.text = (
			"Please select a section."
		)

		create_button.disabled = false

		return


	if school_year.is_empty():

		status_label.text = (
			"Please enter the school year."
		)

		create_button.disabled = false

		return


	if selected_file_path.is_empty():

		status_label.text = (
			"Please select a lesson file."
		)

		create_button.disabled = false

		return


	# ========================================================
	# FILE VALIDATION
	# ========================================================

	if not FileAccess.file_exists(
		selected_file_path
	):

		status_label.text = (
			"The selected file could not be found."
		)

		print(
			"[AddLesson] File does not exist: ",
			selected_file_path
		)

		create_button.disabled = false

		return


	if not is_supported_file(
		selected_file_path
	):

		status_label.text = (
			"This file type is not supported."
		)

		print(
			"[AddLesson] Unsupported file type: ",
			selected_file_path.get_extension()
		)

		create_button.disabled = false

		return


	# ========================================================
	# FILE INFORMATION
	# ========================================================

	var file_name := selected_file_path.get_file()

	var file_extension := (
		selected_file_path
		.get_extension()
		.to_lower()
	)

	var file_size := (
		FileAccess
		.get_file_as_bytes(selected_file_path)
		.size()
	)


	# ========================================================
	# GET TEACHER UID
	# ========================================================

	var teacher_id := AuthManager.get_uid()

	if teacher_id.is_empty():

		status_label.text = (
			"Unable to identify the teacher account."
		)

		print(
			"[AddLesson] ERROR: Teacher UID is empty."
		)

		create_button.disabled = false

		return


	# ========================================================
	# FIRESTORE LESSON DATA
	# ========================================================

	var lesson_fields := {

		"title": {
			"stringValue": lesson_title
		},

		"description": {
			"stringValue": description
		},

		"subject": {
			"stringValue": subject
		},

		"section": {
			"stringValue": section
		},

		"school_year": {
			"stringValue": school_year
		},

		"teacher_id": {
			"stringValue": teacher_id
		},

		"file_name": {
			"stringValue": file_name
		},

		"file_extension": {
			"stringValue": file_extension
		},

		"file_size": {
			"integerValue": file_size
		},

		"file_path": {
			"stringValue": selected_file_path
		},

		"created_at": {
			"timestampValue":
				Time.get_datetime_string_from_system(true)
				+ "Z"
		}
	}


	# ========================================================
	# COMPLETE FIRESTORE DOCUMENT
	# ========================================================

	var firestore_data := {
		"fields": lesson_fields
	}


	# ========================================================
	# PRINT DATA FOR DEBUGGING
	# ========================================================

	print(
		"[AddLesson] ================================="
	)

	print(
		"[AddLesson] Saving lesson..."
	)

	print(
		"[AddLesson] Lesson Title: ",
		lesson_title
	)

	print(
		"[AddLesson] Description: ",
		description
	)

	print(
		"[AddLesson] Subject: ",
		subject
	)

	print(
		"[AddLesson] Section: ",
		section
	)

	print(
		"[AddLesson] School Year: ",
		school_year
	)

	print(
		"[AddLesson] Teacher ID: ",
		teacher_id
	)

	print(
		"[AddLesson] File Name: ",
		file_name
	)

	print(
		"[AddLesson] File Extension: ",
		file_extension
	)

	print(
		"[AddLesson] File Size: ",
		file_size,
		" bytes"
	)

	print(
		"[AddLesson] File Path: ",
		selected_file_path
	)

	print(
		"[AddLesson] ================================="
	)


	# ========================================================
	# SAVE TO FIRESTORE
	# ========================================================

	_save_lesson_to_firestore(
		firestore_data
	)


# ============================================================
# SAVE LESSON TO FIRESTORE
# ============================================================

func _save_lesson_to_firestore(
	firestore_data: Dictionary
) -> void:

	if firestore_request == null:

		print(
			"[AddLesson] ERROR: Firestore HTTPRequest is null."
		)

		status_label.text = (
			"Database connection is not available."
		)

		create_button.disabled = false

		return


	# --------------------------------------------------------
	# Get Firebase authentication token
	# --------------------------------------------------------

	var auth_data = Firebase.Firestore.auth

	if auth_data == null:

		print(
			"[AddLesson] ERROR: Firebase authentication data is null."
		)

		status_label.text = (
			"Firebase authentication is not available."
		)

		create_button.disabled = false

		return


	var id_token: String = str(
		auth_data.get("idtoken", "")
	)


	if id_token.is_empty():

		print(
			"[AddLesson] ERROR: Firebase ID token is empty."
		)

		status_label.text = (
			"Firebase authentication token is missing."
		)

		create_button.disabled = false

		return


	# --------------------------------------------------------
	# Get Firebase project ID
	# --------------------------------------------------------

	var project_id: String = str(
		Firebase.Firestore._config.get(
			"projectId",
			""
		)
	)


	if project_id.is_empty():

		print(
			"[AddLesson] ERROR: Firebase project ID is empty."
		)

		status_label.text = (
			"Firebase project configuration is missing."
		)

		create_button.disabled = false

		return


	# --------------------------------------------------------
	# Firestore REST URL
	# --------------------------------------------------------

	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+ project_id
		+ "/databases/(default)/documents/lessons"
	)


	# --------------------------------------------------------
	# HTTP headers
	# --------------------------------------------------------

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]


	# --------------------------------------------------------
	# Convert dictionary to JSON
	# --------------------------------------------------------

	var json_body := JSON.stringify(
		firestore_data
	)


	print(
		"[AddLesson] Sending lesson to Firestore..."
	)

	print(
		"[AddLesson] URL: ",
		url
	)


	# --------------------------------------------------------
	# POST document
	# --------------------------------------------------------

	var error := firestore_request.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)


	if error != OK:

		print(
			"[AddLesson] Firestore request failed to start. Error: ",
			error
		)

		status_label.text = (
			"Failed to connect to the database."
		)

		create_button.disabled = false

		return


# ============================================================
# FIRESTORE RESPONSE
# ============================================================

func _on_firestore_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	print(
		"[AddLesson] Firestore response: ",
		response_code
	)


	var response_text := body.get_string_from_utf8()

	print(
		"[AddLesson] Firestore response body: ",
		response_text
	)


	# ========================================================
	# SUCCESS
	# ========================================================

	if response_code == 200:

		print(
			"[AddLesson] ================================="
		)

		print(
			"[AddLesson] LESSON SAVED SUCCESSFULLY!"
		)

		print(
			"[AddLesson] ================================="
		)

		status_label.text = (
			"Lesson created successfully!"
		)

		create_button.disabled = false

		lesson_created.emit()

		return


	# ========================================================
	# ERROR
	# ========================================================

	print(
		"[AddLesson] ================================="
	)

	print(
		"[AddLesson] ERROR SAVING LESSON"
	)

	print(
		"[AddLesson] HTTP Result: ",
		result
	)

	print(
		"[AddLesson] HTTP Code: ",
		response_code
	)

	print(
		"[AddLesson] Response: ",
		response_text
	)

	print(
		"[AddLesson] ================================="
	)


	status_label.text = (
		"Failed to save lesson. Please try again."
	)

	create_button.disabled = false


# ============================================================
# RESET FORM
# ============================================================

func reset_form() -> void:

	selected_file_path = ""

	title_input.clear()

	description_input.clear()

	subject_input.clear()

	section_input.select(0)

	school_year_input.clear()

	file_name_label.text = (
		"No file selected."
	)

	status_label.text = ""

	create_button.disabled = false


# ============================================================
# CANCEL
# ============================================================

func _on_cancel_button_pressed() -> void:

	print("[AddLesson] Cancelled.")

	reset_form()

	queue_free()

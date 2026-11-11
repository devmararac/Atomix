
extends Control

signal lesson_created

enum FormMode {
	ADD,
	EDIT,
	VIEW
}

# ------------------------------------------------------------
# NODE REFERENCES — MATCHES add_lesson.tscn
# ------------------------------------------------------------

@onready var page_title: Label = $Title
@onready var page_subtitle: Label = $Title/Subtitle

@onready var title_input: LineEdit = $FormPanel/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/VBoxContainer/TitleInput
@onready var subject_input: LineEdit = $FormPanel/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/VBoxContainer2/SubjectInput
@onready var description_input: TextEdit = $FormPanel/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer2/DescriptionInput

@onready var file_dialog: FileDialog = $FileDialog
@onready var file_name_label: Label = $FormPanel/VBoxContainer/HBoxContainer/VBoxContainer4/FileNameLabel
@onready var status_label: Label = $FormPanel/VBoxContainer/HBoxContainer/VBoxContainer/StatusLabel

@onready var create_button: Button = $FormPanel/VBoxContainer/ButtonContainer/CreateButton
@onready var cancel_button: Button = $FormPanel/VBoxContainer/ButtonContainer/CancelButton
@onready var choose_file_button: Button = $FormPanel/VBoxContainer/HBoxContainer/VBoxContainer4/Panel/ChooseFileButton

# ------------------------------------------------------------
# FIRESTORE AND FORM STATE
# ------------------------------------------------------------

const SUPPORTED_EXTENSIONS := [
	"pdf", "doc", "docx",
	"ppt", "pptx", "xls", "xlsx", "csv",
	"txt", "png", "jpg", "jpeg", "webp"
]

var firestore_request: HTTPRequest

var form_mode: FormMode = FormMode.ADD
var lesson_data: Dictionary = {}
var lesson_document_name: String = ""

var selected_file_path: String = ""
var existing_file_name: String = ""
var existing_file_extension: String = ""
var existing_file_size: String = ""

var is_saving: bool = false
var cloudinary_uploader: Node

# ------------------------------------------------------------
# INITIALIZATION
# ------------------------------------------------------------

func _ready() -> void:
	firestore_request = HTTPRequest.new()
	add_child(firestore_request)

	firestore_request.request_completed.connect(
		_on_firestore_request_completed
	)

	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Select Lesson Material"
	file_dialog.clear_filters()

	file_dialog.add_filter(
		"*.pdf,*.doc,*.docx,*.ppt,*.pptx,*.xls,*.xlsx,*.csv,*.txt,*.png,*.jpg,*.jpeg,*.webp",
		"Supported Lesson Materials"
	)

	if not file_dialog.file_selected.is_connected(_on_file_selected):
		file_dialog.file_selected.connect(_on_file_selected)

	file_name_label.text = "No file selected"
	status_label.text = ""

	cloudinary_uploader = load("res://Scripts/Admin/CloudinaryUploader.gd").new()
	add_child(cloudinary_uploader)
	_apply_form_mode()

# Call this after instantiating the scene and BEFORE adding it
# to the scene tree.
func setup_form(
	mode: FormMode,
	selected_lesson: Dictionary = {}
) -> void:
	form_mode = mode
	lesson_data = selected_lesson.duplicate(true)

	if form_mode != FormMode.ADD:
		lesson_document_name = str(lesson_data.get("name", ""))


# ------------------------------------------------------------
# FORM MODE SETUP
# ------------------------------------------------------------

func _apply_form_mode() -> void:
	match form_mode:
		FormMode.ADD:
			page_title.text = "Add Lesson"
			page_subtitle.text = "Create a lesson for your students."
			create_button.text = "Create Lesson"
			choose_file_button.disabled = false

			title_input.editable = true
			subject_input.editable = true
			description_input.editable = true
			create_button.visible = true

			_load_lesson_fields() # Empty form when adding.

		FormMode.EDIT:
			page_title.text = "Edit Lesson"
			page_subtitle.text = "Update this lesson's information."
			create_button.text = "Save Changes"
			choose_file_button.disabled = false

			title_input.editable = true
			subject_input.editable = true
			description_input.editable = true
			create_button.visible = true

			_load_lesson_fields()

		FormMode.VIEW:
			page_title.text = "View Lesson"
			page_subtitle.text = "View the details of this lesson."
			create_button.visible = false
			choose_file_button.disabled = true

			title_input.editable = false
			subject_input.editable = false
			description_input.editable = false

			_load_lesson_fields()


# ------------------------------------------------------------
# LOAD LESSON DATA INTO FORM
# ------------------------------------------------------------

func _load_lesson_fields() -> void:
	if form_mode == FormMode.ADD:
		title_input.clear()
		subject_input.clear()
		description_input.clear()

		selected_file_path = ""
		existing_file_name = ""
		existing_file_extension = ""
		existing_file_size = ""

		file_name_label.text = "No file selected"
		return

	var fields: Dictionary = lesson_data.get("fields", {})

	title_input.text = _get_string_field(
		fields, "title", "Untitled Lesson"
	)

	subject_input.text = _get_string_field(
		fields, "subject", ""
	)

	description_input.text = _get_string_field(
		fields, "description", ""
	)

	existing_file_name = _get_string_field(
		fields, "file_name", "No file attached"
	)

	existing_file_extension = _get_string_field(
		fields, "file_extension", ""
	)

	existing_file_size = _get_string_field(
		fields, "file_size", "Unknown"
	)

	# The stored path may belong to another computer.
	# Do not assume the original file is accessible locally.
	selected_file_path = ""

	file_name_label.text = existing_file_name

	if form_mode == FormMode.EDIT:
		status_label.text = "Choose a new file only if you want to replace the existing one."
	else:
		status_label.text = ""


func _get_string_field(
	fields: Dictionary,
	field_name: String,
	default_value: String = ""
) -> String:
	var value: Variant = fields.get(field_name, {})

	if value is Dictionary:
		if value.has("stringValue"):
			return str(value["stringValue"])
		if value.has("integerValue"):
			return str(value["integerValue"])
		if value.has("value"):
			return str(value["value"])
	elif value is String or value is int or value is float:
		return str(value)

	return default_value


# ------------------------------------------------------------
# CHOOSE FILE
# ------------------------------------------------------------

func _on_choose_file_button_pressed() -> void:
	if form_mode == FormMode.VIEW or is_saving:
		return

	status_label.text = ""
	file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	if form_mode == FormMode.VIEW:
		return

	selected_file_path = path
	file_name_label.text = path.get_file()
	status_label.text = "Selected: " + path.get_file()

	print("[AddLesson] Selected file: ", path)


# ------------------------------------------------------------
# CREATE OR UPDATE LESSON
# ------------------------------------------------------------

func _on_create_button_pressed() -> void:
	if is_saving or form_mode == FormMode.VIEW:
		return

	var lesson_title: String = title_input.text.strip_edges()
	var subject: String = subject_input.text.strip_edges()
	var description: String = description_input.text.strip_edges()

	if lesson_title.is_empty():
		_show_error("Please enter a lesson title.")
		return

	if subject.is_empty():
		_show_error("Please enter the subject.")
		return

	if description.is_empty():
		_show_error("Please enter a description.")
		return

	# Validate a newly selected file, if any.
	if not selected_file_path.is_empty():
		if not FileAccess.file_exists(selected_file_path):
			_show_error("The selected file could not be found.")
			return

		var extension := selected_file_path.get_extension().to_lower()

		if extension not in SUPPORTED_EXTENSIONS:
			_show_error("This file type is not supported.")
			return

	if form_mode == FormMode.ADD and selected_file_path.is_empty():
		_show_error("Please select a lesson file.")
		return

	if form_mode == FormMode.EDIT and lesson_document_name.is_empty():
		_show_error("The lesson document ID is missing.")
		return

	var teacher_id := str(AuthManager.get_uid()).strip_edges()

	if teacher_id.is_empty():
		_show_error("Unable to identify the teacher account.")
		return

	var auth_data: Variant = Firebase.Firestore.auth

	if not auth_data is Dictionary:
		_show_error("Firebase authentication is unavailable.")
		return

	var id_token := str(auth_data.get("idtoken", ""))

	if id_token.is_empty():
		id_token = str(auth_data.get("idToken", ""))

	if id_token.is_empty():
		_show_error("Firebase authentication token is missing.")
		return

	var project_id := str(
		Firebase.Firestore._config.get("projectId", "")
	).strip_edges()

	if project_id.is_empty():
		_show_error("Firebase project configuration is missing.")
		return

	# --- NEW GOOGLE DRIVE UPLOAD LOGIC ---
	
	# If editing and no new file is chosen, just save to Firestore immediately
	if form_mode == FormMode.EDIT and selected_file_path.is_empty():
		var lesson_fields: Dictionary = {
			"title": {"stringValue": lesson_title},
			"description": {"stringValue": description},
			"subject": {"stringValue": subject}
		}
		_submit_lesson(project_id, id_token, lesson_fields)
		return

	# Otherwise, we need to upload to Drive first
	is_saving = true
	create_button.disabled = true
	cancel_button.disabled = true
	choose_file_button.disabled = true
	status_label.text = "Uploading file..."

	# Store the data we need for Firestore later in global-scope variables
	# so we can access them in the callback function
	set_meta("pending_teacher_id", teacher_id)
	set_meta("pending_id_token", id_token)
	set_meta("pending_project_id", project_id)
	set_meta("pending_title", lesson_title)
	set_meta("pending_subject", subject)
	set_meta("pending_description", description)

	# Trigger the upload!
	cloudinary_uploader.upload_file(selected_file_path, self, "_on_cloudinary_upload_finished")


func _submit_lesson(
	project_id: String,
	id_token: String,
	lesson_fields: Dictionary
) -> void:
	var url: String
	var method: HTTPClient.Method
	var fields_to_write: Dictionary = {}

	if form_mode == FormMode.ADD:
		url = (
			"https://firestore.googleapis.com/v1/projects/"
			+ project_id
			+ "/databases/(default)/documents/lessons"
		)
		method = HTTPClient.METHOD_POST
		fields_to_write = lesson_fields

	else:
		# PATCH the existing document, updating only the fields
		# provided in lesson_fields.
		var document_id := lesson_document_name.get_file()

		if document_id.is_empty():
			_show_error("Could not determine the lesson document ID.")
			return

		var update_masks := PackedStringArray()

		for field_name in lesson_fields.keys():
			update_masks.append(
				"updateMask.fieldPaths=" + field_name.uri_encode()
			)

		url = (
			"https://firestore.googleapis.com/v1/projects/"
			+ project_id
			+ "/databases/(default)/documents/lessons/"
			+ document_id.uri_encode()
			+ "?"
			+ "&".join(update_masks)
		)

		method = HTTPClient.METHOD_PATCH
		fields_to_write = lesson_fields

	var document_body := {"fields": fields_to_write}

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	])

	is_saving = true
	create_button.disabled = true
	cancel_button.disabled = true
	choose_file_button.disabled = true

	if form_mode == FormMode.ADD:
		status_label.text = "Creating lesson..."
	else:
		status_label.text = "Saving changes..."

	var error := firestore_request.request(
		url,
		headers,
		method,
		JSON.stringify(document_body)
	)

	if error != OK:
		is_saving = false
		create_button.disabled = false
		cancel_button.disabled = false
		choose_file_button.disabled = form_mode == FormMode.VIEW

		_show_error("Could not connect to Firestore.")
		push_error("[AddLesson] Request error: " + str(error))


# ------------------------------------------------------------
# FIRESTORE RESPONSE
# ------------------------------------------------------------

func _on_firestore_request_completed(
	result: int,
	response_code: int,
	_response_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	is_saving = false

	create_button.disabled = false
	cancel_button.disabled = false
	choose_file_button.disabled = form_mode == FormMode.VIEW

	var response_text := body.get_string_from_utf8()

	print("[AddLesson] Firestore HTTP response: ", response_code)

	if result == HTTPRequest.RESULT_SUCCESS \
	and response_code >= 200 \
	and response_code < 300:

		var lesson_title := title_input.text.strip_edges()
		var lesson_id := ""

		if form_mode == FormMode.ADD:
			# Firestore returns the created document's name.
			var response_json := JSON.new()

			if response_json.parse(response_text) == OK:
				if response_json.data is Dictionary:
					var document_name := str(
						response_json.data.get("name", "")
					)

					lesson_id = document_name.get_file()

			status_label.text = "Lesson created successfully!"
			print("[AddLesson] Lesson created.")

			ActivityLogManager.log_activity(
				"Created Lesson",
				"Created lesson: " + lesson_title
					+ " | Subject: " + subject_input.text.strip_edges(),
				"Lesson Management",
				lesson_id
			)

		else:
			lesson_id = lesson_document_name.get_file()

			status_label.text = "Lesson updated successfully!"
			print("[AddLesson] Lesson updated.")

			ActivityLogManager.log_activity(
				"Updated Lesson",
				"Updated lesson: " + lesson_title
					+ " | Subject: " + subject_input.text.strip_edges(),
				"Lesson Management",
				lesson_id
			)

		print("[AddLesson] Activity log recorded.")

		lesson_created.emit()
		queue_free()
		return

	push_error(
		"[AddLesson] Save failed. HTTP "
		+ str(response_code)
		+ " Response: "
		+ response_text
	)

	_show_error("Failed to save lesson. Please try again.")


# ------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------

func _show_error(message: String) -> void:
	status_label.text = message
	print("[AddLesson] ", message)


func reset_form() -> void:
	title_input.clear()
	subject_input.clear()
	description_input.clear()

	selected_file_path = ""
	existing_file_name = ""
	existing_file_extension = ""
	existing_file_size = ""

	file_name_label.text = "No file selected"
	status_label.text = ""

	create_button.disabled = false
	cancel_button.disabled = false
	choose_file_button.disabled = false

	is_saving = false


func _on_cancel_button_pressed() -> void:
	print("[AddLesson] Form closed.")
	queue_free()

func _on_cloudinary_upload_finished(success: bool, file_url_or_error: String):
	if success:
		var file_url = file_url_or_error
		print("[AddLesson] Upload success! URL: ", file_url)
		status_label.text = "File uploaded! Saving to database..."
		
		var lesson_title = get_meta("pending_title")
		var subject = get_meta("pending_subject")
		var description = get_meta("pending_description")
		var teacher_id = get_meta("pending_teacher_id")
		var id_token = get_meta("pending_id_token")
		var project_id = get_meta("pending_project_id")

		var lesson_fields: Dictionary = {
			"title": {"stringValue": lesson_title},
			"description": {"stringValue": description},
			"subject": {"stringValue": subject},
			"file_url": {"stringValue": file_url} # <--- Saving the Cloudinary link here!
		}

		var extension := selected_file_path.get_extension().to_lower()
		var file := FileAccess.open(selected_file_path, FileAccess.READ)
		if file:
			lesson_fields["file_name"] = {"stringValue": selected_file_path.get_file()}
			lesson_fields["file_extension"] = {"stringValue": extension}
			lesson_fields["file_size"] = {"integerValue": str(file.get_length())}
			file.close()

		if form_mode == FormMode.ADD:
			lesson_fields["teacher_id"] = {"stringValue": teacher_id}
			lesson_fields["assigned_sections"] = {"arrayValue": {"values": []}}
			var unix_time := Time.get_unix_time_from_system()
			var datetime := Time.get_datetime_dict_from_unix_time(int(unix_time))
			var timestamp := "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
				datetime["year"], datetime["month"], datetime["day"],
				datetime["hour"], datetime["minute"], datetime["second"]
			]
			lesson_fields["created_at"] = {"timestampValue": timestamp}

		# Send to Firestore
		_submit_lesson(project_id, id_token, lesson_fields)
		
	else:
		is_saving = false
		create_button.disabled = false
		cancel_button.disabled = false
		choose_file_button.disabled = false
		_show_error("Upload Failed: " + file_url_or_error)

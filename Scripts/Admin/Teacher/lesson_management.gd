extends Control


# ============================================================
# SCENES
# ============================================================

const ADD_LESSON = preload(
	"res://Scenes/Admin/Teacher/add_lesson.tscn"
)


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var lesson_list: VBoxContainer = $MarginContainer/VBoxContainer/LessonScroll/LessonList
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel


# ============================================================
# FIRESTORE
# ============================================================

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

var firestore_url: String


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[LessonManagement] Lesson Management opened.")

	firestore_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/lessons"
	)

	load_lessons()


# ============================================================
# ADD LESSON
# ============================================================

func _on_add_lesson_button_pressed() -> void:

	print("[LessonManagement] Add Lesson button pressed.")

	var add_lesson = ADD_LESSON.instantiate()

	add_child(add_lesson)

	if not add_lesson.lesson_created.is_connected(
		_on_lesson_created
	):

		add_lesson.lesson_created.connect(
			_on_lesson_created
		)


# ============================================================
# LESSON CREATED
# ============================================================

func _on_lesson_created() -> void:

	print("[LessonManagement] New lesson created.")

	load_lessons()


# ============================================================
# REFRESH
# ============================================================

func _on_refresh_button_pressed() -> void:

	print("[LessonManagement] Refresh button pressed.")

	load_lessons()


# ============================================================
# LOAD LESSONS
# ============================================================

func load_lessons() -> void:

	print("[LessonManagement] Loading lessons from Firestore...")

	status_label.text = "Loading lessons..."


	# --------------------------------------------------------
	# Remove old lesson cards
	# --------------------------------------------------------

	for child in lesson_list.get_children():

		if child.name != "EmptyLabel":

			child.queue_free()


	# --------------------------------------------------------
	# Hide empty message
	# --------------------------------------------------------

	var empty_label := lesson_list.get_node_or_null(
		"EmptyLabel"
	) as Label

	if empty_label:

		empty_label.visible = false


	# --------------------------------------------------------
	# Get Firebase ID token
	# --------------------------------------------------------

	var id_token := _get_id_token()

	if id_token.is_empty():

		print(
			"[LessonManagement] ERROR: Firebase ID token is empty."
		)

		status_label.text = (
			"Unable to authenticate with Firebase."
		)

		return


	print(
		"[LessonManagement] Firebase ID token obtained."
	)

	print(
		"[LessonManagement] Token length: ",
		id_token.length()
	)


	# --------------------------------------------------------
	# Create HTTP request
	# --------------------------------------------------------

	var http := HTTPRequest.new()

	add_child(http)

	http.request_completed.connect(
		_on_lessons_request_completed.bind(http)
	)


	# --------------------------------------------------------
	# Authorization headers
	# --------------------------------------------------------

	var headers := PackedStringArray()

	headers.append(
		"Authorization: Bearer " + id_token
	)

	headers.append(
		"Content-Type: application/json"
	)


	print(
		"[LessonManagement] Request URL: ",
		firestore_url
	)

	print(
		"[LessonManagement] Sending authenticated GET request..."
	)


	# --------------------------------------------------------
	# Send request
	# --------------------------------------------------------

	var error := http.request(
		firestore_url,
		headers,
		HTTPClient.METHOD_GET
	)


	if error != OK:

		print(
			"[LessonManagement] Failed to send request: ",
			error
		)

		status_label.text = (
			"Could not load lessons."
		)

		http.queue_free()


# ============================================================
# GET FIREBASE ID TOKEN
# ============================================================

func _get_id_token() -> String:
	var auth_manager = get_node_or_null("/root/AuthManager")

	if auth_manager == null:
		print("[LessonManagement] ERROR: AuthManager not found.")
		return ""

	if not auth_manager.is_logged_in():
		print("[LessonManagement] ERROR: User is not logged in.")
		return ""

	var auth_data: Dictionary = auth_manager.current_user

	print("[LessonManagement] Auth data keys: ", auth_data.keys())

	# Firebase Godot plugin normally returns the ID token as idtoken.
	if auth_data.has("idtoken"):
		var token := str(auth_data["idtoken"])

		if not token.is_empty():
			print("[LessonManagement] Firebase ID token found.")
			return token

	# Some Firebase responses use idToken instead.
	if auth_data.has("idToken"):
		var token := str(auth_data["idToken"])

		if not token.is_empty():
			print("[LessonManagement] Firebase ID token found.")
			return token

	print("[LessonManagement] ERROR: Firebase ID token not found in AuthManager.current_user.")
	return ""

# ============================================================
# FIRESTORE RESPONSE
# ============================================================

func _on_lessons_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:

	print(
		"[LessonManagement] Firestore response: ",
		response_code
	)

	var response_text := body.get_string_from_utf8()

	print(
		"[LessonManagement] Response body: ",
		response_text
	)


	http.queue_free()


	# --------------------------------------------------------
	# HTTP request result
	# --------------------------------------------------------

	if result != HTTPRequest.RESULT_SUCCESS:

		print(
			"[LessonManagement] HTTP request failed. Result: ",
			result
		)

		status_label.text = (
			"Could not connect to Firestore."
		)

		return


	# --------------------------------------------------------
	# Firestore response
	# --------------------------------------------------------

	if response_code != 200:

		print(
			"[LessonManagement] ERROR LOADING LESSONS"
		)

		print(
			"[LessonManagement] HTTP Code: ",
			response_code
		)

		status_label.text = (
			"Failed to load lessons."
		)

		return


	# --------------------------------------------------------
	# Parse JSON
	# --------------------------------------------------------

	var json := JSON.new()

	var parse_result := json.parse(
		response_text
	)

	if parse_result != OK:

		print(
			"[LessonManagement] Failed to parse Firestore response."
		)

		status_label.text = (
			"Invalid response from Firestore."
		)

		return


	var data = json.data


	# --------------------------------------------------------
	# Check response
	# --------------------------------------------------------

	if not data is Dictionary:

		status_label.text = (
			"No lessons found."
		)

		return


	var documents = data.get(
		"documents",
		[]
	)


	# --------------------------------------------------------
	# No lessons
	# --------------------------------------------------------

	if documents.is_empty():

		print(
			"[LessonManagement] No lessons found."
		)

		var empty_label := lesson_list.get_node_or_null(
			"EmptyLabel"
		) as Label

		if empty_label:

			empty_label.visible = true

		status_label.text = (
			"No lessons created yet."
		)

		return


	# --------------------------------------------------------
	# Display lessons
	# --------------------------------------------------------

	print(
		"[LessonManagement] Lessons found: ",
		documents.size()
	)


	for document in documents:

		create_lesson_card(
			document
		)


	status_label.text = (
		str(documents.size())
		+ " lesson(s) loaded."
	)


# ============================================================
# CREATE LESSON CARD
# ============================================================

func create_lesson_card(
	document: Dictionary
) -> void:

	var fields: Dictionary = document.get(
		"fields",
		{}
	)


	var title := get_firestore_string(
		fields,
		"title",
		"Untitled Lesson"
	)


	var description := get_firestore_string(
		fields,
		"description",
		"No description."
	)


	var subject := get_firestore_string(
		fields,
		"subject",
		""
	)


	var section := get_firestore_string(
		fields,
		"section",
		""
	)


	var school_year := get_firestore_string(
		fields,
		"school_year",
		""
	)


	var teacher_id := get_firestore_string(
		fields,
		"teacher_id",
		""
	)


	var file_name := get_firestore_string(
		fields,
		"file_name",
		"No file"
	)


	# --------------------------------------------------------
	# Lesson card
	# --------------------------------------------------------

	var card := PanelContainer.new()

	card.custom_minimum_size = Vector2(
		0,
		125
	)

	card.name = "LessonCard"


	# --------------------------------------------------------
	# Card container
	# --------------------------------------------------------

	var margin := MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		18
	)

	margin.add_theme_constant_override(
		"margin_right",
		18
	)

	margin.add_theme_constant_override(
		"margin_top",
		12
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		12
	)

	card.add_child(margin)


	var content := VBoxContainer.new()

	content.add_theme_constant_override(
		"separation",
		4
	)

	margin.add_child(content)


	# --------------------------------------------------------
	# Title
	# --------------------------------------------------------

	var title_label := Label.new()

	title_label.text = title

	title_label.add_theme_font_size_override(
		"font_size",
		24
	)

	title_label.add_theme_color_override(
		"font_color",
		Color(
			0.47,
			0.35,
			0.235,
			1
		)
	)

	content.add_child(title_label)


	# --------------------------------------------------------
	# Description
	# --------------------------------------------------------

	var description_label := Label.new()

	description_label.text = description

	description_label.add_theme_font_size_override(
		"font_size",
		16
	)

	description_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	content.add_child(
		description_label
	)


	# --------------------------------------------------------
	# Lesson information
	# --------------------------------------------------------

	var info_label := Label.new()

	info_label.text = (
		"Subject: "
		+ subject
		+ "    |    Section: "
		+ section
		+ "    |    School Year: "
		+ school_year
	)

	info_label.add_theme_font_size_override(
		"font_size",
		15
	)

	content.add_child(
		info_label
	)


	# --------------------------------------------------------
	# File information
	# --------------------------------------------------------

	var file_label := Label.new()

	file_label.text = (
		"Material: "
		+ file_name
	)

	file_label.add_theme_font_size_override(
		"font_size",
		14
	)

	content.add_child(
		file_label
	)


	# --------------------------------------------------------
	# Teacher information
	# --------------------------------------------------------

	var teacher_label := Label.new()

	teacher_label.text = (
		"Teacher ID: "
		+ teacher_id
	)

	teacher_label.add_theme_font_size_override(
		"font_size",
		12
	)

	content.add_child(
		teacher_label
	)


	# --------------------------------------------------------
	# Add card to list
	# --------------------------------------------------------

	lesson_list.add_child(
		card
	)


# ============================================================
# FIRESTORE STRING HELPER
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

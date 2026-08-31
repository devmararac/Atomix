extends Control


# ============================================================
# FIRESTORE
# ============================================================

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

var firestore_lessons_url: String
var firestore_student_url: String


# ============================================================
# UI
# ============================================================

@onready var lesson_list: VBoxContainer = $MarginContainer/VBoxContainer/LessonScroll/LessonList
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[LessonsPage] Lessons page opened.")

	firestore_lessons_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/lessons"
	)

	firestore_student_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/students/"
	)

	load_student_section()


# ============================================================
# GET FIREBASE ID TOKEN
# ============================================================

func get_id_token() -> String:

	var auth_data: Dictionary = Firebase.Firestore.auth

	if auth_data.is_empty():

		print("[LessonsPage] Firestore auth is empty.")

		return ""


	if not auth_data.has("idtoken"):

		print("[LessonsPage] Firebase ID token not found.")

		return ""


	var token := str(auth_data["idtoken"])

	print(
		"[LessonsPage] Firebase ID token obtained. Length: ",
		token.length()
	)

	return token


# ============================================================
# LOAD STUDENT SECTION
# ============================================================

func load_student_section() -> void:

	print("[LessonsPage] Loading student information...")

	status_label.text = "Loading lessons..."

	var uid := AuthManager.get_uid()

	if uid.is_empty():

		print("[LessonsPage] ERROR: Student UID is empty.")

		status_label.text = "Could not identify student."

		return


	print("[LessonsPage] Student UID: ", uid)


	var token := get_id_token()

	if token.is_empty():

		status_label.text = "Authentication error."

		return


	var url := firestore_student_url + uid

	var headers := PackedStringArray([
		"Authorization: Bearer " + token,
		"Content-Type: application/json"
	])


	var http := HTTPRequest.new()

	add_child(http)


	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)


	if error != OK:

		print(
			"[LessonsPage] Failed to request student: ",
			error
		)

		status_label.text = "Could not load student information."

		http.queue_free()

		return


	var response: Array = await http.request_completed

	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text := response_body.get_string_from_utf8()

	http.queue_free()


	print(
		"[LessonsPage] Student Firestore response: ",
		response_code
	)


	if response_code != 200:

		print(
			"[LessonsPage] Student request failed: ",
			response_text
		)

		status_label.text = "Could not load student information."

		return


	var json := JSON.new()

	var parse_error := json.parse(response_text)

	if parse_error != OK:

		print(
			"[LessonsPage] Failed to parse student data."
		)

		status_label.text = "Invalid student data."

		return


	var data = json.data

	if not data is Dictionary:

		status_label.text = "Invalid student data."

		return


	var fields: Dictionary = data.get(
		"fields",
		{}
	)


	var section := get_firestore_string(
		fields,
		"section",
		""
	)


	print(
		"[LessonsPage] Student section: ",
		section
	)


	if section.is_empty():

		print(
			"[LessonsPage] Student has no section."
		)

		status_label.text = "No section assigned to your account."

		return


	load_lessons(section)


# ============================================================
# LOAD LESSONS
# ============================================================

func load_lessons(student_section: String) -> void:

	print(
		"[LessonsPage] Loading lessons for section: ",
		student_section
	)


	var token := get_id_token()

	if token.is_empty():

		status_label.text = "Authentication error."

		return


	var headers := PackedStringArray([
		"Authorization: Bearer " + token,
		"Content-Type: application/json"
	])


	var http := HTTPRequest.new()

	add_child(http)


	var error := http.request(
		firestore_lessons_url,
		headers,
		HTTPClient.METHOD_GET
	)


	if error != OK:

		print(
			"[LessonsPage] Failed to request lessons: ",
			error
		)

		status_label.text = "Could not load lessons."

		http.queue_free()

		return


	var response: Array = await http.request_completed

	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text := response_body.get_string_from_utf8()

	http.queue_free()


	print(
		"[LessonsPage] Firestore lessons response: ",
		response_code
	)


	if response_code != 200:

		print(
			"[LessonsPage] Lesson request failed: ",
			response_text
		)

		status_label.text = "Could not load lessons."

		return


	var json := JSON.new()

	var parse_error := json.parse(response_text)

	if parse_error != OK:

		print(
			"[LessonsPage] Failed to parse lessons."
		)

		status_label.text = "Invalid lesson data."

		return


	var data = json.data

	if not data is Dictionary:

		status_label.text = "No lessons found."

		return


	var documents: Array = data.get(
		"documents",
		[]
	)


	print(
		"[LessonsPage] Total lessons in Firestore: ",
		documents.size()
	)


	var matching_lessons := 0


	for document in documents:

		var fields: Dictionary = document.get(
			"fields",
			{}
		)


		var lesson_section := get_firestore_string(
			fields,
			"section",
			""
		)


		if lesson_section != student_section:

			print(
				"[LessonsPage] Skipping lesson section: ",
				lesson_section
			)

			continue


		print(
			"[LessonsPage] Lesson matches student section: ",
			lesson_section
		)


		create_lesson_card(document)

		matching_lessons += 1


	# ========================================================
	# RESULT
	# ========================================================

	if matching_lessons == 0:

		var empty_label := lesson_list.get_node_or_null(
			"EmptyLabel"
		) as Label

		if empty_label:

			empty_label.visible = true


		status_label.text = "No lessons available."

	else:

		var empty_label := lesson_list.get_node_or_null(
			"EmptyLabel"
		) as Label

		if empty_label:

			empty_label.visible = false


		status_label.text = (
			str(matching_lessons)
			+ " lesson(s) available."
		)


# ============================================================
# CREATE LESSON CARD
# ============================================================

func create_lesson_card(document: Dictionary) -> void:

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


	var file_name := get_firestore_string(
		fields,
		"file_name",
		"No material"
	)


	# ========================================================
	# CARD
	# ========================================================

	var card := PanelContainer.new()

	card.custom_minimum_size = Vector2(
		0,
		145
	)


	var margin := MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		16
	)

	margin.add_theme_constant_override(
		"margin_right",
		16
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
		5
	)


	margin.add_child(content)


	# ========================================================
	# TITLE
	# ========================================================

	var title_label := Label.new()

	title_label.text = title

	title_label.add_theme_font_size_override(
		"font_size",
		24
	)

	title_label.add_theme_color_override(
		"font_color",
		Color(
			0.470588,
			0.352941,
			0.235294,
			1
		)
	)

	content.add_child(title_label)


	# ========================================================
	# DESCRIPTION
	# ========================================================

	var description_label := Label.new()

	description_label.text = description

	description_label.add_theme_font_size_override(
		"font_size",
		16
	)

	description_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	content.add_child(description_label)


	# ========================================================
	# INFORMATION
	# ========================================================

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
		14
	)

	content.add_child(info_label)


	# ========================================================
	# MATERIAL
	# ========================================================

	var file_label := Label.new()

	file_label.text = (
		"Learning Material: "
		+ file_name
	)

	file_label.add_theme_font_size_override(
		"font_size",
		14
	)

	file_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	content.add_child(file_label)


	# ========================================================
	# ADD TO LIST
	# ========================================================

	lesson_list.add_child(card)


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

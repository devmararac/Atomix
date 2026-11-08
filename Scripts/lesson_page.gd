extends Control


# ============================================================
# FIRESTORE
# ============================================================

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

var firestore_url: String


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var lesson_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/LessonList
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel


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

	load_lessons()


# ============================================================
# LOAD LESSONS
# ============================================================

func load_lessons() -> void:

	print("[LessonPage] Loading lessons from Firestore...")

	status_label.text = "Loading lessons..."

	# Remove old lesson cards.
	for child in lesson_list.get_children():
		child.queue_free()


	# --------------------------------------------------------
	# Get Firebase ID token
	# --------------------------------------------------------

	var id_token := _get_id_token()

	if id_token.is_empty():
		print("[LessonPage] ERROR: Firebase ID token is empty.")
		status_label.text = "Unable to connect to learning materials."
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

		status_label.text = "Could not load learning materials."

		http.queue_free()


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

	var response_text := body.get_string_from_utf8()

	http.queue_free()


	print(
		"[LessonPage] Firestore response: ",
		response_code
	)


	print(
		"[LessonPage] Response body: ",
		response_text
	)


	# --------------------------------------------------------
	# Check response
	# --------------------------------------------------------

	if response_code != 200:

		print("[LessonPage] ERROR LOADING LESSONS")

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

		status_label.text = "No learning materials found."

		return


	var documents = data.get(
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

	var student_section := await _get_student_section()

	print(
		"[LessonPage] Student section: ",
		student_section
	)


	# --------------------------------------------------------
	# Display matching lessons
	# --------------------------------------------------------

	var displayed_count := 0

	for document in documents:

		var fields: Dictionary = document.get(
			"fields",
			{}
		)

		var section := get_firestore_string(
			fields,
			"section",
			""
		)


		# ----------------------------------------------------
		# Only show lessons assigned to student's section.
		# ----------------------------------------------------

		if not _section_matches(section, student_section):

			continue


		create_lesson_card(document)

		displayed_count += 1


	# --------------------------------------------------------
	# Final status
	# --------------------------------------------------------

	if displayed_count == 0:

		status_label.text = (
			"No learning materials assigned to your section."
		)

		print(
			"[LessonPage] No lessons matched student section."
		)

	else:

		status_label.text = (
			str(displayed_count)
			+ " learning material(s) available."
		)

		print(
			"[LessonPage] Lessons displayed: ",
			displayed_count
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
		"No description available."
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

	var file_extension := get_firestore_string(
		fields,
		"file_extension",
		""
	)


	# ========================================================
	# CARD
	# ========================================================

	var card := PanelContainer.new()

	card.custom_minimum_size = Vector2(
		0,
		150
	)


	# ========================================================
	# MARGIN
	# ========================================================

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
		14
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		14
	)

	card.add_child(margin)


	# ========================================================
	# CONTENT
	# ========================================================

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
			0.47,
			0.35,
			0.235,
			1
		)
	)

	content.add_child(title_label)


	# ========================================================
	# DESCRIPTION
	# ========================================================

	var description_label := Label.new()

	description_label.text = description

	description_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	description_label.add_theme_font_size_override(
		"font_size",
		16
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

	var material_label := Label.new()

	material_label.text = (
		"Learning Material: "
		+ file_name
	)

	material_label.add_theme_font_size_override(
		"font_size",
		15
	)

	content.add_child(material_label)


	# ========================================================
	# MATERIAL TYPE
	# ========================================================

	var type_label := Label.new()

	type_label.text = (
		"File Type: "
		+ file_extension.to_upper()
	)

	type_label.add_theme_font_size_override(
		"font_size",
		13
	)

	content.add_child(type_label)


	# ========================================================
	# ADD CARD
	# ========================================================

	lesson_list.add_child(card)


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
# GET ID TOKEN
# ============================================================

func _get_id_token() -> String:

	if not Firebase.Auth:
		print("[LessonPage] Firebase.Auth is unavailable.")
		return ""


	# Firebase.Auth stores the authentication result.
	# The key returned by the current Firebase plugin is
	# "idtoken".

	var auth_data = Firebase.Auth.auth


	if auth_data is Dictionary:

		if auth_data.has("idtoken"):

			var token := str(
				auth_data["idtoken"]
			)

			if not token.is_empty():
				return token


		# Also support camelCase just in case.
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


	# Try AuthManager first.
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


	var id_token := _get_id_token()

	if id_token.is_empty():
		return ""


	var student_url := (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/students/"
		+ uid
	)


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

		return ""


	var result_data = await http.request_completed

	http.queue_free()


	var response_code: int = result_data[1]
	var body: PackedByteArray = result_data[3]


	if response_code != 200:

		print(
			"[LessonPage] Student request failed: ",
			response_code
		)

		return ""


	var response_text := body.get_string_from_utf8()


	var json := JSON.new()

	if json.parse(response_text) != OK:

		return ""


	var data = json.data


	if not data is Dictionary:

		return ""


	var fields: Dictionary = data.get(
		"fields",
		{}
	)


	var section := get_firestore_string(
		fields,
		"section",
		""
	)


	# --------------------------------------------------------
	# Normalize section.
	#
	# Student may have:
	# A
	# 11-A
	# --------------------------------------------------------

	return section


# ============================================================
# SECTION MATCHING
# ============================================================

func _section_matches(
	lesson_section: String,
	student_section: String
) -> bool:

	if lesson_section.is_empty():
		return false

	if student_section.is_empty():
		return false


	var lesson_normalized := lesson_section.strip_edges().to_upper()
	var student_normalized := student_section.strip_edges().to_upper()


	# Exact match.
	if lesson_normalized == student_normalized:
		return true


	# Example:
	# lesson = 11-A
	# student = A

	if lesson_normalized.ends_with(
		"-" + student_normalized
	):

		return true


	# Example:
	# lesson = A
	# student = 11-A

	if student_normalized.ends_with(
		"-" + lesson_normalized
	):

		return true


	return false

extends Control


# ============================================================
# FIRESTORE
# ============================================================

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

var firestore_lessons_url: String
var firestore_quizzes_url: String
var firestore_student_url: String


# ============================================================
# STUDENT DATA
# ============================================================

var student_section: String = ""


# ============================================================
# UI
# ============================================================

@onready var lesson_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/LessonList
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[LessonsPage] Lessons page opened.")

	# --------------------------------------------------------
	# Lessons collection
	# --------------------------------------------------------

	firestore_lessons_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/lessons"
	)

	# --------------------------------------------------------
	# Quizzes collection
	# --------------------------------------------------------

	firestore_quizzes_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/quizzes"
	)

	# --------------------------------------------------------
	# Student document
	# --------------------------------------------------------

	firestore_student_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/students/"
	)

	# --------------------------------------------------------
	# Load student section
	# --------------------------------------------------------

	await load_student_section()


# ============================================================
# GET FIREBASE ID TOKEN
# ============================================================

func get_id_token() -> String:

	if Firebase.Auth != null:

		var auth_data: Dictionary = Firebase.Auth.auth

		if not auth_data.is_empty():

			var token := str(
				auth_data.get(
					"idtoken",
					""
				)
			)

			if token.is_empty():

				token = str(
					auth_data.get(
						"idToken",
						""
					)
				)

			if not token.is_empty():

				print(
					"[LessonsPage] Firebase ID token obtained. Length: ",
					token.length()
				)

				return token


	# --------------------------------------------------------
	# Fallback to Firebase.Firestore.auth
	# --------------------------------------------------------

	if Firebase.Firestore != null:

		var firestore_auth: Dictionary = Firebase.Firestore.auth

		if not firestore_auth.is_empty():

			var token := str(
				firestore_auth.get(
					"idtoken",
					""
				)
			)

			if token.is_empty():

				token = str(
					firestore_auth.get(
						"idToken",
						""
					)
				)

			if not token.is_empty():

				print(
					"[LessonsPage] Firebase Firestore ID token obtained."
				)

				return token


	print(
		"[LessonsPage] Firebase ID token not found."
	)

	return ""


# ============================================================
# LOAD STUDENT SECTION
# ============================================================

func load_student_section() -> void:

	print(
		"[LessonsPage] Loading student information..."
	)

	status_label.text = "Loading learning materials..."


	# --------------------------------------------------------
	# Get UID
	# --------------------------------------------------------

	var uid := AuthManager.get_uid()

	if uid.is_empty():

		print(
			"[LessonsPage] ERROR: Student UID is empty."
		)

		status_label.text = "Could not identify student."

		return


	print(
		"[LessonsPage] Student UID: ",
		uid
	)


	# --------------------------------------------------------
	# Get token
	# --------------------------------------------------------

	var token := get_id_token()

	if token.is_empty():

		status_label.text = "Authentication error."

		return


	# --------------------------------------------------------
	# Request student document
	# --------------------------------------------------------

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

	var response_text := (
		response_body.get_string_from_utf8()
	)

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


	# --------------------------------------------------------
	# Parse JSON
	# --------------------------------------------------------

	var json := JSON.new()

	var parse_error := json.parse(
		response_text
	)

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


	# --------------------------------------------------------
	# Get student section
	# --------------------------------------------------------

	student_section = get_firestore_string(
		fields,
		"section",
		""
	).strip_edges()


	print(
		"[LessonsPage] Student section: ",
		student_section
	)


	if student_section.is_empty():

		print(
			"[LessonsPage] Student has no section."
		)

		status_label.text = (
			"No section assigned to your account."
		)

		return


	# --------------------------------------------------------
	# Load both lessons and quizzes
	# --------------------------------------------------------

	await load_lessons(student_section)

	await load_quizzes(student_section)


# ============================================================
# LOAD LESSONS
# ============================================================

func load_lessons(
	student_section_value: String
) -> void:

	print(
		"[LessonsPage] Loading lessons for section: ",
		student_section_value
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

	var response_text := (
		response_body.get_string_from_utf8()
	)

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

	var parse_error := json.parse(
		response_text
	)

	if parse_error != OK:

		print(
			"[LessonsPage] Failed to parse lessons."
		)

		status_label.text = "Invalid lesson data."

		return


	var data = json.data

	if not data is Dictionary:

		print(
			"[LessonsPage] Invalid lessons response."
		)

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

		if not document is Dictionary:
			continue


		var fields: Dictionary = document.get(
			"fields",
			{}
		)


		var lesson_section := get_firestore_string(
			fields,
			"section",
			""
		).strip_edges()


		# ----------------------------------------------------
		# Only show lessons for student's section
		# ----------------------------------------------------

		if lesson_section != student_section_value:

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


	print(
		"[LessonsPage] Matching lessons: ",
		matching_lessons
	)


# ============================================================
# LOAD QUIZZES
# ============================================================

func load_quizzes(
	student_section_value: String
) -> void:

	print(
		"[LessonsPage] Loading quizzes for section: ",
		student_section_value
	)


	var token := get_id_token()

	if token.is_empty():

		print(
			"[LessonsPage] Cannot load quizzes: token is empty."
		)

		return


	var headers := PackedStringArray([
		"Authorization: Bearer " + token,
		"Content-Type: application/json"
	])


	var http := HTTPRequest.new()

	add_child(http)


	var error := http.request(
		firestore_quizzes_url,
		headers,
		HTTPClient.METHOD_GET
	)


	if error != OK:

		print(
			"[LessonsPage] Failed to request quizzes: ",
			error
		)

		http.queue_free()

		return


	var response: Array = await http.request_completed

	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text := (
		response_body.get_string_from_utf8()
	)

	http.queue_free()


	print(
		"[LessonsPage] Firestore quizzes response: ",
		response_code
	)


	if response_code != 200:

		print(
			"[LessonsPage] Quiz request failed: ",
			response_text
		)

		return


	# --------------------------------------------------------
	# Parse JSON
	# --------------------------------------------------------

	var json := JSON.new()

	var parse_error := json.parse(
		response_text
	)

	if parse_error != OK:

		print(
			"[LessonsPage] Failed to parse quizzes."
		)

		return


	var data = json.data

	if not data is Dictionary:

		print(
			"[LessonsPage] Invalid quizzes response."
		)

		return


	var documents: Array = data.get(
		"documents",
		[]
	)


	print(
		"[LessonsPage] Total quizzes in Firestore: ",
		documents.size()
	)


	var matching_quizzes := 0


	# --------------------------------------------------------
	# Check every quiz
	# --------------------------------------------------------

	for document in documents:

		if not document is Dictionary:
			continue


		var fields: Dictionary = document.get(
			"fields",
			{}
		)


		var quiz_section := get_firestore_string(
			fields,
			"section",
			""
		).strip_edges()


		print(
			"[LessonsPage] Quiz section: ",
			quiz_section
		)


		# ----------------------------------------------------
		# Only show quizzes belonging to student's section
		# ----------------------------------------------------

		if quiz_section != student_section_value:

			print(
				"[LessonsPage] Skipping quiz from section: ",
				quiz_section
			)

			continue


		print(
			"[LessonsPage] Quiz matches student section: ",
			quiz_section
		)


		create_quiz_card(document)

		matching_quizzes += 1


	print(
		"[LessonsPage] Matching quizzes: ",
		matching_quizzes
	)


	# --------------------------------------------------------
	# Final status
	# --------------------------------------------------------

	update_status()


# ============================================================
# UPDATE STATUS
# ============================================================

func update_status() -> void:

	var item_count := lesson_list.get_child_count()


	if item_count == 0:

		status_label.text = (
			"No learning materials available."
		)

		return


	status_label.text = (
		str(item_count)
		+ " learning material(s) available."
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
	# TYPE
	# ========================================================

	var type_label := Label.new()

	type_label.text = "LEARNING MATERIAL"

	type_label.add_theme_font_size_override(
		"font_size",
		14
	)

	content.add_child(type_label)


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
# CREATE QUIZ CARD
# ============================================================

func create_quiz_card(
	document: Dictionary
) -> void:

	var fields: Dictionary = document.get(
		"fields",
		{}
	)


	# --------------------------------------------------------
	# Get quiz information
	# --------------------------------------------------------

	var title := get_firestore_string(
		fields,
		"title",
		"Untitled Quiz"
	)


	var section := get_firestore_string(
		fields,
		"section",
		""
	)


	var quiz_type := get_firestore_string(
		fields,
		"quiz_type",
		""
	)


	var quiz_id := get_firestore_string(
		fields,
		"quiz_id",
		""
	)


	var question_count := get_firestore_integer(
		fields,
		"question_count",
		0
	)


	# ========================================================
	# CARD
	# ========================================================

	var card := PanelContainer.new()

	card.custom_minimum_size = Vector2(
		0,
		125
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
	# TYPE
	# ========================================================

	var type_label := Label.new()

	type_label.text = "QUIZ"

	type_label.add_theme_font_size_override(
		"font_size",
		14
	)

	content.add_child(type_label)


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
	# INFORMATION
	# ========================================================

	var info_label := Label.new()

	info_label.text = (
		"Quiz Type: "
		+ quiz_type
		+ "    |    Section: "
		+ section
		+ "    |    Questions: "
		+ str(question_count)
	)

	info_label.add_theme_font_size_override(
		"font_size",
		14
	)

	content.add_child(info_label)


	# ========================================================
	# QUIZ ID
	# ========================================================

	var id_label := Label.new()

	id_label.text = (
		"Quiz ID: "
		+ quiz_id
	)

	id_label.add_theme_font_size_override(
		"font_size",
		12
	)

	content.add_child(id_label)


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


# ============================================================
# FIRESTORE INTEGER HELPER
# ============================================================

func get_firestore_integer(
	fields: Dictionary,
	field_name: String,
	default_value: int
) -> int:

	if not fields.has(field_name):

		return default_value


	var field_data = fields[field_name]


	if not field_data is Dictionary:

		return default_value


	if field_data.has("integerValue"):

		return int(
			field_data["integerValue"]
		)


	return default_value

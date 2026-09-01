extends Control

# ============================================================
# FIRESTORE
# ============================================================

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

var firestore_url: String = ""


# ============================================================
# QUIZ DATA
# ============================================================

var quizzes: Array[Dictionary] = []

var quiz_loading: bool = false
var student_section: String = ""


# ============================================================
# UI REFERENCES
# ============================================================

@onready var title_label: Label = \
	$QuizPanel/MarginContainer/VBoxContainer/Header/Title

@onready var section_label: Label = \
	$QuizPanel/MarginContainer/VBoxContainer/Header/SectionLabel

@onready var search_bar: LineEdit = \
	$QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SearchPanel/SearchBar

@onready var filter_button: OptionButton = \
	$QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/FilterPanel/FilterButton

@onready var sort_button: OptionButton = \
	$QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SortPanel/SortButton

@onready var refresh_button: Button = \
	$QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/RefreshPanel/RefreshButton

@onready var quiz_scroll: ScrollContainer = \
	$QuizPanel/MarginContainer/VBoxContainer/QuizScroll

@onready var quiz_list: VBoxContainer = \
	$QuizPanel/MarginContainer/VBoxContainer/QuizScroll/QuizList

@onready var status_label: Label = \
	$QuizPanel/MarginContainer/VBoxContainer/StatusLabel


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[QuizPage] Quiz page opened.")

	# --------------------------------------------------------
	# Firestore URL
	# --------------------------------------------------------

	firestore_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/quizzes"
	)

	# --------------------------------------------------------
	# Connect UI buttons
	# --------------------------------------------------------

	if not refresh_button.pressed.is_connected(
		_on_refresh_pressed
	):
		refresh_button.pressed.connect(
			_on_refresh_pressed
		)

	if not search_bar.text_changed.is_connected(
		_on_search_text_changed
	):
		search_bar.text_changed.connect(
			_on_search_text_changed
		)

	if not filter_button.item_selected.is_connected(
		_on_filter_selected
	):
		filter_button.item_selected.connect(
			_on_filter_selected
		)

	if not sort_button.item_selected.is_connected(
		_on_sort_selected
	):
		sort_button.item_selected.connect(
			_on_sort_selected
		)

	# --------------------------------------------------------
	# Setup dropdowns
	# --------------------------------------------------------

	_setup_filter_button()
	_setup_sort_button()

	# --------------------------------------------------------
	# Load student's section
	# --------------------------------------------------------

	status_label.text = "Loading student information..."

	await _load_student_section()

	if student_section.is_empty():

		print(
			"[QuizPage] ERROR: Student section is empty."
		)

		section_label.text = "Section unavailable"
		status_label.text = \
			"Unable to determine your section."

		return

	print(
		"[QuizPage] Student section: ",
		student_section
	)

	section_label.text = \
		"Section: " + student_section

	# --------------------------------------------------------
	# Load quizzes
	# --------------------------------------------------------

	load_quizzes()


# ============================================================
# FILTER BUTTON
# ============================================================

func _setup_filter_button() -> void:

	filter_button.clear()

	filter_button.add_item("All Quiz Types")
	filter_button.add_item("Multiple Choice")
	filter_button.add_item("True or False")
	filter_button.add_item("Identification")

	filter_button.select(0)


# ============================================================
# SORT BUTTON
# ============================================================

func _setup_sort_button() -> void:

	sort_button.clear()

	sort_button.add_item("Newest First")
	sort_button.add_item("Oldest First")
	sort_button.add_item("Title A-Z")
	sort_button.add_item("Title Z-A")

	sort_button.select(0)


# ============================================================
# LOAD STUDENT SECTION
# ============================================================

func _load_student_section() -> void:

	print(
		"[QuizPage] Loading student information..."
	)

	var uid := _get_uid()

	if uid.is_empty():

		print(
			"[QuizPage] ERROR: Student UID is empty."
		)

		return

	print(
		"[QuizPage] Student UID: ",
		uid
	)

	var token := _get_id_token()

	if token.is_empty():

		print(
			"[QuizPage] ERROR: Firebase ID token is empty."
		)

		return

	print(
		"[QuizPage] Firebase ID token obtained."
	)

	var student_url := (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/students/"
		+ uid
	)

	print(
		"[QuizPage] Loading student document: ",
		student_url
	)

	var http := HTTPRequest.new()

	add_child(http)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	])

	var error := http.request(
		student_url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:

		print(
			"[QuizPage] Failed to request student data: ",
			error
		)

		http.queue_free()

		return

	var response: Array = \
		await http.request_completed

	http.queue_free()

	var response_code: int = \
		response[1]

	var body: PackedByteArray = \
		response[3]

	print(
		"[QuizPage] Student Firestore response: ",
		response_code
	)

	if response_code != 200:

		print(
			"[QuizPage] ERROR loading student:"
		)

		print(
			body.get_string_from_utf8()
		)

		return

	var response_text := \
		body.get_string_from_utf8()

	var data = \
		JSON.parse_string(response_text)

	if data == null:

		print(
			"[QuizPage] ERROR: Invalid student JSON."
		)

		return

	var fields: Dictionary = \
		data.get(
			"fields",
			{}
		)

	student_section = \
		_get_string_field(
			fields,
			"section"
		)

	student_section = \
		student_section.strip_edges()

	print(
		"[QuizPage] Student section: ",
		student_section
	)


# ============================================================
# LOAD QUIZZES
# ============================================================

func load_quizzes() -> void:

	if quiz_loading:
		return

	quiz_loading = true

	status_label.text = "Loading quizzes..."

	print(
		"[QuizPage] Loading quizzes for section: ",
		student_section
	)

	var token := _get_id_token()

	if token.is_empty():

		print(
			"[QuizPage] ERROR: Firebase ID token is empty."
		)

		quiz_loading = false

		_show_no_quizzes(
			"Authentication failed."
		)

		return

	var http := HTTPRequest.new()

	add_child(http)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	])

	print(
		"[QuizPage] Request URL: ",
		firestore_url
	)

	var error := http.request(
		firestore_url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:

		print(
			"[QuizPage] Failed to send request: ",
			error
		)

		http.queue_free()

		quiz_loading = false

		_show_no_quizzes(
			"Connection error."
		)

		return

	var response: Array = \
		await http.request_completed

	http.queue_free()

	var response_code: int = \
		response[1]

	var body: PackedByteArray = \
		response[3]

	quiz_loading = false

	print(
		"[QuizPage] Firestore response: ",
		response_code
	)

	if response_code != 200:

		print(
			"[QuizPage] Firestore error:"
		)

		print(
			body.get_string_from_utf8()
		)

		_show_no_quizzes(
			"Could not load quizzes."
		)

		return

	var response_text := \
		body.get_string_from_utf8()

	var data = \
		JSON.parse_string(response_text)

	if data == null:

		print(
			"[QuizPage] ERROR: Invalid JSON response."
		)

		_show_no_quizzes(
			"Invalid server response."
		)

		return

	if not data.has("documents"):

		print(
			"[QuizPage] No quiz documents found."
		)

		_show_no_quizzes(
			"No quizzes are available."
		)

		return

	var documents: Array = \
		data["documents"]

	print(
		"[QuizPage] Total quiz documents received: ",
		documents.size()
	)

	quizzes.clear()

	for document in documents:

		var fields: Dictionary = \
			document.get(
				"fields",
				{}
			)

		var quiz := \
			_parse_quiz_document(
				fields,
				document
			)

		if quiz.is_empty():
			continue

		var quiz_section := \
			str(
				quiz.get(
					"section",
					""
				)
			).strip_edges()

		print(
			"[QuizPage] Quiz section: ",
			quiz_section
		)

		if quiz_section != student_section:

			print(
				"[QuizPage] Quiz rejected because section does not match."
			)

			continue

		print(
			"[QuizPage] Quiz matches student section: ",
			student_section
		)

		quizzes.append(
			quiz
		)

	print(
		"[QuizPage] Matching quizzes: ",
		quizzes.size()
	)

	if quizzes.is_empty():

		_show_no_quizzes(
			"No quizzes available for your section."
		)

		return

	_apply_sort()

	_build_quiz_list()


# ============================================================
# PARSE QUIZ DOCUMENT
# ============================================================

func _parse_quiz_document(
	fields: Dictionary,
	document: Dictionary
) -> Dictionary:

	var quiz: Dictionary = {}

	quiz["quiz_id"] = \
		_get_string_field(
			fields,
			"quiz_id"
		)

	quiz["teacher_id"] = \
		_get_string_field(
			fields,
			"teacher_id"
		)

	quiz["title"] = \
		_get_string_field(
			fields,
			"title"
		)

	if str(
		quiz["title"]
	).strip_edges().is_empty():

		quiz["title"] = \
			"Untitled Quiz"

	quiz["section"] = \
		_get_string_field(
			fields,
			"section"
		)

	quiz["quiz_type"] = \
		_get_string_field(
			fields,
			"quiz_type"
		)

	quiz["question_count"] = \
		_get_integer_field(
			fields,
			"question_count"
		)

	quiz["questions"] = \
		_get_questions_field(
			fields,
			"questions"
		)

	quiz["created_at"] = \
		_get_string_field(
			fields,
			"created_at"
		)

	quiz["document_name"] = \
		str(
			document.get(
				"name",
				""
			)
		)

	var questions: Array = \
		quiz["questions"]

	if questions.is_empty():

		print(
			"[QuizPage] Quiz rejected because it has no questions."
		)

		return {}

	return quiz


# ============================================================
# GET QUESTIONS
# ============================================================

func _get_questions_field(
	fields: Dictionary,
	field_name: String
) -> Array:

	if not fields.has(field_name):
		return []

	var field = fields[field_name]

	if not field is Dictionary:
		return []

	var array_value = \
		field.get(
			"arrayValue",
			{}
		)

	if not array_value is Dictionary:
		return []

	var values = \
		array_value.get(
			"values",
			[]
		)

	if not values is Array:
		return []

	var result: Array = []

	for value in values:

		if not value is Dictionary:
			continue

		var map_value = \
			value.get(
				"mapValue",
				{}
			)

		if not map_value is Dictionary:
			continue

		var question_fields = \
			map_value.get(
				"fields",
				{}
			)

		if not question_fields is Dictionary:
			continue

		var question_data: Dictionary = {}

		question_data["question"] = \
			_get_string_field(
				question_fields,
				"question"
			)

		question_data["type"] = \
			_get_string_field(
				question_fields,
				"type"
			)

		question_data["answers"] = \
			_get_string_array_field(
				question_fields,
				"answers"
			)

		question_data["correct_answers"] = \
			_get_integer_array_field(
				question_fields,
				"correct_answers"
			)

		if str(
			question_data["question"]
		).strip_edges().is_empty():

			continue

		result.append(
			question_data
		)

	return result


# ============================================================
# BUILD QUIZ LIST
# ============================================================

func _build_quiz_list() -> void:

	for child in quiz_list.get_children():

		child.queue_free()

	await get_tree().process_frame

	status_label.text = \
		str(quizzes.size()) \
		+ " quiz(es) available."

	for index in range(
		quizzes.size()
	):

		var quiz: Dictionary = \
			quizzes[index]

		_create_quiz_list_item(
			quiz,
			index
		)


# ============================================================
# CREATE QUIZ ITEM
# ============================================================

func _create_quiz_list_item(
	quiz: Dictionary,
	index: int
) -> void:

	var button := Button.new()

	button.name = \
		"Quiz_" + str(index)

	button.custom_minimum_size = \
		Vector2(0, 90)

	button.size_flags_horizontal = \
		Control.SIZE_EXPAND_FILL

	var title := \
		str(
			quiz.get(
				"title",
				"Untitled Quiz"
			)
		)

	var quiz_type := \
		str(
			quiz.get(
				"quiz_type",
				""
			)
		)

	var question_count := \
		int(
			quiz.get(
				"question_count",
				0
			)
		)

	button.text = (
		title
		+ "\n"
		+ quiz_type.capitalize()
		+ " • "
		+ str(question_count)
		+ " question(s)"
	)

	button.add_theme_font_size_override(
		"font_size",
		20
	)

	button.pressed.connect(
		_on_quiz_selected.bind(index)
	)

	quiz_list.add_child(
		button
	)


# ============================================================
# QUIZ SELECTED
# ============================================================

func _on_quiz_selected(index: int) -> void:

	if index < 0:
		return

	if index >= quizzes.size():
		return

	var quiz: Dictionary = quizzes[index]

	print(
		"[QuizPage] Quiz selected: ",
		quiz.get(
			"title",
			"Untitled Quiz"
		)
	)

	print(
		"[QuizPage] Quiz ID: ",
		quiz.get(
			"quiz_id",
			""
		)
	)

	# --------------------------------------------------------
	# Open the quiz-taking page
	# --------------------------------------------------------

	var quiz_scene := preload(
		"res://Scenes/UI/quiz_taking_page.tscn"
	)

	var quiz_taking_page = quiz_scene.instantiate()

	# Give the selected quiz to the quiz-taking page
	quiz_taking_page.quiz_data = quiz

	# --------------------------------------------------------
	# IMPORTANT:
	# Add the quiz-taking page to the SAME PARENT
	# where QuizPage currently exists.
	#
	# This keeps the GameMenu and StartMap intact.
	# --------------------------------------------------------

	var parent_node := get_parent()

	if parent_node == null:
		print("[QuizPage] ERROR: QuizPage has no parent.")
		quiz_taking_page.queue_free()
		return

	parent_node.add_child(quiz_taking_page)

	# --------------------------------------------------------
	# Remove only the quiz list page.
	# GameMenu remains open.
	# --------------------------------------------------------

	queue_free()

	print("[QuizPage] QuizTakingPage opened inside GameMenu.")


# ============================================================
# SEARCH
# ============================================================

func _on_search_text_changed(
	new_text: String
) -> void:

	var search_text := \
		new_text.strip_edges().to_lower()

	for child in quiz_list.get_children():

		if not child is Button:
			continue

		var button: Button = child

		var visible := true

		if not search_text.is_empty():

			visible = \
				button.text.to_lower().contains(
					search_text
				)

		button.visible = visible


# ============================================================
# FILTER
# ============================================================

func _on_filter_selected(
	index: int
) -> void:

	var selected_type := ""

	match index:

		0:
			selected_type = ""

		1:
			selected_type = "multiple choice"

		2:
			selected_type = "true or false"

		3:
			selected_type = "identification"

	_apply_filter(
		selected_type
	)


func _apply_filter(
	selected_type: String
) -> void:

	for index in range(
		quiz_list.get_child_count()
	):

		var child := \
			quiz_list.get_child(index)

		if not child is Button:
			continue

		var button: Button = child

		if selected_type.is_empty():

			button.visible = true

			continue

		var quiz_type := \
			str(
				quizzes[index].get(
					"quiz_type",
					""
				)
			).to_lower()

		button.visible = \
			quiz_type == selected_type


# ============================================================
# SORT
# ============================================================

func _on_sort_selected(
	_index: int
) -> void:

	_apply_sort()

	_build_quiz_list()


func _apply_sort() -> void:

	var sort_index := \
		sort_button.selected

	match sort_index:

		0:
			quizzes.sort_custom(
				_sort_newest
			)

		1:
			quizzes.sort_custom(
				_sort_oldest
			)

		2:
			quizzes.sort_custom(
				_sort_title_ascending
			)

		3:
			quizzes.sort_custom(
				_sort_title_descending
			)


func _sort_newest(
	a: Dictionary,
	b: Dictionary
) -> bool:

	return str(
		a.get(
			"created_at",
			""
		)
	) > str(
		b.get(
			"created_at",
			""
		)
	)


func _sort_oldest(
	a: Dictionary,
	b: Dictionary
) -> bool:

	return str(
		a.get(
			"created_at",
			""
		)
	) < str(
		b.get(
			"created_at",
			""
		)
	)


func _sort_title_ascending(
	a: Dictionary,
	b: Dictionary
) -> bool:

	return str(
		a.get(
			"title",
			""
		)
	).to_lower() < str(
		b.get(
			"title",
			""
		)
	).to_lower()


func _sort_title_descending(
	a: Dictionary,
	b: Dictionary
) -> bool:

	return str(
		a.get(
			"title",
			""
		)
	).to_lower() > str(
		b.get(
			"title",
			""
		)
	).to_lower()


# ============================================================
# REFRESH
# ============================================================

func _on_refresh_pressed() -> void:

	print(
		"[QuizPage] Refreshing quizzes..."
	)

	status_label.text = \
		"Refreshing quizzes..."

	load_quizzes()


# ============================================================
# SHOW NO QUIZZES
# ============================================================

func _show_no_quizzes(
	message: String
) -> void:

	quizzes.clear()

	for child in quiz_list.get_children():

		child.queue_free()

	status_label.text = message


# ============================================================
# STRING FIELD
# ============================================================

func _get_string_field(
	fields: Dictionary,
	field_name: String
) -> String:

	if not fields.has(field_name):
		return ""

	var field = fields[field_name]

	if not field is Dictionary:
		return ""

	if field.has("stringValue"):

		return str(
			field["stringValue"]
		)

	if field.has("timestampValue"):

		return str(
			field["timestampValue"]
		)

	return ""


# ============================================================
# INTEGER FIELD
# ============================================================

func _get_integer_field(
	fields: Dictionary,
	field_name: String
) -> int:

	if not fields.has(field_name):
		return 0

	var field = fields[field_name]

	if not field is Dictionary:
		return 0

	if field.has("integerValue"):

		return int(
			field["integerValue"]
		)

	if field.has("doubleValue"):

		return int(
			field["doubleValue"]
		)

	return 0


# ============================================================
# STRING ARRAY FIELD
# ============================================================

func _get_string_array_field(
	fields: Dictionary,
	field_name: String
) -> Array:

	var result: Array = []

	if not fields.has(field_name):
		return result

	var field = fields[field_name]

	if not field is Dictionary:
		return result

	var array_value = \
		field.get(
			"arrayValue",
			{}
		)

	if not array_value is Dictionary:
		return result

	var values = \
		array_value.get(
			"values",
			[]
		)

	if not values is Array:
		return result

	for value in values:

		if not value is Dictionary:
			continue

		if value.has("stringValue"):

			result.append(
				str(
					value["stringValue"]
				)
			)

	return result


# ============================================================
# INTEGER ARRAY FIELD
# ============================================================

func _get_integer_array_field(
	fields: Dictionary,
	field_name: String
) -> Array:

	var result: Array = []

	if not fields.has(field_name):
		return result

	var field = fields[field_name]

	if not field is Dictionary:
		return result

	var array_value = \
		field.get(
			"arrayValue",
			{}
		)

	if not array_value is Dictionary:
		return result

	var values = \
		array_value.get(
			"values",
			[]
		)

	if not values is Array:
		return result

	for value in values:

		if not value is Dictionary:
			continue

		if value.has("integerValue"):

			result.append(
				int(
					value["integerValue"]
				)
			)

		elif value.has("doubleValue"):

			result.append(
				int(
					value["doubleValue"]
				)
			)

	return result


# ============================================================
# FIREBASE UID
# ============================================================

func _get_uid() -> String:

	if StudentDataManager != null:

		if StudentDataManager.has_method(
			"get_student_uid"
		):

			var student_uid := \
				str(
					StudentDataManager.get_student_uid()
				)

			if not student_uid.is_empty():

				return student_uid

	if Firebase.Auth == null:
		return ""

	var auth_data: Dictionary = {}

	if Firebase.Auth.has_method(
		"get_auth"
	):

		var result = \
			Firebase.Auth.get_auth()

		if result is Dictionary:

			auth_data = result

	else:

		var auth_property = \
			Firebase.Auth.get("auth")

		if auth_property is Dictionary:

			auth_data = \
				auth_property

	if auth_data.is_empty():
		return ""

	if auth_data.has("localid"):

		return str(
			auth_data["localid"]
		)

	if auth_data.has("localId"):

		return str(
			auth_data["localId"]
		)

	if auth_data.has("uid"):

		return str(
			auth_data["uid"]
		)

	return ""


# ============================================================
# FIREBASE ID TOKEN
# ============================================================

func _get_id_token() -> String:

	if Firebase.Auth == null:

		print(
			"[QuizPage] Firebase.Auth is null."
		)

		return ""

	var auth_data: Dictionary = {}

	if Firebase.Auth.has_method(
		"get_auth"
	):

		var result = \
			Firebase.Auth.get_auth()

		if result is Dictionary:

			auth_data = result

	else:

		var auth_property = \
			Firebase.Auth.get("auth")

		if auth_property is Dictionary:

			auth_data = \
				auth_property

	if auth_data.is_empty():

		print(
			"[QuizPage] Firebase auth data is empty."
		)

		return ""

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

	if token.is_empty():

		print(
			"[QuizPage] Could not find ID token."
		)

	else:

		print(
			"[QuizPage] Firebase ID token obtained."
		)

	return token

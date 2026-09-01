extends Control


# ============================================================
# SCENES
# ============================================================

const QUIZ_CHOICES = preload(
	"res://Scenes/Admin/Teacher/quiz_choises.tscn"
)

const QUIZ_ROW = preload(
	"res://Scenes/Admin/Teacher/quiz_row.tscn"
)


# ============================================================
# FIRESTORE
# ============================================================

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

var firestore_url: String


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var rows: VBoxContainer = \
	$QuizPanel/MarginContainer/VBoxContainer/StudentTable/ScrollContainer/Rows

@onready var search_bar: LineEdit = \
	$QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SearchPanel/SearchBar

@onready var filter_button: OptionButton = \
	$QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/FilterPanel/FilterButton

@onready var sort_button: OptionButton = \
	$QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SortPanel/SortButton

@onready var refresh_button: Button = \
	$QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/RefreshPanel/RefreshButton


# ============================================================
# QUIZ DATA
# ============================================================

var quizzes: Array[Dictionary] = []

var filtered_quizzes: Array[Dictionary] = []


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[QuizManagement] Quiz Management opened.")

	firestore_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/quizzes"
	)

	_setup_filters()
	_connect_buttons()

	load_quizzes()


# ============================================================
# SETUP FILTERS
# ============================================================

func _setup_filters() -> void:

	if filter_button != null:

		filter_button.clear()

		filter_button.add_item("All Quiz Types")
		filter_button.add_item("Multiple Choice")

		filter_button.select(0)


	if sort_button != null:

		sort_button.clear()

		sort_button.add_item("Newest First")
		sort_button.add_item("Oldest First")
		sort_button.add_item("Title A-Z")
		sort_button.add_item("Title Z-A")

		sort_button.select(0)


# ============================================================
# CONNECT BUTTONS
# ============================================================

func _connect_buttons() -> void:

	if search_bar != null:

		if not search_bar.text_changed.is_connected(
			_on_search_changed
		):

			search_bar.text_changed.connect(
				_on_search_changed
			)


	if filter_button != null:

		if not filter_button.item_selected.is_connected(
			_on_filter_changed
		):

			filter_button.item_selected.connect(
				_on_filter_changed
			)


	if sort_button != null:

		if not sort_button.item_selected.is_connected(
			_on_sort_changed
		):

			sort_button.item_selected.connect(
				_on_sort_changed
			)


	if refresh_button != null:

		if not refresh_button.pressed.is_connected(
			_on_refresh_pressed
		):

			refresh_button.pressed.connect(
				_on_refresh_pressed
			)


# ============================================================
# LOAD QUIZZES
# ============================================================

func load_quizzes() -> void:

	print("[QuizManagement] Loading quizzes from Firestore...")

	quizzes.clear()

	var token := _get_id_token()

	if token.is_empty():

		print(
			"[QuizManagement] ERROR: Firebase ID token is empty."
		)

		display_quizzes()

		return


	var http := HTTPRequest.new()

	add_child(http)

	http.request_completed.connect(
		_on_load_quizzes_completed.bind(http)
	)


	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	])


	print(
		"[QuizManagement] Firestore URL: ",
		firestore_url
	)


	var error := http.request(
		firestore_url,
		headers,
		HTTPClient.METHOD_GET
	)


	if error != OK:

		print(
			"[QuizManagement] ERROR: Failed to request quizzes. Error: ",
			error
		)

		http.queue_free()


# ============================================================
# LOAD QUIZZES RESPONSE
# ============================================================

func _on_load_quizzes_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:

	var response_text := \
		body.get_string_from_utf8()


	print(
		"[QuizManagement] Firestore response code: ",
		response_code
	)


	if response_code != 200:

		print(
			"[QuizManagement] ERROR loading quizzes."
		)

		print(
			"[QuizManagement] Response: ",
			response_text
		)

		http.queue_free()

		display_quizzes()

		return


	var json := JSON.new()

	var parse_error := json.parse(
		response_text
	)


	if parse_error != OK:

		print(
			"[QuizManagement] ERROR: Could not parse Firestore response."
		)

		http.queue_free()

		display_quizzes()

		return


	var data = json.data


	if not data is Dictionary:

		print(
			"[QuizManagement] ERROR: Firestore response is not a Dictionary."
		)

		http.queue_free()

		display_quizzes()

		return


	var documents = data.get(
		"documents",
		[]
	)


	if not documents is Array:

		print(
			"[QuizManagement] ERROR: documents is not an Array."
		)

		http.queue_free()

		display_quizzes()

		return


	print(
		"[QuizManagement] Firestore returned ",
		documents.size(),
		" quiz documents."
	)


	# ========================================================
	# CONVERT FIRESTORE DOCUMENTS
	# ========================================================

	for document in documents:

		if not document is Dictionary:
			continue


		var fields: Dictionary = document.get(
			"fields",
			{}
		)


		if fields.is_empty():
			continue


		var quiz := _firestore_document_to_quiz(
			document
		)


		if quiz.is_empty():
			continue


		quizzes.append(
			quiz
		)


		print(
			"[QuizManagement] Loaded quiz: ",
			quiz.get("title", "Untitled Quiz")
		)


	http.queue_free()


	# ========================================================
	# DISPLAY
	# ========================================================

	display_quizzes()


# ============================================================
# CONVERT FIRESTORE DOCUMENT
# ============================================================

func _firestore_document_to_quiz(
	document: Dictionary
) -> Dictionary:

	var fields: Dictionary = document.get(
		"fields",
		{}
	)


	var quiz_id := _firestore_string(
		fields.get("quiz_id", {})
	)


	var title := _firestore_string(
		fields.get("title", {})
	)


	var teacher_id := _firestore_string(
		fields.get("teacher_id", {})
	)


	var quiz_type := _firestore_string(
		fields.get("quiz_type", {})
	)


	var question_count := _firestore_integer(
		fields.get("question_count", {})
	)


	var created_at := _firestore_string(
		fields.get("created_at", {})
	)


	# --------------------------------------------------------
	# Questions
	# --------------------------------------------------------

	var questions: Array = []

	var questions_field: Dictionary = fields.get(
		"questions",
		{}
	)


	var array_value: Dictionary = questions_field.get(
		"arrayValue",
		{}
	)


	var question_values: Array = array_value.get(
		"values",
		[]
	)


	for question_value in question_values:

		if not question_value is Dictionary:
			continue


		var map_value: Dictionary = question_value.get(
			"mapValue",
			{}
		)


		var question_fields: Dictionary = map_value.get(
			"fields",
			{}
		)


		var question_text := _firestore_string(
			question_fields.get(
				"question",
				{}
			)
		)


		var type := _firestore_string(
			question_fields.get(
				"type",
				{}
			)
		)


		var answers: Array = []

		var answers_field: Dictionary = \
			question_fields.get(
				"answers",
				{}
			)


		var answers_array: Dictionary = \
			answers_field.get(
				"arrayValue",
				{}
			)


		var answer_values: Array = \
			answers_array.get(
				"values",
				[]
			)


		for answer_value in answer_values:

			answers.append(
				_firestore_string(answer_value)
			)


		var correct_answers: Array = []

		var correct_field: Dictionary = \
			question_fields.get(
				"correct_answers",
				{}
			)


		var correct_array: Dictionary = \
			correct_field.get(
				"arrayValue",
				{}
			)


		var correct_values: Array = \
			correct_array.get(
				"values",
				[]
			)


		for correct_value in correct_values:

			correct_answers.append(
				_firestore_integer(correct_value)
			)


		questions.append(
			{
				"question": question_text,
				"type": type,
				"answers": answers,
				"correct_answers": correct_answers
			}
		)


	# --------------------------------------------------------
	# Return quiz
	# --------------------------------------------------------

	return {
		"quiz_id": quiz_id,
		"title": title,
		"teacher_id": teacher_id,
		"quiz_type": quiz_type,
		"question_count": question_count,
		"questions": questions,
		"created_at": created_at
	}


# ============================================================
# FIRESTORE STRING
# ============================================================

func _firestore_string(
	value: Dictionary
) -> String:

	if value.has("stringValue"):

		return str(
			value.get("stringValue", "")
		)

	return ""


# ============================================================
# FIRESTORE INTEGER
# ============================================================

func _firestore_integer(
	value: Dictionary
) -> int:

	if value.has("integerValue"):

		return int(
			value.get("integerValue", "0")
		)

	if value.has("doubleValue"):

		return int(
			float(
				value.get("doubleValue", 0)
			)
		)

	return 0


# ============================================================
# DISPLAY QUIZZES
# ============================================================

func display_quizzes() -> void:

	# --------------------------------------------------------
	# Remove old rows
	# --------------------------------------------------------

	for child in rows.get_children():

		child.queue_free()


	# --------------------------------------------------------
	# Apply search/filter/sort
	# --------------------------------------------------------

	filtered_quizzes = quizzes.duplicate()

	_apply_search_filter()
	_apply_type_filter()
	_apply_sort()


	# --------------------------------------------------------
	# Create rows
	# --------------------------------------------------------

	for quiz in filtered_quizzes:

		var row := QUIZ_ROW.instantiate()

		rows.add_child(row)


		# ----------------------------------------------------
		# Pass quiz data to quiz_row.gd
		# ----------------------------------------------------

		if row.has_method("setup_quiz"):

			row.setup_quiz(
				quiz
			)

		else:

			print(
				"[QuizManagement] WARNING: quiz_row.tscn does not have setup_quiz()."
			)


	print(
		"[QuizManagement] Displayed ",
		filtered_quizzes.size(),
		" quizzes."
	)


# ============================================================
# SEARCH
# ============================================================

func _apply_search_filter() -> void:

	if search_bar == null:
		return


	var search_text := \
		search_bar.text.strip_edges().to_lower()


	if search_text.is_empty():
		return


	var result: Array[Dictionary] = []


	for quiz in filtered_quizzes:

		var title := str(
			quiz.get(
				"title",
				""
			)
		).to_lower()


		var quiz_id := str(
			quiz.get(
				"quiz_id",
				""
			)
		).to_lower()


		if title.contains(search_text) \
		or quiz_id.contains(search_text):

			result.append(
				quiz
			)


	filtered_quizzes = result


# ============================================================
# TYPE FILTER
# ============================================================

func _apply_type_filter() -> void:

	if filter_button == null:
		return


	var selected := \
		filter_button.selected


	# 0 = All
	if selected == 0:
		return


	var result: Array[Dictionary] = []


	for quiz in filtered_quizzes:

		var quiz_type := str(
			quiz.get(
				"quiz_type",
				""
			)
		).to_lower()


		if quiz_type == "multiple_choice":

			result.append(
				quiz
			)


	filtered_quizzes = result


# ============================================================
# SORT
# ============================================================

func _apply_sort() -> void:

	if sort_button == null:
		return


	var selected := \
		sort_button.selected


	# Newest first
	if selected == 0:

		filtered_quizzes.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:

				return str(
					a.get("created_at", "")
				) > str(
					b.get("created_at", "")
				)
		)


	# Oldest first
	elif selected == 1:

		filtered_quizzes.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:

				return str(
					a.get("created_at", "")
				) < str(
					b.get("created_at", "")
				)
		)


	# Title A-Z
	elif selected == 2:

		filtered_quizzes.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:

				return str(
					a.get("title", "")
				).to_lower() < str(
					b.get("title", "")
				).to_lower()
		)


	# Title Z-A
	elif selected == 3:

		filtered_quizzes.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:

				return str(
					a.get("title", "")
				).to_lower() > str(
					b.get("title", "")
				).to_lower()
		)


# ============================================================
# SEARCH CHANGED
# ============================================================

func _on_search_changed(
	new_text: String
) -> void:

	display_quizzes()


# ============================================================
# FILTER CHANGED
# ============================================================

func _on_filter_changed(
	index: int
) -> void:

	display_quizzes()


# ============================================================
# SORT CHANGED
# ============================================================

func _on_sort_changed(
	index: int
) -> void:

	display_quizzes()


# ============================================================
# REFRESH
# ============================================================

func _on_refresh_pressed() -> void:

	print(
		"[QuizManagement] Refresh pressed."
	)

	load_quizzes()


# ============================================================
# CREATE QUIZ
# ============================================================

func _on_create_quiz_pressed() -> void:

	print(
		"[QuizManagement] Create Quiz pressed."
	)


	var choices := \
		QUIZ_CHOICES.instantiate()


	get_tree().current_scene.add_child(
		choices
	)


# ============================================================
# FIREBASE ID TOKEN
# ============================================================

func _get_id_token() -> String:

	if Firebase.Auth == null:

		print(
			"[QuizManagement] Firebase.Auth is null."
		)

		return ""


	var auth_data: Dictionary = \
		Firebase.Auth.auth


	if auth_data.is_empty():

		print(
			"[QuizManagement] Firebase.Auth.auth is empty."
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
			"[QuizManagement] Could not find Firebase ID token."
		)

		return ""


	return token


extends Control

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

const QUIZ_CARD_SCENE := preload(
	"res://Scenes/UI/Student/quiz_card_student.tscn"
)

const QUIZ_FORM_SCENE := preload(
	"res://Scenes/UI/qiuz_form.tscn"
)

var firestore_url: String = ""

var quizzes: Array[Dictionary] = []
var completed_quiz_ids: Dictionary = {}

var quiz_loading: bool = false
var student_section: String = ""
var selected_filter: String = ""

@onready var title_label: Label = $QuizPanel/MarginContainer/VBoxContainer/Header/Title
@onready var section_label: Label = $QuizPanel/MarginContainer/VBoxContainer/Header/SectionLabel
@onready var search_bar: LineEdit = $QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SearchPanel/SearchBar
@onready var filter_button: OptionButton = $QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/FilterPanel/FilterButton
@onready var quiz_scroll: ScrollContainer = $QuizPanel/MarginContainer/VBoxContainer/QuizScroll
@onready var quiz_list: GridContainer = $QuizPanel/MarginContainer/VBoxContainer/QuizScroll/CenterContainer/QuizList
@onready var status_label: Label = $QuizPanel/MarginContainer/VBoxContainer/StatusLabel


func _ready() -> void:
	firestore_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/quizzes"
	)

	search_bar.text_changed.connect(_on_search_text_changed)
	filter_button.item_selected.connect(_on_filter_selected)

	_setup_filter_button()
	
	# Check school-year learning access before loading quizzes.
	var access_allowed := await _check_learning_access()

	if not access_allowed:
		return


	status_label.text = "Loading student information..."

	await _load_student_section()

	if student_section.is_empty():
		section_label.text = "Section unavailable"
		status_label.text = "Unable to determine your section."
		return

	section_label.text = "Section: " + student_section

	status_label.text = "Loading quiz progress..."
	await _load_completed_quizzes()

	await load_quizzes()


func _setup_filter_button() -> void:
	filter_button.clear()

	filter_button.add_item("All Quiz Types")
	filter_button.add_item("Multiple Choice")
	filter_button.add_item("True or False")
	filter_button.add_item("Identification")
	filter_button.add_item("Enumeration")

	filter_button.select(0)



func _check_learning_access() -> bool:
	print("[QuizPage] Checking learning access...")

	var uid := AuthManager.get_uid()

	if uid.is_empty():
		status_label.text = "Unable to verify your account. Please log in again."
		push_warning("[QuizPage] UID is empty. Access denied.")
		return false

	# Retrieve the user's role.
	var role: String = await AuthManager.get_user_role()

	print("[QuizPage] User role: ", role)

	# Admin and teachers are not restricted.
	if role == "admin" or role == "teacher":
		print("[QuizPage] Staff account. Quiz access granted.")
		return true

	# Unknown roles are blocked.
	if role != "student":
		status_label.text = "Unable to verify your account role."
		push_warning("[QuizPage] Unknown role. Quiz access denied.")
		return false

	# Check whether the student's school year is active.
	var access_result: Dictionary = await SchoolYearAccess.check_student_learning_access(uid)

	if not access_result.get("success", false):
		status_label.text = "Unable to verify your school year. Please try again later."
		push_warning("[QuizPage] School-year verification failed.")
		return false

	if not access_result.get("allowed", false):
		status_label.text = "Your school year is inactive. Game access is available, but quizzes and assessments are restricted."
		print("[QuizPage] Inactive school year. Quiz access denied.")
		return false

	print("[QuizPage] Active school year. Quiz access granted.")
	return true
	



func _load_student_section() -> void:
	var uid := _get_uid()
	var token := _get_id_token()

	if uid.is_empty() or token.is_empty():
		return

	var student_url := (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/students/"
		+ uid
	)

	var data: Dictionary = await _firestore_get(student_url, token)

	if data.is_empty():
		return

	var fields: Dictionary = data.get("fields", {})

	student_section = _get_string_field(
		fields,
		"section"
	).strip_edges()


func _load_completed_quizzes() -> void:
	completed_quiz_ids.clear()

	var uid := _get_uid()
	var token := _get_id_token()

	if uid.is_empty() or token.is_empty():
		return

	var assessment_url := (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/students/"
		+ uid
	)

	var data: Dictionary = await _firestore_get(assessment_url, token)

	if data.is_empty():
		return

	var fields: Dictionary = data.get("fields", {})
	var assessment_field = fields.get("assessment", {})

	if not assessment_field is Dictionary:
		return

	var assessment_map: Dictionary = assessment_field.get("mapValue", {})
	var assessment_fields: Dictionary = assessment_map.get("fields", {})

	for assessment_key in assessment_fields.keys():
		var quiz_entry = assessment_fields[assessment_key]

		if not quiz_entry is Dictionary:
			continue

		var quiz_map: Dictionary = quiz_entry.get("mapValue", {})
		var quiz_fields: Dictionary = quiz_map.get("fields", {})

		if not _get_boolean_field(quiz_fields, "completed"):
			continue

		var saved_quiz_id := _get_string_field(
			quiz_fields,
			"quiz_id"
		).strip_edges()

		if saved_quiz_id.is_empty():
			saved_quiz_id = str(assessment_key).strip_edges()

		if saved_quiz_id.is_empty():
			continue
			
		#

		var student_answers: Dictionary = {}

		var student_answers_field: Dictionary = quiz_fields.get(
			"student_answers",
			{}
		)

		var student_answers_map: Dictionary = student_answers_field.get(
			"mapValue",
			{}
		)

		var student_answers_fields: Dictionary = student_answers_map.get(
			"fields",
			{}
		)

		for question_index in student_answers_fields.keys():
			var answer_field: Dictionary = student_answers_fields[question_index]

			if answer_field.has("stringValue"):
				student_answers[int(question_index)] = answer_field.get("stringValue", "")

			elif answer_field.has("integerValue"):
				student_answers[int(question_index)] = int(answer_field.get("integerValue", "0"))

			elif answer_field.has("arrayValue"):
				var array_data: Dictionary = answer_field.get("arrayValue", {})
				var array_values: Array = array_data.get("values", [])
				var parsed_answers: Array = []

				for answer_value in array_values:
					if answer_value is Dictionary:
						if answer_value.has("integerValue"):
							parsed_answers.append(int(answer_value.get("integerValue", "0")))
						elif answer_value.has("stringValue"):
							parsed_answers.append(str(answer_value.get("stringValue", "")))

				student_answers[int(question_index)] = parsed_answers

		var assessment: Dictionary = {
			"quiz_id": saved_quiz_id,
			"quiz_title": _get_string_field(quiz_fields, "quiz_title"),
			"score": _get_integer_field(quiz_fields, "score"),
			"total_questions": _get_integer_field(quiz_fields, "total_questions"),
			"percentage": _get_float_field(quiz_fields, "percentage"),
			"completed": true,
			"completed_at": _get_string_field(quiz_fields, "completed_at"),
			"student_answers": student_answers
		}

		completed_quiz_ids[saved_quiz_id] = assessment

	print("[QuizPage] Completed assessments loaded: ", completed_quiz_ids.size())



func _firestore_get(url: String, token: String) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	])

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		http.queue_free()
		return {}

	var response: Array = await http.request_completed
	http.queue_free()

	var response_code: int = response[1]

	if response_code != 200:
		return {}

	var response_text: String = response[3].get_string_from_utf8()
	var data = JSON.parse_string(response_text)

	if not data is Dictionary:
		return {}

	return data


func load_quizzes() -> void:
	if quiz_loading:
		return

	quiz_loading = true
	status_label.text = "Loading quizzes..."

	var token := _get_id_token()

	if token.is_empty():
		quiz_loading = false
		_show_no_quizzes("Authentication failed.")
		return

	var data: Dictionary = await _firestore_get(
		firestore_url,
		token
	)

	quiz_loading = false

	if data.is_empty():
		_show_no_quizzes("Could not load quizzes.")
		return

	var documents = data.get("documents", [])

	if not documents is Array:
		_show_no_quizzes("No quizzes are available.")
		return

	quizzes.clear()

	for document in documents:
		if not document is Dictionary:
			continue

		var fields: Dictionary = document.get("fields", {})
		var quiz := _parse_quiz_document(fields, document)

		if quiz.is_empty():
			continue

		# Check whether this quiz is assigned to the student's section.
		var assigned_sections: Array = quiz.get(
			"assigned_sections",
			[]
		)

		if not assigned_sections.has(student_section):
			continue

		quizzes.append(quiz)

	if quizzes.is_empty():
		_show_no_quizzes(
			"No quizzes available for your section."
		)
		return

	_build_quiz_list()


func _parse_quiz_document(
	fields: Dictionary,
	document: Dictionary
) -> Dictionary:
	var quiz: Dictionary = {}

	quiz["quiz_id"] = _get_string_field(
		fields,
		"quiz_id"
	).strip_edges()

	if str(quiz["quiz_id"]).is_empty():
		quiz["quiz_id"] = _get_quiz_id_from_document_name(
			str(document.get("name", ""))
		)

	quiz["teacher_id"] = _get_string_field(
		fields,
		"teacher_id"
	)

	quiz["title"] = _get_string_field(
		fields,
		"title"
	)

	# Read the new assigned_sections array.
	quiz["assigned_sections"] = _get_string_array_field(
		fields,
		"assigned_sections"
	)

	quiz["quiz_type"] = _get_string_field(
		fields,
		"quiz_type"
	)

	quiz["question_count"] = _get_integer_field(
		fields,
		"question_count"
	)

	quiz["questions"] = _get_questions_field(
		fields,
		"questions"
	)

	quiz["created_at"] = _get_string_field(
		fields,
		"created_at"
	)

	quiz["document_name"] = str(
		document.get("name", "")
	)

	if str(quiz["title"]).strip_edges().is_empty():
		quiz["title"] = "Untitled Quiz"

	if quiz["questions"].is_empty():
		return {}

	return quiz


func _get_quiz_id_from_document_name(document_name: String) -> String:
	if document_name.is_empty():
		return ""

	var parts := document_name.split("/")

	if parts.is_empty():
		return ""

	return str(parts[parts.size() - 1])


func _get_questions_field(fields: Dictionary, field_name: String) -> Array:
	var result: Array = []

	if not fields.has(field_name):
		return result

	var field = fields[field_name]

	if not field is Dictionary:
		return result

	var array_value: Dictionary = field.get("arrayValue", {})
	var values = array_value.get("values", [])

	if not values is Array:
		return result

	for value in values:
		if not value is Dictionary:
			continue

		var map_value: Dictionary = value.get("mapValue", {})
		var question_fields: Dictionary = map_value.get("fields", {})

		if question_fields.is_empty():
			continue

		var question_data: Dictionary = {}

		question_data["question"] = _get_string_field(
			question_fields,
			"question"
		)

		question_data["type"] = _get_string_field(
			question_fields,
			"type"
		)

		question_data["answers"] = _get_string_array_field(
			question_fields,
			"answers"
		)

		question_data["correct_answers"] = _get_integer_array_field(
			question_fields,
			"correct_answers"
		)

		if str(question_data["question"]).strip_edges().is_empty():
			continue

		result.append(question_data)

	return result


func _build_quiz_list() -> void:
	for child in quiz_list.get_children():
		child.queue_free()

	await get_tree().process_frame

	var available_count := 0
	var completed_count := 0

	for quiz in quizzes:
		if _is_quiz_completed(
			str(quiz.get("quiz_id", "")),
			quiz
		):
			completed_count += 1
		else:
			available_count += 1

	status_label.text = (
		str(available_count)
		+ " quiz(es) available. "
		+ str(completed_count)
		+ " completed."
	)

	for index in range(quizzes.size()):
		_create_quiz_card(quizzes[index], index)

	_apply_filters()


func _is_quiz_completed(quiz_id: String, quiz: Dictionary) -> bool:
	quiz_id = quiz_id.strip_edges()

	if not quiz_id.is_empty() and completed_quiz_ids.has(quiz_id):
		return true

	var document_name := str(
		quiz.get("document_name", "")
	)

	var document_quiz_id := _get_quiz_id_from_document_name(
		document_name
	)

	return (
		not document_quiz_id.is_empty()
		and completed_quiz_ids.has(document_quiz_id)
	)


func _create_quiz_card(quiz: Dictionary, index: int) -> void:
	var card := QUIZ_CARD_SCENE.instantiate()

	card.name = "QuizCard_" + str(index)
	card.set_meta("quiz_index", index)

	var title_label_node := card.find_child("QuizTitle", true, false) as Label
	var type_label := card.find_child("QuizType", true, false) as Label
	var item_count_label := card.find_child("ItemCount", true, false) as Label
	var status_node := card.find_child("Status", true, false) as Label
	var score_label := card.find_child("Score", true, false) as Label

	var take_button := card.find_child("TakeQuizButton", true, false) as Button
	var view_button := card.find_child("ViewAssessmentButton", true, false) as Button

	var title := str(quiz.get("title", "Untitled Quiz"))
	var quiz_type := str(quiz.get("quiz_type", ""))
	var question_count := int(
		quiz.get("question_count", quiz.get("questions", []).size())
	)

	var quiz_id := str(quiz.get("quiz_id", ""))

	var completed := _is_quiz_completed(quiz_id, quiz)

	if title_label_node:
		title_label_node.text = title

	if type_label:
		type_label.text = _format_quiz_type(quiz_type)

	if item_count_label:
		item_count_label.text = str(question_count) + " Item(s)"

	if status_node:
		status_node.text = "Completed" if completed else "Available"

	# ------------------------------------------------
	# COMPLETED ASSESSMENT SCORE
	# ------------------------------------------------

	if completed:
		var assessment: Dictionary = completed_quiz_ids.get(
			quiz_id,
			{}
		)

		var score := int(assessment.get("score", 0))
		var total := int(assessment.get("total_questions", 0))

		if score_label:
			if total > 0:
				score_label.text = "Score: %d / %d" % [score, total]
			else:
				score_label.text = "Score: %d" % score

			var score_container := score_label.get_parent() as Control

			if score_container:
				score_container.visible = true
	else:
		if score_label:
			var score_container := score_label.get_parent() as Control

			if score_container:
				score_container.visible = false

	# ------------------------------------------------
	# TAKE QUIZ BUTTON
	# ------------------------------------------------

	if take_button:
		take_button.visible = not completed

		if not completed:
			take_button.disabled = false
			take_button.pressed.connect(
				_on_quiz_selected.bind(index)
			)

	# ------------------------------------------------
	# VIEW ASSESSMENT BUTTON
	# ------------------------------------------------

	if view_button:
		view_button.visible = completed
		view_button.disabled = false

		var button_container := view_button.get_parent() as Control

		if button_container:
			button_container.visible = completed

		if completed:
			view_button.pressed.connect(
				_on_view_assessment_pressed.bind(index)
			)

	quiz_list.add_child(card)
func _on_view_assessment_pressed(index: int) -> void:
	if index < 0 or index >= quizzes.size():
		push_error("[QuizPage] Invalid quiz index.")
		return

	var quiz: Dictionary = quizzes[index]
	var quiz_id: String = str(quiz.get("quiz_id", "")).strip_edges()

	if quiz_id.is_empty():
		push_error("[QuizPage] Quiz ID is missing.")
		return

	if not completed_quiz_ids.has(quiz_id):
		push_error("[QuizPage] Assessment record not found.")
		return

	var assessment: Dictionary = completed_quiz_ids[quiz_id]

	var assessment_form = QUIZ_FORM_SCENE.instantiate()
	assessment_form.quiz_data = quiz
	assessment_form.review_mode = true
	assessment_form.assessment_data = assessment
	assessment_form.return_page = self

	var parent_node: Node = get_parent()

	if parent_node == null:
		assessment_form.queue_free()
		push_error("[QuizPage] Parent node is missing.")
		return

	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	parent_node.add_child(assessment_form)

	print("[QuizPage] Opened assessment in review mode: ", quiz_id)

func _format_quiz_type(quiz_type: String) -> String:
	match quiz_type.to_lower().strip_edges():
		"multiple_choice":
			return "Multiple Choice"
		"true_false":
			return "True or False"
		"identification":
			return "Identification"
		"enumeration":
			return "Enumeration"
		_:
			return quiz_type.capitalize()


func _on_quiz_selected(index: int) -> void:
	if index < 0 or index >= quizzes.size():
		return

	var quiz: Dictionary = quizzes[index]
	var quiz_id := str(quiz.get("quiz_id", "")).strip_edges()

	if _is_quiz_completed(quiz_id, quiz):
		status_label.text = "This quiz has already been completed."
		return

	var quiz_taking_page = QUIZ_FORM_SCENE.instantiate()
	quiz_taking_page.quiz_data = quiz
	quiz_taking_page.set("return_page", self)

	var parent_node := get_parent()

	if parent_node == null:
		quiz_taking_page.queue_free()
		return

	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	parent_node.add_child(quiz_taking_page)


func _on_search_text_changed(_new_text: String) -> void:
	_apply_filters()


func _on_filter_selected(index: int) -> void:
	match index:
		0:
			selected_filter = ""
		1:
			selected_filter = "multiple_choice"
		2:
			selected_filter = "true_false"
		3:
			selected_filter = "identification"
		4:
			selected_filter = "enumeration"

	_apply_filters()


func _apply_filters() -> void:
	var search_text := search_bar.text.strip_edges().to_lower()

	for card in quiz_list.get_children():
		if not card.has_meta("quiz_index"):
			continue

		var index: int = card.get_meta("quiz_index")

		if index < 0 or index >= quizzes.size():
			continue

		var quiz: Dictionary = quizzes[index]
		var title := str(quiz.get("title", "")).to_lower()
		var quiz_type := str(quiz.get("quiz_type", "")).to_lower()

		var matches_search := (
			search_text.is_empty()
			or title.contains(search_text)
		)

		var matches_filter := (
			selected_filter.is_empty()
			or quiz_type == selected_filter
		)

		card.visible = matches_search and matches_filter


func _show_no_quizzes(message: String) -> void:
	quizzes.clear()

	for child in quiz_list.get_children():
		child.queue_free()

	status_label.text = message


func _get_string_field(fields: Dictionary, field_name: String) -> String:
	var field = fields.get(field_name, {})

	if not field is Dictionary:
		return ""

	if field.has("stringValue"):
		return str(field["stringValue"])

	if field.has("timestampValue"):
		return str(field["timestampValue"])

	return ""



func _get_float_field(fields: Dictionary, field_name: String) -> float:
	var field = fields.get(field_name, {})

	if not field is Dictionary:
		return 0.0

	if field.has("doubleValue"):
		return float(field["doubleValue"])

	if field.has("integerValue"):
		return float(field["integerValue"])

	return 0.0



func _get_integer_field(fields: Dictionary, field_name: String) -> int:
	var field = fields.get(field_name, {})

	if not field is Dictionary:
		return 0

	if field.has("integerValue"):
		return int(field["integerValue"])

	if field.has("doubleValue"):
		return int(field["doubleValue"])

	return 0


func _get_boolean_field(fields: Dictionary, field_name: String) -> bool:
	var field = fields.get(field_name, {})

	if not field is Dictionary:
		return false

	return bool(field.get("booleanValue", false))


func _get_string_array_field(fields: Dictionary, field_name: String) -> Array:
	var result: Array = []
	var field = fields.get(field_name, {})

	if not field is Dictionary:
		return result

	var array_value: Dictionary = field.get("arrayValue", {})
	var values = array_value.get("values", [])

	if not values is Array:
		return result

	for value in values:
		if value is Dictionary and value.has("stringValue"):
			result.append(str(value["stringValue"]))

	return result


func _get_integer_array_field(fields: Dictionary, field_name: String) -> Array:
	var result: Array = []
	var field = fields.get(field_name, {})

	if not field is Dictionary:
		return result

	var array_value: Dictionary = field.get("arrayValue", {})
	var values = array_value.get("values", [])

	if not values is Array:
		return result

	for value in values:
		if not value is Dictionary:
			continue

		if value.has("integerValue"):
			result.append(int(value["integerValue"]))
		elif value.has("doubleValue"):
			result.append(int(value["doubleValue"]))

	return result


func _get_uid() -> String:
	if StudentDataManager != null:
		if StudentDataManager.has_method("get_student_uid"):
			var student_uid := str(
				StudentDataManager.get_student_uid()
			)

			if not student_uid.is_empty():
				return student_uid

	if Firebase.Auth == null:
		return ""

	var auth_data: Dictionary = {}

	if Firebase.Auth.has_method("get_auth"):
		var result = Firebase.Auth.get_auth()

		if result is Dictionary:
			auth_data = result
	else:
		var auth_property = Firebase.Auth.get("auth")

		if auth_property is Dictionary:
			auth_data = auth_property

	if auth_data.is_empty():
		return ""

	return str(
		auth_data.get(
			"localid",
			auth_data.get(
				"localId",
				auth_data.get("uid", "")
			)
		)
	)


func _get_id_token() -> String:
	if Firebase.Auth == null:
		return ""

	var auth_data: Dictionary = {}

	if Firebase.Auth.has_method("get_auth"):
		var result = Firebase.Auth.get_auth()

		if result is Dictionary:
			auth_data = result
	else:
		var auth_property = Firebase.Auth.get("auth")

		if auth_property is Dictionary:
			auth_data = auth_property

	if auth_data.is_empty():
		return ""

	return str(
		auth_data.get(
			"idtoken",
			auth_data.get("idToken", "")
		)
	)

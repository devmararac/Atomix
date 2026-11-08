
extends PanelContainer

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"
const MIN_ANSWER_COUNT := 3

enum CreatorMode {
	CREATE,
	VIEW,
	EDIT
}

var firestore_url: String
var creator_mode: CreatorMode = CreatorMode.CREATE
var existing_document_path: String = ""
var existing_quiz_id: String = ""
var saved_quiz_id: String = ""

var quiz_title: String = "Untitled Quiz"
var quiz_section: String = ""
var questions: Array[Dictionary] = []
var current_question_index: int = 0
var answer_counter: int = MIN_ANSWER_COUNT

@onready var quiz_title_input: LineEdit = $MarginContainer/VBoxContainer/QuizSettings/QuizTitle
@onready var question_text: TextEdit = $MarginContainer/VBoxContainer/QuestionPanel/QuestionMargin/QuestionText
@onready var answers_container: GridContainer = $MarginContainer/VBoxContainer/EnumerationPanel/Margin/VBox/AnswerScroll/CenterContainer/Answers
@onready var answer_scroll: ScrollContainer = $MarginContainer/VBoxContainer/EnumerationPanel/Margin/VBox/AnswerScroll
@onready var add_answer_button: Button = $MarginContainer/VBoxContainer/EnumerationPanel/Margin/VBox/AddAnswerButton
@onready var previous_button: Button = $MarginContainer/VBoxContainer/NavigationBar/PreviousButton
@onready var save_button: Button = $MarginContainer/VBoxContainer/NavigationBar/SaveButton
@onready var next_button: Button = $MarginContainer/VBoxContainer/NavigationBar/NextButton


func _ready() -> void:
	firestore_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/quizzes"
	)

	_configure_answer_scroll()
	_update_answer_counter()

	if not add_answer_button.pressed.is_connected(_on_add_answer_button_pressed):
		add_answer_button.pressed.connect(_on_add_answer_button_pressed)

	if not previous_button.pressed.is_connected(_on_previous_button_pressed):
		previous_button.pressed.connect(_on_previous_button_pressed)

	if not save_button.pressed.is_connected(_on_save_button_pressed):
		save_button.pressed.connect(_on_save_button_pressed)

	if not next_button.pressed.is_connected(_on_next_button_pressed):
		next_button.pressed.connect(_on_next_button_pressed)

	_update_navigation_buttons()


# ============================================================
# CREATE, VIEW AND EDIT MODES
# ============================================================

func open_view_mode(quiz_data: Dictionary) -> void:
	creator_mode = CreatorMode.VIEW
	_load_existing_quiz(quiz_data)
	_apply_creator_mode()


func open_edit_mode(quiz_data: Dictionary) -> void:
	creator_mode = CreatorMode.EDIT
	_load_existing_quiz(quiz_data)
	_apply_creator_mode()


func _load_existing_quiz(quiz_data: Dictionary) -> void:
	existing_document_path = str(quiz_data.get("document_path", ""))
	existing_quiz_id = str(
		quiz_data.get("document_id", quiz_data.get("quiz_id", ""))
	)

	quiz_title = str(quiz_data.get("title", "Untitled Quiz"))
	quiz_section = str(quiz_data.get("section", ""))
	quiz_title_input.text = quiz_title

	questions.clear()

	var saved_questions: Array = quiz_data.get("questions", [])

	for saved_question in saved_questions:
		if not saved_question is Dictionary:
			continue

		var question_data: Dictionary = saved_question.duplicate(true)
		var answers: Array[String] = []

		for answer in question_data.get("answers", []):
			answers.append(str(answer))

		question_data["question"] = str(question_data.get("question", ""))
		question_data["type"] = "enumeration"
		question_data["answers"] = answers
		questions.append(question_data)

	current_question_index = 0

	if questions.is_empty():
		_clear_question_ui()
	else:
		_load_question(0)

	_update_navigation_buttons()


func _apply_creator_mode() -> void:
	var is_view_mode := creator_mode == CreatorMode.VIEW

	quiz_title_input.editable = not is_view_mode
	question_text.editable = not is_view_mode
	add_answer_button.disabled = is_view_mode
	save_button.visible = not is_view_mode

	for child in answers_container.get_children():
		if child is LineEdit:
			child.editable = not is_view_mode

	_update_navigation_buttons()


# ============================================================
# ANSWER SCROLL AND ANSWER BOXES
# ============================================================

func _configure_answer_scroll() -> void:
	if answer_scroll == null:
		push_error("[EnumerationCreator] AnswerScroll node not found.")
		return

	answer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	answer_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answer_scroll.custom_minimum_size = Vector2(0, 110)
	answer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	answer_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	if answers_container != null:
		answers_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_add_answer_button_pressed() -> void:
	if creator_mode == CreatorMode.VIEW:
		return

	if answers_container == null:
		push_error("[EnumerationCreator] Answers container not found.")
		return

	var reference_answer := answers_container.get_node_or_null("Answer1") as LineEdit

	if reference_answer == null:
		push_error("[EnumerationCreator] Answer1 template not found.")
		return

	answer_counter = answers_container.get_child_count() + 1

	var answer := reference_answer.duplicate() as LineEdit
	answer.name = "Answer%d" % answer_counter
	answer.text = ""
	answer.placeholder_text = "Type Answer"
	answer.add_theme_color_override(
		"font_placeholder_color",
		Color(0.57, 0.4617, 0.3534, 1)
	)

	answers_container.add_child(answer)


func _create_answer_from_data(text_value: String = "") -> LineEdit:
	var reference_answer := answers_container.get_node_or_null("Answer1") as LineEdit

	if reference_answer == null:
		push_error("[EnumerationCreator] Answer1 template not found.")
		return null

	var answer := reference_answer.duplicate() as LineEdit
	answer.name = "Answer%d" % (answers_container.get_child_count() + 1)
	answer.text = text_value
	answer.placeholder_text = "Type Answer"
	answer.editable = creator_mode != CreatorMode.VIEW

	answers_container.add_child(answer)
	return answer


func _get_answers() -> Array[String]:
	var answers: Array[String] = []

	for child in answers_container.get_children():
		if child is LineEdit:
			var value: String = child.text.strip_edges()

			if not value.is_empty():
				answers.append(value)

	return answers


func _update_answer_counter() -> void:
	if answers_container != null:
		answer_counter = answers_container.get_child_count()


# ============================================================
# QUESTION DATA
# ============================================================

func _get_quiz_title() -> String:
	var title := quiz_title_input.text.strip_edges()
	return title if not title.is_empty() else "Untitled Quiz"


func _save_current_question_to_memory() -> bool:
	var question := question_text.text.strip_edges()

	if question.is_empty():
		push_warning("[EnumerationCreator] Enter a question before continuing.")
		return false

	var answers := _get_answers()

	if answers.is_empty():
		push_warning("[EnumerationCreator] Add at least one answer.")
		return false

	var question_data: Dictionary = {
		"question": question,
		"type": "enumeration",
		"answers": answers
	}

	if current_question_index < questions.size():
		questions[current_question_index] = question_data
	else:
		questions.append(question_data)

	return true


func _load_question(index: int) -> void:
	if index < 0 or index >= questions.size():
		return

	current_question_index = index
	var data: Dictionary = questions[index]

	question_text.text = str(data.get("question", ""))

	await _clear_answer_boxes()

	var answers: Array = data.get("answers", [])

	for i in range(min(answers.size(), MIN_ANSWER_COUNT)):
		if i < answers_container.get_child_count():
			var answer_box := answers_container.get_child(i) as LineEdit
			if answer_box != null:
				answer_box.text = str(answers[i])

	for i in range(MIN_ANSWER_COUNT, answers.size()):
		_create_answer_from_data(str(answers[i]))

	_update_answer_counter()

	if answer_scroll != null:
		answer_scroll.scroll_vertical = 0

	_update_navigation_buttons()


func _clear_question_ui() -> void:
	question_text.text = ""

	var children := answers_container.get_children()

	for i in range(children.size() - 1, MIN_ANSWER_COUNT - 1, -1):
		children[i].queue_free()

	await get_tree().process_frame

	for child in answers_container.get_children():
		if child is LineEdit:
			child.text = ""

	answer_counter = MIN_ANSWER_COUNT

	if answer_scroll != null:
		answer_scroll.scroll_vertical = 0

	_update_navigation_buttons()


func _clear_answer_boxes() -> void:
	var children := answers_container.get_children()

	for i in range(children.size() - 1, MIN_ANSWER_COUNT - 1, -1):
		children[i].queue_free()

	await get_tree().process_frame

	for child in answers_container.get_children():
		if child is LineEdit:
			child.text = ""

	answer_counter = MIN_ANSWER_COUNT

	if answer_scroll != null:
		answer_scroll.scroll_vertical = 0


# ============================================================
# QUESTION NAVIGATION
# ============================================================

func _on_next_button_pressed() -> void:
	if creator_mode == CreatorMode.VIEW:
		if current_question_index < questions.size() - 1:
			_load_question(current_question_index + 1)
		return

	if not _save_current_question_to_memory():
		return

	if current_question_index < questions.size() - 1:
		_load_question(current_question_index + 1)
	else:
		current_question_index = questions.size()
		await _clear_question_ui()
		_update_navigation_buttons()


func _on_previous_button_pressed() -> void:
	if current_question_index <= 0:
		return

	if creator_mode != CreatorMode.VIEW and current_question_index < questions.size():
		if not _save_current_question_to_memory():
			return

	_load_question(current_question_index - 1)


func _update_navigation_buttons() -> void:
	if previous_button == null or next_button == null:
		return

	previous_button.disabled = current_question_index <= 0

	if creator_mode == CreatorMode.VIEW:
		next_button.text = "Next >"
		next_button.disabled = current_question_index >= questions.size() - 1
	elif current_question_index >= questions.size():
		next_button.text = "Add Question >"
		next_button.disabled = false
	else:
		next_button.text = "Next >"
		next_button.disabled = false


func _on_texture_button_pressed() -> void:
	queue_free()


# ============================================================
# SAVE QUIZ TO FIRESTORE
# ============================================================

func _on_save_button_pressed() -> void:
	if creator_mode == CreatorMode.VIEW:
		return

	if not _save_current_question_to_memory():
		return

	if questions.is_empty():
		push_warning("[EnumerationCreator] Add at least one question.")
		return

	quiz_title = _get_quiz_title()

	var token := _get_id_token()
	if token.is_empty():
		push_warning("[EnumerationCreator] Firebase ID token is unavailable.")
		return

	var uid := _get_uid()
	if uid.is_empty():
		push_warning("[EnumerationCreator] User UID is unavailable.")
		return

	var quiz_id := _generate_quiz_id()

	if creator_mode == CreatorMode.EDIT:
		if existing_document_path.is_empty():
			push_error("[EnumerationCreator] Existing Firestore document path is missing.")
			return

		quiz_id = existing_quiz_id
	
	saved_quiz_id = quiz_id
	
	var question_values: Array = []

	for question_data in questions:
		var answer_values: Array = []

		for answer in question_data.get("answers", []):
			answer_values.append({"stringValue": str(answer)})

		var question_map := {
			"question": {
				"stringValue": str(question_data.get("question", ""))
			},
			"type": {
				"stringValue": "enumeration"
			},
			"answers": {
				"arrayValue": {
					"values": answer_values
				}
			}
		}

		question_values.append({
			"mapValue": {
				"fields": question_map
			}
		})

	var fields := {
		"quiz_id": {"stringValue": quiz_id},
		"teacher_id": {"stringValue": uid},
		"title": {"stringValue": quiz_title},
		"section": {"stringValue": quiz_section},
		"quiz_type": {"stringValue": "enumeration"},
		"question_count": {"integerValue": str(questions.size())},
		"questions": {
			"arrayValue": {
				"values": question_values
			}
		}
	}

	if creator_mode == CreatorMode.CREATE:
		fields["created_at"] = {
			"timestampValue": _get_firestore_timestamp()
		}

	var document := {"fields": fields}
	var target_url := firestore_url + "/" + quiz_id

	if creator_mode == CreatorMode.EDIT:
		target_url = (
			"https://firestore.googleapis.com/v1/"
			+ existing_document_path
		)

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_save_request_completed.bind(http))

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	])

	var error := http.request(
		target_url,
		headers,
		HTTPClient.METHOD_PATCH,
		JSON.stringify(document)
	)

	if error != OK:
		push_error("[EnumerationCreator] Could not send Firestore request: %s" % error)
		http.queue_free()


func _on_save_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:
	http.queue_free()

	if response_code == 200:

		var action := ""
		var details := ""

		if creator_mode == CreatorMode.CREATE:
			action = "Created Quiz"
			details = (
				"Created enumeration quiz: " + quiz_title
				+ " | Questions: " + str(questions.size())
				+ " | Section: " + quiz_section
			)

		elif creator_mode == CreatorMode.EDIT:
			action = "Updated Quiz"
			details = (
				"Updated enumeration quiz: " + quiz_title
				+ " | Questions: " + str(questions.size())
				+ " | Section: " + quiz_section
			)

		ActivityLogManager.log_activity(
			action,
			details,
			"Quiz Management",
			saved_quiz_id
		)

		print("[EnumerationCreator] Activity log recorded.")

		_refresh_quiz_management()
		queue_free()
		return

	push_error(
		"[EnumerationCreator] Save failed (HTTP %d): %s"
		% [response_code, body.get_string_from_utf8()]
	)

# ============================================================
# FIREBASE AUTHENTICATION
# ============================================================

func _get_id_token() -> String:
	if Firebase.Auth == null:
		return ""

	var auth_data: Dictionary = Firebase.Auth.auth
	if auth_data.is_empty():
		return ""

	var token := str(auth_data.get("idtoken", ""))

	if token.is_empty():
		token = str(auth_data.get("idToken", ""))

	return token


func _get_uid() -> String:
	if has_node("/root/AuthManager"):
		var auth_manager := get_node("/root/AuthManager")

		if auth_manager.has_method("get_uid"):
			var uid := str(auth_manager.get_uid())
			if not uid.is_empty():
				return uid

	if Firebase.Auth != null:
		var auth_data: Dictionary = Firebase.Auth.auth
		var uid := str(auth_data.get("localid", ""))

		if uid.is_empty():
			uid = str(auth_data.get("localId", ""))

		return uid

	return ""


# ============================================================
# FIRESTORE HELPERS
# ============================================================

func _get_firestore_timestamp() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


func _generate_quiz_id() -> String:
	return "quiz_%s_%s" % [
		str(Time.get_unix_time_from_system()),
		str(randi())
	]


func _refresh_quiz_management() -> void:
	var management := get_tree().get_first_node_in_group("quiz_management")

	if is_instance_valid(management):
		management.load_quizzes()

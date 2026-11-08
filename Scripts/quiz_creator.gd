extends PanelContainer

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"
const MIN_ANSWER_COUNT := 4

var firestore_url: String

enum CreatorMode {
	CREATE,
	VIEW,
	EDIT
}

var creator_mode: CreatorMode = CreatorMode.CREATE
var existing_document_path: String = ""
var existing_quiz_id: String = ""
var saved_quiz_id: String = ""

var quiz_title: String = "Untitled Quiz"
var quiz_section: String = ""
var questions: Array[Dictionary] = []
var current_question_index: int = 0
var assigned_sections: Array = []

@onready var quiz_title_input: LineEdit = $MarginContainer/VBoxContainer/QuizSettings/QuizTitle
@onready var question_text: TextEdit = $MarginContainer/VBoxContainer/QuestionPanel/QuestionMargin/QuestionText
@onready var answers_container: GridContainer = $MarginContainer/VBoxContainer/AnswersScroll/Center/Answers
@onready var multiple_answers: CheckBox = $MarginContainer/VBoxContainer/BottomBar/MultipleAnswers
@onready var add_answer_button: Button = $MarginContainer/VBoxContainer/BottomBar/AddAnswerButton
@onready var save_button: Button = $MarginContainer/VBoxContainer/NavigationBar/SaveButton
@onready var next_button: Button = $MarginContainer/VBoxContainer/NavigationBar/NextButton
@onready var previous_button: Button = $MarginContainer/VBoxContainer/NavigationBar/PreviousButton


func _ready() -> void:
	firestore_url = "https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents/quizzes" % [PROJECT_ID, DATABASE_ID]
	add_answer_button.show()
	_connect_button_signals()
	_set_answer_card_count(MIN_ANSWER_COUNT)

	_update_navigation_buttons()

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
	existing_quiz_id = str(quiz_data.get("document_id", quiz_data.get("quiz_id", "")))

	quiz_title = str(quiz_data.get("title", "Untitled Quiz"))
	quiz_section = str(quiz_data.get("section", ""))

	quiz_title_input.text = quiz_title

	questions.clear()

	var saved_questions: Array = quiz_data.get("questions", [])

	for saved_question in saved_questions:
		if not saved_question is Dictionary:
			continue

		var question_data: Dictionary = saved_question.duplicate(true)
		question_data["question"] = str(question_data.get("question", ""))
		question_data["type"] = str(question_data.get("type", "multiple_choice"))

		var saved_answers: Array = question_data.get("answers", [])
		var answers: Array[String] = []

		for answer in saved_answers:
			answers.append(str(answer))

		question_data["answers"] = answers

		var saved_correct_answers: Array = question_data.get("correct_answers", [])
		var correct_answers: Array[int] = []

		for answer_index in saved_correct_answers:
			correct_answers.append(int(answer_index))

		question_data["correct_answers"] = correct_answers
		questions.append(question_data)

	current_question_index = 0

	if questions.is_empty():
		_clear_question()
	else:
		_load_question(0)

	_update_navigation_buttons()


func _apply_creator_mode() -> void:
	var is_view_mode := creator_mode == CreatorMode.VIEW

	quiz_title_input.editable = not is_view_mode
	question_text.editable = not is_view_mode
	multiple_answers.disabled = is_view_mode
	add_answer_button.disabled = is_view_mode
	save_button.visible = not is_view_mode

	for card in _get_answer_cards():
		_get_card_text(card).editable = not is_view_mode
		_get_card_checkbox(card).disabled = is_view_mode

	# In View mode, navigation is still available for reading questions.
	previous_button.disabled = current_question_index <= 0

	if is_view_mode:
		next_button.text = "Next >"
		next_button.disabled = questions.size() <= 1
	else:
		_update_navigation_buttons()


func _connect_button_signals() -> void:
	if save_button and not save_button.pressed.is_connected(_on_save_button_pressed):
		save_button.pressed.connect(_on_save_button_pressed)
	if next_button and not next_button.pressed.is_connected(_on_next_button_pressed):
		next_button.pressed.connect(_on_next_button_pressed)
	if previous_button and not previous_button.pressed.is_connected(_on_previous_button_pressed):
		previous_button.pressed.connect(_on_previous_button_pressed)
	if multiple_answers and not multiple_answers.toggled.is_connected(_on_multiple_answers_toggled):
		multiple_answers.toggled.connect(_on_multiple_answers_toggled)




func _on_texture_button_pressed() -> void:
	queue_free()


func _get_quiz_title() -> String:
	var title := quiz_title_input.text.strip_edges()
	return title if not title.is_empty() else "Untitled Quiz"


# Answer-card helpers
func _get_answer_cards() -> Array[Control]:
	var cards: Array[Control] = []
	for child in answers_container.get_children():
		if child is Control:
			cards.append(child)
	return cards


func _get_card_text(card: Control) -> TextEdit:
	return card.get_node("Margin/VBox/AnswerText") as TextEdit


func _get_card_checkbox(card: Control) -> CheckBox:
	return card.get_node("Margin/VBox/TopBar/Correct") as CheckBox


func _get_card_label(card: Control) -> Label:
	return card.get_node("Margin/VBox/TopBar/Label") as Label


func _connect_answer_card(card: Control) -> void:
	var checkbox := _get_card_checkbox(card)
	var callback := _on_answer_correct_toggled.bind(checkbox)
	if not checkbox.toggled.is_connected(callback):
		checkbox.toggled.connect(callback)


func _get_answer_label(index: int) -> String:
	var number := index + 1
	var label := ""
	while number > 0:
		number -= 1
		label = char(65 + number % 26) + label
		number = int(number / 26)
	return label + "."


func _set_answer_card_count(requested_count: int) -> void:
	var target_count: int = maxi(MIN_ANSWER_COUNT, requested_count)
	var cards := _get_answer_cards()

	while cards.size() > target_count:
		var card: Control = cards.pop_back()
		answers_container.remove_child(card)
		card.free()

	while cards.size() < target_count:
		var new_index := cards.size()
		var new_card := cards[0].duplicate() as Control
		new_card.name = "AnswerOption%d" % (new_index + 1)
		answers_container.add_child(new_card)
		_get_card_text(new_card).text = ""
		_get_card_checkbox(new_card).set_pressed_no_signal(false)
		_get_card_label(new_card).text = _get_answer_label(new_index)
		_connect_answer_card(new_card)
		cards.append(new_card)

	for i in range(cards.size()):
		_get_card_label(cards[i]).text = _get_answer_label(i)
		_connect_answer_card(cards[i])

	_update_answer_choice_colors()


func _get_answer_texts() -> Array[String]:
	var answers: Array[String] = []
	for card in _get_answer_cards():
		answers.append(_get_card_text(card).text.strip_edges())
	return answers


func _get_correct_answers() -> Array[int]:
	var correct_answers: Array[int] = []
	var cards := _get_answer_cards()
	for i in range(cards.size()):
		if _get_card_checkbox(cards[i]).button_pressed:
			correct_answers.append(i)
	return correct_answers


func _save_current_question() -> bool:
	var question := question_text.text.strip_edges()
	if question.is_empty():
		push_warning("Enter a question before continuing.")
		return false

	var answers := _get_answer_texts()
	for i in range(answers.size()):
		if answers[i].is_empty():
			push_warning("Answer %s is empty." % _get_answer_label(i).trim_suffix("."))
			return false

	var correct_answers := _get_correct_answers()
	if correct_answers.is_empty():
		push_warning("Select at least one correct answer.")
		return false
	if not multiple_answers.button_pressed and correct_answers.size() > 1:
		push_warning("Enable Multiple Correct Answers to select more than one correct choice.")
		return false

	var question_data := {
		"question": question,
		"type": "multiple_choice",
		"answers": answers,
		"correct_answers": correct_answers
	}

	if current_question_index < questions.size():
		questions[current_question_index] = question_data
	else:
		questions.append(question_data)
	return true


func _load_question(index: int) -> void:
	if index < 0:
		return
	if index >= questions.size():
		_clear_question()
		return

	var data: Dictionary = questions[index]
	question_text.text = str(data.get("question", ""))
	var answers: Array = data.get("answers", [])
	_set_answer_card_count(max(MIN_ANSWER_COUNT, answers.size()))
	var cards := _get_answer_cards()
	var correct_answers: Array = data.get("correct_answers", [])

	for i in range(cards.size()):
		_get_card_text(cards[i]).text = _get_answer_from_array(answers, i)
		_get_card_checkbox(cards[i]).set_pressed_no_signal(i in correct_answers)

	multiple_answers.set_pressed_no_signal(correct_answers.size() > 1)
	_update_navigation_buttons()
	_update_answer_choice_colors()


func _get_answer_from_array(answers: Array, index: int) -> String:
	if index >= answers.size():
		return ""
	return str(answers[index])


func _clear_question() -> void:
	question_text.text = ""
	_set_answer_card_count(MIN_ANSWER_COUNT)
	for card in _get_answer_cards():
		_get_card_text(card).text = ""
		_get_card_checkbox(card).set_pressed_no_signal(false)
	multiple_answers.set_pressed_no_signal(false)
	_update_navigation_buttons()
	_update_answer_choice_colors()


func _on_multiple_answers_toggled(_enabled: bool) -> void:
	_update_answer_choice_colors()


func _on_answer_correct_toggled(pressed: bool, selected_checkbox: CheckBox) -> void:
	if pressed and not multiple_answers.button_pressed:
		for card in _get_answer_cards():
			var checkbox := _get_card_checkbox(card)
			if checkbox != selected_checkbox:
				checkbox.set_pressed_no_signal(false)
	_update_answer_choice_colors()


func _update_answer_choice_colors() -> void:
	var cards := _get_answer_cards()
	var gray := Color(0.55, 0.55, 0.55, 1.0)
	var normal := Color.WHITE

	if multiple_answers.button_pressed:
		for card in cards:
			card.modulate = normal
		return

	var selected_index := -1
	for i in range(cards.size()):
		if _get_card_checkbox(cards[i]).button_pressed:
			selected_index = i
			break

	for i in range(cards.size()):
		cards[i].modulate = normal if selected_index == -1 or i == selected_index else gray


func _on_add_answer_button_pressed() -> void:
	_set_answer_card_count(_get_answer_cards().size() + 1)


func _on_next_button_pressed() -> void:
	if creator_mode == CreatorMode.VIEW:
		if current_question_index < questions.size() - 1:
			current_question_index += 1
			_load_question(current_question_index)
			_apply_creator_mode()
		return
	if not _save_current_question():
		return

	if current_question_index < questions.size() - 1:
		current_question_index += 1
		_load_question(current_question_index)
	else:
		current_question_index = questions.size()
		_clear_question()
	_update_navigation_buttons()


func _on_previous_button_pressed() -> void:
	if creator_mode == CreatorMode.VIEW:
		if current_question_index > 0:
			current_question_index -= 1
			_load_question(current_question_index)
			_apply_creator_mode()
		return
	
	if current_question_index <= 0:
		return
	if current_question_index < questions.size() and not _save_current_question():
		return
	current_question_index -= 1
	_load_question(current_question_index)
	_update_navigation_buttons()


func _update_navigation_buttons() -> void:
	previous_button.disabled = current_question_index <= 0
	next_button.text = "Add Question >" if current_question_index >= questions.size() else "Next >"


func _on_save_button_pressed() -> void:
	if creator_mode == CreatorMode.VIEW:
		return
	if not _save_current_question():
		return
	if questions.is_empty():
		push_warning("Add at least one question before saving.")
		return

	quiz_title = _get_quiz_title()

	var token := _get_id_token()
	if token.is_empty():
		push_warning("Firebase ID token is unavailable.")
		return
	var uid := _get_uid()
	if uid.is_empty():
		push_warning("User UID is unavailable.")
		return

	var quiz_id := _generate_quiz_id()

	if creator_mode == CreatorMode.EDIT:
		if existing_document_path.is_empty():
			push_error("Cannot edit quiz: existing Firestore document path is missing.")
			return
		quiz_id = existing_quiz_id

	saved_quiz_id = quiz_id
	
	var question_values: Array = []

	for question_data in questions:
		var question_map := {
			"question": {"stringValue": str(question_data.get("question", ""))},
			"type": {"stringValue": "multiple_choice"},
			"answers": {
				"arrayValue": {
					"values": _string_array_to_firestore(question_data.get("answers", []))
				}
			},
			"correct_answers": {
				"arrayValue": {
					"values": _int_array_to_firestore(question_data.get("correct_answers", []))
				}
			}
		}
		question_values.append({"mapValue": {"fields": question_map}})

	var fields := {
		"quiz_id": {"stringValue": quiz_id},
		"teacher_id": {"stringValue": uid},
		"title": {"stringValue": quiz_title},
		"section": {"stringValue": quiz_section},
		"quiz_type": {"stringValue": "multiple_choice"},
		"question_count": {"integerValue": str(questions.size())},
		"questions": {"arrayValue": {"values": question_values}}
	}

	# Only assign created_at when creating a new quiz.
	if creator_mode == CreatorMode.CREATE:
		fields["created_at"] = {
			"timestampValue": _get_firestore_timestamp()
		}

	var document := {"fields": fields}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_save_request_completed.bind(http))
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	])
	var target_url := firestore_url + "/" + quiz_id

	if creator_mode == CreatorMode.EDIT:
		target_url = "https://firestore.googleapis.com/v1/" + existing_document_path

	var error := http.request(
		target_url,
		headers,
		HTTPClient.METHOD_PATCH,
		JSON.stringify(document)
	)
	if error != OK:
		push_error("Could not send quiz save request. Error: %s" % error)
		http.queue_free()


func _string_array_to_firestore(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append({"stringValue": str(value)})
	return result


func _int_array_to_firestore(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append({"integerValue": str(int(value))})
	return result


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
				"Created multiple-choice quiz: " + quiz_title
				+ " | Questions: " + str(questions.size())
			)

		elif creator_mode == CreatorMode.EDIT:
			action = "Updated Quiz"
			details = (
				"Updated multiple-choice quiz: " + quiz_title
				+ " | Questions: " + str(questions.size())
			)

		var target_id := saved_quiz_id

		ActivityLogManager.log_activity(
			action,
			details,
			"Quiz Management",
			target_id
		)

		print("[QuizCreator] Activity log recorded: ", action)
		print("Quiz saved successfully.")

		_refresh_quiz_management()
		queue_free()
	else:
		push_error(
			"Quiz save failed (HTTP %d): %s"
			% [response_code, body.get_string_from_utf8()]
		)
		

func _get_id_token() -> String:
	if Firebase.Auth == null:
		return ""
	var auth_data: Dictionary = Firebase.Auth.auth
	var token := str(auth_data.get("idtoken", ""))
	if token.is_empty():
		token = str(auth_data.get("idToken", ""))
	return token


func _get_uid() -> String:
	if has_node("/root/AuthManager"):
		var auth_manager = get_node("/root/AuthManager")
		if auth_manager.has_method("get_uid"):
			var uid := str(auth_manager.get_uid())
			if not uid.is_empty():
				return uid

	if Firebase.Auth != null:
		var auth_data: Dictionary = Firebase.Auth.auth
		var uid := str(auth_data.get("localid", auth_data.get("localId", "")))
		return uid
	return ""


func _get_firestore_timestamp() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


func _generate_quiz_id() -> String:
	return "quiz_%s_%s" % [str(Time.get_unix_time_from_system()), str(randi())]

func _refresh_quiz_management() -> void:
	var management := get_tree().get_first_node_in_group(
        "quiz_management"
	)

	if is_instance_valid(management):
		management.load_quizzes()

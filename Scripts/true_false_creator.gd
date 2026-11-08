
extends PanelContainer

enum CreatorMode { CREATE, VIEW, EDIT }

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"
const QUIZ_TYPE := "true_false"

var firestore_url: String
var quiz_title: String = "True or False Quiz"
var questions: Array[Dictionary] = []
var current_question_index: int = 0
var creator_mode: CreatorMode = CreatorMode.CREATE
var existing_quiz_id: String = ""
var existing_document_path: String = ""
var existing_section: String = ""
var saved_quiz_id: String = ""

@onready var quiz_title_input: LineEdit = $MarginContainer/VBoxContainer/QuizSettings/QuizTitle
@onready var question_text: TextEdit = $MarginContainer/VBoxContainer/QuestionPanel/QuestionMargin/QuestionText
@onready var true_correct: CheckBox = $MarginContainer/VBoxContainer/AnswerPanel/Answers/TruePanel/Margin/VBox/Correct
@onready var false_correct: CheckBox = $MarginContainer/VBoxContainer/AnswerPanel/Answers/FalsePanel/Margin/VBox/Correct
@onready var previous_button: Button = $MarginContainer/VBoxContainer/NavigationBar/PreviousButton
@onready var save_button: Button = $MarginContainer/VBoxContainer/NavigationBar/SaveButton
@onready var next_button: Button = $MarginContainer/VBoxContainer/NavigationBar/NextButton
@onready var true_panel: Control = $MarginContainer/VBoxContainer/AnswerPanel/Answers/TruePanel
@onready var false_panel: Control = $MarginContainer/VBoxContainer/AnswerPanel/Answers/FalsePanel


func _ready() -> void:
	firestore_url = "https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents/quizzes" % [
		PROJECT_ID,
		DATABASE_ID
	]

	if not previous_button.pressed.is_connected(_on_previous_pressed):
		previous_button.pressed.connect(_on_previous_pressed)

	if not save_button.pressed.is_connected(_on_save_pressed):
		save_button.pressed.connect(_on_save_pressed)

	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)

	if not true_correct.toggled.is_connected(_on_true_toggled):
		true_correct.toggled.connect(_on_true_toggled)

	if not false_correct.toggled.is_connected(_on_false_toggled):
		false_correct.toggled.connect(_on_false_toggled)

	_apply_creator_mode()
	_update_navigation_buttons()
	_update_answer_choice_colors()


# Call this when opening an existing quiz in View mode.
func open_view_mode(quiz_data: Dictionary) -> void:
	creator_mode = CreatorMode.VIEW
	_load_existing_quiz(quiz_data)
	_apply_creator_mode()


# Call this when opening an existing quiz in Edit mode.
func open_edit_mode(quiz_data: Dictionary) -> void:
	creator_mode = CreatorMode.EDIT
	_load_existing_quiz(quiz_data)
	_apply_creator_mode()


func _load_existing_quiz(quiz_data: Dictionary) -> void:
	existing_quiz_id = str(
		quiz_data.get(
			"quiz_id",
			quiz_data.get("document_id", "")
		)
	)

	existing_document_path = str(quiz_data.get("document_path", ""))
	existing_section = str(quiz_data.get("section", ""))
	quiz_title = str(quiz_data.get("title", "True or False Quiz"))

	if quiz_title_input != null:
		quiz_title_input.text = quiz_title

	questions.clear()
	var loaded_questions: Variant = quiz_data.get("questions", [])

	if loaded_questions is Array:
		for item in loaded_questions:
			if item is Dictionary:
				var question_data: Dictionary = item.duplicate(true)
				var question_value: Variant = _decode_firestore_value(
					question_data.get("question", "")
				)
				var answers_value: Variant = _decode_firestore_value(
					question_data.get("answers", ["True", "False"])
				)
				var correct_value: Variant = _decode_firestore_value(
					question_data.get("correct_answers", [])
				)

				question_data["question"] = str(question_value)
				question_data["type"] = QUIZ_TYPE
				question_data["answers"] = answers_value if answers_value is Array else ["True", "False"]
				question_data["correct_answers"] = correct_value if correct_value is Array else []

				questions.append(question_data)

	if existing_document_path.is_empty() and not existing_quiz_id.is_empty():
		existing_document_path = "projects/%s/databases/%s/documents/quizzes/%s" % [
			PROJECT_ID,
			DATABASE_ID,
			existing_quiz_id
		]

	current_question_index = 0

	if questions.is_empty():
		_clear_question_ui()
	else:
		_load_question(0)

	_update_navigation_buttons()


func _decode_firestore_value(value: Variant) -> Variant:
	if not value is Dictionary:
		return value

	if value.has("stringValue"):
		return value["stringValue"]
	if value.has("integerValue"):
		return int(value["integerValue"])
	if value.has("booleanValue"):
		return bool(value["booleanValue"])
	if value.has("doubleValue"):
		return float(value["doubleValue"])
	if value.has("nullValue"):
		return null

	if value.has("arrayValue"):
		var decoded_array: Array = []
		var array_data: Dictionary = value["arrayValue"]
		for item in array_data.get("values", []):
			decoded_array.append(_decode_firestore_value(item))
		return decoded_array

	if value.has("mapValue"):
		var decoded_map: Dictionary = {}
		var map_data: Dictionary = value["mapValue"]
		var fields: Dictionary = map_data.get("fields", {})
		for key in fields:
			decoded_map[key] = _decode_firestore_value(fields[key])
		return decoded_map

	return value


func _apply_creator_mode() -> void:
	var is_view_mode := creator_mode == CreatorMode.VIEW
	var is_create_mode := creator_mode == CreatorMode.CREATE

	quiz_title_input.editable = not is_view_mode
	question_text.editable = not is_view_mode
	true_correct.disabled = is_view_mode
	false_correct.disabled = is_view_mode

	save_button.visible = not is_view_mode
	save_button.disabled = is_view_mode

	if creator_mode == CreatorMode.VIEW:
		save_button.text = "View Only"
	elif creator_mode == CreatorMode.EDIT:
		save_button.text = "Update Quiz"
	else:
		save_button.text = "Save Quiz"

	if is_create_mode:
		existing_quiz_id = ""
		existing_document_path = ""
		existing_section = ""


func _on_texture_button_pressed() -> void:
	queue_free()


func _on_true_toggled(pressed: bool) -> void:
	if pressed:
		false_correct.button_pressed = false
	_update_answer_choice_colors()


func _on_false_toggled(pressed: bool) -> void:
	if pressed:
		true_correct.button_pressed = false
	_update_answer_choice_colors()


func _update_answer_choice_colors() -> void:
	var gray := Color(0.55, 0.55, 0.55, 1.0)
	var normal := Color.WHITE

	if true_correct.button_pressed:
		true_panel.modulate = normal
		false_panel.modulate = gray
	elif false_correct.button_pressed:
		true_panel.modulate = gray
		false_panel.modulate = normal
	else:
		true_panel.modulate = normal
		false_panel.modulate = normal


func _get_quiz_title() -> String:
	var title := quiz_title_input.text.strip_edges()
	return title if not title.is_empty() else "True or False Quiz"


func _save_current_question_to_memory() -> bool:
	if creator_mode == CreatorMode.VIEW:
		return true

	var statement := question_text.text.strip_edges()
	if statement.is_empty():
		push_warning("Enter a statement before continuing.")
		return false

	var correct_answers: Array[int] = []

	if true_correct.button_pressed:
		correct_answers.append(0)
	elif false_correct.button_pressed:
		correct_answers.append(1)
	else:
		push_warning("Select True or False as the correct answer.")
		return false

	var question_data := {
		"question": statement,
		"type": QUIZ_TYPE,
		"answers": ["True", "False"],
		"correct_answers": correct_answers
	}

	if current_question_index < questions.size():
		questions[current_question_index] = question_data
	else:
		questions.append(question_data)

	return true


func _load_question(index: int) -> void:
	if index < 0 or index >= questions.size():
		_clear_question_ui()
		return

	current_question_index = index
	var data: Dictionary = questions[index]

	question_text.text = str(data.get("question", ""))

	true_correct.set_pressed_no_signal(false)
	false_correct.set_pressed_no_signal(false)

	var correct_answers: Variant = data.get("correct_answers", [])
	if correct_answers is Array and not correct_answers.is_empty():
		var correct_index := int(correct_answers[0])
		if correct_index == 0:
			true_correct.set_pressed_no_signal(true)
		elif correct_index == 1:
			false_correct.set_pressed_no_signal(true)

	_update_answer_choice_colors()
	_update_navigation_buttons()


func _clear_question_ui() -> void:
	question_text.clear()
	true_correct.set_pressed_no_signal(false)
	false_correct.set_pressed_no_signal(false)
	_update_answer_choice_colors()
	_update_navigation_buttons()


func _on_next_pressed() -> void:
	if creator_mode != CreatorMode.VIEW:
		if not _save_current_question_to_memory():
			return

	if current_question_index < questions.size() - 1:
		current_question_index += 1
		_load_question(current_question_index)
	else:
		if creator_mode == CreatorMode.VIEW:
			return

		current_question_index = questions.size()
		_clear_question_ui()

	_update_navigation_buttons()


func _on_previous_pressed() -> void:
	if current_question_index <= 0:
		return

	if creator_mode != CreatorMode.VIEW and current_question_index < questions.size():
		if not _save_current_question_to_memory():
			return

	current_question_index -= 1
	_load_question(current_question_index)
	_update_navigation_buttons()


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


func _on_save_pressed() -> void:
	if creator_mode == CreatorMode.VIEW:
		return

	if not _save_current_question_to_memory():
		return

	if questions.is_empty():
		push_warning("Add at least one question before saving.")
		return

	quiz_title = _get_quiz_title()

	var token := _get_id_token()
	if token.is_empty():
		push_error("Cannot save quiz: Firebase ID token is missing.")
		return

	var uid := _get_uid()
	if uid.is_empty():
		push_error("Cannot save quiz: user UID is missing.")
		return

	var quiz_id := existing_quiz_id
	if creator_mode == CreatorMode.CREATE:
		quiz_id = _generate_quiz_id()
	
	quiz_id = _generate_quiz_id()
	
	var question_values: Array = []

	for question_data in questions:
		var question_map := {
			"question": {
				"stringValue": str(question_data.get("question", ""))
			},
			"type": {
				"stringValue": QUIZ_TYPE
			},
			"answers": {
				"arrayValue": {
					"values": _string_array_to_firestore(
						question_data.get("answers", ["True", "False"])
					)
				}
			},
			"correct_answers": {
				"arrayValue": {
					"values": _int_array_to_firestore(
						question_data.get("correct_answers", [])
					)
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
		"quiz_type": {"stringValue": QUIZ_TYPE},
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

	if not existing_section.is_empty():
		fields["section"] = {"stringValue": existing_section}

	var document := {"fields": fields}
	var json_body := JSON.stringify(document)

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_save_request_completed.bind(http))

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	])

	var request_url: String
	if creator_mode == CreatorMode.EDIT:
		if existing_document_path.is_empty():
			http.queue_free()
			push_error("Cannot update quiz: Firestore document path is missing.")
			return
		request_url = "https://firestore.googleapis.com/v1/" + existing_document_path
	else:
		request_url = firestore_url + "/" + quiz_id

	var error := http.request(
		request_url,
		headers,
		HTTPClient.METHOD_PATCH,
		json_body
	)

	if error != OK:
		http.queue_free()
		push_error("Could not send quiz save request. Error code: %s" % error)


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
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:
	var response_text := body.get_string_from_utf8()
	http.queue_free()

	if response_code == 200:

		var action := ""
		var details := ""

		if creator_mode == CreatorMode.CREATE:
			action = "Created Quiz"
			details = (
				"Created True/False quiz: " + quiz_title
				+ " | Questions: " + str(questions.size())
				+ " | Section: " + existing_section
			)

		elif creator_mode == CreatorMode.EDIT:
			action = "Updated Quiz"
			details = (
				"Updated True/False quiz: " + quiz_title
				+ " | Questions: " + str(questions.size())
				+ " | Section: " + existing_section
			)

		ActivityLogManager.log_activity(
			action,
			details,
			"Quiz Management",
			saved_quiz_id
		)

		print("[TrueFalseCreator] Activity log recorded.")

		_refresh_quiz_management()
		queue_free()
	else:
		push_error(
			"Failed to save True/False quiz. HTTP %s: %s" % [
				response_code,
				response_text
			]
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


func _get_firestore_timestamp() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


func _generate_quiz_id() -> String:
	return "quiz_%s_%s" % [
		str(Time.get_unix_time_from_system()),
		str(randi())
	]


func _refresh_quiz_management() -> void:
	var management := get_tree().get_first_node_in_group("quiz_management")
	if is_instance_valid(management) and management.has_method("load_quizzes"):
		management.load_quizzes()

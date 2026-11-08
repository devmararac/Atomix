
extends PanelContainer

enum CreatorMode {
	CREATE,
	VIEW,
	EDIT
}

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"
const QUIZ_TYPE := "identification"

var firestore_url: String
var creator_mode: CreatorMode = CreatorMode.CREATE
var existing_document_path := ""
var existing_quiz_id := ""
var saved_quiz_id := ""
var quiz_section := ""

var quiz_title := "Untitled Quiz"
var questions: Array[Dictionary] = []
var current_question_index := 0

@onready var quiz_settings: Control = $MarginContainer/VBoxContainer/QuizSettings
@onready var quiz_title_input: LineEdit = $MarginContainer/VBoxContainer/QuizSettings/QuizTitle
@onready var question_text: TextEdit = $MarginContainer/VBoxContainer/QuestionPanel/QuestionMargin/QuestionText
@onready var answer_text: TextEdit = $MarginContainer/VBoxContainer/AnswerPanel/Margin/VBox/AnswerText
@onready var save_button: Button = $MarginContainer/VBoxContainer/NavigationBar/SaveButton
@onready var next_button: Button = $MarginContainer/VBoxContainer/NavigationBar/NextButton
@onready var previous_button: Button = $MarginContainer/VBoxContainer/NavigationBar/PreviousButton


func _ready() -> void:
	firestore_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/quizzes"
	)

	if not save_button.pressed.is_connected(_on_save_button_pressed):
		save_button.pressed.connect(_on_save_button_pressed)

	if not next_button.pressed.is_connected(_on_next_button_pressed):
		next_button.pressed.connect(_on_next_button_pressed)

	if not previous_button.pressed.is_connected(_on_previous_button_pressed):
		previous_button.pressed.connect(_on_previous_button_pressed)

	_apply_creator_mode()
	_update_navigation_buttons()


# Called by quiz_management.gd when View is selected.
func open_view_mode(quiz_data: Dictionary) -> void:
	creator_mode = CreatorMode.VIEW
	_load_existing_quiz(quiz_data)
	_apply_creator_mode()


# Called by quiz_management.gd when Edit is selected.
func open_edit_mode(quiz_data: Dictionary) -> void:
	creator_mode = CreatorMode.EDIT
	_load_existing_quiz(quiz_data)
	_apply_creator_mode()


func _load_existing_quiz(quiz_data: Dictionary) -> void:
	existing_document_path = str(quiz_data.get("document_path", ""))
	existing_quiz_id = str(
		quiz_data.get(
			"document_id",
			quiz_data.get("quiz_id", "")
		)
	)
	quiz_section = str(quiz_data.get("section", ""))

	quiz_title = str(
		_get_field_value(
			quiz_data,
			"title",
			"Identification Quiz"
		)
	)

	var question_data: Variant = _get_field_value(
		quiz_data,
		"questions",
		[]
	)

	questions.clear()

	if question_data is Array:
		for item in question_data:
			if item is Dictionary:
				var question := str(
					_get_field_value(item, "question", "")
				)
				var answers_value: Variant = _get_field_value(
					item,
					"answers",
					[]
				)

				var answer := ""
				if answers_value is Array and not answers_value.is_empty():
					answer = str(answers_value[0])

				if question.is_empty() and answer.is_empty():
					continue

				questions.append({
					"question": question,
					"type": QUIZ_TYPE,
					"answers": [answer],
					"correct_answers": [0]
				})

	current_question_index = 0
	quiz_title_input.text = quiz_title

	if questions.is_empty():
		_clear_question()
	else:
		_load_question(0)

	if existing_document_path.is_empty() and not existing_quiz_id.is_empty():
		existing_document_path = "projects/" + PROJECT_ID \
			+ "/databases/" + DATABASE_ID \
			+ "/documents/quizzes/" + existing_quiz_id


func _get_field_value(
	data: Dictionary,
	field_name: String,
	default_value: Variant
) -> Variant:
	if not data.has(field_name):
		return default_value

	var value: Variant = data[field_name]

	# Support Firestore REST fields, such as {"stringValue": "..."}.
	if value is Dictionary:
		if value.has("stringValue"):
			return value["stringValue"]
		if value.has("integerValue"):
			return int(value["integerValue"])
		if value.has("doubleValue"):
			return float(value["doubleValue"])
		if value.has("booleanValue"):
			return value["booleanValue"]
		if value.has("arrayValue"):
			var array_data: Dictionary = value["arrayValue"]
			var result: Array = []
			for entry in array_data.get("values", []):
				result.append(_decode_firestore_value(entry))
			return result
		if value.has("mapValue"):
			return _decode_firestore_value(value)

	return value


func _decode_firestore_value(value: Variant) -> Variant:
	if not value is Dictionary:
		return value

	if value.has("stringValue"):
		return value["stringValue"]
	if value.has("integerValue"):
		return int(value["integerValue"])
	if value.has("doubleValue"):
		return float(value["doubleValue"])
	if value.has("booleanValue"):
		return value["booleanValue"]
	if value.has("nullValue"):
		return null

	if value.has("arrayValue"):
		var result: Array = []
		var array_data: Dictionary = value["arrayValue"]
		for entry in array_data.get("values", []):
			result.append(_decode_firestore_value(entry))
		return result

	if value.has("mapValue"):
		var map_data: Dictionary = value["mapValue"]
		var fields: Dictionary = map_data.get("fields", {})
		var result: Dictionary = {}
		for key in fields:
			result[key] = _decode_firestore_value(fields[key])
		return result

	return value


func _apply_creator_mode() -> void:
	var is_view := creator_mode == CreatorMode.VIEW
	var is_create := creator_mode == CreatorMode.CREATE

	quiz_title_input.editable = not is_view
	question_text.editable = not is_view
	answer_text.editable = not is_view

	save_button.visible = not is_view

	if is_view:
		save_button.disabled = true
		save_button.text = "View Only"
	elif creator_mode == CreatorMode.EDIT:
		save_button.disabled = false
		save_button.text = "Update Quiz"
	else:
		save_button.disabled = false
		save_button.text = "Save Quiz"

	if is_create and quiz_title_input.text.is_empty():
		quiz_title_input.text = "Identification Quiz"

	_update_navigation_buttons()


func _on_texture_button_pressed() -> void:
	queue_free()


func _save_current_question() -> bool:
	if creator_mode == CreatorMode.VIEW:
		return true

	var question := question_text.text.strip_edges()
	var answer := answer_text.text.strip_edges()

	if question.is_empty():
		push_warning("[IdentificationCreator] Enter a question before continuing.")
		return false

	if answer.is_empty():
		push_warning("[IdentificationCreator] Enter the correct answer before continuing.")
		return false

	var question_data := {
		"question": question,
		"type": QUIZ_TYPE,
		"answers": [answer],
		"correct_answers": [0]
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

	current_question_index = index
	var data: Dictionary = questions[index]

	question_text.text = str(data.get("question", ""))

	var answers: Array = data.get("answers", [])
	answer_text.text = str(answers[0]) if not answers.is_empty() else ""

	_update_navigation_buttons()


func _clear_question() -> void:
	question_text.text = ""
	answer_text.text = ""
	_update_navigation_buttons()


func _on_next_button_pressed() -> void:
	if creator_mode != CreatorMode.VIEW:
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
	if current_question_index <= 0:
		return

	if creator_mode != CreatorMode.VIEW:
		if current_question_index < questions.size():
			if not _save_current_question():
				return

	current_question_index -= 1
	_load_question(current_question_index)
	_update_navigation_buttons()


func _update_navigation_buttons() -> void:
	if not is_node_ready():
		return

	previous_button.disabled = current_question_index <= 0

	if creator_mode == CreatorMode.VIEW:
		next_button.text = "Next >"
		next_button.disabled = questions.size() <= 1 \
			or current_question_index >= questions.size() - 1
	else:
		next_button.disabled = false
		if current_question_index >= questions.size():
			next_button.text = "Add Question >"
		else:
			next_button.text = "Next >"


func _on_save_button_pressed() -> void:
	if creator_mode == CreatorMode.VIEW:
		return

	if not _save_current_question():
		return

	if questions.is_empty():
		push_warning("[IdentificationCreator] Add at least one question.")
		return

	var title := quiz_title_input.text.strip_edges()
	if title.is_empty():
		push_warning("[IdentificationCreator] Enter a quiz title.")
		return

	var token := _get_id_token()
	if token.is_empty():
		push_error("[IdentificationCreator] Firebase ID token is unavailable.")
		return

	var uid := _get_uid()
	if uid.is_empty():
		push_error("[IdentificationCreator] User UID is unavailable.")
		return

	if creator_mode == CreatorMode.EDIT and existing_document_path.is_empty():
		push_error("[IdentificationCreator] Cannot edit: Firestore document path is missing.")
		return

	var quiz_id := existing_quiz_id
	if creator_mode == CreatorMode.CREATE:
		quiz_id = _generate_quiz_id()
	
	saved_quiz_id = quiz_id
	
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
						question_data.get("answers", [])
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
		"quiz_id": {
			"stringValue": quiz_id
		},
		"teacher_id": {
			"stringValue": uid
		},
		"title": {
			"stringValue": title
		},
		"quiz_type": {
			"stringValue": QUIZ_TYPE
		},
		"question_count": {
			"integerValue": str(questions.size())
		},
		"questions": {
			"arrayValue": {
				"values": question_values
			}
		}
	}

	if not quiz_section.is_empty():
		fields["section"] = {
			"stringValue": quiz_section
		}

	if creator_mode == CreatorMode.CREATE:
		fields["created_at"] = {
			"timestampValue": _get_firestore_timestamp()
		}

	var document := {"fields": fields}
	var json_body := JSON.stringify(document)

	var target_url := ""
	if creator_mode == CreatorMode.EDIT:
		target_url = "https://firestore.googleapis.com/v1/" + existing_document_path
	else:
		target_url = firestore_url + "/" + quiz_id

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(
		_on_save_request_completed.bind(http)
	)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	])

	var error := http.request(
		target_url,
		headers,
		HTTPClient.METHOD_PATCH,
		json_body
	)

	if error != OK:
		push_error("[IdentificationCreator] Failed to send Firestore request: %s" % error)
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
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:
	var response_text := body.get_string_from_utf8()
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[IdentificationCreator] Network request failed.")
		return

	if response_code == 200 or response_code == 201:

		var action := ""
		var details := ""

		if creator_mode == CreatorMode.CREATE:
			action = "Created Quiz"
			details = (
				"Created identification quiz: " + quiz_title_input.text.strip_edges()
				+ " | Questions: " + str(questions.size())
				+ " | Section: " + quiz_section
			)

		elif creator_mode == CreatorMode.EDIT:
			action = "Updated Quiz"
			details = (
				"Updated identification quiz: " + quiz_title_input.text.strip_edges()
				+ " | Questions: " + str(questions.size())
				+ " | Section: " + quiz_section
			)

		ActivityLogManager.log_activity(
			action,
			details,
			"Quiz Management",
			saved_quiz_id
		)

		print("[IdentificationCreator] Activity log recorded.")

		_refresh_quiz_management()
		queue_free()
		return

	push_error(
		"[IdentificationCreator] Firestore save failed (%s): %s"
		% [response_code, response_text]
	)
	
	
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
		var auth_manager: Node = get_node("/root/AuthManager")
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
	var management: Node = get_tree().get_first_node_in_group(
		"quiz_management"
	)
	if is_instance_valid(management) and management.has_method("load_quizzes"):
		management.call("load_quizzes")

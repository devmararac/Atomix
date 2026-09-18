extends PanelContainer


# ============================================================
# FIRESTORE
# ============================================================

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

var firestore_url: String


# ============================================================
# QUIZ DATA
# ============================================================

var quiz_title: String = "Untitled Quiz"
var quiz_section: String = ""

var questions: Array[Dictionary] = []
var current_question_index: int = 0


# ============================================================
# TEACHER DATA
# ============================================================

var assigned_sections: Array = []


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var quiz_title_input: LineEdit = \
	$MarginContainer/VBoxContainer/QuizSettings/QuizTitle

@onready var section_option: OptionButton = \
	$MarginContainer/VBoxContainer/QuizSettings/SectionOption

@onready var question_text: TextEdit = \
	$MarginContainer/VBoxContainer/QuestionPanel/QuestionMargin/QuestionText


# ------------------------------------------------------------
# ANSWER TEXT BOXES
# ------------------------------------------------------------

@onready var answer_a: TextEdit = \
	$MarginContainer/VBoxContainer/AnswersScroll/Center/Answers/AnswerA/Margin/VBox/AnswerText

@onready var answer_b: TextEdit = \
	$MarginContainer/VBoxContainer/AnswersScroll/Center/Answers/AnswerB/Margin/VBox/AnswerText

@onready var answer_c: TextEdit = \
	$MarginContainer/VBoxContainer/AnswersScroll/Center/Answers/AnswerC/Margin/VBox/AnswerText

@onready var answer_d: TextEdit = \
	$MarginContainer/VBoxContainer/AnswersScroll/Center/Answers/AnswerD/Margin/VBox/AnswerText


# ------------------------------------------------------------
# CORRECT ANSWER CHECKBOXES
# ------------------------------------------------------------

@onready var correct_a: CheckBox = \
	$MarginContainer/VBoxContainer/AnswersScroll/Center/Answers/AnswerA/Margin/VBox/TopBar/Correct

@onready var correct_b: CheckBox = \
	$MarginContainer/VBoxContainer/AnswersScroll/Center/Answers/AnswerB/Margin/VBox/TopBar/Correct

@onready var correct_c: CheckBox = \
	$MarginContainer/VBoxContainer/AnswersScroll/Center/Answers/AnswerC/Margin/VBox/TopBar/Correct

@onready var correct_d: CheckBox = \
	$MarginContainer/VBoxContainer/AnswersScroll/Center/Answers/AnswerD/Margin/VBox/TopBar/Correct


# ------------------------------------------------------------
# MULTIPLE ANSWERS
# ------------------------------------------------------------

@onready var multiple_answers: CheckBox = \
	$MarginContainer/VBoxContainer/BottomBar/MultipleAnswers


# ------------------------------------------------------------
# BUTTONS
# ------------------------------------------------------------

@onready var add_answer_button: Button = \
	$MarginContainer/VBoxContainer/BottomBar/AddAnswerButton

@onready var save_button: Button = \
	$MarginContainer/VBoxContainer/NavigationBar/SaveButton

@onready var next_button: Button = \
	$MarginContainer/VBoxContainer/NavigationBar/NextButton

@onready var previous_button: Button = \
	$MarginContainer/VBoxContainer/NavigationBar/PreviousButton


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[QuizCreator] Quiz Creator opened.")

	# --------------------------------------------------------
	# Firestore URL
	# --------------------------------------------------------

	firestore_url = \
		"https://firestore.googleapis.com/v1/projects/" \
		+ PROJECT_ID \
		+ "/databases/" \
		+ DATABASE_ID \
		+ "/documents/quizzes"


	# --------------------------------------------------------
	# Multiple choice always has four answer boxes
	# --------------------------------------------------------

	if add_answer_button != null:
		add_answer_button.hide()


	# --------------------------------------------------------
	# Load teacher sections
	# --------------------------------------------------------

	await _load_teacher_sections()


	# --------------------------------------------------------
	# Connect buttons
	# --------------------------------------------------------

	if save_button != null:
		if not save_button.pressed.is_connected(
			_on_save_button_pressed
		):
			save_button.pressed.connect(
				_on_save_button_pressed
			)


	if next_button != null:
		if not next_button.pressed.is_connected(
			_on_next_button_pressed
		):
			next_button.pressed.connect(
				_on_next_button_pressed
			)


	if previous_button != null:
		if not previous_button.pressed.is_connected(
			_on_previous_button_pressed
		):
			previous_button.pressed.connect(
				_on_previous_button_pressed
			)


	if multiple_answers != null:
		if not multiple_answers.toggled.is_connected(
			_on_multiple_answers_toggled
		):
			multiple_answers.toggled.connect(
				_on_multiple_answers_toggled
			)


	_update_navigation_buttons()


# ============================================================
# LOAD TEACHER ASSIGNED SECTIONS
# ============================================================

func _load_teacher_sections() -> void:

	print(
		"[QuizCreator] Loading teacher assigned sections."
	)


	# --------------------------------------------------------
	# Check user role
	# --------------------------------------------------------

	var role = await AuthManager.get_user_role()

	print(
		"[QuizCreator] Current user role: ",
		role
	)


	if role != "teacher":

		print(
			"[QuizCreator] Current user is not a teacher."
		)

		_configure_default_sections()

		return


	# --------------------------------------------------------
	# Get teacher UID
	# --------------------------------------------------------

	var uid = AuthManager.get_uid()

	if uid.is_empty():

		print(
			"[QuizCreator] ERROR: Teacher UID is empty."
		)

		_configure_default_sections()

		return


	print(
		"[QuizCreator] Teacher detected. UID: ",
		uid
	)


	# --------------------------------------------------------
	# Get assigned sections
	# --------------------------------------------------------

	assigned_sections = \
		await TeacherDataManager.get_current_teacher_sections()


	print(
		"[QuizCreator] Teacher assigned sections: ",
		assigned_sections
	)


	# --------------------------------------------------------
	# Configure dropdown
	# --------------------------------------------------------

	section_option.clear()

	section_option.add_item(
		"Select Section"
	)


	if assigned_sections.is_empty():

		print(
			"[QuizCreator] WARNING: No assigned sections found."
		)

	else:

		for section in assigned_sections:

			var section_name := \
				str(section).strip_edges()

			if section_name.is_empty():
				continue

			section_option.add_item(
				section_name
			)

			print(
				"[QuizCreator] Added assigned section: ",
				section_name
			)


	section_option.select(0)


# ============================================================
# DEFAULT SECTIONS
# ============================================================

func _configure_default_sections() -> void:

	print(
		"[QuizCreator] Configuring default sections."
	)


	section_option.clear()

	section_option.add_item(
		"Select Section"
	)

	section_option.add_item(
		"11-A"
	)

	section_option.add_item(
		"11-B"
	)

	section_option.add_item(
		"11-C"
	)

	section_option.select(0)


# ============================================================
# CLOSE
# ============================================================

func _on_texture_button_pressed() -> void:

	print(
		"[QuizCreator] Closing."
	)

	queue_free()


# ============================================================
# GET QUIZ TITLE
# ============================================================

func _get_quiz_title() -> String:

	if quiz_title_input == null:
		return "Untitled Quiz"

	var title := \
		quiz_title_input.text.strip_edges()

	if title.is_empty():
		return "Untitled Quiz"

	return title


# ============================================================
# GET SECTION
# ============================================================

func _get_section() -> String:

	if section_option == null:
		return ""

	if section_option.selected <= 0:
		return ""

	return section_option.get_item_text(
		section_option.selected
	).strip_edges()


# ============================================================
# VALIDATE SECTION
# ============================================================

func _is_valid_teacher_section(
	selected_section: String
) -> bool:

	if selected_section.is_empty():
		return false


	for section in assigned_sections:

		var assigned_section := \
			str(section).strip_edges()

		if assigned_section.is_empty():
			continue


		if assigned_section == selected_section:

			print(
				"[QuizCreator] Section validation passed: ",
				selected_section
			)

			return true


	print(
		"[QuizCreator] Section validation failed: ",
		selected_section
	)

	return false


# ============================================================
# GET ANSWER TEXTS
# ============================================================

func _get_answer_texts() -> Array[String]:

	return [
		answer_a.text.strip_edges(),
		answer_b.text.strip_edges(),
		answer_c.text.strip_edges(),
		answer_d.text.strip_edges()
	]


# ============================================================
# GET CORRECT ANSWERS
# ============================================================

func _get_correct_answers() -> Array[int]:

	var correct_answers: Array[int] = []

	if correct_a.button_pressed:
		correct_answers.append(0)

	if correct_b.button_pressed:
		correct_answers.append(1)

	if correct_c.button_pressed:
		correct_answers.append(2)

	if correct_d.button_pressed:
		correct_answers.append(3)

	return correct_answers


# ============================================================
# SAVE CURRENT QUESTION
# ============================================================

func _save_current_question() -> bool:

	if question_text == null:
		print(
			"[QuizCreator] ERROR: Question field is missing."
		)

		return false


	var question := \
		question_text.text.strip_edges()


	if question.is_empty():

		print(
			"[QuizCreator] ERROR: Question is empty."
		)

		return false


	# --------------------------------------------------------
	# Get all four answers
	# --------------------------------------------------------

	var answers := _get_answer_texts()


	# --------------------------------------------------------
	# Validate answers
	# --------------------------------------------------------

	for i in range(answers.size()):

		if answers[i].is_empty():

			print(
				"[QuizCreator] ERROR: Answer ",
				char(65 + i),
				" is empty."
			)

			return false


	# --------------------------------------------------------
	# Get correct answers
	# --------------------------------------------------------

	var correct_answers := \
		_get_correct_answers()


	if correct_answers.is_empty():

		print(
			"[QuizCreator] ERROR: No correct answer selected."
		)

		return false


	# --------------------------------------------------------
	# Check multiple-answer setting
	# --------------------------------------------------------

	if not multiple_answers.button_pressed:

		if correct_answers.size() > 1:

			print(
				"[QuizCreator] ERROR: Multiple correct answers ",
				"are selected but Multiple Correct Answers ",
				"is disabled."
			)

			return false


	# --------------------------------------------------------
	# Build question data
	# --------------------------------------------------------

	var question_data := {

		"question": question,

		"type": "multiple_choice",

		"answers": answers,

		"correct_answers": correct_answers

	}


	# --------------------------------------------------------
	# Store question
	# --------------------------------------------------------

	if current_question_index < questions.size():

		questions[current_question_index] = \
			question_data

	else:

		questions.append(
			question_data
		)


	print(
		"[QuizCreator] Question ",
		current_question_index + 1,
		" stored."
	)


	return true


# ============================================================
# LOAD QUESTION
# ============================================================

func _load_question(index: int) -> void:

	if index < 0:
		return


	if index >= questions.size():

		_clear_question()

		return


	var data: Dictionary = \
		questions[index]


	# --------------------------------------------------------
	# Question
	# --------------------------------------------------------

	question_text.text = str(
		data.get(
			"question",
			""
		)
	)


	# --------------------------------------------------------
	# Answers
	# --------------------------------------------------------

	var answers: Array = \
		data.get(
			"answers",
			[]
		)


	answer_a.text = \
		_get_answer_from_array(
			answers,
			0
		)

	answer_b.text = \
		_get_answer_from_array(
			answers,
			1
		)

	answer_c.text = \
		_get_answer_from_array(
			answers,
			2
		)

	answer_d.text = \
		_get_answer_from_array(
			answers,
			3
		)


	# --------------------------------------------------------
	# Correct answers
	# --------------------------------------------------------

	var correct_answers: Array = \
		data.get(
			"correct_answers",
			[]
		)


	correct_a.button_pressed = \
		0 in correct_answers

	correct_b.button_pressed = \
		1 in correct_answers

	correct_c.button_pressed = \
		2 in correct_answers

	correct_d.button_pressed = \
		3 in correct_answers


	# --------------------------------------------------------
	# Multiple correct
	# --------------------------------------------------------

	multiple_answers.button_pressed = \
		correct_answers.size() > 1


	_update_navigation_buttons()


# ============================================================
# GET ANSWER FROM ARRAY
# ============================================================

func _get_answer_from_array(
	answers: Array,
	index: int
) -> String:

	if index >= answers.size():
		return ""

	return str(
		answers[index]
	)


# ============================================================
# CLEAR QUESTION
# ============================================================

func _clear_question() -> void:

	question_text.text = ""

	answer_a.text = ""
	answer_b.text = ""
	answer_c.text = ""
	answer_d.text = ""

	correct_a.button_pressed = false
	correct_b.button_pressed = false
	correct_c.button_pressed = false
	correct_d.button_pressed = false

	_update_navigation_buttons()


# ============================================================
# MULTIPLE ANSWERS TOGGLE
# ============================================================

func _on_multiple_answers_toggled(
	enabled: bool
) -> void:

	print(
		"[QuizCreator] Multiple correct answers: ",
		enabled
	)


# ============================================================
# ADD ANSWER BUTTON
# ============================================================

func _on_add_answer_button_pressed() -> void:

	print(
		"[QuizCreator] Multiple choice quizzes already ",
		"use four answer options."
	)


# ============================================================
# NEXT QUESTION
# ============================================================

func _on_next_button_pressed() -> void:

	print(
		"[QuizCreator] Next button pressed."
	)


	# --------------------------------------------------------
	# Save current question
	# --------------------------------------------------------

	if not _save_current_question():
		return


	# --------------------------------------------------------
	# Move to next existing question
	# --------------------------------------------------------

	if current_question_index < questions.size() - 1:

		current_question_index += 1

		_load_question(
			current_question_index
		)


	# --------------------------------------------------------
	# Create new question
	# --------------------------------------------------------

	else:

		current_question_index = \
			questions.size()

		_clear_question()


	_update_navigation_buttons()


	print(
		"[QuizCreator] Now editing question ",
		current_question_index + 1
	)


# ============================================================
# PREVIOUS QUESTION
# ============================================================

func _on_previous_button_pressed() -> void:

	print(
		"[QuizCreator] Previous button pressed."
	)


	if current_question_index <= 0:

		print(
			"[QuizCreator] Already at first question."
		)

		return


	# --------------------------------------------------------
	# Save current question if it already exists
	# --------------------------------------------------------

	if current_question_index < questions.size():

		if not _save_current_question():
			return


	current_question_index -= 1


	_load_question(
		current_question_index
	)


	_update_navigation_buttons()


# ============================================================
# NAVIGATION BUTTONS
# ============================================================

func _update_navigation_buttons() -> void:

	if previous_button == null \
	or next_button == null:

		return


	previous_button.disabled = \
		current_question_index <= 0


	if current_question_index >= questions.size():

		next_button.text = \
			"Add Question >"

	else:

		next_button.text = \
			"Next >"


# ============================================================
# SAVE WHOLE QUIZ
# ============================================================

func _on_save_button_pressed() -> void:

	print(
		"[QuizCreator] Save button pressed."
	)


	# --------------------------------------------------------
	# Save current question
	# --------------------------------------------------------

	if not _save_current_question():
		return


	# --------------------------------------------------------
	# Make sure quiz has questions
	# --------------------------------------------------------

	if questions.is_empty():

		print(
			"[QuizCreator] ERROR: Quiz has no questions."
		)

		return


	# --------------------------------------------------------
	# Quiz settings
	# --------------------------------------------------------

	quiz_title = \
		_get_quiz_title()

	quiz_section = \
		_get_section()


	print(
		"[QuizCreator] Quiz title: ",
		quiz_title
	)

	print(
		"[QuizCreator] Section: ",
		quiz_section
	)

	print(
		"[QuizCreator] Total questions: ",
		questions.size()
	)


	# --------------------------------------------------------
	# Validate section
	# --------------------------------------------------------

	if quiz_section.is_empty():

		print(
			"[QuizCreator] ERROR: No section selected."
		)

		return


	# --------------------------------------------------------
	# Security check
	# --------------------------------------------------------

	if not _is_valid_teacher_section(
		quiz_section
	):

		print(
			"[QuizCreator] ERROR: Selected section ",
			"is not assigned to this teacher."
		)

		return


	print(
		"[QuizCreator] Selected teacher section: ",
		quiz_section
	)


	# --------------------------------------------------------
	# Firebase token
	# --------------------------------------------------------

	var token := \
		_get_id_token()


	if token.is_empty():

		print(
			"[QuizCreator] ERROR: Firebase ID token is empty."
		)

		return


	# --------------------------------------------------------
	# UID
	# --------------------------------------------------------

	var uid := \
		_get_uid()


	if uid.is_empty():

		print(
			"[QuizCreator] ERROR: User UID is empty."
		)

		return


	# --------------------------------------------------------
	# Quiz ID
	# --------------------------------------------------------

	var quiz_id := \
		_generate_quiz_id()


	# --------------------------------------------------------
	# Convert questions to Firestore
	# --------------------------------------------------------

	var question_values: Array = []


	for question_data in questions:

		var question_map := {

			"question": {

				"stringValue": str(
					question_data.get(
						"question",
						""
					)
				)
			},

			"type": {

				"stringValue": "multiple_choice"

			},

			"answers": {

				"arrayValue": {

					"values": \
						_string_array_to_firestore(
							question_data.get(
								"answers",
								[]
							)
						)

				}

			},

			"correct_answers": {

				"arrayValue": {

					"values": \
						_int_array_to_firestore(
							question_data.get(
								"correct_answers",
								[]
							)
						)

				}

			}

		}


		question_values.append(
			{
				"mapValue": {

					"fields": question_map

				}
			}
		)


	# --------------------------------------------------------
	# Firestore fields
	# --------------------------------------------------------

	var fields := {

		"quiz_id": {

			"stringValue": \
				quiz_id

		},

		"teacher_id": {

			"stringValue": \
				uid

		},

		"title": {

			"stringValue": \
				quiz_title

		},

		"section": {

			"stringValue": \
				quiz_section

		},

		"quiz_type": {

			"stringValue": \
				"multiple_choice"

		},

		"question_count": {

			"integerValue": \
				str(
					questions.size()
				)

		},

		"questions": {

			"arrayValue": {

				"values": \
					question_values

			}

		},

		"created_at": {

			"timestampValue": \
				_get_firestore_timestamp()

		}

	}


	# --------------------------------------------------------
	# Firestore document
	# --------------------------------------------------------

	var document := {

		"fields": \
			fields

	}


	var json_body := \
		JSON.stringify(
			document
		)


	# --------------------------------------------------------
	# HTTP request
	# --------------------------------------------------------

	var http := \
		HTTPRequest.new()


	add_child(
		http
	)


	http.request_completed.connect(
		_on_save_request_completed.bind(
			http
		)
	)


	var headers := PackedStringArray([

		"Content-Type: application/json",

		"Authorization: Bearer " + token

	])


	print(
		"[QuizCreator] Saving quiz to Firestore."
	)

	print(
		"[QuizCreator] Quiz ID: ",
		quiz_id
	)

	print(
		"[QuizCreator] Teacher ID: ",
		uid
	)

	print(
		"[QuizCreator] Section: ",
		quiz_section
	)


	var error := \
		http.request(
			firestore_url + "/" + quiz_id,
			headers,
			HTTPClient.METHOD_PATCH,
			json_body
		)


	if error != OK:

		print(
			"[QuizCreator] Failed to send request: ",
			error
		)

		http.queue_free()


# ============================================================
# FIRESTORE STRING ARRAY
# ============================================================

func _string_array_to_firestore(
	values: Array
) -> Array:

	var result: Array = []


	for value in values:

		result.append(
			{
				"stringValue": \
					str(value)
			}
		)


	return result


# ============================================================
# FIRESTORE INTEGER ARRAY
# ============================================================

func _int_array_to_firestore(
	values: Array
) -> Array:

	var result: Array = []


	for value in values:

		result.append(
			{
				"integerValue": \
					str(
						int(value)
					)
			}
		)


	return result


# ============================================================
# SAVE RESPONSE
# ============================================================

func _on_save_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:

	var response_text := \
		body.get_string_from_utf8()


	print(
		"[QuizCreator] Firestore response: ",
		response_code
	)

	print(
		"[QuizCreator] Response body: ",
		response_text
	)


	http.queue_free()


	if response_code == 200:

		print(
			"[QuizCreator] QUIZ SAVED SUCCESSFULLY!"
		)

		queue_free()

		return


	print(
		"[QuizCreator] ERROR SAVING QUIZ."
	)


# ============================================================
# FIREBASE TOKEN
# ============================================================

func _get_id_token() -> String:

	if Firebase.Auth == null:

		print(
			"[QuizCreator] Firebase.Auth is null."
		)

		return ""


	var auth_data: Dictionary = \
		Firebase.Auth.auth


	if auth_data.is_empty():

		print(
			"[QuizCreator] Firebase.Auth.auth is empty."
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
			"[QuizCreator] Could not find ID token."
		)

		return ""


	return token


# ============================================================
# UID
# ============================================================

func _get_uid() -> String:

	if has_node(
		"/root/AuthManager"
	):

		var auth_manager := \
			get_node(
				"/root/AuthManager"
			)


		if auth_manager.has_method(
			"get_uid"
		):

			var uid := str(
				auth_manager.get_uid()
			)


			if not uid.is_empty():
				return uid


	if Firebase.Auth != null:

		var auth_data: Dictionary = \
			Firebase.Auth.auth


		var uid := str(
			auth_data.get(
				"localid",
				""
			)
		)


		if uid.is_empty():

			uid = str(
				auth_data.get(
					"localId",
					""
				)
			)


		return uid


	return ""


# ============================================================
# FIRESTORE TIMESTAMP
# ============================================================

func _get_firestore_timestamp() -> String:

	return Time.get_datetime_string_from_system(
		true
	) + "Z"


# ============================================================
# QUIZ ID
# ============================================================

func _generate_quiz_id() -> String:

	return "quiz_" \
		+ str(
			Time.get_unix_time_from_system()
		) \
		+ "_" \
		+ str(
			randi()
		)

extends PanelContainer


# ============================================================
# FIRESTORE
# ============================================================

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

var firestore_url: String


# ============================================================
# QUIZ SETTINGS
# ============================================================

var quiz_title: String = "True or False Quiz"
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

@onready var true_correct: CheckBox = \
	$MarginContainer/VBoxContainer/AnswerPanel/Answers/TruePanel/Margin/VBox/Correct

@onready var false_correct: CheckBox = \
	$MarginContainer/VBoxContainer/AnswerPanel/Answers/FalsePanel/Margin/VBox/Correct

@onready var previous_button: Button = \
	$MarginContainer/VBoxContainer/NavigationBar/PreviousButton

@onready var save_button: Button = \
	$MarginContainer/VBoxContainer/NavigationBar/SaveButton

@onready var next_button: Button = \
	$MarginContainer/VBoxContainer/NavigationBar/NextButton


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[TrueFalseCreator] True/False Creator opened.")

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
	# Load teacher's assigned sections
	# --------------------------------------------------------

	await _load_teacher_sections()

	# --------------------------------------------------------
	# Button connections
	# --------------------------------------------------------

	if not previous_button.pressed.is_connected(
		_on_previous_pressed
	):

		previous_button.pressed.connect(
			_on_previous_pressed
		)

	if not save_button.pressed.is_connected(
		_on_save_pressed
	):

		save_button.pressed.connect(
			_on_save_pressed
		)

	if not next_button.pressed.is_connected(
		_on_next_pressed
	):

		next_button.pressed.connect(
			_on_next_pressed
		)

	# --------------------------------------------------------
	# True / False checkbox connections
	# --------------------------------------------------------

	if not true_correct.toggled.is_connected(
		_on_true_toggled
	):

		true_correct.toggled.connect(
			_on_true_toggled
		)

	if not false_correct.toggled.is_connected(
		_on_false_toggled
	):

		false_correct.toggled.connect(
			_on_false_toggled
		)

	_update_navigation_buttons()


# ============================================================
# LOAD TEACHER ASSIGNED SECTIONS
# ============================================================

func _load_teacher_sections() -> void:

	print(
		"[TrueFalseCreator] Loading teacher assigned sections."
	)

	# --------------------------------------------------------
	# Check user role
	# --------------------------------------------------------

	var role = await AuthManager.get_user_role()

	print(
		"[TrueFalseCreator] Current user role: ",
		role
	)

	if role != "teacher":

		print(
			"[TrueFalseCreator] Current user is not a teacher."
		)

		_configure_default_sections()

		return

	# --------------------------------------------------------
	# Get teacher UID
	# --------------------------------------------------------

	var uid := AuthManager.get_uid()

	if uid.is_empty():

		print(
			"[TrueFalseCreator] ERROR: Teacher UID is empty."
		)

		_configure_default_sections()

		return

	print(
		"[TrueFalseCreator] Teacher detected. UID: ",
		uid
	)

	# --------------------------------------------------------
	# Get assigned sections
	# --------------------------------------------------------

	assigned_sections = \
		await TeacherDataManager.get_current_teacher_sections()

	print(
		"[TrueFalseCreator] Teacher assigned sections: ",
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
			"[TrueFalseCreator] WARNING: No assigned sections found."
		)

	else:

		for section in assigned_sections:

			var section_name := \
				str(section).strip_edges()

			if section_name.is_empty():
				continue

			# Use the exact section stored in Firestore.
			section_option.add_item(
				section_name
			)

			print(
				"[TrueFalseCreator] Added assigned section: ",
				section_name
			)

	section_option.select(0)


# ============================================================
# DEFAULT SECTIONS
# ============================================================

func _configure_default_sections() -> void:

	print(
		"[TrueFalseCreator] Configuring default sections."
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
		"[TrueFalseCreator] Closing True/False Creator."
	)

	queue_free()


# ============================================================
# TRUE CHECKBOX
# ============================================================

func _on_true_toggled(pressed: bool) -> void:

	if pressed:

		false_correct.button_pressed = false


# ============================================================
# FALSE CHECKBOX
# ============================================================

func _on_false_toggled(pressed: bool) -> void:

	if pressed:

		true_correct.button_pressed = false


# ============================================================
# GET QUIZ TITLE
# ============================================================

func _get_quiz_title() -> String:

	if quiz_title_input == null:

		return "True or False Quiz"

	var title := \
		quiz_title_input.text.strip_edges()

	if title.is_empty():

		return "True or False Quiz"

	return title


# ============================================================
# GET SECTION
# ============================================================

func _get_section() -> String:

	if section_option == null:

		return ""

	# Item 0 is "Select Section"

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

	# --------------------------------------------------------
	# Compare directly with the teacher's assigned sections.
	# --------------------------------------------------------

	for section in assigned_sections:

		var assigned_section := \
			str(section).strip_edges()

		if assigned_section.is_empty():
			continue

		if assigned_section == selected_section:

			return true

	return false


# ============================================================
# SAVE CURRENT QUESTION TO MEMORY
# ============================================================

func _save_current_question_to_memory() -> bool:

	var question: String = \
		question_text.text.strip_edges()

	if question.is_empty():

		print(
			"[TrueFalseCreator] ERROR: Statement is empty."
		)

		return false

	var correct_answers: Array[int] = []

	if true_correct.button_pressed:

		correct_answers.append(0)

	elif false_correct.button_pressed:

		correct_answers.append(1)

	else:

		print(
			"[TrueFalseCreator] ERROR: Select True or False."
		)

		return false

	var question_data: Dictionary = {

		"question": question,

		"type": "true_false",

		"answers": [
			"True",
			"False"
		],

		"correct_answers": correct_answers
	}

	if current_question_index < questions.size():

		questions[current_question_index] = \
			question_data

	else:

		questions.append(
			question_data
		)

	print(
		"[TrueFalseCreator] Question ",
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

		_clear_question_ui()

		return

	var data: Dictionary = \
		questions[index]

	question_text.text = str(
		data.get(
			"question",
			""
		)
	)

	# --------------------------------------------------------
	# Reset checkboxes
	# --------------------------------------------------------

	true_correct.button_pressed = false
	false_correct.button_pressed = false

	# --------------------------------------------------------
	# Load correct answer
	# --------------------------------------------------------

	var correct_answers: Array = \
		data.get(
			"correct_answers",
			[]
		)

	if not correct_answers.is_empty():

		var correct_index: int = int(
			correct_answers[0]
		)

		if correct_index == 0:

			true_correct.button_pressed = true

		elif correct_index == 1:

			false_correct.button_pressed = true

	_update_navigation_buttons()


# ============================================================
# CLEAR QUESTION UI
# ============================================================

func _clear_question_ui() -> void:

	question_text.text = ""

	true_correct.button_pressed = false
	false_correct.button_pressed = false

	_update_navigation_buttons()


# ============================================================
# NEXT QUESTION
# ============================================================

func _on_next_pressed() -> void:

	print(
		"[TrueFalseCreator] Next question pressed."
	)

	# --------------------------------------------------------
	# Save current question
	# --------------------------------------------------------

	if not _save_current_question_to_memory():

		return

	# --------------------------------------------------------
	# Move forward
	# --------------------------------------------------------

	if current_question_index < questions.size() - 1:

		current_question_index += 1

		_load_question(
			current_question_index
		)

	else:

		current_question_index = \
			questions.size()

		_clear_question_ui()

	_update_navigation_buttons()

	print(
		"[TrueFalseCreator] Now editing question ",
		current_question_index + 1
	)


# ============================================================
# PREVIOUS QUESTION
# ============================================================

func _on_previous_pressed() -> void:

	print(
		"[TrueFalseCreator] Previous question pressed."
	)

	if current_question_index <= 0:

		print(
			"[TrueFalseCreator] Already at first question."
		)

		return

	# --------------------------------------------------------
	# Save current question if editing an existing question
	# --------------------------------------------------------

	if current_question_index < questions.size():

		if not _save_current_question_to_memory():

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

	previous_button.disabled = (
		current_question_index <= 0
	)

	if current_question_index >= questions.size():

		next_button.text = \
			"Add Question >"

	else:

		next_button.text = \
			"Next >"


# ============================================================
# SAVE WHOLE QUIZ
# ============================================================

func _on_save_pressed() -> void:

	print(
		"[TrueFalseCreator] Save button pressed."
	)

	# --------------------------------------------------------
	# Save current question
	# --------------------------------------------------------

	if not _save_current_question_to_memory():

		return

	# --------------------------------------------------------
	# Make sure quiz has questions
	# --------------------------------------------------------

	if questions.is_empty():

		print(
			"[TrueFalseCreator] ERROR: Quiz has no questions."
		)

		return

	# --------------------------------------------------------
	# Get Quiz Title
	# --------------------------------------------------------

	quiz_title = \
		_get_quiz_title()

	# --------------------------------------------------------
	# Get Section
	# --------------------------------------------------------

	quiz_section = \
		_get_section()

	if quiz_section.is_empty():

		print(
			"[TrueFalseCreator] ERROR: Please select a section."
		)

		return

	# --------------------------------------------------------
	# Security check
	#
	# Make sure the selected section actually belongs
	# to this teacher.
	# --------------------------------------------------------

	if not _is_valid_teacher_section(
		quiz_section
	):

		print(
			"[TrueFalseCreator] ERROR: Selected section is not assigned to this teacher."
		)

		return

	print(
		"[TrueFalseCreator] Quiz title: ",
		quiz_title
	)

	print(
		"[TrueFalseCreator] Quiz section: ",
		quiz_section
	)

	print(
		"[TrueFalseCreator] Total questions: ",
		questions.size()
	)

	print(
		"[TrueFalseCreator] Selected teacher section: ",
		quiz_section
	)

	# --------------------------------------------------------
	# Firebase token
	# --------------------------------------------------------

	var token := \
		_get_id_token()

	if token.is_empty():

		print(
			"[TrueFalseCreator] ERROR: Firebase ID token is empty."
		)

		return

	# --------------------------------------------------------
	# UID
	# --------------------------------------------------------

	var uid := \
		_get_uid()

	if uid.is_empty():

		print(
			"[TrueFalseCreator] ERROR: User UID is empty."
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

				"stringValue": \
					"true_false"
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
				"true_false"
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
		"[TrueFalseCreator] Saving True/False quiz to Firestore."
	)

	print(
		"[TrueFalseCreator] Quiz ID: ",
		quiz_id
	)

	print(
		"[TrueFalseCreator] Teacher ID: ",
		uid
	)

	print(
		"[TrueFalseCreator] Section: ",
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
			"[TrueFalseCreator] Failed to send request: ",
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
		"[TrueFalseCreator] Firestore response: ",
		response_code
	)

	print(
		"[TrueFalseCreator] Response body: ",
		response_text
	)

	http.queue_free()

	if response_code == 200:

		print(
			"[TrueFalseCreator] TRUE/FALSE QUIZ SAVED SUCCESSFULLY!"
		)

		queue_free()

		return

	print(
		"[TrueFalseCreator] ERROR SAVING TRUE/FALSE QUIZ."
	)


# ============================================================
# FIREBASE TOKEN
# ============================================================

func _get_id_token() -> String:

	if Firebase.Auth == null:

		print(
			"[TrueFalseCreator] Firebase.Auth is null."
		)

		return ""

	var auth_data: Dictionary = \
		Firebase.Auth.auth

	if auth_data.is_empty():

		print(
			"[TrueFalseCreator] Firebase.Auth.auth is empty."
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
			"[TrueFalseCreator] Could not find ID token."
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

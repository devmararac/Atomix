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

@onready var quiz_settings = \
	$MarginContainer/VBoxContainer/QuizSettings

@onready var quiz_title_input: LineEdit = \
	$MarginContainer/VBoxContainer/QuizSettings/QuizTitle

@onready var section_option: OptionButton = \
	$MarginContainer/VBoxContainer/QuizSettings/SectionOption

@onready var question_text: TextEdit = \
	$MarginContainer/VBoxContainer/QuestionPanel/QuestionMargin/QuestionText

@onready var answer_text: TextEdit = \
	$MarginContainer/VBoxContainer/AnswerPanel/Margin/VBox/AnswerText

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

	print("[IdentificationCreator] Identification Quiz Creator opened.")

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
	# Connect buttons
	# --------------------------------------------------------

	if not save_button.pressed.is_connected(
		_on_save_button_pressed
	):
		save_button.pressed.connect(
			_on_save_button_pressed
	)

	if not next_button.pressed.is_connected(
		_on_next_button_pressed
	):
		next_button.pressed.connect(
			_on_next_button_pressed
	)

	if not previous_button.pressed.is_connected(
		_on_previous_button_pressed
	):
		previous_button.pressed.connect(
			_on_previous_button_pressed
	)

	_update_navigation_buttons()


# ============================================================
# LOAD TEACHER ASSIGNED SECTIONS
# ============================================================

func _load_teacher_sections() -> void:

	print(
		"[IdentificationCreator] Loading teacher assigned sections."
	)

	# --------------------------------------------------------
	# Check user role
	# --------------------------------------------------------

	var role = await AuthManager.get_user_role()

	print(
		"[IdentificationCreator] Current user role: ",
		role
	)

	if role != "teacher":

		print(
			"[IdentificationCreator] Current user is not a teacher."
		)

		_configure_default_sections()

		return

	# --------------------------------------------------------
	# Get teacher UID
	# --------------------------------------------------------

	var uid := AuthManager.get_uid()

	if uid.is_empty():

		print(
			"[IdentificationCreator] ERROR: Teacher UID is empty."
		)

		_configure_default_sections()

		return

	print(
		"[IdentificationCreator] Teacher detected. UID: ",
		uid
	)

	# --------------------------------------------------------
	# Get assigned sections from TeacherDataManager
	# --------------------------------------------------------

	assigned_sections = \
		await TeacherDataManager.get_current_teacher_sections()

	print(
		"[IdentificationCreator] Teacher assigned sections: ",
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
			"[IdentificationCreator] WARNING: No assigned sections found."
		)

	else:

		for section in assigned_sections:

			var section_name := \
				str(section).strip_edges()

			if section_name.is_empty():
				continue

			# ------------------------------------------------
			# DO NOT ADD GRADE LEVEL
			#
			# Firestore:
			# assigned_sections = ["A"]
			#
			# Dropdown:
			# A
			# ------------------------------------------------

			section_option.add_item(
				section_name
			)

			print(
				"[IdentificationCreator] Added assigned section: ",
				section_name
			)

	section_option.select(0)


# ============================================================
# DEFAULT SECTIONS
# ============================================================

func _configure_default_sections() -> void:

	print(
		"[IdentificationCreator] Configuring default sections."
	)

	section_option.clear()

	section_option.add_item(
		"Select Section"
	)

	section_option.add_item(
		"A"
	)

	section_option.add_item(
		"B"
	)

	section_option.add_item(
		"C"
	)

	section_option.select(0)


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

# ============================================================
# VALIDATE SECTION
# ============================================================

func _is_valid_teacher_section(
	selected_section: String
) -> bool:

	if selected_section.is_empty():
		return false

	# --------------------------------------------------------
	# Check selected section directly against teacher's
	# assigned sections.
	# --------------------------------------------------------

	for section in assigned_sections:

		var assigned_section := \
			str(section).strip_edges()

		if assigned_section.is_empty():
			continue

		# ----------------------------------------------------
		# Direct comparison.
		#
		# assigned_sections:
		# ["A"]
		#
		# selected_section:
		# "A"
		#
		# Result:
		# VALID
		# ----------------------------------------------------

		if assigned_section == selected_section:

			return true

	return false

# ============================================================
# CLOSE
# ============================================================

func _on_texture_button_pressed() -> void:

	print(
		"[IdentificationCreator] Closing."
	)

	queue_free()


# ============================================================
# SAVE CURRENT QUESTION
# ============================================================

func _save_current_question() -> bool:

	var question := \
		question_text.text.strip_edges()

	var answer := \
		answer_text.text.strip_edges()

	if question.is_empty():

		print(
			"[IdentificationCreator] ERROR: Question is empty."
		)

		return false

	if answer.is_empty():

		print(
			"[IdentificationCreator] ERROR: Correct answer is empty."
		)

		return false

	var question_data := {

		"question": question,

		"type": "identification",

		"answers": [
			answer
		],

		"correct_answers": [
			0
		]
	}

	if current_question_index < questions.size():

		questions[current_question_index] = \
			question_data

	else:

		questions.append(
			question_data
		)

	print(
		"[IdentificationCreator] Question ",
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

	question_text.text = str(
		data.get(
			"question",
			""
		)
	)

	var answers: Array = \
		data.get(
			"answers",
			[]
		)

	if answers.size() > 0:

		answer_text.text = str(
			answers[0]
		)

	else:

		answer_text.text = ""

	_update_navigation_buttons()


# ============================================================
# CLEAR QUESTION
# ============================================================

func _clear_question() -> void:

	question_text.text = ""

	answer_text.text = ""

	_update_navigation_buttons()


# ============================================================
# NEXT QUESTION
# ============================================================

func _on_next_button_pressed() -> void:

	print(
		"[IdentificationCreator] Next button pressed."
	)

	if not _save_current_question():

		return

	if current_question_index < questions.size() - 1:

		current_question_index += 1

		_load_question(
			current_question_index
		)

	else:

		current_question_index = \
			questions.size()

		_clear_question()

	_update_navigation_buttons()


# ============================================================
# PREVIOUS QUESTION
# ============================================================

func _on_previous_button_pressed() -> void:

	print(
		"[IdentificationCreator] Previous button pressed."
	)

	if current_question_index <= 0:

		print(
			"[IdentificationCreator] Already at first question."
		)

		return

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

	if previous_button == null:
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

func _on_save_button_pressed() -> void:

	print(
		"[IdentificationCreator] Save button pressed."
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
			"[IdentificationCreator] ERROR: Quiz has no questions."
		)

		return

	# --------------------------------------------------------
	# Get selected section
	# --------------------------------------------------------

	quiz_section = _get_section()

	if quiz_section.is_empty():

		print(
			"[IdentificationCreator] ERROR: No section selected."
		)

		return

	# --------------------------------------------------------
	# SECURITY CHECK
	#
	# Make sure the selected section actually belongs
	# to the teacher.
	# --------------------------------------------------------

	if not _is_valid_teacher_section(
		quiz_section
	):

		print(
			"[IdentificationCreator] ERROR: Selected section is not assigned to this teacher."
		)

		return

	print(
		"[IdentificationCreator] Selected teacher section: ",
		quiz_section
	)

	print(
		"[IdentificationCreator] Total questions: ",
		questions.size()
	)

	# --------------------------------------------------------
	# Firebase token
	# --------------------------------------------------------

	var token := _get_id_token()

	if token.is_empty():

		print(
			"[IdentificationCreator] ERROR: Firebase ID token is empty."
		)

		return

	# --------------------------------------------------------
	# UID
	# --------------------------------------------------------

	var uid := _get_uid()

	if uid.is_empty():

		print(
			"[IdentificationCreator] ERROR: User UID is empty."
		)

		return

	# --------------------------------------------------------
	# Quiz ID
	# --------------------------------------------------------

	var quiz_id := \
		_generate_quiz_id()

	# --------------------------------------------------------
	# Convert questions
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
				"stringValue": "identification"
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
	# Quiz title
	# --------------------------------------------------------

	quiz_title = "Identification Quiz"

	# --------------------------------------------------------
	# Firestore document
	# --------------------------------------------------------

	var fields := {

		"quiz_id": {
			"stringValue": quiz_id
		},

		"teacher_id": {
			"stringValue": uid
		},

		"title": {
			"stringValue": quiz_title
		},

		"section": {
			"stringValue": quiz_section
		},

		"quiz_type": {
			"stringValue": "identification"
		},

		"question_count": {
			"integerValue": str(
				questions.size()
			)
		},

		"questions": {
			"arrayValue": {
				"values": question_values
			}
		},

		"created_at": {
			"timestampValue":
				_get_firestore_timestamp()
		}
	}

	var document := {
		"fields": fields
	}

	var json_body := \
		JSON.stringify(document)

	# --------------------------------------------------------
	# HTTP request
	# --------------------------------------------------------

	var http := HTTPRequest.new()

	add_child(http)

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
		"[IdentificationCreator] Saving quiz to Firestore."
	)

	print(
		"[IdentificationCreator] Quiz ID: ",
		quiz_id
	)

	print(
		"[IdentificationCreator] Teacher ID: ",
		uid
	)

	print(
		"[IdentificationCreator] Section: ",
		quiz_section
	)

	var error := http.request(
		firestore_url + "/" + quiz_id,
		headers,
		HTTPClient.METHOD_PATCH,
		json_body
	)

	if error != OK:

		print(
			"[IdentificationCreator] Failed to send request: ",
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
				"stringValue": str(value)
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
				"integerValue": str(
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
		"[IdentificationCreator] Firestore response: ",
		response_code
	)

	print(
		"[IdentificationCreator] Response body: ",
		response_text
	)

	http.queue_free()

	if response_code == 200:

		print(
			"[IdentificationCreator] QUIZ SAVED SUCCESSFULLY!"
		)

		queue_free()

		return

	print(
		"[IdentificationCreator] ERROR SAVING QUIZ."
	)


# ============================================================
# FIREBASE TOKEN
# ============================================================

func _get_id_token() -> String:

	if Firebase.Auth == null:

		print(
			"[IdentificationCreator] Firebase.Auth is null."
		)

		return ""

	var auth_data: Dictionary = \
		Firebase.Auth.auth

	if auth_data.is_empty():

		print(
			"[IdentificationCreator] Firebase.Auth.auth is empty."
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
			"[IdentificationCreator] Could not find ID token."
		)

		return ""

	return token


# ============================================================
# UID
# ============================================================

func _get_uid() -> String:

	if has_node("/root/AuthManager"):

		var auth_manager = \
			get_node("/root/AuthManager")

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

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

var quiz_title: String = "Untitled Quiz"
var quiz_section: String = ""

# Sections assigned to the currently logged-in teacher.
#
# Example Firestore:
# assigned_sections = ["A"]
#
# Dropdown:
# A
#
var assigned_sections: Array = []

var questions: Array[Dictionary] = []

var current_question_index: int = 0


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var quiz_title_input: LineEdit = \
	$MarginContainer/VBoxContainer/QuizSettings/QuizTitle

@onready var section_option: OptionButton = \
	$MarginContainer/VBoxContainer/QuizSettings/SectionOption

@onready var question_text: TextEdit = \
	$MarginContainer/VBoxContainer/QuestionPanel/QuestionMargin/QuestionText

@onready var answers_container: VBoxContainer = \
	$MarginContainer/VBoxContainer/EnumerationPanel/Margin/VBox/AnswerScroll/Answers

@onready var answer_scroll: ScrollContainer = \
	$MarginContainer/VBoxContainer/EnumerationPanel/Margin/VBox/AnswerScroll

@onready var add_answer_button: Button = \
	$MarginContainer/VBoxContainer/EnumerationPanel/Margin/VBox/AddAnswerButton

@onready var previous_button: Button = \
	$MarginContainer/VBoxContainer/NavigationBar/PreviousButton

@onready var save_button: Button = \
	$MarginContainer/VBoxContainer/NavigationBar/SaveButton

@onready var next_button: Button = \
	$MarginContainer/VBoxContainer/NavigationBar/NextButton


# ============================================================
# DYNAMIC ANSWER COUNTER
# ============================================================

var answer_counter: int = 3


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[EnumerationCreator] Enumeration Creator opened.")

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
	# Load teacher assigned sections
	# --------------------------------------------------------

	await _load_teacher_sections()

	# --------------------------------------------------------
	# Configure existing answer scroll
	#
	# IMPORTANT:
	# AnswerScroll already exists in enumeration_creator.tscn.
	# We DO NOT create another ScrollContainer here.
	# --------------------------------------------------------

	_configure_answer_scroll()

	# --------------------------------------------------------
	# Update answer counter based on existing boxes
	# --------------------------------------------------------

	_update_answer_counter()

	# --------------------------------------------------------
	# Connect buttons
	# --------------------------------------------------------

	if not add_answer_button.pressed.is_connected(
		_on_add_answer_button_pressed
	):
		add_answer_button.pressed.connect(
			_on_add_answer_button_pressed
	)

	if not previous_button.pressed.is_connected(
		_on_previous_button_pressed
	):
		previous_button.pressed.connect(
			_on_previous_button_pressed
	)

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

	_update_navigation_buttons()


# ============================================================
# LOAD TEACHER ASSIGNED SECTIONS
# ============================================================

func _load_teacher_sections() -> void:

	print(
		"[EnumerationCreator] Loading teacher assigned sections."
	)

	# --------------------------------------------------------
	# Clear dropdown
	# --------------------------------------------------------

	section_option.clear()

	section_option.add_item(
		"Select Section"
	)

	section_option.select(0)

	# --------------------------------------------------------
	# Check user role
	# --------------------------------------------------------

	var role = await AuthManager.get_user_role()

	print(
		"[EnumerationCreator] Current user role: ",
		role
	)

	if role != "teacher":

		print(
			"[EnumerationCreator] Current user is not a teacher."
		)

		_configure_default_sections()

		return

	# --------------------------------------------------------
	# Get teacher UID
	# --------------------------------------------------------

	var uid = AuthManager.get_uid()

	if uid.is_empty():

		print(
			"[EnumerationCreator] ERROR: Teacher UID is empty."
		)

		_configure_default_sections()

		return

	print(
		"[EnumerationCreator] Teacher detected. UID: ",
		uid
	)

	# --------------------------------------------------------
	# Get assigned sections from TeacherDataManager
	# --------------------------------------------------------

	assigned_sections = \
		await TeacherDataManager.get_current_teacher_sections()

	print(
		"[EnumerationCreator] Teacher assigned sections: ",
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
			"[EnumerationCreator] WARNING: No assigned sections found."
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
				"[EnumerationCreator] Added assigned section: ",
				section_name
			)

	section_option.select(0)


# ============================================================
# DEFAULT SECTIONS
# ============================================================

func _configure_default_sections() -> void:

	print(
		"[EnumerationCreator] Configuring default sections."
	)

	# Keep this in sync with the sections used by the teacher
	# system when no teacher-specific data is available.

	assigned_sections = [
		"A",
		"B",
		"C"
	]

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
# CONFIGURE EXISTING ANSWER SCROLL
# ============================================================

func _configure_answer_scroll() -> void:

	# --------------------------------------------------------
	# The ScrollContainer already exists in the .tscn.
	#
	# We simply configure it.
	# --------------------------------------------------------

	if answer_scroll == null:

		print(
			"[EnumerationCreator] ERROR: AnswerScroll node not found."
		)

		return

	answer_scroll.size_flags_vertical = \
		Control.SIZE_EXPAND_FILL

	answer_scroll.size_flags_horizontal = \
		Control.SIZE_EXPAND_FILL

	answer_scroll.custom_minimum_size = \
		Vector2(0, 110)

	answer_scroll.horizontal_scroll_mode = \
		ScrollContainer.SCROLL_MODE_DISABLED

	answer_scroll.vertical_scroll_mode = \
		ScrollContainer.SCROLL_MODE_AUTO

	# Make sure Answers fills the available width.

	if answers_container != null:

		answers_container.size_flags_horizontal = \
			Control.SIZE_EXPAND_FILL

	print(
		"[EnumerationCreator] Existing AnswerScroll configured."
	)


# ============================================================
# CLOSE
# ============================================================

func _on_texture_button_pressed() -> void:

	print(
		"[EnumerationCreator] Closing Enumeration Creator."
	)

	queue_free()


# ============================================================
# ADD ANSWER
# ============================================================

func _on_add_answer_button_pressed() -> void:

	answer_counter += 1

	var answer := LineEdit.new()

	answer.name = \
		"Answer" + str(answer_counter)

	answer.custom_minimum_size = \
		Vector2(0, 45)

	answer.size_flags_horizontal = \
		Control.SIZE_EXPAND_FILL

	answer.placeholder_text = \
		"Answer " + str(answer_counter)

	answer.add_theme_font_size_override(
		"font_size",
		20
	)

	answers_container.add_child(
		answer
	)

	print(
		"[EnumerationCreator] Added Answer ",
		answer_counter
	)


# ============================================================
# GET ANSWERS
# ============================================================

func _get_answers() -> Array[String]:

	var answers: Array[String] = []

	for child in answers_container.get_children():

		if child is LineEdit:

			var value: String = \
				child.text.strip_edges()

			if not value.is_empty():

				answers.append(
					value
				)

	return answers


# ============================================================
# GET QUIZ TITLE
# ============================================================

func _get_quiz_title() -> String:

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

	var selected_section := \
		section_option.get_item_text(
			section_option.selected
		).strip_edges()

	# --------------------------------------------------------
	# Extra security check:
	# Make sure selected section belongs to this teacher.
	# --------------------------------------------------------

	for assigned_section in assigned_sections:

		var allowed_section := \
			str(assigned_section).strip_edges()

		if allowed_section.is_empty():
			continue

		if selected_section == allowed_section:

			return selected_section

	return ""


# ============================================================
# VALIDATE TEACHER SECTION
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
			"[EnumerationCreator] ERROR: Question is empty."
		)

		return false

	var answers: Array[String] = \
		_get_answers()

	if answers.is_empty():

		print(
			"[EnumerationCreator] ERROR: At least one answer is required."
		)

		return false

	var question_data: Dictionary = {

		"question": question,

		"type": "enumeration",

		"answers": answers
	}

	if current_question_index < questions.size():

		questions[
			current_question_index
		] = question_data

	else:

		questions.append(
			question_data
		)

	print(
		"[EnumerationCreator] Question ",
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

	await _clear_answer_boxes()

	var answers: Array = \
		data.get(
			"answers",
			[]
		)

	# --------------------------------------------------------
	# Restore first three answer boxes.
	# --------------------------------------------------------

	for i in range(
		min(
			answers.size(),
			3
		)
	):

		var existing_answer := \
			answers_container.get_child(i)

		if existing_answer is LineEdit:

			existing_answer.text = str(
				answers[i]
			)

	# --------------------------------------------------------
	# Create additional answer boxes.
	# --------------------------------------------------------

	for i in range(
		3,
		answers.size()
	):

		_create_answer_from_data(
			str(answers[i])
		)

	_update_answer_counter()

	# --------------------------------------------------------
	# Start scroll position at top.
	# --------------------------------------------------------

	if answer_scroll != null:

		answer_scroll.scroll_vertical = 0

	_update_navigation_buttons()


# ============================================================
# CREATE ANSWER FROM SAVED DATA
# ============================================================

func _create_answer_from_data(
	text_value: String
) -> void:

	answer_counter += 1

	var answer := LineEdit.new()

	answer.name = \
		"Answer" + str(answer_counter)

	answer.custom_minimum_size = \
		Vector2(0, 45)

	answer.size_flags_horizontal = \
		Control.SIZE_EXPAND_FILL

	answer.text = text_value

	answer.placeholder_text = \
		"Answer " + str(answer_counter)

	answer.add_theme_font_size_override(
		"font_size",
		20
	)

	answers_container.add_child(
		answer
	)


# ============================================================
# UPDATE ANSWER COUNTER
# ============================================================

func _update_answer_counter() -> void:

	answer_counter = \
		answers_container.get_child_count()


# ============================================================
# CLEAR QUESTION UI
# ============================================================

func _clear_question_ui() -> void:

	question_text.text = ""

	# --------------------------------------------------------
	# Remove extra answer boxes.
	# --------------------------------------------------------

	var children := \
		answers_container.get_children()

	for i in range(
		children.size() - 1,
		2,
		-1
	):

		children[i].queue_free()

	# --------------------------------------------------------
	# Wait until Godot actually removes the nodes.
	# --------------------------------------------------------

	await get_tree().process_frame

	# --------------------------------------------------------
	# Clear first three boxes.
	# --------------------------------------------------------

	for child in answers_container.get_children():

		if child is LineEdit:

			child.text = ""

	answer_counter = 3

	if answer_scroll != null:

		answer_scroll.scroll_vertical = 0

	_update_navigation_buttons()


# ============================================================
# CLEAR ANSWER BOXES
# ============================================================

func _clear_answer_boxes() -> void:

	var children := \
		answers_container.get_children()

	# --------------------------------------------------------
	# Keep Answer1, Answer2 and Answer3.
	# --------------------------------------------------------

	for i in range(
		children.size() - 1,
		2,
		-1
	):

		children[i].queue_free()

	# --------------------------------------------------------
	# Wait until Godot actually removes the nodes.
	# --------------------------------------------------------

	await get_tree().process_frame

	answer_counter = 3

	# --------------------------------------------------------
	# Clear first three boxes.
	# --------------------------------------------------------

	for child in answers_container.get_children():

		if child is LineEdit:

			child.text = ""

	# --------------------------------------------------------
	# Reset scroll position.
	# --------------------------------------------------------

	if answer_scroll != null:

		answer_scroll.scroll_vertical = 0


# ============================================================
# NEXT QUESTION
# ============================================================

func _on_next_button_pressed() -> void:

	print(
		"[EnumerationCreator] Next question pressed."
	)

	if not _save_current_question_to_memory():
		return

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
		"[EnumerationCreator] Now editing question ",
		current_question_index + 1
	)


# ============================================================
# PREVIOUS QUESTION
# ============================================================

func _on_previous_button_pressed() -> void:

	print(
		"[EnumerationCreator] Previous question pressed."
	)

	if current_question_index <= 0:

		print(
			"[EnumerationCreator] Already at first question."
		)

		return

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

	if previous_button == null:
		return

	if next_button == null:
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
		"[EnumerationCreator] Save button pressed."
	)

	# --------------------------------------------------------
	# Get selected section.
	# --------------------------------------------------------

	quiz_section = \
		_get_section()

	if quiz_section.is_empty():

		print(
			"[EnumerationCreator] ERROR: Invalid or unassigned section."
		)

		return

	# --------------------------------------------------------
	# Security check.
	# --------------------------------------------------------

	if not _is_valid_teacher_section(
		quiz_section
	):

		print(
			"[EnumerationCreator] ERROR: Selected section is not assigned to this teacher."
		)

		return

	# --------------------------------------------------------
	# Save current question.
	# --------------------------------------------------------

	if not _save_current_question_to_memory():

		return

	# --------------------------------------------------------
	# Make sure quiz has questions.
	# --------------------------------------------------------

	if questions.is_empty():

		print(
			"[EnumerationCreator] ERROR: Quiz has no questions."
		)

		return

	# --------------------------------------------------------
	# Quiz title.
	# --------------------------------------------------------

	quiz_title = \
		_get_quiz_title()

	print(
		"[EnumerationCreator] Quiz title: ",
		quiz_title
	)

	print(
		"[EnumerationCreator] Teacher section: ",
		quiz_section
	)

	print(
		"[EnumerationCreator] Total questions: ",
		questions.size()
	)

	# --------------------------------------------------------
	# Firebase ID token.
	# --------------------------------------------------------

	var token := \
		_get_id_token()

	if token.is_empty():

		print(
			"[EnumerationCreator] ERROR: Firebase ID token is empty."
		)

		return

	# --------------------------------------------------------
	# UID.
	# --------------------------------------------------------

	var uid := \
		_get_uid()

	if uid.is_empty():

		print(
			"[EnumerationCreator] ERROR: User UID is empty."
		)

		return

	# --------------------------------------------------------
	# Quiz ID.
	# --------------------------------------------------------

	var quiz_id := \
		_generate_quiz_id()

	# --------------------------------------------------------
	# Convert questions to Firestore format.
	# --------------------------------------------------------

	var question_values: Array = []

	for question_data in questions:

		var answer_values: Array = []

		var question_answers: Array = \
			question_data.get(
				"answers",
				[]
			)

		for answer in question_answers:

			answer_values.append(
				{
					"stringValue": str(answer)
				}
			)

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
				"stringValue": "enumeration"
			},

			"answers": {
				"arrayValue": {
					"values": answer_values
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
	# Firestore fields.
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
			"stringValue": "enumeration"
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
			"timestampValue": \
				_get_firestore_timestamp()
		}
	}

	# --------------------------------------------------------
	# Firestore document.
	# --------------------------------------------------------

	var document := {
		"fields": fields
	}

	var json_body := \
		JSON.stringify(document)

	# --------------------------------------------------------
	# HTTP request.
	# --------------------------------------------------------

	var http := \
		HTTPRequest.new()

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
		"[EnumerationCreator] Saving enumeration quiz to Firestore."
	)

	print(
		"[EnumerationCreator] Quiz ID: ",
		quiz_id
	)

	print(
		"[EnumerationCreator] Teacher ID: ",
		uid
	)

	print(
		"[EnumerationCreator] Section: ",
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
			"[EnumerationCreator] Failed to send request: ",
			error
		)

		http.queue_free()


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

	var response_text: String = \
		body.get_string_from_utf8()

	print(
		"[EnumerationCreator] Firestore response: ",
		response_code
	)

	print(
		"[EnumerationCreator] Response body: ",
		response_text
	)

	http.queue_free()

	if response_code == 200:

		print(
			"[EnumerationCreator] ENUMERATION QUIZ SAVED SUCCESSFULLY!"
		)

		queue_free()

		return

	print(
		"[EnumerationCreator] ERROR SAVING ENUMERATION QUIZ."
	)


# ============================================================
# FIREBASE TOKEN
# ============================================================

func _get_id_token() -> String:

	if Firebase.Auth == null:

		print(
			"[EnumerationCreator] Firebase.Auth is null."
		)

		return ""

	var auth_data: Dictionary = \
		Firebase.Auth.auth

	if auth_data.is_empty():

		print(
			"[EnumerationCreator] Firebase.Auth.auth is empty."
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
			"[EnumerationCreator] Could not find ID token."
		)

		return ""

	return token


# ============================================================
# UID
# ============================================================

func _get_uid() -> String:

	if has_node("/root/AuthManager"):

		var auth_manager := \
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

	return "quiz_" + str(
		Time.get_unix_time_from_system()
	) + "_" + str(
		randi()
	)

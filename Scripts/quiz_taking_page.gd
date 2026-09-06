extends Control

# ============================================================

# QUIZ DATA

# ============================================================

var quiz_data: Dictionary = {}
var return_page: Control = null
var questions: Array = []
var current_question_index: int = 0
var score: int = 0

# True when the quiz has already been submitted.

var quiz_completed: bool = false

# Prevents submitting the same quiz multiple times.

var saving_result: bool = false

# Stores the student's selected answer for each question.

# -1 means no answer selected.

var selected_answers: Array = []

# Stores text answers for identification questions.

var text_answers: Array = []

# Stores multiple text answers for enumeration questions.

# Each question contains an Array of strings.

var enumeration_answers: Array = []

# ============================================================

# FIREBASE CONFIG

# ============================================================

const PROJECT_ID: String = "atomix-f6c6b"
const DATABASE_ID: String = "(default)"

# ============================================================

# UI REFERENCES

# ============================================================

@onready var quiz_title: Label = $QuizPanel/MarginContainer/VBoxContainer/Header/QuizTitle

@onready var question_counter: Label = $QuizPanel/MarginContainer/VBoxContainer/Header/QuestionCounter

@onready var question_label: Label = $QuizPanel/MarginContainer/VBoxContainer/QuestionPanel/MarginContainer/QuestionLabel

@onready var answer_container: VBoxContainer = $QuizPanel/MarginContainer/VBoxContainer/AnswerScroll/AnswerContainer

@onready var identification_input: LineEdit = $QuizPanel/MarginContainer/VBoxContainer/AnswerScroll/AnswerContainer/IdentificationInput

@onready var enumeration_input: VBoxContainer = $QuizPanel/MarginContainer/VBoxContainer/AnswerScroll/AnswerContainer/EnumerationInput

@onready var back_button: Button = $QuizPanel/MarginContainer/VBoxContainer/BottomBar/BackButton

@onready var next_button: Button = $QuizPanel/MarginContainer/VBoxContainer/BottomBar/NextButton

@onready var status_label: Label = $QuizPanel/MarginContainer/VBoxContainer/StatusLabel

# ============================================================
# READY
# ============================================================
func _ready() -> void:


	print("[QuizTakingPage] Quiz taking page opened.")

	visible = true
	z_index = 100

	_hide_previous_ui()

	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)

	if quiz_data.is_empty():

		print("[QuizTakingPage] ERROR: No quiz data received.")

		question_label.text = "Unable to load this quiz."
		status_label.text = "No quiz data was provided."

		next_button.disabled = true

		return

	questions = quiz_data.get("questions", [])

	if questions.is_empty():

		print("[QuizTakingPage] ERROR: Quiz contains no questions.")

		question_label.text = "This quiz has no questions."
		status_label.text = "No questions are available."

		next_button.disabled = true

		return

	quiz_title.text = str(
		quiz_data.get("title", "Quiz")
	)

	print(
		"[QuizTakingPage] Quiz title: ",
		quiz_title.text
	)

	print(
		"[QuizTakingPage] Total questions: ",
		questions.size()
	)

	selected_answers.clear()
	text_answers.clear()
	enumeration_answers.clear()

	for i in range(questions.size()):

		selected_answers.append(-1)
		text_answers.append("")
		enumeration_answers.append([])

	current_question_index = 0
	score = 0
	quiz_completed = false
	saving_result = false

	_show_question()


	# ============================================================

	# HIDE PREVIOUS UI

	# ============================================================

func _hide_previous_ui() -> void:
	print(
		"[QuizTakingPage] Previous UI is already handled by QuizPage."
	)

	# ============================================================

	# SHOW QUESTION

	# ============================================================

func _show_question() -> void:


	if current_question_index < 0:
		return

	if current_question_index >= questions.size():
		return

	var question_data: Dictionary = \
		questions[current_question_index]

	var question_text: String = str(
		question_data.get(
			"question",
			"Question unavailable."
		)
	)

	question_label.text = question_text

	question_counter.text = \
		"Question " \
		+ str(current_question_index + 1) \
		+ " / " \
		+ str(questions.size())

	var question_type: String = str(
		question_data.get(
			"type",
			"multiple_choice"
		)
	).strip_edges().to_lower()

	print(
		"[QuizTakingPage] Showing question ",
		current_question_index + 1,
		" type: ",
		question_type
	)

	# --------------------------------------------------------
	# Remove dynamically-created answer controls.
	# --------------------------------------------------------

	for child in answer_container.get_children():

		if child == identification_input:
			continue

		if child == enumeration_input:
			continue

		child.queue_free()

	await get_tree().process_frame

	# --------------------------------------------------------
	# Hide fixed inputs.
	# --------------------------------------------------------

	identification_input.visible = false
	identification_input.text = ""

	enumeration_input.visible = false

	# Remove old enumeration input boxes.
	for child in enumeration_input.get_children():

		child.queue_free()

	# --------------------------------------------------------
	# Build question based on type.
	# --------------------------------------------------------

	if _is_multiple_choice(question_type):

		_build_multiple_choice(question_data)

	elif _is_true_false(question_type):

		_build_true_false(question_data)

	elif _is_identification(question_type):

		_build_identification(question_data)

	elif _is_enumeration(question_type):

		_build_enumeration(question_data)

	else:

		print(
			"[QuizTakingPage] Unknown question type: ",
			question_type
		)

		_build_multiple_choice(question_data)

	# --------------------------------------------------------
	# Button text.
	# --------------------------------------------------------

	if current_question_index == questions.size() - 1:

		next_button.text = "SUBMIT ✓"

	else:

		next_button.text = "NEXT →"

	status_label.text = "Select your answer."

	_restore_previous_answer(
		question_data,
		question_type
	)


	# ============================================================

	# MULTIPLE CHOICE

	# ============================================================

func _build_multiple_choice(
	question_data: Dictionary
	) -> void:

	var answers: Array = question_data.get(
		"answers",
		[]
	)

	if answers.is_empty():

		var label: Label = Label.new()

		label.text = "No answer choices available."

		label.horizontal_alignment = \
			HORIZONTAL_ALIGNMENT_CENTER

		answer_container.add_child(label)

		return

	var button_group: ButtonGroup = ButtonGroup.new()

	for index in range(answers.size()):

		var answer_button: Button = Button.new()

		answer_button.custom_minimum_size = \
			Vector2(0, 65)

		answer_button.size_flags_horizontal = \
			Control.SIZE_EXPAND_FILL

		answer_button.text = str(
			answers[index]
		)

		answer_button.add_theme_font_size_override(
			"font_size",
			20
		)

		answer_button.toggle_mode = true
		answer_button.button_group = button_group

		answer_button.pressed.connect(
			_on_answer_selected.bind(index)
		)

		answer_container.add_child(
			answer_button
		)


	# ============================================================

	# TRUE / FALSE

	# ============================================================

func _build_true_false(
	question_data: Dictionary
	) -> void:


	var button_group: ButtonGroup = ButtonGroup.new()

	var true_button: Button = Button.new()

	true_button.custom_minimum_size = \
		Vector2(0, 65)

	true_button.size_flags_horizontal = \
		Control.SIZE_EXPAND_FILL

	true_button.text = "True"

	true_button.add_theme_font_size_override(
		"font_size",
		20
	)

	true_button.toggle_mode = true
	true_button.button_group = button_group

	true_button.pressed.connect(
		_on_answer_selected.bind(0)
	)

	answer_container.add_child(
		true_button
	)


	var false_button: Button = Button.new()

	false_button.custom_minimum_size = \
		Vector2(0, 65)

	false_button.size_flags_horizontal = \
		Control.SIZE_EXPAND_FILL

	false_button.text = "False"

	false_button.add_theme_font_size_override(
		"font_size",
		20
	)

	false_button.toggle_mode = true
	false_button.button_group = button_group

	false_button.pressed.connect(
		_on_answer_selected.bind(1)
	)

	answer_container.add_child(
		false_button
	)


	# ============================================================

	# IDENTIFICATION

	# ============================================================

func _build_identification(
	question_data: Dictionary
	) -> void:

	identification_input.visible = true

	identification_input.placeholder_text = \
		"Type your answer here..."

	print(
		"[QuizTakingPage] Identification input enabled."
	)


	# ============================================================

	# ENUMERATION

	# ============================================================

func _build_enumeration(
	question_data: Dictionary
	) -> void:

	enumeration_input.visible = true

	var answers: Array = question_data.get(
		"answers",
		[]
	)

	if answers.is_empty():

		print(
			"[QuizTakingPage] Enumeration question has no required answers."
		)

		return

	print(
		"[QuizTakingPage] Creating ",
		answers.size(),
		" enumeration input boxes."
	)

	for index in range(answers.size()):

		var answer_row: HBoxContainer = \
			HBoxContainer.new()

		answer_row.custom_minimum_size = \
			Vector2(0, 60)

		answer_row.size_flags_horizontal = \
			Control.SIZE_EXPAND_FILL

		# ----------------------------------------------------
		# Answer number.
		# ----------------------------------------------------

		var answer_label: Label = Label.new()

		answer_label.custom_minimum_size = \
			Vector2(110, 60)

		answer_label.text = \
			"Answer " + str(index + 1)

		answer_label.vertical_alignment = \
			VERTICAL_ALIGNMENT_CENTER

		answer_label.add_theme_font_size_override(
			"font_size",
			20
		)

		answer_row.add_child(
			answer_label
		)

		# ----------------------------------------------------
		# Student input.
		# ----------------------------------------------------

		var input: LineEdit = LineEdit.new()

		input.custom_minimum_size = \
			Vector2(0, 55)

		input.size_flags_horizontal = \
			Control.SIZE_EXPAND_FILL

		input.placeholder_text = \
			"Enter answer " + str(index + 1) + "..."

		input.add_theme_font_size_override(
			"font_size",
			20
		)

		var style: StyleBoxFlat = \
			StyleBoxFlat.new()

		style.bg_color = Color(
			0.968627,
			0.886275,
			0.772549,
			1
		)

		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3

		style.border_color = Color(
			0.7764706,
			0.627451,
			0.48235294,
			1
		)

		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6

		input.add_theme_stylebox_override(
			"normal",
			style
		)

		input.add_theme_color_override(
			"font_color",
			Color(
				0.47058824,
				0.3529412,
				0.23529412,
				1
			)
		)

		input.add_theme_font_override(
			"font",
			quiz_title.get_theme_font("font")
		)

		answer_row.add_child(
			input
		)

		enumeration_input.add_child(
			answer_row
		)

	print(
		"[QuizTakingPage] Enumeration input boxes created: ",
		answers.size()
	)

	# ============================================================

	# ANSWER SELECTED

	# ============================================================

func _on_answer_selected(
	answer_index: int
	) -> void:

	if current_question_index < 0:
		return

	if current_question_index >= selected_answers.size():
		return

	selected_answers[current_question_index] = \
		answer_index

	status_label.text = "Answer selected."

	print(
		"[QuizTakingPage] Selected answer index: ",
		answer_index
	)


	# ============================================================

	# NEXT / SUBMIT

	# ============================================================

func _on_next_pressed() -> void:


	if saving_result:
		return

	if quiz_completed:
		return

	if current_question_index < 0:
		return

	if current_question_index >= questions.size():
		return

	var question_data: Dictionary = \
		questions[current_question_index]

	var question_type: String = str(
		question_data.get(
			"type",
			"multiple_choice"
		)
	).strip_edges().to_lower()


	# --------------------------------------------------------
	# Identification
	# --------------------------------------------------------

	if _is_identification(question_type):

		var identification_answer: String = \
			identification_input.text.strip_edges()

		if identification_answer.is_empty():

			status_label.text = \
				"Please enter an answer."

			return

		text_answers[current_question_index] = \
			identification_answer


	# --------------------------------------------------------
	# Enumeration
	# --------------------------------------------------------

	elif _is_enumeration(question_type):

		var answers: Array = question_data.get(
			"answers",
			[]
		)

		var student_answers: Array[String] = []

		for child in enumeration_input.get_children():

			if not child is HBoxContainer:
				continue

			var row: HBoxContainer = child

			for row_child in row.get_children():

				if not row_child is LineEdit:
					continue

				var input: LineEdit = row_child

				var answer_text: String = \
					input.text.strip_edges()

				if answer_text.is_empty():

					status_label.text = \
						"Please answer all fields."

					return

				student_answers.append(
					answer_text
				)

		if student_answers.size() != answers.size():

			status_label.text = \
				"Please answer all fields."

			return

		enumeration_answers[current_question_index] = \
			student_answers

		print(
			"[QuizTakingPage] Enumeration answers saved: ",
			student_answers
		)


	# --------------------------------------------------------
	# MC / True-False
	# --------------------------------------------------------

	else:

		if selected_answers[current_question_index] == -1:

			status_label.text = \
				"Please select an answer."

			return


	# --------------------------------------------------------
	# Debug feedback.
	# --------------------------------------------------------

	_check_current_answer()


	# --------------------------------------------------------
	# Submit.
	# --------------------------------------------------------

	if current_question_index >= questions.size() - 1:

		await _submit_quiz()

		return


	# --------------------------------------------------------
	# Next question.
	# --------------------------------------------------------

	current_question_index += 1

	_show_question()
	# ============================================================

	# SUBMIT QUIZ

	# ============================================================
func _submit_quiz() -> void:

	if saving_result:
		return

	if quiz_completed:
		return

	saving_result = true

	next_button.disabled = true
	back_button.disabled = true

	status_label.text = \
		"Saving your quiz result..."

	print(
		"[QuizTakingPage] Submitting quiz result..."
	)

	# --------------------------------------------------------
	# Calculate final score.
	# --------------------------------------------------------

	_calculate_final_score()

	var total_questions: int = \
		questions.size()

	var percentage: float = 0.0

	if total_questions > 0:

		percentage = (
			float(score)
			/ float(total_questions)
		) * 100.0

	print(
		"[QuizTakingPage] Score ready to save: ",
		score,
		" / ",
		total_questions
	)

	print(
		"[QuizTakingPage] Percentage ready to save: ",
		percentage,
		"%"
	)

	# --------------------------------------------------------
	# Save to Firebase.
	# --------------------------------------------------------

	var save_success: bool = \
		await _save_quiz_result(
			score,
			total_questions,
			percentage
		)

	if not save_success:

		saving_result = false

		next_button.disabled = false
		back_button.disabled = false

		status_label.text = \
			"Unable to save your result. Please try again."

		print(
			"[QuizTakingPage] ERROR: Quiz result was NOT saved."
		)

		return

	# --------------------------------------------------------
	# Firebase save succeeded.
	# --------------------------------------------------------

	print(
		"[QuizTakingPage] Quiz result successfully saved."
	)

	saving_result = false
	quiz_completed = true

	_show_result()


	# ============================================================

	# SAVE QUIZ RESULT TO FIREBASE

	# ============================================================

func _save_quiz_result(score: int, total_questions: int, percentage: float) -> bool:
	var uid: String = _get_uid()
	var id_token: String = _get_id_token()

	if uid == "":
		print("[QuizTakingPage] ERROR: Student UID is empty.")
		return false

	if id_token == "":
		print("[QuizTakingPage] ERROR: Firebase ID token is empty.")
		return false

	if quiz_data == null:
		print("[QuizTakingPage] ERROR: quiz_data is null.")
		return false

	var quiz_id: String = str(quiz_data.get("quiz_id", ""))

	if quiz_id == "":
		print("[QuizTakingPage] ERROR: Quiz ID is empty.")
		return false

	var quiz_title: String = str(quiz_data.get("title", "Untitled Quiz"))

	var project_id: String = "atomix-f6c6b"
	var database_id: String = "(default)"

	# -----------------------------------------------------
	# Firestore student document URL
	# -----------------------------------------------------

	var url: String = "https://firestore.googleapis.com/v1/projects/" \
		+ project_id \
		+ "/databases/" \
		+ database_id \
		+ "/documents/students/" \
		+ uid

	print("[QuizTakingPage] Saving assessment result to: ", url)

	# -----------------------------------------------------
	# Firestore timestamp
	# -----------------------------------------------------

	var timestamp: String = Time.get_datetime_string_from_system(true) + "Z"

	# -----------------------------------------------------
	# Build the quiz assessment entry
	# -----------------------------------------------------

	var quiz_entry: Dictionary = {
		"mapValue": {
			"fields": {
				"quiz_id": {
					"stringValue": quiz_id
				},
				"quiz_title": {
					"stringValue": quiz_title
				},
				"score": {
					"integerValue": str(score)
				},
				"total_questions": {
					"integerValue": str(total_questions)
				},
				"percentage": {
					"doubleValue": percentage
				},
				"completed": {
					"booleanValue": true
				},
				"completed_at": {
					"timestampValue": timestamp
				}
			}
		}
	}

	# -----------------------------------------------------
	# IMPORTANT:
	# Only update this specific assessment entry.
	#
	# Example:
	# assessment.quiz_123
	#
	# Existing assessment entries are NOT replaced.
	# -----------------------------------------------------

	var update_mask_field: String = "assessment.`" + quiz_id + "`"

	var patch_url: String = url + "?updateMask.fieldPaths=" \
		+ update_mask_field.uri_encode()

	print("[QuizTakingPage] Updating only: ", update_mask_field)

	var body: Dictionary = {
		"fields": {
			"assessment": {
				"mapValue": {
					"fields": {}
				}
			}
		}
	}

	body["fields"]["assessment"]["mapValue"]["fields"][quiz_id] = quiz_entry

	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]

	var http_request: HTTPRequest = HTTPRequest.new()
	add_child(http_request)

	var error: Error = http_request.request(
		patch_url,
		headers,
		HTTPClient.METHOD_PATCH,
		JSON.stringify(body)
	)

	if error != OK:
		print("[QuizTakingPage] ERROR: Failed to send assessment request.")
		print("[QuizTakingPage] Error code: ", error)
		http_request.queue_free()
		return false

	var result: Array = await http_request.request_completed
	http_request.queue_free()

	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]

	print("[QuizTakingPage] Firebase assessment response: ", response_code)

	if response_code >= 200 and response_code < 300:
		print("[QuizTakingPage] Assessment result saved successfully.")
		print("[QuizTakingPage] Quiz ID saved: ", quiz_id)
		print("[QuizTakingPage] Score saved: ", score, " / ", total_questions)
		print("[QuizTakingPage] Percentage saved: ", percentage, "%")
		return true

	print("[QuizTakingPage] ERROR: Firebase rejected assessment result.")
	print("[QuizTakingPage] Response: ", response_body.get_string_from_utf8())

	return false


	# ============================================================

	# CHECK CURRENT ANSWER

	# ============================================================

func _check_current_answer() -> void:


	var question_data: Dictionary = \
		questions[current_question_index]

	var question_type: String = str(
		question_data.get(
			"type",
			"multiple_choice"
		)
	).strip_edges().to_lower()


	if _is_identification(question_type):

		_check_identification_answer(
			question_data
		)

		return


	if _is_enumeration(question_type):

		_check_enumeration_answer(
			question_data
		)

		return


	var correct_answers: Array = \
		question_data.get(
			"correct_answers",
			[]
		)

	if correct_answers.is_empty():

		print(
			"[QuizTakingPage] No correct answer configured."
		)

		return

	var selected_index: int = \
		selected_answers[current_question_index]

	var correct_index: int = \
		int(correct_answers[0])

	if selected_index == correct_index:

		print(
			"[QuizTakingPage] Correct answer."
		)

	else:

		print(
			"[QuizTakingPage] Wrong answer."
		)


	# ============================================================

	# CHECK IDENTIFICATION

	# ============================================================

func _check_identification_answer(
	question_data: Dictionary
	) -> void:


	var correct_answers: Array = \
		question_data.get(
			"correct_answers",
			[]
		)

	if correct_answers.is_empty():

		print(
			"[QuizTakingPage] Identification question has no answer."
		)

		return

	var answers: Array = \
		question_data.get(
			"answers",
			[]
		)

	var correct_index: int = \
		int(correct_answers[0])

	if correct_index < 0:
		return

	if correct_index >= answers.size():
		return

	var student_answer: String = \
		text_answers[current_question_index] \
		.strip_edges() \
		.to_lower()

	var correct_answer: String = \
		str(answers[correct_index]) \
		.strip_edges() \
		.to_lower()

	if student_answer == correct_answer:

		print(
			"[QuizTakingPage] Identification answer correct."
		)

	else:

		print(
			"[QuizTakingPage] Identification answer incorrect."
		)


	# ============================================================

	# CHECK ENUMERATION

	# ============================================================

func _check_enumeration_answer(
	question_data: Dictionary
	) -> void:


	var accepted_answers: Array = \
		question_data.get(
			"answers",
			[]
		)

	if accepted_answers.is_empty():

		print(
			"[QuizTakingPage] Enumeration question has no required answers."
		)

		return

	if current_question_index >= enumeration_answers.size():

		print(
			"[QuizTakingPage] Enumeration answers unavailable."
		)

		return

	var student_answers: Array = \
		enumeration_answers[current_question_index]

	var normalized_student: Array[String] = []

	for answer in student_answers:

		var cleaned: String = \
			str(answer).strip_edges().to_lower()

		if not cleaned.is_empty():

			normalized_student.append(
				cleaned
			)

	var normalized_accepted: Array[String] = []

	for answer in accepted_answers:

		var cleaned: String = \
			str(answer).strip_edges().to_lower()

		if not cleaned.is_empty():

			normalized_accepted.append(
				cleaned
			)

	if normalized_student.size() != \
		normalized_accepted.size():

		print(
			"[QuizTakingPage] Enumeration answer count incorrect."
		)

		return

	for answer in normalized_student:

		if not normalized_accepted.has(answer):

			print(
				"[QuizTakingPage] Enumeration answer not accepted: ",
				answer
			)

			return

	print(
		"[QuizTakingPage] Enumeration answer correct."
	)

	# ============================================================

	# CALCULATE FINAL SCORE

	# ============================================================

func _calculate_final_score() -> void:


	score = 0

	print(
		"[QuizTakingPage] Calculating final score..."
	)

	for i in range(questions.size()):

		var question_data: Dictionary = \
			questions[i]

		var question_type: String = str(
			question_data.get(
				"type",
				"multiple_choice"
			)
		).strip_edges().to_lower()


		# ====================================================
		# ENUMERATION
		# ====================================================

		if _is_enumeration(question_type):

			var accepted_answers: Array = \
				question_data.get(
					"answers",
					[]
				)

			if accepted_answers.is_empty():

				print(
					"[QuizTakingPage] Question ",
					i + 1,
					": no required enumeration answers."
				)

				continue

			if i >= enumeration_answers.size():

				continue

			var student_answers: Array = \
				enumeration_answers[i]

			var normalized_student: Array[String] = []

			for answer in student_answers:

				var cleaned: String = \
					str(answer).strip_edges().to_lower()

				if not cleaned.is_empty():

					normalized_student.append(
						cleaned
					)

			var normalized_accepted: Array[String] = []

			for answer in accepted_answers:

				var cleaned: String = \
					str(answer).strip_edges().to_lower()

				if not cleaned.is_empty():

					normalized_accepted.append(
						cleaned
					)


			var enumeration_correct: bool = true


			if normalized_student.size() != \
				normalized_accepted.size():

				enumeration_correct = false


			for answer in normalized_accepted:

				if not normalized_student.has(answer):

					enumeration_correct = false

					print(
						"[QuizTakingPage] Question ",
						i + 1,
						": missing answer = ",
						answer
					)


			for answer in normalized_student:

				if not normalized_accepted.has(answer):

					enumeration_correct = false

					print(
						"[QuizTakingPage] Question ",
						i + 1,
						": unaccepted answer = ",
						answer
					)


			if enumeration_correct:

				score += 1

				print(
					"[QuizTakingPage] Question ",
					i + 1,
					": correct."
				)

			else:

				print(
					"[QuizTakingPage] Question ",
					i + 1,
					": incorrect."
				)

			continue


		# ====================================================
		# OTHER QUIZ TYPES
		# ====================================================

		var correct_answers: Array = \
			question_data.get(
				"correct_answers",
				[]
			)

		if correct_answers.is_empty():

			print(
				"[QuizTakingPage] Question ",
				i + 1,
				": no correct answer configured."
			)

			continue

		var correct_index: int = \
			int(correct_answers[0])


		# ====================================================
		# IDENTIFICATION
		# ====================================================

		if _is_identification(question_type):

			if i >= text_answers.size():
				continue

			var answers: Array = \
				question_data.get(
					"answers",
					[]
				)

			if correct_index < 0:
				continue

			if correct_index >= answers.size():
				continue

			var identification_student: String = \
				text_answers[i] \
				.strip_edges() \
				.to_lower()

			var identification_correct: String = \
				str(answers[correct_index]) \
				.strip_edges() \
				.to_lower()

			if identification_student == \
				identification_correct:

				score += 1

				print(
					"[QuizTakingPage] Question ",
					i + 1,
					": correct."
				)

			else:

				print(
					"[QuizTakingPage] Question ",
					i + 1,
					": incorrect."
				)

			continue


		# ====================================================
		# MULTIPLE CHOICE / TRUE-FALSE
		# ====================================================

		if i >= selected_answers.size():
			continue

		var selected_index: int = \
			int(selected_answers[i])

		if selected_index == correct_index:

			score += 1

			print(
				"[QuizTakingPage] Question ",
				i + 1,
				": correct."
			)

		else:

			print(
				"[QuizTakingPage] Question ",
				i + 1,
				": incorrect."
			)


	print(
		"[QuizTakingPage] Final score calculated: ",
		score,
		" / ",
		questions.size()
	)


	# ============================================================

	# RESULT

	# ============================================================

func _show_result() -> void:


	var total_questions: int = \
		questions.size()

	var percentage: float = 0.0

	if total_questions > 0:

		percentage = (
			float(score)
			/ float(total_questions)
		) * 100.0

	print(
		"[QuizTakingPage] Quiz completed."
	)

	print(
		"[QuizTakingPage] Score: ",
		score,
		" / ",
		total_questions
	)

	print(
		"[QuizTakingPage] Percentage: ",
		percentage,
		"%"
	)

	question_counter.text = "Completed"

	question_label.text = "QUIZ COMPLETE!"

	for child in answer_container.get_children():

		if child == identification_input:
			continue

		if child == enumeration_input:
			continue

		child.queue_free()

	await get_tree().process_frame

	identification_input.visible = false
	enumeration_input.visible = false

	var score_label: Label = Label.new()

	score_label.custom_minimum_size = \
		Vector2(0, 100)

	score_label.text = \
		"Score: " \
		+ str(score) \
		+ " / " \
		+ str(total_questions) \
		+ "\n" \
		+ "Percentage: " \
		+ str(round(percentage)) \
		+ "%"

	score_label.horizontal_alignment = \
		HORIZONTAL_ALIGNMENT_CENTER

	score_label.vertical_alignment = \
		VERTICAL_ALIGNMENT_CENTER

	score_label.add_theme_font_size_override(
		"font_size",
		32
	)

	answer_container.add_child(
		score_label
	)

	next_button.visible = false

	back_button.disabled = false
	back_button.text = "← Back to Quizzes"

	status_label.text = \
		"Quiz completed."


	# ============================================================

	# RESTORE PREVIOUS ANSWER

	# ============================================================

func _restore_previous_answer(
	question_data: Dictionary,
	question_type: String
	) -> void:


	if current_question_index < 0:
		return

	if current_question_index >= selected_answers.size():
		return


	# --------------------------------------------------------
	# Identification
	# --------------------------------------------------------

	if _is_identification(question_type):

		if current_question_index < text_answers.size():

			identification_input.text = \
				text_answers[current_question_index]

		return


	# --------------------------------------------------------
	# Enumeration
	# --------------------------------------------------------

	if _is_enumeration(question_type):

		if current_question_index >= \
			enumeration_answers.size():

			return

		var previous_answers: Array = \
			enumeration_answers[current_question_index]

		var input_index: int = 0

		for child in enumeration_input.get_children():

			if not child is HBoxContainer:
				continue

			var row: HBoxContainer = child

			for row_child in row.get_children():

				if not row_child is LineEdit:
					continue

				var input: LineEdit = row_child

				if input_index < previous_answers.size():

					input.text = \
						str(previous_answers[input_index])

				input_index += 1

		return


	# --------------------------------------------------------
	# Multiple Choice / True-False
	# --------------------------------------------------------

	var previous_answer: int = \
		int(selected_answers[current_question_index])

	if previous_answer == -1:
		return

	var button_index: int = 0

	for child in answer_container.get_children():

		if not child is Button:
			continue

		var button: Button = child

		if button_index == previous_answer:

			button.button_pressed = true

			break

		button_index += 1


	# ============================================================

	# QUESTION TYPE HELPERS

	# ============================================================

func _is_multiple_choice(
	question_type: String
	) -> bool:


	return (
		question_type == "multiple choice"
		or question_type == "multiple_choice"
		or question_type == "multiplechoice"
		or question_type == "mc"
	)


func _is_true_false(
	question_type: String
	) -> bool:
	return (
		question_type == "true or false"
		or question_type == "true_false"
		or question_type == "true/false"
		or question_type == "truefalse"
	)

func _is_identification(
	question_type: String
	) -> bool:


	return (
		question_type == "identification"
		or question_type == "identify"
	)


func _is_enumeration(
	question_type: String
	) -> bool:

	return (
		question_type == "enumeration"
		or question_type == "enumerate"
		or question_type == "enumeration_type"
	)


	# ============================================================

	# FIREBASE HELPERS

	# ============================================================

func _get_uid() -> String:


	if AuthManager.has_method("get_uid"):

		var uid_value: Variant = \
			AuthManager.get_uid()

		if uid_value != null:

			return str(uid_value).strip_edges()

	if "user_uid" in AuthManager:

		var uid_value: Variant = \
			AuthManager.user_uid

		if uid_value != null:

			return str(uid_value).strip_edges()

	print(
		"[QuizTakingPage] ERROR: Could not obtain student UID."
	)

	return ""


func _get_id_token() -> String:


	if Firebase.Firestore == null:

		print(
			"[QuizTakingPage] ERROR: Firebase.Firestore is null."
		)

		return ""

	if Firebase.Firestore.auth == null:

		print(
			"[QuizTakingPage] ERROR: Firebase auth is null."
		)

		return ""

	var auth_data: Dictionary = \
		Firebase.Firestore.auth

	var token_value: Variant = \
		auth_data.get("idtoken", "")

	if token_value == null:

		return ""

	return str(token_value).strip_edges()


	# ============================================================

	# BACK BUTTON

	# ============================================================

func _on_back_pressed() -> void:

	# --------------------------------------------------------
	# If quiz has been submitted, return to QuizPage
	# --------------------------------------------------------

	if quiz_completed:

		if return_page != null and is_instance_valid(return_page):

			return_page.visible = true

			await return_page._load_completed_quizzes()

			return_page._apply_sort()

			await return_page._build_quiz_list()

			queue_free()

		else:

			print(
				"[QuizTakingPage] No return_page found."
			)

			queue_free()

		return

	# --------------------------------------------------------
	# If we are not on the first question,
	# go back to the previous question
	# --------------------------------------------------------

	if current_question_index > 0:

		current_question_index -= 1

		_show_question()

		return

	# --------------------------------------------------------
	# We are on Question 1.
	# Return to the existing QuizPage.
	# --------------------------------------------------------

	if return_page != null and is_instance_valid(return_page):

		return_page.visible = true

		await return_page._load_completed_quizzes()

		return_page._apply_sort()

		await return_page._build_quiz_list()

		queue_free()

	else:

		print(
			"[QuizTakingPage] No return_page found."
		)

		queue_free()

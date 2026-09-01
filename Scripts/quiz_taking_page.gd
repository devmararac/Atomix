extends Control

# ============================================================
# QUIZ DATA
# ============================================================

var quiz_data: Dictionary = {}

var questions: Array = []
var current_question_index: int = 0
var score: int = 0

# Stores the student's selected answer for each question.
# -1 means no answer selected.
var selected_answers: Array = []

# Stores text answers for identification/enumeration questions.
var text_answers: Array = []


# ============================================================
# UI REFERENCES
# ============================================================

@onready var quiz_title: Label = \
	$QuizPanel/MarginContainer/VBoxContainer/Header/QuizTitle

@onready var question_counter: Label = \
	$QuizPanel/MarginContainer/VBoxContainer/Header/QuestionCounter

@onready var question_label: Label = \
	$QuizPanel/MarginContainer/VBoxContainer/QuestionPanel/MarginContainer/QuestionLabel

@onready var answer_container: VBoxContainer = \
	$QuizPanel/MarginContainer/VBoxContainer/AnswerScroll/AnswerContainer

@onready var identification_input: LineEdit = \
	$QuizPanel/MarginContainer/VBoxContainer/AnswerScroll/AnswerContainer/IdentificationInput

@onready var enumeration_input: TextEdit = \
	$QuizPanel/MarginContainer/VBoxContainer/AnswerScroll/AnswerContainer/EnumerationInput

@onready var back_button: Button = \
	$QuizPanel/MarginContainer/VBoxContainer/BottomBar/BackButton

@onready var next_button: Button = \
	$QuizPanel/MarginContainer/VBoxContainer/BottomBar/NextButton

@onready var status_label: Label = \
	$QuizPanel/MarginContainer/VBoxContainer/StatusLabel


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[QuizTakingPage] Quiz taking page opened.")

	# --------------------------------------------------------
	# Make sure this page is visible above normal Control nodes.
	# --------------------------------------------------------

	visible = true
	z_index = 100

	# --------------------------------------------------------
	# Hide GameMenu / previous UI overlays.
	# --------------------------------------------------------

	_hide_previous_ui()

	# --------------------------------------------------------
	# Connect buttons
	# --------------------------------------------------------

	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)

	# --------------------------------------------------------
	# Check quiz data
	# --------------------------------------------------------

	if quiz_data.is_empty():

		print(
			"[QuizTakingPage] ERROR: No quiz data received."
		)

		question_label.text = \
			"Unable to load this quiz."

		status_label.text = \
			"No quiz data was provided."

		next_button.disabled = true

		return

	# --------------------------------------------------------
	# Get questions
	# --------------------------------------------------------

	questions = quiz_data.get(
		"questions",
		[]
	)

	if questions.is_empty():

		print(
			"[QuizTakingPage] ERROR: Quiz contains no questions."
		)

		question_label.text = \
			"This quiz has no questions."

		status_label.text = \
			"No questions are available."

		next_button.disabled = true

		return

	# --------------------------------------------------------
	# Setup title
	# --------------------------------------------------------

	quiz_title.text = str(
		quiz_data.get(
			"title",
			"Quiz"
		)
	)

	print(
		"[QuizTakingPage] Quiz title: ",
		quiz_title.text
	)

	print(
		"[QuizTakingPage] Total questions: ",
		questions.size()
	)

	# --------------------------------------------------------
	# Prepare answer tracking
	# --------------------------------------------------------

	selected_answers.clear()
	text_answers.clear()

	for i in range(questions.size()):

		selected_answers.append(-1)
		text_answers.append("")

	# --------------------------------------------------------
	# Show first question
	# --------------------------------------------------------

	current_question_index = 0
	score = 0

	_show_question()


# ============================================================
# HIDE PREVIOUS UI
# ============================================================

func _hide_previous_ui() -> void:

	print(
		"[QuizTakingPage] Hiding previous UI overlays."
	)

	var root := get_tree().root

	# --------------------------------------------------------
	# Check every direct child of the root.
	# --------------------------------------------------------

	for child in root.get_children():

		if child == self:
			continue

		if child.name == "GameMenu":

			if child is CanvasLayer:
				child.visible = false

				print(
					"[QuizTakingPage] GameMenu CanvasLayer hidden."
				)

			elif child is Control:
				child.visible = false

				print(
					"[QuizTakingPage] GameMenu Control hidden."
				)

		elif child.name == "QuizPage":

			if child is CanvasLayer:
				child.visible = false

			elif child is Control:
				child.visible = false

			print(
				"[QuizTakingPage] Previous QuizPage hidden."
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

	# --------------------------------------------------------
	# Question text
	# --------------------------------------------------------

	var question_text := str(
		question_data.get(
			"question",
			"Question unavailable."
		)
	)

	question_label.text = question_text

	# --------------------------------------------------------
	# Question counter
	# --------------------------------------------------------

	question_counter.text = \
		"Question " \
		+ str(current_question_index + 1) \
		+ " / " \
		+ str(questions.size())

	# --------------------------------------------------------
	# Question type
	# --------------------------------------------------------

	var question_type := str(
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
	# Remove old dynamic answer controls.
	# --------------------------------------------------------

	for child in answer_container.get_children():

		if child == identification_input:
			continue

		if child == enumeration_input:
			continue

		child.queue_free()

	await get_tree().process_frame

	# --------------------------------------------------------
	# Hide text inputs by default.
	# --------------------------------------------------------

	identification_input.visible = false
	identification_input.text = ""

	enumeration_input.visible = false
	enumeration_input.text = ""

	# --------------------------------------------------------
	# Build question type.
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
	# Button text
	# --------------------------------------------------------

	if current_question_index == questions.size() - 1:

		next_button.text = "SUBMIT ✓"

	else:

		next_button.text = "NEXT →"

	# --------------------------------------------------------
	# Status
	# --------------------------------------------------------

	status_label.text = \
		"Select your answer."

	# --------------------------------------------------------
	# Restore previous answer.
	# --------------------------------------------------------

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

		var label := Label.new()

		label.text = \
			"No answer choices available."

		label.horizontal_alignment = \
			HORIZONTAL_ALIGNMENT_CENTER

		answer_container.add_child(label)

		return

	var button_group := ButtonGroup.new()

	for index in range(answers.size()):

		var answer_button := Button.new()

		answer_button.custom_minimum_size = \
			Vector2(0, 65)

		answer_button.size_flags_horizontal = \
			Control.SIZE_EXPAND_FILL

		answer_button.text = \
			str(answers[index])

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

	var button_group := ButtonGroup.new()

	var true_button := Button.new()

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

	var false_button := Button.new()

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

	enumeration_input.placeholder_text = \
		"Type your answers here..."

	enumeration_input.custom_minimum_size = \
		Vector2(0, 140)

	print(
		"[QuizTakingPage] Enumeration input enabled."
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

	status_label.text = \
		"Answer selected."

	print(
		"[QuizTakingPage] Selected answer index: ",
		answer_index
	)


# ============================================================
# NEXT / SUBMIT
# ============================================================

func _on_next_pressed() -> void:

	if current_question_index < 0:
		return

	if current_question_index >= questions.size():
		return

	var question_data: Dictionary = \
		questions[current_question_index]

	var question_type := str(
		question_data.get(
			"type",
			"multiple_choice"
		)
	).strip_edges().to_lower()

	# --------------------------------------------------------
	# Identification
	# --------------------------------------------------------

	if _is_identification(question_type):

		var identification_answer := \
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

		var enumeration_answer := \
			enumeration_input.text.strip_edges()

		if enumeration_answer.is_empty():

			status_label.text = \
				"Please enter your answers."

			return

		text_answers[current_question_index] = \
			enumeration_answer

	# --------------------------------------------------------
	# Multiple choice / True False
	# --------------------------------------------------------

	else:

		if selected_answers[current_question_index] == -1:

			status_label.text = \
				"Please select an answer."

			return

	# --------------------------------------------------------
	# Check answer
	# --------------------------------------------------------

	_check_current_answer()

	# --------------------------------------------------------
	# Last question
	# --------------------------------------------------------

	if current_question_index >= questions.size() - 1:

		_show_result()

		return

	# --------------------------------------------------------
	# Next question
	# --------------------------------------------------------

	current_question_index += 1

	_show_question()


# ============================================================
# CHECK CURRENT ANSWER
# ============================================================

func _check_current_answer() -> void:

	var question_data: Dictionary = \
		questions[current_question_index]

	var question_type := str(
		question_data.get(
			"type",
			"multiple_choice"
		)
	).strip_edges().to_lower()

	var correct_answers: Array = \
		question_data.get(
			"correct_answers",
			[]
		)

	# --------------------------------------------------------
	# Identification
	# --------------------------------------------------------

	if _is_identification(question_type):

		_check_identification_answer(
			question_data,
			correct_answers
		)

		return

	# --------------------------------------------------------
	# Enumeration
	# --------------------------------------------------------

	if _is_enumeration(question_type):

		_check_enumeration_answer(
			question_data,
			correct_answers
		)

		return

	# --------------------------------------------------------
	# Multiple choice / True False
	# --------------------------------------------------------

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

		score += 1

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
	question_data: Dictionary,
	correct_answers: Array
) -> void:

	if correct_answers.is_empty():

		print(
			"[QuizTakingPage] Identification question has no answer."
		)

		return

	var answers: Array = question_data.get(
		"answers",
		[]
	)

	var student_answer := \
		identification_input.text.strip_edges().to_lower()

	var correct_index: int = \
		int(correct_answers[0])

	if correct_index < 0:
		return

	if correct_index >= answers.size():
		return

	var correct_answer := str(
		answers[correct_index]
	).strip_edges().to_lower()

	if student_answer == correct_answer:

		score += 1

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
	question_data: Dictionary,
	correct_answers: Array
) -> void:

	if correct_answers.is_empty():

		print(
			"[QuizTakingPage] Enumeration question has no answer."
		)

		return

	var answers: Array = question_data.get(
		"answers",
		[]
	)

	var student_answer := \
		enumeration_input.text.strip_edges().to_lower()

	var correct_index: int = \
		int(correct_answers[0])

	if correct_index < 0:
		return

	if correct_index >= answers.size():
		return

	var correct_answer := str(
		answers[correct_index]
	).strip_edges().to_lower()

	if student_answer == correct_answer:

		score += 1

		print(
			"[QuizTakingPage] Enumeration answer correct."
		)

	else:

		print(
			"[QuizTakingPage] Enumeration answer incorrect."
		)


# ============================================================
# RESULT
# ============================================================

func _show_result() -> void:

	var total_questions := \
		questions.size()

	var percentage := 0.0

	if total_questions > 0:

		percentage = \
			(float(score) / float(total_questions)) * 100.0

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

	# --------------------------------------------------------
	# Replace question UI
	# --------------------------------------------------------

	question_counter.text = \
		"Completed"

	question_label.text = \
		"QUIZ COMPLETE!"

	for child in answer_container.get_children():

		if child == identification_input:
			continue

		if child == enumeration_input:
			continue

		child.queue_free()

	await get_tree().process_frame

	identification_input.visible = false
	enumeration_input.visible = false

	# --------------------------------------------------------
	# Score label
	# --------------------------------------------------------

	var score_label := Label.new()

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

	# --------------------------------------------------------
	# Buttons
	# --------------------------------------------------------

	next_button.visible = false

	back_button.text = \
		"← Back to Quizzes"

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

		if current_question_index < text_answers.size():

			enumeration_input.text = \
				text_answers[current_question_index]

		return

	# --------------------------------------------------------
	# Multiple choice / True False
	# --------------------------------------------------------

	var previous_answer := \
		int(selected_answers[current_question_index])

	if previous_answer == -1:
		return

	var button_index := 0

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
# BACK BUTTON
# ============================================================

func _on_back_pressed() -> void:

	print("[QuizTakingPage] Back button pressed.")

	# --------------------------------------------------------
	# Find the existing QuizPage.
	# We do NOT instantiate quiz_page.tscn again.
	# --------------------------------------------------------

	var quiz_page: Node = null

	# Check our parent first.
	var parent_node := get_parent()

	if parent_node != null:

		print(
			"[QuizTakingPage] Parent: ",
			parent_node.name
		)

		quiz_page = parent_node.get_node_or_null("QuizPage")

	# --------------------------------------------------------
	# If QuizPage is not directly under our parent,
	# search the parent hierarchy.
	# --------------------------------------------------------

	if quiz_page == null and parent_node != null:

		var ancestor := parent_node.get_parent()

		while ancestor != null:

			quiz_page = ancestor.get_node_or_null("QuizPage")

			if quiz_page != null:
				break

			ancestor = ancestor.get_parent()

	# --------------------------------------------------------
	# Show existing QuizPage if found.
	# --------------------------------------------------------

	if quiz_page != null:

		print(
			"[QuizTakingPage] Existing QuizPage found: ",
			quiz_page.get_path()
		)

		if quiz_page is CanvasLayer:

			quiz_page.visible = true

		elif quiz_page is Control:

			quiz_page.visible = true

		# Remove the quiz-taking page.
		queue_free()

		return

	# --------------------------------------------------------
	# QuizPage was not found.
	# --------------------------------------------------------

	print(
		"[QuizTakingPage] WARNING: Existing QuizPage not found."
	)

	# Still close QuizTakingPage so the user is not trapped.
	queue_free()

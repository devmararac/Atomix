
extends Panel

# ============================================================
# QUIZ CONFIGURATION
# ============================================================

const MULTIPLE_CHOICE_TIME := 60
const TRUE_FALSE_TIME := 60
const IDENTIFICATION_TIME := 60
const ENUMERATION_TIME := 120

# ============================================================
# QUIZ DATA
# ============================================================

var quiz_data: Dictionary = {}
var return_page: Control = null

var review_mode: bool = false
var assessment_data: Dictionary = {}

var questions: Array = []
var current_question_index: int = 0

# Stores student answers using the question index as key.
var student_answers: Dictionary = {}

# Stores remaining time separately for every question.
var question_times: Dictionary = {}

var remaining_time: int = 0
var quiz_active: bool = false
var quiz_submitted: bool = false

var score: int = 0
var percentage: float = 0.0

var quiz_timer: Timer

# Firebase configuration
const PROJECT_ID: String = "atomix-f6c6b"
const DATABASE_ID: String = "(default)"

# Prevent duplicate submissions
var saving_result: bool = false

# ============================================================
# SCENE REFERENCES
# ============================================================

@onready var number_label: Label = $VBoxContainer/HBoxContainer2/NumberofItem
@onready var type_label: Label = $VBoxContainer/HBoxContainer2/NumberofItem2
@onready var timer_label: Label = $VBoxContainer/HBoxContainer2/Timer

@onready var question_text: TextEdit = $VBoxContainer/QuestionPanel/QuestionMargin/QuestionText

@onready var multiple_choice_panel: Control = $VBoxContainer/MultipleChoicePanel
@onready var enumeration_panel: Control = $VBoxContainer/EnumetrationPanel
@onready var identification_panel: Control = $VBoxContainer/IdentficationPanel
@onready var true_false_panel: Control = $VBoxContainer/TrueFalsePanel
@onready var completion_panel: Control = $VBoxContainer/CompletionPanel

@onready var back_button: Button = $VBoxContainer/HBoxContainer/Button
@onready var next_button: Button = $VBoxContainer/HBoxContainer/Button2
@onready var status_label: Label = $VBoxContainer/HBoxContainer/StatusLabel

@onready var score_value_label: Label = $VBoxContainer/CompletionPanel/VBoxContainer3/VBoxContainer/ScoreValue
@onready var percentage_value_label: Label = $VBoxContainer/CompletionPanel/VBoxContainer3/VBoxContainer2/PercentageValue


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	print("[QuizForm] Initialized.")

	back_button.pressed.connect(_on_back_pressed)
	next_button.pressed.connect(_on_next_pressed)

	quiz_timer = Timer.new()
	quiz_timer.wait_time = 1.0
	quiz_timer.one_shot = false
	add_child(quiz_timer)
	quiz_timer.timeout.connect(_on_timer_timeout)

	if quiz_data.is_empty():
		push_warning("[QuizForm] No quiz data received.")
		return

	questions = quiz_data.get("questions", [])

	if questions.is_empty():
		push_error("[QuizForm] This quiz has no questions.")
		return

	print("[QuizForm] Quiz: ", quiz_data.get("title", "Untitled Quiz"))
	print("[QuizForm] Questions: ", questions.size())
	print("[QuizForm] Review mode: ", review_mode)

	_initialize_question_times()

	current_question_index = 0

	if review_mode:
		quiz_active = false
		_load_saved_student_answers()
	else:
		quiz_active = true

	_display_question()


func _load_saved_student_answers() -> void:
	student_answers.clear()

	var saved_answers: Dictionary = assessment_data.get(
		"student_answers",
		{}
	)

	for question_index in saved_answers.keys():
		var saved_answer: Variant = saved_answers[question_index]

		if question_index is String:
			student_answers[int(question_index)] = saved_answer
		else:
			student_answers[question_index] = saved_answer

	print("[QuizForm] Loaded saved student answers: ", student_answers.size())


func _initialize_question_times() -> void:
	question_times.clear()

	for i in range(questions.size()):
		var question: Dictionary = questions[i]
		var question_type := str(question.get("type", "")).to_lower()

		question_times[i] = _get_question_time(question_type)


func _get_question_time(question_type: String) -> int:
	match question_type:
		"multiple_choice":
			return MULTIPLE_CHOICE_TIME
		"true_false":
			return TRUE_FALSE_TIME
		"identification":
			return IDENTIFICATION_TIME
		"enumeration":
			return ENUMERATION_TIME
		_:
			return MULTIPLE_CHOICE_TIME


# ============================================================
# DISPLAY QUESTION
# ============================================================

func _display_question() -> void:
	if current_question_index < 0 or current_question_index >= questions.size():
		return

	var question: Dictionary = questions[current_question_index]

	var question_type := str(question.get("type", "")).to_lower()

	number_label.text = "Question %d / %d" % [
		current_question_index + 1,
		questions.size()
	]

	type_label.text = question_type.replace("_", " ").capitalize()

	question_text.text = str(question.get("question", ""))
	question_text.editable = false

	multiple_choice_panel.hide()
	enumeration_panel.hide()
	identification_panel.hide()
	true_false_panel.hide()
	completion_panel.hide()

	match question_type:
		"multiple_choice":
			multiple_choice_panel.show()
			_display_multiple_choice(question)

		"true_false":
			true_false_panel.show()
			_display_true_false(question)

		"identification":
			identification_panel.show()
			_display_identification(question)

		"enumeration":
			enumeration_panel.show()
			_display_enumeration(question)

		_:
			status_label.text = "Unsupported question type."
			return

	back_button.visible = current_question_index > 0

	if current_question_index == questions.size() - 1:
		next_button.text = "SUBMIT" if not review_mode else "FINISH"
	else:
		next_button.text = "NEXT"

	if review_mode:
		timer_label.text = "REVIEW"
		status_label.text = "Viewing completed assessment."
		next_button.text = "NEXT" if current_question_index < questions.size() - 1 else "FINISH"
		quiz_timer.stop()
	else:
		remaining_time = int(question_times.get(current_question_index, 60))
		_update_timer_display()

		if quiz_active:
			quiz_timer.start()

	print("[QuizForm] Displaying question ", current_question_index + 1)


# ============================================================
# MULTIPLE CHOICE
# ============================================================

func _get_multiple_choice_cards() -> Array:
	return [
		$VBoxContainer/MultipleChoicePanel/AnswersScroll/Center/Answers/AnswerA,
		$VBoxContainer/MultipleChoicePanel/AnswersScroll/Center/Answers/AnswerB,
		$VBoxContainer/MultipleChoicePanel/AnswersScroll/Center/Answers/AnswerC,
		$VBoxContainer/MultipleChoicePanel/AnswersScroll/Center/Answers/AnswerD
	]


func _display_multiple_choice(question: Dictionary) -> void:
	var answers: Array = question.get("answers", [])
	var answer_nodes := _get_multiple_choice_cards()

	for i in range(answer_nodes.size()):
		var answer_card: Control = answer_nodes[i]

		var answer_text := answer_card.get_node("Margin/VBox/AnswerText") as TextEdit
		var correct_checkbox := answer_card.get_node("Margin/VBox/TopBar/Correct") as CheckBox

		if i < answers.size():
			answer_card.show()
			answer_text.text = str(answers[i])
		else:
			answer_card.hide()
			answer_text.text = ""

		answer_text.editable = false
		correct_checkbox.hide()

		var card_button := answer_card.get_node_or_null("AnswerButton") as Button

		if card_button == null:
			card_button = Button.new()
			card_button.name = "AnswerButton"
			card_button.flat = true
			card_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			answer_card.add_child(card_button)

		card_button.disabled = review_mode or i >= answers.size()

		var callback := _select_multiple_choice.bind(i)

		if not card_button.pressed.is_connected(callback):
			card_button.pressed.connect(callback)

	_update_multiple_choice_selection()


func _select_multiple_choice(answer_index: int) -> void:
	if review_mode or quiz_submitted:
		return

	var selected: Array = student_answers.get(current_question_index, []).duplicate()

	if selected.has(answer_index):
		selected.erase(answer_index)
	else:
		selected.append(answer_index)

	student_answers[current_question_index] = selected

	_update_multiple_choice_selection()


func _update_multiple_choice_selection() -> void:
	var selected: Array = student_answers.get(current_question_index, [])

	var question: Dictionary = questions[current_question_index]
	var correct_indices: Array = question.get("correct_answers", [])

	var answer_nodes := _get_multiple_choice_cards()

	for i in range(answer_nodes.size()):
		var answer_card: Control = answer_nodes[i]
		var background: ColorRect = (
			answer_card.get_node("AnswerABg") as ColorRect
			if i == 0
			else answer_card.get_child(0) as ColorRect
		)

		if review_mode:
			if correct_indices.has(i):
				background.color = Color(0.294, 0.55, 0.259, 1)
			elif selected.has(i):
				background.color = Color(0.65, 0.25, 0.22, 1)
			else:
				background.color = Color(0.235, 0.639, 0.675, 1)
		else:
			background.color = (
				Color(0.294, 0.365, 0.259, 1)
				if selected.has(i)
				else Color(0.235, 0.639, 0.675, 1)
			)


# ============================================================
# TRUE / FALSE
# ============================================================
func _display_true_false(question: Dictionary) -> void:
	var true_checkbox := $VBoxContainer/TrueFalsePanel/AnswerPanel/Answers/TruePanel/Margin/VBox/Correct as CheckBox
	var false_checkbox := $VBoxContainer/TrueFalsePanel/AnswerPanel/Answers/FalsePanel/Margin/VBox/Correct as CheckBox

	var selected := str(student_answers.get(current_question_index, ""))

	var correct_answers: Array = question.get("correct_answers", [])
	var correct_value := ""

	if not correct_answers.is_empty():
		correct_value = "True" if int(correct_answers[0]) == 0 else "False"

	true_checkbox.set_pressed_no_signal(selected == "True")
	false_checkbox.set_pressed_no_signal(selected == "False")

	true_checkbox.disabled = review_mode
	false_checkbox.disabled = review_mode

	if review_mode:
		true_checkbox.modulate = (
			Color(0.55, 0.9, 0.45, 1)
			if correct_value == "True"
			else Color.WHITE
		)

		false_checkbox.modulate = (
			Color(0.55, 0.9, 0.45, 1)
			if correct_value == "False"
			else Color.WHITE
		)
	else:
		true_checkbox.modulate = Color.WHITE
		false_checkbox.modulate = Color.WHITE

	if not true_checkbox.toggled.is_connected(_on_true_selected):
		true_checkbox.toggled.connect(_on_true_selected)

	if not false_checkbox.toggled.is_connected(_on_false_selected):
		false_checkbox.toggled.connect(_on_false_selected)

func _on_true_selected(pressed: bool) -> void:
	if review_mode or quiz_submitted:
		return

	var true_checkbox := $VBoxContainer/TrueFalsePanel/AnswerPanel/Answers/TruePanel/Margin/VBox/Correct as CheckBox
	var false_checkbox := $VBoxContainer/TrueFalsePanel/AnswerPanel/Answers/FalsePanel/Margin/VBox/Correct as CheckBox

	if pressed:
		false_checkbox.set_pressed_no_signal(false)
		student_answers[current_question_index] = "True"
	else:
		student_answers.erase(current_question_index)


func _on_false_selected(pressed: bool) -> void:
	if review_mode or quiz_submitted:
		return

	var true_checkbox := $VBoxContainer/TrueFalsePanel/AnswerPanel/Answers/TruePanel/Margin/VBox/Correct as CheckBox
	var false_checkbox := $VBoxContainer/TrueFalsePanel/AnswerPanel/Answers/FalsePanel/Margin/VBox/Correct as CheckBox

	if pressed:
		true_checkbox.set_pressed_no_signal(false)
		student_answers[current_question_index] = "False"
	else:
		student_answers.erase(current_question_index)


# ============================================================
# IDENTIFICATION
# ============================================================

func _display_identification(question: Dictionary) -> void:
	var answer_input := $VBoxContainer/IdentficationPanel/QuestionPanel/QuestionMargin/VBox/AnswerText as TextEdit

	var student_answer := str(
		student_answers.get(current_question_index, "")
	)

	answer_input.text = student_answer
	answer_input.editable = not review_mode

	if review_mode:
		var accepted_answers: Array = question.get("answers", [])
		var correct_answer := ""

		if not accepted_answers.is_empty():
			correct_answer = str(accepted_answers[0])

		if student_answer.strip_edges().to_lower() == correct_answer.strip_edges().to_lower():
			answer_input.modulate = Color(0.55, 0.9, 0.45, 1)
		else:
			answer_input.modulate = Color(1.0, 0.55, 0.45, 1)
	else:
		answer_input.modulate = Color.WHITE

func _save_identification_answer() -> void:
	var answer_input := $VBoxContainer/IdentficationPanel/QuestionPanel/QuestionMargin/VBox/AnswerText as TextEdit

	student_answers[current_question_index] = answer_input.text.strip_edges()


# ============================================================
# ENUMERATION
# ============================================================

func _display_enumeration(question: Dictionary) -> void:
	var answer_nodes := [
		$VBoxContainer/EnumetrationPanel/Margin/VBox/AnswerScroll/CenterContainer/Answers/Answer1,
		$VBoxContainer/EnumetrationPanel/Margin/VBox/AnswerScroll/CenterContainer/Answers/Answer2,
		$VBoxContainer/EnumetrationPanel/Margin/VBox/AnswerScroll/CenterContainer/Answers/Answer3
	]

	var saved_answers: Array = student_answers.get(current_question_index, [])
	var accepted_answers: Array = question.get("answers", [])

	for i in range(answer_nodes.size()):
		var answer_input: LineEdit = answer_nodes[i]

		var student_answer: String = (
			str(saved_answers[i])
			if i < saved_answers.size()
			else ""
		)

		answer_input.text = student_answer
		answer_input.editable = not review_mode

		if review_mode:
			var is_correct := false

			for accepted in accepted_answers:
				if student_answer.strip_edges().to_lower() == str(accepted).strip_edges().to_lower():
					is_correct = true
					break

			answer_input.modulate = (
				Color(0.55, 0.9, 0.45, 1)
				if is_correct
				else Color(1.0, 0.55, 0.45, 1)
			) if not student_answer.is_empty() else Color.WHITE
		else:
			answer_input.modulate = Color.WHITE


func _save_enumeration_answer() -> void:
	var answer_nodes := [
		$VBoxContainer/EnumetrationPanel/Margin/VBox/AnswerScroll/CenterContainer/Answers/Answer1,
		$VBoxContainer/EnumetrationPanel/Margin/VBox/AnswerScroll/CenterContainer/Answers/Answer2,
		$VBoxContainer/EnumetrationPanel/Margin/VBox/AnswerScroll/CenterContainer/Answers/Answer3
	]

	var answers: Array = []

	for answer_input in answer_nodes:
		var value: String = answer_input.text.strip_edges()

		if not value.is_empty():
			answers.append(value)

	student_answers[current_question_index] = answers


# ============================================================
# SAVE CURRENT ANSWER
# ============================================================

func _save_current_answer() -> void:
	if current_question_index >= questions.size():
		return

	var question: Dictionary = questions[current_question_index]
	var question_type := str(question.get("type", "")).to_lower()

	match question_type:
		"identification":
			_save_identification_answer()

		"enumeration":
			_save_enumeration_answer()


# ============================================================
# NAVIGATION
# ============================================================

func _on_back_pressed() -> void:
	if current_question_index <= 0 or quiz_submitted:
		return

	_save_current_answer()

	if not review_mode:
		quiz_timer.stop()
		question_times[current_question_index] = remaining_time

	current_question_index -= 1
	_display_question()


func _on_next_pressed() -> void:
	if quiz_submitted:
		_exit_form()
		return	

	if review_mode:
		if completion_panel.visible:
			_exit_form()
		elif current_question_index < questions.size() - 1:
			current_question_index += 1
			_display_question()
		else:
			_show_review_completion()

		return

	_save_current_answer()

	if current_question_index < questions.size() - 1:
		quiz_timer.stop()
		question_times[current_question_index] = remaining_time

		current_question_index += 1
		_display_question()
	else:
		_submit_quiz()


# ============================================================
# TIMER
# ============================================================

func _on_timer_timeout() -> void:
	if not quiz_active or review_mode or quiz_submitted:
		return

	remaining_time -= 1
	_update_timer_display()

	if remaining_time <= 0:
		_save_current_answer()
		question_times[current_question_index] = 0

		quiz_timer.stop()

		if current_question_index < questions.size() - 1:
			current_question_index += 1
			_display_question()
		else:
			_submit_quiz()


func _update_timer_display() -> void:
	var minutes := int(remaining_time / 60)
	var seconds := remaining_time % 60

	timer_label.text = "%02d:%02d" % [minutes, seconds]


# ============================================================
# SCORING
# ============================================================

func _calculate_score() -> void:
	score = 0

	for i in range(questions.size()):
		var question: Dictionary = questions[i]
		var question_type := str(question.get("type", "")).to_lower()

		var correct_answers: Array = question.get("correct_answers", [])
		var accepted_answers: Array = question.get("answers", [])

		var student_answer = student_answers.get(i, null)

		match question_type:
			"multiple_choice":
				var correct_indices: Array = correct_answers.duplicate()
				var selected_indices: Array = student_answer if student_answer is Array else []

				correct_indices.sort()
				selected_indices.sort()

				if correct_indices == selected_indices and not correct_indices.is_empty():
					score += 1

			"true_false":
				if correct_answers.is_empty():
					continue

				var correct_index := int(correct_answers[0])
				var correct_value := "True" if correct_index == 0 else "False"

				if str(student_answer) == correct_value:
					score += 1

			"identification":
				if accepted_answers.is_empty():
					continue

				var expected := str(accepted_answers[0]).strip_edges().to_lower()
				var actual := str(student_answer).strip_edges().to_lower()

				if not actual.is_empty() and actual == expected:
					score += 1

			"enumeration":
				if accepted_answers.is_empty() or not student_answer is Array:
					continue

				var expected_answers: Array = []

				for accepted in accepted_answers:
					expected_answers.append(str(accepted).strip_edges().to_lower())

				var actual_answers: Array = []

				for entered in student_answer:
					var normalized := str(entered).strip_edges().to_lower()

					if not normalized.is_empty():
						actual_answers.append(normalized)

				expected_answers.sort()
				actual_answers.sort()

				if expected_answers == actual_answers:
					score += 1

	if questions.size() > 0:
		percentage = (float(score) / float(questions.size())) * 100.0
	else:
		percentage = 0.0


# ============================================================
# SUBMISSION
# ============================================================
func _submit_quiz() -> void:
	if review_mode or quiz_submitted or saving_result:
		return

	_save_current_answer()

	if quiz_timer != null:
		quiz_timer.stop()

	quiz_active = false
	saving_result = true

	next_button.disabled = true
	back_button.disabled = true
	status_label.text = "Saving your quiz result..."

	_calculate_score()

	var total_questions: int = questions.size()

	if total_questions <= 0:
		saving_result = false
		next_button.disabled = false
		back_button.disabled = false
		status_label.text = "There are no questions to submit."
		return

	var saved: bool = await _save_quiz_result(
		score,
		total_questions,
		percentage
	)

	saving_result = false

	if not saved:
		next_button.disabled = false
		back_button.disabled = false
		next_button.text = "RETRY"
		status_label.text = "Saving failed. Press RETRY to submit again."
		print("[QuizForm] Quiz result was not saved.")
		return

	quiz_submitted = true

	next_button.disabled = false
	back_button.disabled = false

	_show_completion()

	print("[QuizForm] Quiz submitted successfully.")
	print("[QuizForm] Score: ", score, "/", total_questions)
	print("[QuizForm] Percentage: ", percentage)


func _show_completion() -> void:
	multiple_choice_panel.hide()
	enumeration_panel.hide()
	identification_panel.hide()
	true_false_panel.hide()
	question_text.get_parent().get_parent().hide()

	completion_panel.show()

	score_value_label.text = "%d / %d" % [
		score,
		questions.size()
	]

	percentage_value_label.text = "%.1f%%" % percentage

	number_label.text = "Quiz Completed"
	type_label.text = str(quiz_data.get("title", "Quiz"))

	timer_label.text = "FINISHED"

	back_button.hide()
	next_button.text = "FINISH"

	status_label.text = "You have completed this quiz."


# ============================================================
# REVIEW MODE
# ============================================================

func _show_review_completion() -> void:
	var saved_score := int(assessment_data.get("score", 0))
	var total := int(assessment_data.get("total_questions", questions.size()))
	var saved_percentage := float(assessment_data.get("percentage", 0.0))

	score_value_label.text = "%d / %d" % [
		saved_score,
		total
	]

	percentage_value_label.text = "%.1f%%" % saved_percentage

	multiple_choice_panel.hide()
	enumeration_panel.hide()
	identification_panel.hide()
	true_false_panel.hide()
	question_text.get_parent().get_parent().hide()

	completion_panel.show()

	number_label.text = "Assessment Review"
	timer_label.text = "REVIEW"

	back_button.hide()
	next_button.text = "FINISH"

	status_label.text = "This assessment has already been completed."


func _get_uid() -> String:
	if AuthManager.has_method("get_uid"):
		var uid_value: Variant = AuthManager.get_uid()
		if uid_value != null:
			return str(uid_value).strip_edges()

	if "user_uid" in AuthManager:
		var uid_value: Variant = AuthManager.user_uid
		if uid_value != null:
			return str(uid_value).strip_edges()

	print("[QuizForm] ERROR: Could not obtain student UID.")
	return ""


func _get_id_token() -> String:
	if Firebase.Firestore == null:
		print("[QuizForm] ERROR: Firebase.Firestore is null.")
		return ""

	if Firebase.Firestore.auth == null:
		print("[QuizForm] ERROR: Firebase auth is null.")
		return ""

	var auth_data: Dictionary = Firebase.Firestore.auth
	var token_value: Variant = auth_data.get("idtoken", "")

	if token_value == null:
		return ""

	return str(token_value).strip_edges()


func _save_quiz_result(
	result_score: int,
	total_questions: int,
	result_percentage: float
) -> bool:
	var uid: String = _get_uid()
	var id_token: String = _get_id_token()
	var quiz_id: String = str(quiz_data.get("quiz_id", "")).strip_edges()
	var quiz_title: String = str(quiz_data.get("title", "Untitled Quiz"))

	if uid.is_empty():
		status_label.text = "Unable to identify your student account."
		return false

	if id_token.is_empty():
		status_label.text = "Your login session has expired. Please log in again."
		return false

	if quiz_id.is_empty():
		status_label.text = "Quiz ID is missing. Please contact your teacher."
		return false

	var firestore_url: String = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/students/"
		+ uid
	)

	var timestamp: String = Time.get_datetime_string_from_system(true) + "Z"

	# Convert the student's answers into Firestore-compatible values.
	var student_answers_fields: Dictionary = {}

	for question_index in range(questions.size()):
		var index_key: String = str(question_index)

		if not student_answers.has(question_index):
			continue

		var student_answer: Variant = student_answers[question_index]

		if student_answer is Array:
			var answer_values: Array = []

			for answer in student_answer:
				if answer is int:
					answer_values.append({
						"integerValue": str(answer)
					})
				else:
					answer_values.append({
						"stringValue": str(answer)
					})

			student_answers_fields[index_key] = {
				"arrayValue": {
					"values": answer_values
				}
			}
		else:
			student_answers_fields[index_key] = {
				"stringValue": str(student_answer)
			}

	var assessment_fields: Dictionary = {
		"quiz_id": {
			"stringValue": quiz_id
		},
		"quiz_title": {
			"stringValue": quiz_title
		},
		"score": {
			"integerValue": str(result_score)
		},
		"total_questions": {
			"integerValue": str(total_questions)
		},
		"percentage": {
			"doubleValue": result_percentage
		},
		"completed": {
			"booleanValue": true
		},
		"completed_at": {
			"timestampValue": timestamp
		},
		"student_answers": {
			"mapValue": {
				"fields": student_answers_fields
			}
		}
	}

	var request_body: Dictionary = {
		"fields": {
			"assessment": {
				"mapValue": {
					"fields": {
						quiz_id: {
							"mapValue": {
								"fields": assessment_fields
							}
						}
					}
				}
			}
		}
	}

	var update_mask: String = "assessment.`" + quiz_id + "`"
	var encoded_mask: String = update_mask.uri_encode()

	var request_url: String = firestore_url + "?updateMask.fieldPaths=" + encoded_mask

	var http_request := HTTPRequest.new()
	add_child(http_request)

	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]

	var error: Error = http_request.request(
		request_url,
		headers,
		HTTPClient.METHOD_PATCH,
		JSON.stringify(request_body)
	)

	if error != OK:
		print("[QuizForm] Firestore request error: ", error)
		http_request.queue_free()
		status_label.text = "Could not send your quiz result."
		return false

	var response: Array = await http_request.request_completed
	var response_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]

	http_request.queue_free()

	if response_code < 200 or response_code >= 300:
		print("[QuizForm] Failed to save quiz result. HTTP: ", response_code)
		print("[QuizForm] Response: ", response_body.get_string_from_utf8())
		status_label.text = "Failed to save your quiz result. Please try again."
		return false

	print("[QuizForm] Quiz result and student answers saved successfully.")
	return true


# ============================================================
# EXIT
# ============================================================

func _exit_form() -> void:
	if quiz_timer != null:
		quiz_timer.stop()

	if return_page != null and is_instance_valid(return_page):
		return_page.visible = true
		return_page.mouse_filter = Control.MOUSE_FILTER_STOP

		# Refresh the quiz list after a successful submission.
		if quiz_submitted and return_page.has_method("_load_completed_quizzes"):
			return_page._load_completed_quizzes()

	queue_free()


func _on_back_pressed_exit() -> void:
	_exit_form()

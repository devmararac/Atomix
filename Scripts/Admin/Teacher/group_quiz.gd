extends Control


signal back_pressed
signal quiz_started


# ============================================================
# FIRESTORE
# ============================================================

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

var firestore_url: String


# ============================================================
# DATA
# ============================================================

var students: Array[Dictionary] = []

var group_a: Array[Dictionary] = []
var group_b: Array[Dictionary] = []

var leader_a: Dictionary = {}
var leader_b: Dictionary = {}


# ============================================================
# QUIZ DATA
# ============================================================

var quizzes: Array[Dictionary] = []

var selected_quiz: Dictionary = {}


# ============================================================
# NODES
# ============================================================

@onready var quiz_option: OptionButton = \
	$MarginContainer/VBoxContainer/Content/SetupPanel/MarginContainer/VBoxContainer/QuizOption

@onready var required_points: SpinBox = \
	$MarginContainer/VBoxContainer/Content/SetupPanel/MarginContainer/VBoxContainer/RequiredPoints

@onready var students_list: ItemList = \
	$MarginContainer/VBoxContainer/Content/SetupPanel/MarginContainer/VBoxContainer/StudentsList

@onready var leader_a_label: Label = \
	$MarginContainer/VBoxContainer/Content/TeamsPanel/MarginContainer/VBoxContainer/Groups/GroupA/VBoxContainer/LeaderA

@onready var members_a_label: Label = \
	$MarginContainer/VBoxContainer/Content/TeamsPanel/MarginContainer/VBoxContainer/Groups/GroupA/VBoxContainer/ScrollContainer/MembersA

@onready var leader_b_label: Label = \
	$MarginContainer/VBoxContainer/Content/TeamsPanel/MarginContainer/VBoxContainer/Groups/GroupB/VBoxContainer/LeaderB

@onready var members_b_label: Label = \
	$MarginContainer/VBoxContainer/Content/TeamsPanel/MarginContainer/VBoxContainer/Groups/GroupB/VBoxContainer/ScrollContainer/MembersB

@onready var randomize_button: Button = \
	$MarginContainer/VBoxContainer/BottomBar/RandomizeButton

@onready var start_quiz_button: Button = \
	$MarginContainer/VBoxContainer/BottomBar/StartQuizButton

@onready var back_button: Button = \
	$MarginContainer/VBoxContainer/Header/BackButton


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	back_button.pressed.connect(
		_on_back_pressed
	)

	randomize_button.pressed.connect(
		_on_randomize_pressed
	)

	start_quiz_button.pressed.connect(
		_on_start_quiz_pressed
	)

	quiz_option.item_selected.connect(
		_on_quiz_selected
	)

	# --------------------------------------------------------
	# FIRESTORE URL
	# --------------------------------------------------------

	firestore_url = (
		"https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/quizzes"
	)

	# --------------------------------------------------------
	# LOAD QUIZZES
	# --------------------------------------------------------

	load_quizzes()

	# --------------------------------------------------------
	# LOAD REAL STUDENTS
	# --------------------------------------------------------

	if not TeacherDataManager.students_loaded.is_connected(
		_on_students_loaded
	):
		TeacherDataManager.students_loaded.connect(
		_on_students_loaded
	)

	if not TeacherDataManager.students_error.is_connected(
		_on_students_error
	):
		TeacherDataManager.students_error.connect(
		_on_students_error
	)

	load_students()

	# --------------------------------------------------------
	# START DISABLED
	# --------------------------------------------------------

	start_quiz_button.disabled = true

# ============================================================
# LOAD QUIZZES FROM FIRESTORE
# ============================================================

func load_quizzes() -> void:

	print(
		"[GroupQuiz] Loading quizzes from Firestore..."
	)

	quizzes.clear()
	selected_quiz.clear()

	var token := _get_id_token()

	if token.is_empty():

		print(
			"[GroupQuiz] ERROR: Firebase ID token is empty."
		)

		_setup_empty_quiz_option()

		return


	var http := HTTPRequest.new()

	add_child(http)

	http.request_completed.connect(
		_on_load_quizzes_completed.bind(http)
	)


	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	])


	print(
		"[GroupQuiz] Firestore URL: ",
		firestore_url
	)


	var error := http.request(
		firestore_url,
		headers,
		HTTPClient.METHOD_GET
	)


	if error != OK:

		print(
			"[GroupQuiz] ERROR: Failed to request quizzes. Error: ",
			error
		)

		http.queue_free()


# ============================================================
# FIRESTORE RESPONSE
# ============================================================

func _on_load_quizzes_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:

	var response_text := \
		body.get_string_from_utf8()


	print(
		"[GroupQuiz] Firestore response code: ",
		response_code
	)


	if response_code != 200:

		print(
			"[GroupQuiz] ERROR loading quizzes."
		)

		print(
			"[GroupQuiz] Response: ",
			response_text
		)

		http.queue_free()

		_setup_empty_quiz_option()

		return


	var json := JSON.new()

	var parse_error := json.parse(
		response_text
	)


	if parse_error != OK:

		print(
			"[GroupQuiz] ERROR: Could not parse Firestore response."
		)

		http.queue_free()

		_setup_empty_quiz_option()

		return


	var data = json.data


	if not data is Dictionary:

		print(
			"[GroupQuiz] ERROR: Firestore response is not a Dictionary."
		)

		http.queue_free()

		_setup_empty_quiz_option()

		return


	var documents = data.get(
		"documents",
		[]
	)


	if not documents is Array:

		print(
			"[GroupQuiz] ERROR: documents is not an Array."
		)

		http.queue_free()

		_setup_empty_quiz_option()

		return


	print(
		"[GroupQuiz] Firestore returned ",
		documents.size(),
		" quiz documents."
	)


	# ========================================================
	# CONVERT DOCUMENTS
	# ========================================================

	for document in documents:

		if not document is Dictionary:
			continue


		var quiz := _firestore_document_to_quiz(
			document
		)


		if quiz.is_empty():
			continue


		quizzes.append(
			quiz
		)


		print(
			"[GroupQuiz] Loaded quiz: ",
			quiz.get(
				"title",
				"Untitled Quiz"
			)
		)


	http.queue_free()


	# ========================================================
	# DISPLAY QUIZZES
	# ========================================================

	_setup_quiz_options()


# ============================================================
# CONVERT FIRESTORE DOCUMENT TO QUIZ
# ============================================================

func _firestore_document_to_quiz(
	document: Dictionary
) -> Dictionary:

	var fields: Dictionary = document.get(
		"fields",
		{}
	)


	if fields.is_empty():
		return {}


	var quiz_id := _firestore_string(
		fields.get(
			"quiz_id",
			{}
		)
	)


	var title := _firestore_string(
		fields.get(
			"title",
			{}
		)
	)


	var teacher_id := _firestore_string(
		fields.get(
			"teacher_id",
			{}
		)
	)


	var quiz_type := _firestore_string(
		fields.get(
			"quiz_type",
			{}
		)
	)


	var question_count := _firestore_integer(
		fields.get(
			"question_count",
			{}
		)
	)


	var created_at := _firestore_string(
		fields.get(
			"created_at",
			{}
		)
	)


	# ========================================================
	# QUESTIONS
	# ========================================================

	var questions: Array = []

	var questions_field: Dictionary = fields.get(
		"questions",
		{}
	)


	var array_value: Dictionary = questions_field.get(
		"arrayValue",
		{}
	)


	var question_values: Array = array_value.get(
		"values",
		[]
	)


	for question_value in question_values:

		if not question_value is Dictionary:
			continue


		var map_value: Dictionary = question_value.get(
			"mapValue",
			{}
		)


		var question_fields: Dictionary = map_value.get(
			"fields",
			{}
		)


		var question_text := _firestore_string(
			question_fields.get(
				"question",
				{}
			)
		)


		var type := _firestore_string(
			question_fields.get(
				"type",
				{}
			)
		)


		# ----------------------------------------------------
		# ANSWERS
		# ----------------------------------------------------

		var answers: Array = []

		var answers_field: Dictionary = \
			question_fields.get(
				"answers",
				{}
			)


		var answers_array: Dictionary = \
			answers_field.get(
				"arrayValue",
				{}
			)


		var answer_values: Array = \
			answers_array.get(
				"values",
				[]
			)


		for answer_value in answer_values:

			answers.append(
				_firestore_string(
					answer_value
				)
			)


		# ----------------------------------------------------
		# CORRECT ANSWERS
		# ----------------------------------------------------

		var correct_answers: Array = []

		var correct_field: Dictionary = \
			question_fields.get(
				"correct_answers",
				{}
			)


		var correct_array: Dictionary = \
			correct_field.get(
				"arrayValue",
				{}
			)


		var correct_values: Array = \
			correct_array.get(
				"values",
				[]
			)


		for correct_value in correct_values:

			correct_answers.append(
				_firestore_integer(
					correct_value
				)
			)


		questions.append(
			{
				"question": question_text,
				"type": type,
				"answers": answers,
				"correct_answers": correct_answers
			}
		)


	# ========================================================
	# RETURN QUIZ
	# ========================================================

	return {
		"quiz_id": quiz_id,
		"title": title,
		"teacher_id": teacher_id,
		"quiz_type": quiz_type,
		"question_count": question_count,
		"questions": questions,
		"created_at": created_at
	}


# ============================================================
# FIRESTORE STRING
# ============================================================

func _firestore_string(
	value: Dictionary
) -> String:

	if value.has("stringValue"):

		return str(
			value.get(
				"stringValue",
				""
			)
		)

	return ""


# ============================================================
# FIRESTORE INTEGER
# ============================================================

func _firestore_integer(
	value: Dictionary
) -> int:

	if value.has("integerValue"):

		return int(
			value.get(
				"integerValue",
				"0"
			)
		)


	if value.has("doubleValue"):

		return int(
			float(
				value.get(
					"doubleValue",
					0
				)
			)
		)


	return 0


# ============================================================
# QUIZ OPTIONS
# ============================================================

func _setup_quiz_options() -> void:

	quiz_option.clear()


	if quizzes.is_empty():

		_setup_empty_quiz_option()

		return


	for quiz in quizzes:

		var title := str(
			quiz.get(
				"title",
				"Untitled Quiz"
			)
		)

		quiz_option.add_item(
			title
		)


	# Select first quiz automatically.

	quiz_option.select(0)

	selected_quiz = quizzes[0]

	print(
		"[GroupQuiz] Default quiz selected: ",
		selected_quiz.get(
			"title",
			"Untitled Quiz"
		)
	)


# ============================================================
# EMPTY QUIZ OPTION
# ============================================================

func _setup_empty_quiz_option() -> void:

	quiz_option.clear()

	quiz_option.add_item(
		"No quizzes available"
	)

	quiz_option.select(0)

	selected_quiz.clear()


# ============================================================
# QUIZ SELECTION CHANGED
# ============================================================

func _on_quiz_selected(
	index: int
) -> void:

	if index < 0:
		return


	if index >= quizzes.size():
		return


	selected_quiz = quizzes[index]


	print(
		"[GroupQuiz] Quiz selected: ",
		selected_quiz.get(
			"title",
			"Untitled Quiz"
		)
	)

	print(
		"[GroupQuiz] Quiz ID: ",
		selected_quiz.get(
			"quiz_id",
			""
		)
	)

	print(
		"[GroupQuiz] Questions: ",
		selected_quiz.get(
			"questions",
			[]
		).size()
	)

# ============================================================
# STUDENT LIST
# ============================================================

func _refresh_student_list() -> void:

	students_list.clear()

	for student in students:

		students_list.add_item(
			str(
				student.get(
					"display_name",
					"Unknown"
				)
			)
		)


# ============================================================
# RANDOMIZE GROUPS
# ============================================================

func _randomize_groups() -> void:

	group_a.clear()
	group_b.clear()

	leader_a.clear()
	leader_b.clear()


	if students.size() < 2:

		push_warning(
			"[GroupQuiz] At least 2 students are required."
		)

		return


	var shuffled_students := \
		students.duplicate()

	shuffled_students.shuffle()


	for i in range(
		shuffled_students.size()
	):

		if i % 2 == 0:

			group_a.append(
				shuffled_students[i]
			)

		else:

			group_b.append(
				shuffled_students[i]
			)


	# --------------------------------------------------------
	# PICK LEADERS
	# --------------------------------------------------------

	if not group_a.is_empty():

		leader_a = \
			group_a.pick_random()


	if not group_b.is_empty():

		leader_b = \
			group_b.pick_random()


	_refresh_team_display()

	start_quiz_button.disabled = false


# ============================================================
# TEAM DISPLAY
# ============================================================

func _refresh_team_display() -> void:

	if leader_a.is_empty():

		leader_a_label.text = \
			"Leader: —"

	else:

		leader_a_label.text = \
			"Leader: " + str(
				leader_a.get(
					"display_name",
					"Unknown"
				)
			)


	if leader_b.is_empty():

		leader_b_label.text = \
			"Leader: —"

	else:

		leader_b_label.text = \
			"Leader: " + str(
				leader_b.get(
					"display_name",
					"Unknown"
				)
			)


	# ========================================================
	# GROUP A MEMBERS
	# ========================================================

	var members_a := ""

	for student in group_a:

		var name := str(
			student.get(
				"display_name",
				"Unknown"
			)
		)


		if student.get("uid") == \
			leader_a.get("uid"):

			name += "  ★"


		members_a += name + "\n"


	members_a_label.text = \
		members_a


	# ========================================================
	# GROUP B MEMBERS
	# ========================================================

	var members_b := ""

	for student in group_b:

		var name := str(
			student.get(
				"display_name",
				"Unknown"
			)
		)


		if student.get("uid") == \
			leader_b.get("uid"):

			name += "  ★"


		members_b += name + "\n"


	members_b_label.text = \
		members_b


# ============================================================
# RANDOMIZE BUTTON
# ============================================================

func _on_randomize_pressed() -> void:

	print(
		"[GroupQuiz] Randomizing groups..."
	)


	GroupQuizManager.set_students(
		students
	)


	GroupQuizManager.randomize_teams()


	group_a = \
		GroupQuizManager.group_a

	group_b = \
		GroupQuizManager.group_b

	leader_a = \
		GroupQuizManager.leader_a

	leader_b = \
		GroupQuizManager.leader_b


	_refresh_team_display()


	start_quiz_button.disabled = false


	print(
		"[GroupQuiz] Group A: ",
		group_a
	)

	print(
		"[GroupQuiz] Group B: ",
		group_b
	)

	print(
		"[GroupQuiz] Leader A: ",
		leader_a
	)

	print(
		"[GroupQuiz] Leader B: ",
		leader_b
	)


# ============================================================
# START QUIZ
# ============================================================

func _on_start_quiz_pressed() -> void:

	if selected_quiz.is_empty():

		push_warning(
			"[GroupQuiz] No quiz selected."
		)

		return


	if group_a.is_empty() \
	or group_b.is_empty():

		push_warning(
			"[GroupQuiz] Groups have not been generated."
		)

		return


	var quiz_id := str(
		selected_quiz.get(
			"quiz_id",
			""
		)
	)


	var quiz_name := str(
		selected_quiz.get(
			"title",
			"Untitled Quiz"
		)
	)


	var points := int(
		required_points.value
	)


	if quiz_id.is_empty():

		push_warning(
			"[GroupQuiz] Selected quiz has no quiz_id."
		)

		return


	print("========================================")
	print("[GroupQuiz] STARTING GROUP QUIZ")
	print("[GroupQuiz] Quiz: ", quiz_name)
	print("[GroupQuiz] Quiz ID: ", quiz_id)
	print("[GroupQuiz] Questions: ", selected_quiz.get("questions", []).size())
	print("[GroupQuiz] Required Points: ", points)
	print("========================================")


	# ========================================================
	# CREATE GROUP QUIZ SESSION
	# ========================================================

	var session_id := \
		"LOCAL_TEST_SESSION"


	var host_uid := \
		"TEACHER_LOCAL"


	GroupQuizManager.create_session(
		session_id,
		host_uid,
		quiz_id,
		quiz_name,
		points
	)


	# --------------------------------------------------------
	# Give the manager the students.
	# --------------------------------------------------------

	GroupQuizManager.set_students(
		students
	)


	# --------------------------------------------------------
	# Use the already-created teams.
	# --------------------------------------------------------

	GroupQuizManager.group_a = \
		group_a.duplicate()

	GroupQuizManager.group_b = \
		group_b.duplicate()

	GroupQuizManager.leader_a = \
		leader_a.duplicate()

	GroupQuizManager.leader_b = \
		leader_b.duplicate()


	# --------------------------------------------------------
	# Start the quiz.
	# --------------------------------------------------------

	GroupQuizManager.start_quiz()


	print(
		"[GroupQuiz] Group Quiz session started."
	)


	quiz_started.emit()

# ============================================================
# LOAD STUDENTS
# ============================================================

func load_students() -> void:

	print(
		"[GroupQuiz] Requesting students from TeacherDataManager..."
	)

	TeacherDataManager.load_students()


# ============================================================
# STUDENTS LOADED
# ============================================================

func _on_students_loaded(
	student_list: Array
) -> void:

	print(
		"[GroupQuiz] Received ",
		student_list.size(),
		" students from TeacherDataManager."
	)

	students.clear()

	for student_data in student_list:

		if not student_data is Dictionary:
			continue

		var uid := str(
			student_data.get(
				"uid",
				""
			)
		)

		if uid.is_empty():

			print(
				"[GroupQuiz] Skipping student without UID: ",
				student_data.get(
					"name",
					"Unknown"
				)
			)

			continue

		var student := {
			"uid": uid,
			"display_name": str(
				student_data.get(
					"name",
					"Unknown Student"
				)
			),
			"student_id": str(
				student_data.get(
					"student_id",
					""
				)
			),
			"section": str(
				student_data.get(
					"section",
					""
				)
			),
			"email": str(
				student_data.get(
					"email",
					""
				)
			)
		}

		students.append(
			student
		)

		print(
			"[GroupQuiz] Student added: ",
			student["display_name"],
			" | UID: ",
			student["uid"],
			" | Section: ",
			student["section"]
		)

	_refresh_student_list()

	print(
		"[GroupQuiz] Group Quiz student count: ",
		students.size()
	)

	# Groups must be regenerated whenever the student list changes.
	group_a.clear()
	group_b.clear()
	leader_a.clear()
	leader_b.clear()

	_refresh_team_display()

	start_quiz_button.disabled = true


# ============================================================
# STUDENT LOAD ERROR
# ============================================================

func _on_students_error(
	error
) -> void:

	print(
		"[GroupQuiz] Failed to load students: ",
		error
	)

	students.clear()

	_refresh_student_list()

	group_a.clear()
	group_b.clear()

	leader_a.clear()
	leader_b.clear()

	_refresh_team_display()

	start_quiz_button.disabled = true


# ============================================================
# FIREBASE ID TOKEN
# ============================================================

func _get_id_token() -> String:

	if Firebase.Auth == null:

		print(
			"[GroupQuiz] Firebase.Auth is null."
		)

		return ""


	var auth_data: Dictionary = \
		Firebase.Auth.auth


	if auth_data.is_empty():

		print(
			"[GroupQuiz] Firebase.Auth.auth is empty."
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
			"[GroupQuiz] Could not find Firebase ID token."
		)

		return ""


	return token


# ============================================================
# BACK
# ============================================================

func _on_back_pressed() -> void:

	back_pressed.emit()

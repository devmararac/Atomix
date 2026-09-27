extends Node

# ============================================================
# GROUP QUIZ MANAGER
# ============================================================
#
# Handles the temporary state of a teacher-hosted Group Quiz.
#
# This manager is intentionally separate from:
# - StudentDataManager
# - PartyManager
# - InventoryManager
# - QuestManager
#
# Firebase synchronization will be added later.
# ============================================================


# ============================================================
# SIGNALS
# ============================================================

signal session_created(session_data: Dictionary)
signal session_updated(session_data: Dictionary)

signal students_updated(students: Array[Dictionary])

signal teams_randomized(
	group_a: Array[Dictionary],
	group_b: Array[Dictionary],
	leader_a: Dictionary,
	leader_b: Dictionary
)

signal quiz_started(session_data: Dictionary)
signal quiz_ended()

signal question_started(question_index: int)
signal answer_submitted(
	uid: String,
	answer: String
)

signal scores_updated(
	score_a: int,
	score_b: int
)


# ============================================================
# SESSION STATE
# ============================================================

var session_id: String = ""
var host_uid: String = ""

var quiz_id: String = ""
var quiz_name: String = ""

var status: String = "idle"
var phase: String = "lobby"

var current_question: int = 0
var required_score: int = 5


# ============================================================
# STUDENTS
# ============================================================

var students: Array[Dictionary] = []


# ============================================================
# TEAMS
# ============================================================

var group_a: Array[Dictionary] = []
var group_b: Array[Dictionary] = []

var leader_a: Dictionary = {}
var leader_b: Dictionary = {}


# ============================================================
# SCORES
# ============================================================

var score_a: int = 0
var score_b: int = 0


# ============================================================
# ANSWERS
# ============================================================

var answers: Dictionary = {}


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[GroupQuizManager] Initialized.")


# ============================================================
# SESSION CREATION
# ============================================================

func create_session(
	new_session_id: String,
	new_host_uid: String,
	new_quiz_id: String,
	new_quiz_name: String,
	new_required_score: int
) -> void:

	session_id = new_session_id
	host_uid = new_host_uid

	quiz_id = new_quiz_id
	quiz_name = new_quiz_name

	required_score = max(new_required_score, 1)

	status = "lobby"
	phase = "team_assignment"

	current_question = 0

	score_a = 0
	score_b = 0

	answers.clear()

	group_a.clear()
	group_b.clear()

	leader_a.clear()
	leader_b.clear()

	var session_data := get_session_data()

	print("========================================")
	print("[GroupQuizManager] Session Created")
	print("[GroupQuizManager] Session ID: ", session_id)
	print("[GroupQuizManager] Host UID: ", host_uid)
	print("[GroupQuizManager] Quiz: ", quiz_name)
	print("[GroupQuizManager] Required Score: ", required_score)
	print("========================================")

	session_created.emit(session_data)


# ============================================================
# STUDENT MANAGEMENT
# ============================================================

func set_students(new_students: Array[Dictionary]) -> void:

	students.clear()

	for student in new_students:

		if not student.has("uid"):
			continue

		var student_data := student.duplicate()

		if not student_data.has("display_name"):
			student_data["display_name"] = "Unknown"

		students.append(student_data)

	students_updated.emit(students)

	print(
		"[GroupQuizManager] Students updated: ",
		students.size()
	)


func add_student(
	uid: String,
	display_name: String
) -> void:

	if uid.is_empty():
		return

	if has_student(uid):
		return

	var student := {
		"uid": uid,
		"display_name": display_name
	}

	students.append(student)

	students_updated.emit(students)

	print(
		"[GroupQuizManager] Student joined: ",
		display_name
	)


func remove_student(uid: String) -> void:

	for i in range(students.size()):

		if students[i].get("uid") == uid:

			print(
				"[GroupQuizManager] Student removed: ",
				students[i].get("display_name", "Unknown")
			)

			students.remove_at(i)

			students_updated.emit(students)

			return


func has_student(uid: String) -> bool:

	for student in students:

		if student.get("uid") == uid:
			return true

	return false


# ============================================================
# TEAM RANDOMIZATION
# ============================================================

func randomize_teams() -> void:

	group_a.clear()
	group_b.clear()

	leader_a.clear()
	leader_b.clear()

	if students.size() < 2:

		push_warning(
			"[GroupQuizManager] At least 2 students are required."
		)

		return

	var shuffled_students := students.duplicate()

	shuffled_students.shuffle()

	for i in range(shuffled_students.size()):

		if i % 2 == 0:
			group_a.append(shuffled_students[i])
		else:
			group_b.append(shuffled_students[i])


	# --------------------------------------------------------
	# RANDOM LEADERS
	# --------------------------------------------------------

	if not group_a.is_empty():

		leader_a = group_a.pick_random()


	if not group_b.is_empty():

		leader_b = group_b.pick_random()


	phase = "team_assignment"

	print("========================================")
	print("[GroupQuizManager] Teams Randomized")
	print("[GroupQuizManager] Group A: ", group_a)
	print("[GroupQuizManager] Group B: ", group_b)
	print(
		"[GroupQuizManager] Leader A: ",
		leader_a
	)
	print(
		"[GroupQuizManager] Leader B: ",
		leader_b
	)
	print("========================================")

	teams_randomized.emit(
		group_a,
		group_b,
		leader_a,
		leader_b
	)

	session_updated.emit(
		get_session_data()
	)


# ============================================================
# START QUIZ
# ============================================================

func start_quiz() -> void:

	if group_a.is_empty() or group_b.is_empty():

		push_warning(
			"[GroupQuizManager] Cannot start quiz without two groups."
		)

		return

	if quiz_id.is_empty():

		push_warning(
			"[GroupQuizManager] No quiz selected."
		)

		return

	status = "active"
	phase = "question"

	current_question = 0

	score_a = 0
	score_b = 0

	answers.clear()

	print("========================================")
	print("[GroupQuizManager] Quiz Started")
	print("[GroupQuizManager] Quiz: ", quiz_name)
	print("[GroupQuizManager] Required Score: ", required_score)
	print("========================================")

	quiz_started.emit(
		get_session_data()
	)

	question_started.emit(current_question)

	session_updated.emit(
		get_session_data()
	)


# ============================================================
# QUESTION
# ============================================================

func start_question(question_index: int) -> void:

	if status != "active":

		push_warning(
			"[GroupQuizManager] Quiz is not active."
		)

		return

	current_question = question_index

	answers.clear()

	phase = "question"

	print(
		"[GroupQuizManager] Question started: ",
		current_question
	)

	question_started.emit(current_question)

	session_updated.emit(
		get_session_data()
	)


# ============================================================
# ANSWERS
# ============================================================

func submit_answer(
	uid: String,
	answer: String
) -> void:

	if status != "active":

		push_warning(
			"[GroupQuizManager] Cannot submit answer. Quiz is not active."
		)

		return

	if not has_student(uid):

		push_warning(
			"[GroupQuizManager] Unknown student attempted to answer: ",
			uid
		)

		return

	answers[uid] = answer

	print(
		"[GroupQuizManager] Answer submitted: ",
		uid,
		" = ",
		answer
	)

	answer_submitted.emit(
		uid,
		answer
	)

	session_updated.emit(
		get_session_data()
	)


# ============================================================
# CHECK ANSWERS
# ============================================================

func has_answered(uid: String) -> bool:

	return answers.has(uid)


func get_answer(uid: String) -> String:

	return str(
		answers.get(uid, "")
	)


func get_answer_count() -> int:

	return answers.size()


# ============================================================
# SCORING
# ============================================================

func add_score(
	group: String,
	points: int = 1
) -> void:

	points = max(points, 0)

	match group:

		"A":
			score_a += points

		"B":
			score_b += points

		_:
			push_warning(
				"[GroupQuizManager] Invalid group: ",
				group
			)

			return

	print(
		"[GroupQuizManager] Score updated - A: ",
		score_a,
		" | B: ",
		score_b
	)

	scores_updated.emit(
		score_a,
		score_b
	)

	session_updated.emit(
		get_session_data()
	)


func get_winning_group() -> String:

	if score_a >= required_score:

		return "A"

	if score_b >= required_score:

		return "B"

	return ""


func has_winner() -> bool:

	return not get_winning_group().is_empty()


# ============================================================
# END QUIZ
# ============================================================

func end_quiz() -> void:

	status = "ended"
	phase = "finished"

	print(
		"[GroupQuizManager] Quiz ended."
	)

	quiz_ended.emit()

	session_updated.emit(
		get_session_data()
	)


# ============================================================
# RESET SESSION
# ============================================================

func reset_session() -> void:

	session_id = ""
	host_uid = ""

	quiz_id = ""
	quiz_name = ""

	status = "idle"
	phase = "lobby"

	current_question = 0
	required_score = 5

	students.clear()

	group_a.clear()
	group_b.clear()

	leader_a.clear()
	leader_b.clear()

	score_a = 0
	score_b = 0

	answers.clear()

	print(
		"[GroupQuizManager] Session reset."
	)


# ============================================================
# GET SESSION DATA
# ============================================================

func get_session_data() -> Dictionary:

	return {
		"session_id": session_id,
		"host_uid": host_uid,

		"quiz_id": quiz_id,
		"quiz_name": quiz_name,

		"status": status,
		"phase": phase,

		"current_question": current_question,
		"required_score": required_score,

		"teams": {
			"A": {
				"leader_uid": str(
					leader_a.get("uid", "")
				),
				"members": _get_member_uids(group_a),
				"score": score_a
			},

			"B": {
				"leader_uid": str(
					leader_b.get("uid", "")
				),
				"members": _get_member_uids(group_b),
				"score": score_b
			}
		},

		"answers": answers.duplicate()
	}


# ============================================================
# HELPERS
# ============================================================

func _get_member_uids(
	group: Array[Dictionary]
) -> Array[String]:

	var uids: Array[String] = []

	for student in group:

		var uid := str(
			student.get("uid", "")
		)

		if not uid.is_empty():
			uids.append(uid)

	return uids

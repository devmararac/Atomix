
extends Control

const ELEMENTS_TOTAL: int = 118

const SECTION_BUTTON_SCENE: PackedScene = preload(
	"res://Scenes/Admin/Teacher/section_button.tscn"
)

const QUIZ_ROW_SCENE: PackedScene = preload(
	"res://Scenes/Admin/Teacher/student_quiz_list.tscn"
)

const ATOMON_ROW_SCENE: PackedScene = preload(
	"res://Scenes/Admin/Teacher/student_atomon_list.tscn"
)


# --------------------------------------------------
# DYNAMIC SECTION BUTTON CONTAINERS
# --------------------------------------------------

@onready var quiz_section_container: VBoxContainer = (
	$Background/ScrollContainer/CenterContainer/VBoxContainer/QuizCompletion/QuizCompletion2/VBoxContainer/GraphPanel/ScrollContainer/CenterContainer/VBoxContainer
)

@onready var atomon_section_container: VBoxContainer = (
	$Background/ScrollContainer/CenterContainer/VBoxContainer/QuizCompletion/CaptureProgress/VBoxContainer/GraphPanel/ScrollContainer/CenterContainer/VBoxContainer
)


# --------------------------------------------------
# SUMMARY CARD REFERENCES
# --------------------------------------------------

@onready var total_students_value: Label = (
	$Background/ScrollContainer/CenterContainer/VBoxContainer/StatsRow/TotalStudents/CardContents/VBoxContainer/Value
)

@onready var sections_value: Label = (
	$Background/ScrollContainer/CenterContainer/VBoxContainer/StatsRow/Sections/CardContents/VBoxContainer/Value
)

@onready var average_score_value: Label = (
	$Background/ScrollContainer/CenterContainer/VBoxContainer/StatsRow/QuizAverage/CardContents/VBoxContainer/Value
)


# --------------------------------------------------
# STUDENT PER SECTION GRAPH
# --------------------------------------------------

@onready var section_graph: DashboardGraph = (
	$Background/ScrollContainer/CenterContainer/VBoxContainer/GridContainer/StudentperSection/VBoxContainer/GraphPanel
)


# --------------------------------------------------
# STUDENT RECORD PANELS
# --------------------------------------------------

@onready var student_quiz_panel: Panel = $StudentQuizList

@onready var student_atomon_panel: Panel = $StudentAtomonList


# --------------------------------------------------
# STUDENT RECORD PANEL LABELS
# --------------------------------------------------

@onready var quiz_section_label: Label = (
	$StudentQuizList/VBoxContainer/Section
)

@onready var atomon_section_label: Label = (
	$StudentAtomonList/VBoxContainer/Section
)


# --------------------------------------------------
# STUDENT RECORD CONTAINERS
# --------------------------------------------------

@onready var quiz_records_container: VBoxContainer = (
	$StudentQuizList/VBoxContainer/ScrollContainer/CenterContainer/VBoxContainer
)

@onready var atomon_records_container: VBoxContainer = (
	$StudentAtomonList/VBoxContainer/ScrollContainer/CenterContainer/VBoxContainer
)


# --------------------------------------------------
# DASHBOARD DATA
# --------------------------------------------------

var assigned_sections: Array[String] = []
var scoped_students: Array[Dictionary] = []


# --------------------------------------------------
# INITIALIZATION
# --------------------------------------------------

func _ready() -> void:
	_setup_graphs()

	student_quiz_panel.hide()
	student_atomon_panel.hide()

	if AuthManager == null:
		push_error("Teacher Dashboard: AuthManager is unavailable.")
		_show_error_state()
		return

	if TeacherDataManager == null:
		push_error("Teacher Dashboard: TeacherDataManager is unavailable.")
		_show_error_state()
		return

	var role: String = str(
		await AuthManager.get_user_role()
	).strip_edges().to_lower()

	if role != "teacher":
		push_error(
			"Teacher Dashboard: This dashboard is only for teacher accounts."
		)
		_show_error_state()
		return

	_connect_data_signals()

	var teacher_sections: Array = (
		await TeacherDataManager.get_current_teacher_sections()
	)

	assigned_sections.clear()

	for item in teacher_sections:
		var section_name: String = str(item).strip_edges()

		if (
			not section_name.is_empty()
			and not assigned_sections.has(section_name)
		):
			assigned_sections.append(section_name)

	assigned_sections.sort()

	print(
		"[Teacher Dashboard] Assigned sections: ",
		assigned_sections
	)

	if assigned_sections.is_empty():
		scoped_students.clear()
		_clear_section_buttons()
		_update_dashboard()
		return

	TeacherDataManager.load_students()


# --------------------------------------------------
# SIGNAL CONNECTIONS
# --------------------------------------------------

func _connect_data_signals() -> void:
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


# --------------------------------------------------
# GRAPH SETUP
# --------------------------------------------------

func _setup_graphs() -> void:
	if section_graph != null:
		section_graph.graph_type = (
			DashboardGraph.GraphType.HORIZONTAL_BAR
		)
	else:
		push_error(
			"Teacher Dashboard: Student per Section graph is missing."
		)


# --------------------------------------------------
# STUDENT DATA
# --------------------------------------------------

func _on_students_loaded(student_list: Array) -> void:
	scoped_students.clear()

	for item in student_list:
		if item is Dictionary:
			scoped_students.append(item)

	print(
		"[Teacher Dashboard] Students loaded: ",
		scoped_students.size()
	)

	_update_dashboard()
	_generate_section_buttons()


func _on_students_error(error: Variant) -> void:
	push_error(
		"Teacher Dashboard: Unable to load students: "
		+ str(error)
	)

	_show_error_state()


# --------------------------------------------------
# UPDATE DASHBOARD
# --------------------------------------------------

func _update_dashboard() -> void:
	_update_stat_cards()
	_update_section_graph()


# --------------------------------------------------
# SUMMARY CARDS
# --------------------------------------------------

func _update_stat_cards() -> void:
	total_students_value.text = str(scoped_students.size())

	sections_value.text = str(assigned_sections.size())

	average_score_value.text = (
		_calculate_average_quiz_score()
	)


func _calculate_average_quiz_score() -> String:
	var total_score: float = 0.0
	var completed_attempts: int = 0

	for student in scoped_students:
		var assessment_value: Variant = student.get(
			"assessment", {}
		)

		if not assessment_value is Dictionary:
			continue

		var assessments: Dictionary = assessment_value

		for quiz_value in assessments.values():
			if not quiz_value is Dictionary:
				continue

			var quiz_result: Dictionary = quiz_value

			if not bool(quiz_result.get("completed", false)):
				continue

			if not quiz_result.has("percentage"):
				continue

			var percentage: float = float(
				quiz_result.get("percentage", -1.0)
			)

			if percentage < 0.0 or percentage > 100.0:
				continue

			total_score += percentage
			completed_attempts += 1

	if completed_attempts == 0:
		return "—"

	return "%.1f%%" % (
		total_score / float(completed_attempts)
	)


# --------------------------------------------------
# STUDENT PER SECTION GRAPH
# --------------------------------------------------

func _update_section_graph() -> void:
	if section_graph == null:
		return

	var section_counts: Dictionary = {}

	for section_name in assigned_sections:
		section_counts[section_name] = 0

	for student in scoped_students:
		for section_name in assigned_sections:
			if _student_belongs_to_section(student, section_name):
				section_counts[section_name] = int(
					section_counts.get(section_name, 0)
				) + 1

	var section_names: Array = section_counts.keys()
	section_names.sort()

	var labels: Array[String] = []
	var values: Array[float] = []

	for section_name in section_names:
		labels.append(str(section_name))
		values.append(float(section_counts[section_name]))

	section_graph.set_graph_data(
		labels,
		values,
		[]
	)


# --------------------------------------------------
# DYNAMIC SECTION BUTTON GENERATION
# --------------------------------------------------

func _generate_section_buttons() -> void:
	if (
		quiz_section_container == null
		or atomon_section_container == null
	):
		push_error(
			"Teacher Dashboard: Section button containers are missing. Check dashboard_t.tscn."
		)
		return

	_clear_section_buttons()

	for section_name in assigned_sections:
		var student_count: int = _get_section_student_count(
			section_name
		)

		# QUIZ ACTIVITY BUTTON

		var quiz_button := SECTION_BUTTON_SCENE.instantiate()

		quiz_button.section_name = section_name
		quiz_button.student_count = student_count
		quiz_button.record_type = "quiz"

		quiz_button.section_selected.connect(
			_on_section_selected
		)

		quiz_section_container.add_child(quiz_button)

		# ATOMON COLLECTION BUTTON

		var atomon_button := SECTION_BUTTON_SCENE.instantiate()

		atomon_button.section_name = section_name
		atomon_button.student_count = student_count
		atomon_button.record_type = "atomon"

		atomon_button.section_selected.connect(
			_on_section_selected
		)

		atomon_section_container.add_child(atomon_button)

	print(
		"[Teacher Dashboard] Generated ",
		assigned_sections.size(),
		" quiz buttons and ",
		assigned_sections.size(),
		" Atomon buttons."
	)


func _clear_section_buttons() -> void:
	if quiz_section_container != null:
		for child in quiz_section_container.get_children():
			child.queue_free()

	if atomon_section_container != null:
		for child in atomon_section_container.get_children():
			child.queue_free()


func _get_section_student_count(section_name: String) -> int:
	var count: int = 0

	for student in scoped_students:
		if _student_belongs_to_section(student, section_name):
			count += 1

	return count


# --------------------------------------------------
# SECTION MATCHING
# --------------------------------------------------

func _student_belongs_to_section(
	student: Dictionary,
	section_name: String
) -> bool:
	var section_value: Variant = student.get("section", "")

	if section_value is Array:
		for item in section_value:
			if str(item).strip_edges() == section_name:
				return true

		return false

	return str(section_value).strip_edges() == section_name


# --------------------------------------------------
# SECTION BUTTON CLICK
# --------------------------------------------------

func _on_section_selected(
	section_name: String,
	record_type: String
) -> void:
	print(
		"[Teacher Dashboard] Selected section: ",
		section_name,
		" | Type: ",
		record_type
	)

	var selected_students: Array[Dictionary] = []

	for student in scoped_students:
		if _student_belongs_to_section(student, section_name):
			selected_students.append(student)

	if record_type == "quiz":
		_show_quiz_records(
			section_name,
			selected_students
		)

	elif record_type == "atomon":
		_show_atomon_records(
			section_name,
			selected_students
		)


# --------------------------------------------------
# STUDENT RECORD PANEL HELPERS
# --------------------------------------------------

func _clear_record_rows(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _get_student_full_name(student: Dictionary) -> String:
	var first_name: String = str(
		student.get("first_name", "")
	).strip_edges()

	var last_name: String = str(
		student.get("last_name", "")
	).strip_edges()

	var full_name: String = (
		first_name + " " + last_name
	).strip_edges()

	if full_name.is_empty():
		full_name = str(
			student.get("name", "Unknown Student")
		)

	return full_name


# --------------------------------------------------
# QUIZ RECORD PANEL
# --------------------------------------------------

func _show_quiz_records(
	section_name: String,
	students: Array[Dictionary]
) -> void:
	student_atomon_panel.hide()
	student_quiz_panel.show()

	quiz_section_label.text = section_name

	_clear_record_rows(quiz_records_container)

	for student in students:
		var row := QUIZ_ROW_SCENE.instantiate()

		quiz_records_container.add_child(row)

		var completed_quizzes: int = 0
		var total_score: float = 0.0
		var score_count: int = 0

		var assessment_value: Variant = student.get(
			"assessment", {}
		)

		if assessment_value is Dictionary:
			var assessments: Dictionary = assessment_value

			for quiz_value in assessments.values():
				if not quiz_value is Dictionary:
					continue

				var result: Dictionary = quiz_value

				if not bool(result.get("completed", false)):
					continue

				completed_quizzes += 1

				if not result.has("percentage"):
					continue

				var percentage: float = float(
					result.get("percentage", -1.0)
				)

				if percentage < 0.0 or percentage > 100.0:
					continue

				total_score += percentage
				score_count += 1

		var average_text: String = "—"

		if score_count > 0:
			average_text = "%.1f%%" % (
				total_score / float(score_count)
			)

		row.get_node(
			"HBoxContainer/Name"
		).text = _get_student_full_name(student)

		row.get_node(
			"HBoxContainer/QuizNumberTaken"
		).text = str(completed_quizzes)

		row.get_node(
			"HBoxContainer/OverallScoreAverage"
		).text = average_text

	if students.is_empty():
		print(
			"[Teacher Dashboard] No students found in section: ",
			section_name
		)


# --------------------------------------------------
# ATOMON RECORD PANEL
# --------------------------------------------------

func _show_atomon_records(
	section_name: String,
	students: Array[Dictionary]
) -> void:
	student_quiz_panel.hide()
	student_atomon_panel.show()

	atomon_section_label.text = section_name

	_clear_record_rows(atomon_records_container)

	var student_number: int = 1

	for student in students:
		var row := ATOMON_ROW_SCENE.instantiate()

		atomon_records_container.add_child(row)

		var collected: int = _get_elements_collected(student)

		row.get_node(
			"HBoxContainer/Number"
		).text = str(student_number)

		row.get_node(
			"HBoxContainer/Name"
		).text = _get_student_full_name(student)

		row.get_node(
			"HBoxContainer/VBoxContainer/HBoxContainer/Progress"
		).text = "%d/%d" % [
			collected,
			ELEMENTS_TOTAL
		]

		var progress_bar: ProgressBar = row.get_node(
			"HBoxContainer/VBoxContainer/ProgressBar"
		)

		progress_bar.max_value = ELEMENTS_TOTAL
		progress_bar.value = collected

		student_number += 1

	if students.is_empty():
		print(
			"[Teacher Dashboard] No students found in section: ",
			section_name
		)


func _get_elements_collected(student: Dictionary) -> int:
	var progress_value: Variant = student.get(
		"progress", {}
	)

	if not progress_value is Dictionary:
		return 0

	var progress: Dictionary = progress_value

	return clampi(
		int(progress.get("elements_collected", 0)),
		0,
		ELEMENTS_TOTAL
	)


# --------------------------------------------------
# ERROR STATE
# --------------------------------------------------

func _show_error_state() -> void:
	if not is_node_ready():
		return

	total_students_value.text = "—"
	sections_value.text = "—"
	average_score_value.text = "—"

	scoped_students.clear()
	_clear_section_buttons()

	if section_graph != null:
		section_graph.set_graph_data([], [], [])


# --------------------------------------------------
# CLOSE BUTTONS
# --------------------------------------------------

func _on_quiz_list_close_button_pressed() -> void:
	student_quiz_panel.hide()


func _on_atomon_list_close_button_pressed() -> void:
	student_atomon_panel.hide()

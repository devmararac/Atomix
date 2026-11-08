
extends Control

const ELEMENTS_TOTAL: int = 118

const COLOR_GREEN: Color = Color("#75A66A")
const COLOR_CORAL: Color = Color("#D98A75")
const COLOR_YELLOW: Color = Color("#E4BD6B")

const SECTION_QUIZ_ROW_SCENE: PackedScene = preload(
	"res://Scenes/Admin/HeadTeacher/quiz_row_ht.tscn"
)

@onready var total_students_value: Label = $Background/ScrollContainer/CenterContainer/VBoxContainer/StatsRow/TotalStudents/CardContents/VBoxContainer/Value
@onready var total_teachers_value: Label = $Background/ScrollContainer/CenterContainer/VBoxContainer/StatsRow/TotalTeachers/CardContents/VBoxContainer/Value
@onready var sections_value: Label = $Background/ScrollContainer/CenterContainer/VBoxContainer/StatsRow/Sections/CardContents/VBoxContainer/Value
@onready var average_score_value: Label = $Background/ScrollContainer/CenterContainer/VBoxContainer/StatsRow/QuizAverage/CardContents/VBoxContainer/Value

@onready var section_graph_panel: Control = $Background/ScrollContainer/CenterContainer/VBoxContainer/GridContainer/StudentperSection/VBoxContainer/GraphPanel/ScrollContainer/CenterContainer/VBoxContainer/SectionGraphContent
@onready var users_graph_panel: Control = $Background/ScrollContainer/CenterContainer/VBoxContainer/GridContainer/TotalUsers/VBoxContainer/GraphPanel

@onready var atomon_progress_panel: Control = $Background/ScrollContainer/CenterContainer/VBoxContainer/CaptureProgress/VBoxContainer/GraphPanel/ScrollContainer/CenterContainer/VBoxContainer/AtomonGraphContent

# This is the VBoxContainer that holds the dynamically generated section rows.
@onready var section_quiz_rows_container: VBoxContainer = $Background/ScrollContainer/CenterContainer/VBoxContainer/QuizCompletion/QuizCompletion2/VBoxContainer/GraphPanel/ScrollContainer/CenterContainer/VBoxContainer

var section_graph: DashboardGraph
var users_graph: DashboardGraph
var atomon_graph: DashboardGraph

var dashboard_role: String = ""
var assigned_sections: Array[String] = []

var scoped_students: Array[Dictionary] = []
var dashboard_sections: Array[Dictionary] = []
var dashboard_quizzes: Array[Dictionary] = []


func _ready() -> void:
	_setup_graphs()

	if AuthManager == null:
		push_error("Dashboard: AuthManager is unavailable.")
		_show_error_state()
		return

	if TeacherDataManager == null:
		push_error("Dashboard: TeacherDataManager is unavailable.")
		_show_error_state()
		return

	await _get_account_scope()

	if dashboard_role.is_empty():
		push_error("Dashboard: Unable to determine account role.")
		_show_error_state()
		return

	_connect_data_signals()

	if dashboard_role == "teacher" and assigned_sections.is_empty():
		scoped_students.clear()
		_update_dashboard(scoped_students)
		return

	TeacherDataManager.load_students()

	if _is_headteacher():
		await TeacherDataManager.load_school_years()

		var year_id: String = TeacherDataManager.get_selected_school_year_id()

		if not year_id.is_empty():
			await TeacherDataManager.load_sections(year_id)
		else:
			sections_value.text = "—"
			dashboard_sections.clear()
			_update_section_graph([])
			_rebuild_section_quiz_rows()

		TeacherDataManager.load_teachers()
		TeacherDataManager.load_users()
		TeacherDataManager.load_quizzes()


# --------------------------------------------------
# ACCOUNT SCOPE
# --------------------------------------------------

func _connect_data_signals() -> void:
	if not TeacherDataManager.students_loaded.is_connected(_on_students_loaded):
		TeacherDataManager.students_loaded.connect(_on_students_loaded)

	if not TeacherDataManager.students_error.is_connected(_on_students_error):
		TeacherDataManager.students_error.connect(_on_students_error)

	if not _is_headteacher():
		return

	if not TeacherDataManager.teachers_loaded.is_connected(_on_teachers_loaded):
		TeacherDataManager.teachers_loaded.connect(_on_teachers_loaded)

	if not TeacherDataManager.teachers_error.is_connected(_on_teachers_error):
		TeacherDataManager.teachers_error.connect(_on_teachers_error)

	if not TeacherDataManager.users_loaded.is_connected(_on_users_loaded):
		TeacherDataManager.users_loaded.connect(_on_users_loaded)

	if not TeacherDataManager.users_error.is_connected(_on_users_error):
		TeacherDataManager.users_error.connect(_on_users_error)

	if not TeacherDataManager.sections_loaded.is_connected(_on_sections_loaded):
		TeacherDataManager.sections_loaded.connect(_on_sections_loaded)

	if not TeacherDataManager.sections_error.is_connected(_on_sections_error):
		TeacherDataManager.sections_error.connect(_on_sections_error)

	if not TeacherDataManager.quizzes_loaded.is_connected(_on_quizzes_loaded):
		TeacherDataManager.quizzes_loaded.connect(_on_quizzes_loaded)

	if not TeacherDataManager.quizzes_error.is_connected(_on_quizzes_error):
		TeacherDataManager.quizzes_error.connect(_on_quizzes_error)


func _get_account_scope() -> void:
	dashboard_role = ""
	assigned_sections.clear()

	dashboard_role = str(await AuthManager.get_user_role()).strip_edges().to_lower()

	if _is_headteacher():
		return

	if dashboard_role == "teacher":
		var teacher_sections: Array = await TeacherDataManager.get_current_teacher_sections()

		for value in teacher_sections:
			var section_name: String = str(value).strip_edges()

			if not section_name.is_empty() and not assigned_sections.has(section_name):
				assigned_sections.append(section_name)

		return

	push_warning("Dashboard: Unrecognized account role.")
	dashboard_role = ""


func _is_headteacher() -> bool:
	return dashboard_role in [
		"admin",
		"headteacher",
		"head_teacher",
		"head teacher"
	]


func _filter_students_by_access(student_list: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if _is_headteacher():
		for item in student_list:
			if item is Dictionary:
				result.append(item)
		return result

	if dashboard_role != "teacher" or assigned_sections.is_empty():
		return result

	for item in student_list:
		if not item is Dictionary:
			continue

		var student: Dictionary = item
		var section_name: String = str(student.get("section", "")).strip_edges()

		if assigned_sections.has(section_name):
			result.append(student)

	return result


# --------------------------------------------------
# GRAPH SETUP
# --------------------------------------------------

func _setup_graphs() -> void:
	section_graph = section_graph_panel as DashboardGraph
	users_graph = users_graph_panel as DashboardGraph
	atomon_graph = atomon_progress_panel as DashboardGraph

	if section_graph != null:
		section_graph.graph_type = DashboardGraph.GraphType.HORIZONTAL_BAR
	else:
		push_error("Dashboard: Students per Section graph is missing.")

	if users_graph != null:
		users_graph.graph_type = DashboardGraph.GraphType.PIE
	else:
		push_error("Dashboard: Total Users graph is missing.")

	if atomon_graph != null:
		atomon_graph.graph_type = DashboardGraph.GraphType.PROGRESS
	else:
		push_error("Dashboard: Atomon Collection graph is missing.")


# --------------------------------------------------
# STUDENTS
# --------------------------------------------------

func _on_students_loaded(student_list: Array) -> void:
	scoped_students = _filter_students_by_access(student_list)
	_update_dashboard(scoped_students)


func _on_students_error(error: Variant) -> void:
	push_error("Dashboard: Unable to load students: " + str(error))
	scoped_students.clear()
	_show_error_state()


func _update_dashboard(student_list: Array[Dictionary]) -> void:
	_update_stat_cards(student_list)
	_update_section_graph(student_list)
	_update_atomon_graph(student_list)

	if _is_headteacher():
		_rebuild_section_quiz_rows()


# --------------------------------------------------
# SECTIONS
# --------------------------------------------------

func _on_sections_loaded(section_list: Array) -> void:
	dashboard_sections.clear()

	for item in section_list:
		if item is Dictionary:
			dashboard_sections.append(item)

	_update_stat_cards(scoped_students)
	_update_section_graph(scoped_students)
	_update_atomon_graph(scoped_students)
	_rebuild_section_quiz_rows()


func _on_sections_error(error: Variant) -> void:
	push_error("Dashboard: Unable to load sections: " + str(error))

	dashboard_sections.clear()
	sections_value.text = "—"

	if section_graph != null:
		section_graph.set_graph_data([], [], [])

	_rebuild_section_quiz_rows()

	if atomon_graph != null:
		atomon_graph.set_graph_data([], [], [])


# --------------------------------------------------
# SUMMARY CARDS
# --------------------------------------------------

func _update_stat_cards(student_list: Array[Dictionary]) -> void:
	total_students_value.text = str(student_list.size())

	if _is_headteacher():
		sections_value.text = str(dashboard_sections.size())
	else:
		var unique_sections: Dictionary = {}

		for student in student_list:
			var section_name: String = str(student.get("section", "")).strip_edges()

			if not section_name.is_empty():
				unique_sections[section_name] = true

		sections_value.text = str(unique_sections.size())

	average_score_value.text = _calculate_average_quiz_score(student_list)


func _calculate_average_quiz_score(student_list: Array[Dictionary]) -> String:
	var total_percentage: float = 0.0
	var completed_attempts: int = 0

	for student in student_list:
		var assessment_value: Variant = student.get("assessment", {})

		if not assessment_value is Dictionary:
			continue

		var assessments: Dictionary = assessment_value

		for quiz_value in assessments.values():
			if not quiz_value is Dictionary:
				continue

			var quiz_result: Dictionary = quiz_value

			if not bool(quiz_result.get("completed", false)):
				continue

			var percentage: float = _get_quiz_percentage(quiz_result)

			if percentage < 0.0:
				continue

			total_percentage += percentage
			completed_attempts += 1

	if completed_attempts == 0:
		return "—"

	return "%.1f%%" % (total_percentage / float(completed_attempts))


# --------------------------------------------------
# STUDENTS PER SECTION
# --------------------------------------------------

func _update_section_graph(student_list: Array[Dictionary]) -> void:
	if section_graph == null:
		return

	var counts: Dictionary = {}

	if _is_headteacher():
		for section_data in dashboard_sections:
			var section_id: String = str(section_data.get("uid", "")).strip_edges()
			var section_name: String = str(section_data.get("name", "")).strip_edges()

			if section_name.is_empty():
				section_name = section_id

			if not section_name.is_empty() and not counts.has(section_name):
				counts[section_name] = 0

		for student in student_list:
			var student_section_id: String = str(student.get("section_id", "")).strip_edges()
			var student_section_name: String = str(student.get("section", "")).strip_edges()

			for section_data in dashboard_sections:
				var actual_id: String = str(section_data.get("uid", "")).strip_edges()
				var actual_name: String = str(section_data.get("name", "")).strip_edges()

				if actual_name.is_empty():
					actual_name = actual_id

				var matches_id: bool = (
					not student_section_id.is_empty()
					and student_section_id == actual_id
				)

				var matches_name: bool = (
					not student_section_name.is_empty()
					and student_section_name == actual_name
				)

				if matches_id or matches_name:
					if not actual_name.is_empty():
						counts[actual_name] = int(counts.get(actual_name, 0)) + 1
					break
	else:
		for student in student_list:
			var section_name: String = str(student.get("section", "")).strip_edges()

			if not section_name.is_empty():
				counts[section_name] = int(counts.get(section_name, 0)) + 1

	var labels: Array[String] = []
	var values: Array[float] = []

	var section_names: Array = counts.keys()
	section_names.sort()

	for section_name in section_names:
		labels.append(str(section_name))
		values.append(float(counts[section_name]))

	section_graph.set_graph_data(labels, values, [])


# --------------------------------------------------
# TOTAL USERS
# --------------------------------------------------

func _on_users_loaded(user_list: Array) -> void:
	if users_graph == null:
		return

	var admin_count: int = 0
	var teacher_count: int = 0
	var student_count: int = 0

	for item in user_list:
		if not item is Dictionary:
			continue

		var role: String = str(item.get("role", "")).strip_edges().to_lower()

		match role:
			"admin", "headteacher", "head_teacher", "head teacher":
				admin_count += 1
			"teacher":
				teacher_count += 1
			"student":
				student_count += 1

	users_graph.set_graph_data(
		["Admin", "Teacher", "Student"],
		[float(admin_count), float(teacher_count), float(student_count)],
		[COLOR_CORAL, COLOR_YELLOW, COLOR_GREEN]
	)


func _on_users_error(error: Variant) -> void:
	push_error("Dashboard: Unable to load user accounts: " + str(error))

	if users_graph != null:
		users_graph.set_graph_data([], [], [])


# --------------------------------------------------
# SECTION NAME RESOLUTION
# --------------------------------------------------
func _get_dashboard_section_name(student: Dictionary) -> String:
	var student_section_id: String = str(
		student.get("section_id", "")
	).strip_edges()

	var student_section_name: String = str(
		student.get("section", "")
	).strip_edges()

	# Match the student's section ID or section name
	# against the loaded section records.
	for section_data in dashboard_sections:
		var actual_id: String = str(
			section_data.get("uid", "")
		).strip_edges()

		var actual_name: String = str(
			section_data.get("name", "")
		).strip_edges()

		if actual_name.is_empty():
			actual_name = actual_id

		if not student_section_id.is_empty() and student_section_id == actual_id:
			return actual_name

		if not student_section_name.is_empty():
			if student_section_name == actual_name or student_section_name == actual_id:
				return actual_name

	# Fallback: use the section value stored in the student record.
	return student_section_name


# --------------------------------------------------
# QUIZ DATA
# --------------------------------------------------

func _on_quizzes_loaded(quiz_list: Array) -> void:
	dashboard_quizzes.clear()

	for item in quiz_list:
		if item is Dictionary:
			dashboard_quizzes.append(item)

	print("[Dashboard] Quizzes received: ", dashboard_quizzes.size())

	_rebuild_section_quiz_rows()


func _on_quizzes_error(error: Variant) -> void:
	push_error("Dashboard: Unable to load quizzes: " + str(error))

	dashboard_quizzes.clear()
	_rebuild_section_quiz_rows()


# --------------------------------------------------
# SECTION QUIZ ROWS
# --------------------------------------------------

func _clear_section_quiz_rows() -> void:
	if section_quiz_rows_container == null:
		return

	for child in section_quiz_rows_container.get_children():
		section_quiz_rows_container.remove_child(child)
		child.queue_free()


func _rebuild_section_quiz_rows() -> void:
	if not _is_headteacher():
		return

	if section_quiz_rows_container == null:
		push_error("Dashboard: Section quiz rows container is missing.")
		return

	_clear_section_quiz_rows()

	if dashboard_sections.is_empty():
		return

	var sorted_sections: Array[Dictionary] = dashboard_sections.duplicate()
	sorted_sections.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
	)

	for section_data in sorted_sections:
		var section_id: String = str(section_data.get("uid", "")).strip_edges()
		var section_name: String = str(section_data.get("name", "")).strip_edges()

		if section_name.is_empty():
			section_name = section_id

		if section_name.is_empty():
			continue

		var row: Control = SECTION_QUIZ_ROW_SCENE.instantiate() as Control

		if row == null:
			push_error("Dashboard: Unable to instantiate section quiz row.")
			continue

		section_quiz_rows_container.add_child(row)

		_setup_section_quiz_row(
			row,
			section_id,
			section_name
		)


func _setup_section_quiz_row(
	row: Control,
	section_id: String,
	section_name: String
) -> void:
	var title_label := row.get_node_or_null("VBoxContainer/Label") as Label

	var average_graph_node := row.get_node_or_null(
		"VBoxContainer/Panel/HBoxContainer/VBoxContainer/BarGraph"
	)

	var participation_graph_node := row.get_node_or_null(
		"VBoxContainer/Panel/HBoxContainer/VBoxContainer2/PieGraph"
	)

	if title_label != null:
		title_label.text = section_name

	if average_graph_node == null or participation_graph_node == null:
		push_error(
			"Dashboard: Section row graph nodes are missing for " + section_name
		)
		return

	var average_graph := average_graph_node as DashboardGraph
	var participation_graph := participation_graph_node as DashboardGraph

	if average_graph == null or participation_graph == null:
		push_error(
			"Dashboard: Section row graphs need the DashboardGraph script: "
			+ section_name
		)
		return

	average_graph.graph_type = DashboardGraph.GraphType.BAR
	participation_graph.graph_type = DashboardGraph.GraphType.PIE

	var section_students: Array[Dictionary] = _get_students_for_section(
		section_id,
		section_name
	)

	var section_quizzes: Array[Dictionary] = _get_quizzes_for_section(
		section_id,
		section_name
	)

	var expected_assignments: int = (
		section_students.size() * section_quizzes.size()
	)

	var completed_assignments: int = 0
	var total_percentage: float = 0.0
	var scored_submissions: int = 0

	for student in section_students:
		var assessment_value: Variant = student.get("assessment", {})

		if not assessment_value is Dictionary:
			continue

		var assessments: Dictionary = assessment_value

		for quiz in section_quizzes:
			var quiz_id: String = str(quiz.get("quiz_id", "")).strip_edges()

			if quiz_id.is_empty():
				continue

			var result_value: Variant = assessments.get(quiz_id, {})

			if not result_value is Dictionary:
				continue

			var result: Dictionary = result_value

			if not bool(result.get("completed", false)):
				continue

			var percentage: float = _get_quiz_percentage(result)

			if percentage < 0.0:
				continue

			completed_assignments += 1
			total_percentage += percentage
			scored_submissions += 1

	# Prevent the completed count from exceeding the expected count.
	completed_assignments = mini(
		completed_assignments,
		expected_assignments
	)

	var incomplete_assignments: int = maxi(
		0,
		expected_assignments - completed_assignments
	)

	# Average score graph.
	if scored_submissions > 0:
		var average_score: float = (
			total_percentage / float(scored_submissions)
		)

		var average_labels: Array[String] = ["Average"]
		var average_values: Array[float] = [average_score]
		var average_colors: Array[Color] = [COLOR_GREEN]

		average_graph.set_graph_data(
			average_labels,
			average_values,
			average_colors
		)
	else:
		average_graph.set_graph_data([], [], [])

	# Participation graph.
	if expected_assignments > 0:
		var participation_labels: Array[String] = [
			"Completed",
			"Incomplete"
		]

		var participation_values: Array[float] = [
			float(completed_assignments),
			float(incomplete_assignments)
		]

		var participation_colors: Array[Color] = [
			COLOR_GREEN,
			COLOR_CORAL
		]

		participation_graph.set_graph_data(
			participation_labels,
			participation_values,
			participation_colors
		)
	else:
		participation_graph.set_graph_data([], [], [])

	print(
		"[Dashboard] Section: ", section_name,
		" | Students: ", section_students.size(),
		" | Quizzes: ", section_quizzes.size(),
		" | Expected: ", expected_assignments,
		" | Completed: ", completed_assignments,
		" | Incomplete: ", incomplete_assignments,
		" | Scored: ", scored_submissions
	)


# --------------------------------------------------
# STUDENTS ASSIGNED TO A SECTION
# --------------------------------------------------

func _get_students_for_section(
	section_id: String,
	section_name: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for student in scoped_students:
		var student_section_id: String = str(
			student.get("section_id", "")
		).strip_edges()

		var resolved_section_name: String = _get_dashboard_section_name(
			student
		)

		var matches_id: bool = (
			not section_id.is_empty()
			and student_section_id == section_id
		)

		var matches_name: bool = (
			not section_name.is_empty()
			and resolved_section_name == section_name
		)

		if matches_id or matches_name:
			result.append(student)

	return result


# --------------------------------------------------
# QUIZZES ASSIGNED TO A SECTION
# --------------------------------------------------

func _get_quizzes_for_section(
	section_id: String,
	section_name: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for quiz in dashboard_quizzes:
		var quiz_section: String = str(
			quiz.get("section", "")
		).strip_edges()

		var matches_name: bool = (
			not section_name.is_empty()
			and quiz_section == section_name
		)

		var matches_id: bool = (
			not section_id.is_empty()
			and quiz_section == section_id
		)

		if matches_name or matches_id:
			result.append(quiz)

	return result


# --------------------------------------------------
# QUIZ SCORE EXTRACTION
# --------------------------------------------------

func _get_quiz_percentage(result: Dictionary) -> float:
	if result.has("percentage"):
		var percentage: float = float(result.get("percentage", -1.0))

		if percentage >= 0.0 and percentage <= 100.0:
			return percentage

		return -1.0

	# Fallback for older results that store score and total_questions.
	if result.has("score") and result.has("total_questions"):
		var score: float = float(result.get("score", 0))
		var total_questions: float = float(
			result.get("total_questions", 0)
		)

		if total_questions <= 0.0:
			return -1.0

		var percentage: float = (
			score / total_questions
		) * 100.0

		if percentage >= 0.0 and percentage <= 100.0:
			return percentage

	return -1.0


# --------------------------------------------------
# ATOMON COLLECTION PROGRESS
# --------------------------------------------------
func _update_atomon_graph(student_list: Array[Dictionary]) -> void:
	if atomon_graph == null:
		return

	var section_totals: Dictionary = {}
	var section_student_counts: Dictionary = {}

	# Initialize sections so they can appear even when
	# no students have collected any Atomons.
	if _is_headteacher():
		for section_data in dashboard_sections:
			var section_name: String = str(
				section_data.get("name", "")
			).strip_edges()

			if section_name.is_empty():
				section_name = str(
					section_data.get("uid", "")
				).strip_edges()

			if not section_name.is_empty():
				section_totals[section_name] = 0
				section_student_counts[section_name] = 0

	# Collect each student's progress.
	for student in student_list:
		var section_name: String = _get_dashboard_section_name(student)

		if section_name.is_empty():
			continue

		if not section_totals.has(section_name):
			section_totals[section_name] = 0
			section_student_counts[section_name] = 0

		var collected: int = _get_elements_collected(student)

		section_totals[section_name] += collected
		section_student_counts[section_name] += 1

	# Calculate the average for each section.
	var labels: Array[String] = []
	var values: Array[float] = []

	var section_names: Array = section_totals.keys()
	section_names.sort()

	for section_name in section_names:
		var student_count: int = int(
			section_student_counts[section_name]
		)

		var average_collected: float = 0.0

		if student_count > 0:
			average_collected = (
				float(section_totals[section_name])
				/ float(student_count)
			)

		labels.append(str(section_name))
		values.append(average_collected)

		print(
			"[Atomon Graph] Section: ", section_name,
			" | Students: ", student_count,
			" | Total collected: ", section_totals[section_name],
			" | Average: ", average_collected,
			" / ", ELEMENTS_TOTAL
		)

	atomon_graph.set_graph_data(labels, values, [])


func _get_elements_collected(data: Dictionary) -> int:
	var progress_value: Variant = data.get("progress", {})

	if not progress_value is Dictionary:
		return 0

	var progress: Dictionary = progress_value

	return clampi(
		int(progress.get("elements_collected", 0)),
		0,
		ELEMENTS_TOTAL
	)


# --------------------------------------------------
# TEACHER COUNT
# --------------------------------------------------

func _on_teachers_loaded(teacher_list: Array) -> void:
	total_teachers_value.text = str(teacher_list.size())


func _on_teachers_error(error: Variant) -> void:
	push_error("Dashboard: Unable to load teachers: " + str(error))
	total_teachers_value.text = "—"


# --------------------------------------------------
# ERROR STATE
# --------------------------------------------------

func _show_error_state() -> void:
	total_students_value.text = "—"
	total_teachers_value.text = "—"
	sections_value.text = "—"
	average_score_value.text = "—"

	if section_graph != null:
		section_graph.set_graph_data([], [], [])

	if users_graph != null:
		users_graph.set_graph_data([], [], [])

	if atomon_graph != null:
		atomon_graph.set_graph_data([], [], [])

	_clear_section_quiz_rows()

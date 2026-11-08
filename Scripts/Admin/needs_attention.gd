
extends Panel

const STUDENT_ROW_SCENE: PackedScene = preload(
	"res://Scenes/Admin/HeadTeacher/student_row_ht.tscn"
)

const QUIZ_SCORE_THRESHOLD: float = 75.0
const ATOMON_PROGRESS_THRESHOLD: float = 50.0
const TOTAL_ATOMONS: int = 118

@onready var search_input: LineEdit = get_node(
	"PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SearchPanel/SearchInput"
)

@onready var filter_button: OptionButton = get_node(
	"PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/FilterButton"
)

@onready var rows_container: VBoxContainer = get_node(
	"PageBackground/MarginContainer/VBoxContainer/StudentTable/ScrollContainer/Rows"
)

@onready var empty_state: Control = get_node(
	"PageBackground/MarginContainer/VBoxContainer/StudentTable/EmptyState"
)

var all_students: Array[Dictionary] = []
var search_text: String = ""
var selected_filter: int = 0


func _ready() -> void:
	search_input.text_changed.connect(_on_search_changed)
	filter_button.item_selected.connect(_on_filter_changed)

	_setup_filters()

	if not TeacherDataManager.students_loaded.is_connected(_on_students_loaded):
		TeacherDataManager.students_loaded.connect(_on_students_loaded)

	if not TeacherDataManager.students_error.is_connected(_on_students_error):
		TeacherDataManager.students_error.connect(_on_students_error)

	load_students()


func _setup_filters() -> void:
	filter_button.clear()
	filter_button.add_item("All Needs Attention", 0)
	filter_button.add_item("Low Quiz Score", 1)
	filter_button.add_item("Low Atomon Progress", 2)
	filter_button.select(0)


func load_students() -> void:
	clear_rows()
	empty_state.visible = false

	# Reuse the existing shared data manager.
	TeacherDataManager.load_students()


func _on_students_loaded(students: Array) -> void:
	all_students.clear()

	for student in students:
		if student is Dictionary:
			all_students.append(student)

	display_students()


func _on_students_error(error: Variant) -> void:
	push_error("[NeedsAttention] Failed to load students: " + str(error))
	clear_rows()
	empty_state.visible = true


func _on_search_changed(new_text: String) -> void:
	search_text = new_text.strip_edges().to_lower()
	display_students()


func _on_filter_changed(index: int) -> void:
	selected_filter = index
	display_students()


func display_students() -> void:
	clear_rows()

	var displayed_count: int = 0

	for student in all_students:
		if not needs_attention(student):
			continue

		if not matches_selected_filter(student):
			continue

		if not matches_search(student):
			continue

		var row: Node = STUDENT_ROW_SCENE.instantiate()
		rows_container.add_child(row)

		# The existing row script should provide setup(data, number).
		if row.has_method("setup"):
			displayed_count += 1
			row.call("setup", student, displayed_count)

			if row.has_signal("student_clicked"):
				var callback := _on_student_clicked
				if not row.is_connected("student_clicked", callback):
					row.connect("student_clicked", callback)
		else:
			push_error(
				"[NeedsAttention] Student row has no setup() method."
			)
			row.queue_free()

	empty_state.visible = displayed_count == 0


func needs_attention(student: Dictionary) -> bool:
	var quiz_average: float = get_quiz_average(student)
	var atomon_progress: float = get_atomon_progress_percent(student)

	var low_quiz: bool = (
		quiz_average >= 0.0
		and quiz_average < QUIZ_SCORE_THRESHOLD
	)

	var low_atomon: bool = (
		atomon_progress >= 0.0
		and atomon_progress < ATOMON_PROGRESS_THRESHOLD
	)

	return low_quiz or low_atomon


func matches_selected_filter(student: Dictionary) -> bool:
	var quiz_average: float = get_quiz_average(student)
	var atomon_progress: float = get_atomon_progress_percent(student)

	match selected_filter:
		1:
			return (
				quiz_average >= 0.0
				and quiz_average < QUIZ_SCORE_THRESHOLD
			)
		2:
			return (
				atomon_progress >= 0.0
				and atomon_progress < ATOMON_PROGRESS_THRESHOLD
			)
		_:
			return needs_attention(student)


func get_quiz_average(student: Dictionary) -> float:
	var assessment: Variant = student.get("assessment", {})

	if not assessment is Dictionary:
		return -1.0

	var total_percentage: float = 0.0
	var completed_quizzes: int = 0

	for quiz_id in assessment.keys():
		var quiz_value: Variant = assessment[quiz_id]

		if not quiz_value is Dictionary:
			continue

		var quiz: Dictionary = quiz_value

		if not bool(quiz.get("completed", false)):
			continue

		if quiz.has("percentage"):
			total_percentage += float(quiz["percentage"])
			completed_quizzes += 1
			continue

		var score: float = float(quiz.get("score", 0))
		var total_questions: float = float(
			quiz.get("total_questions", 0)
		)

		if total_questions <= 0.0:
			continue

		total_percentage += (score / total_questions) * 100.0
		completed_quizzes += 1

	if completed_quizzes == 0:
		return -1.0

	return total_percentage / float(completed_quizzes)


func get_atomon_progress_percent(student: Dictionary) -> float:
	var progress_value: Variant = student.get("progress", {})

	if not progress_value is Dictionary:
		return -1.0

	var progress: Dictionary = progress_value

	# These field names must match the fields actually saved in Firestore.
	if not progress.has("elements_collected"):
		return -1.0

	var collected: float = float(progress.get("elements_collected", 0))
	var total: float = float(
		progress.get("elements_total", TOTAL_ATOMONS)
	)

	if total <= 0.0:
		return -1.0

	return clampf((collected / total) * 100.0, 0.0, 100.0)


func matches_search(student: Dictionary) -> bool:
	if search_text.is_empty():
		return true

	var searchable_text: String = " ".join([
		str(student.get("name", "")),
		str(student.get("first_name", "")),
		str(student.get("last_name", "")),
		str(student.get("student_id", "")),
		str(student.get("lrn", "")),
		str(student.get("section", ""))
	]).to_lower()

	return searchable_text.contains(search_text)


func clear_rows() -> void:
	for child in rows_container.get_children():
		rows_container.remove_child(child)
		child.queue_free()


func _on_student_clicked(student_data: Dictionary) -> void:
	print(
		"[NeedsAttention] Selected student: ",
		student_data.get("name", "Unknown")
	)

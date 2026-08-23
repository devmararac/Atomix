extends Control

@onready var rows: VBoxContainer = $PageBackground/MarginContainer/VBoxContainer/TablePanel/MarginContainer/VBoxContainer/ScrollContainer/Rows
@onready var empty_state: Panel = $PageBackground/MarginContainer/VBoxContainer/TablePanel/MarginContainer/VBoxContainer/EmptyState

@onready var add_student_button: Button = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/AddStudentButton
@onready var refresh_button: Button = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/RefreshButton
@onready var search_input: LineEdit = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SearchPanel/SearchInput
@onready var filter_button: OptionButton = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/FilterButton
@onready var sort_button: OptionButton = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SortButton

# ADD STUDENT PANEL
@onready var add_student_panel: Control = $AddStudent

const STUDENT_ROW = preload("res://Scenes/Admin/student_row.tscn")


func _ready() -> void:

	# --------------------------------------------------------
	# BUTTON CONNECTIONS
	# --------------------------------------------------------

	refresh_button.pressed.connect(_on_refresh_pressed)
	add_student_button.pressed.connect(_on_add_student_pressed)

	search_input.text_changed.connect(_on_search_changed)
	filter_button.item_selected.connect(_on_filter_changed)
	sort_button.item_selected.connect(_on_sort_changed)

	# --------------------------------------------------------
	# TEACHER DATA MANAGER
	# --------------------------------------------------------

	TeacherDataManager.students_loaded.connect(_on_students_loaded)
	TeacherDataManager.students_error.connect(_on_students_error)

	# --------------------------------------------------------
	# ADD STUDENT PANEL
	# --------------------------------------------------------

	# Make sure the Add Student panel is hidden when
	# the Students page first opens.
	add_student_panel.hide()

	# Listen for successful student creation.
	if add_student_panel.has_signal("student_created"):
		add_student_panel.student_created.connect(_on_student_created)

	# --------------------------------------------------------
	# INITIAL STATE
	# --------------------------------------------------------

	empty_state.show()

	load_students()


# ============================================================
# BUTTONS
# ============================================================

func _on_refresh_pressed() -> void:
	load_students()


func _on_add_student_pressed() -> void:
	print("[Students] Opening Add Student panel.")

	add_student_panel.show()

	# Optional: bring panel to the front.
	add_student_panel.move_to_front()


# ============================================================
# ADD STUDENT
# ============================================================

func _on_student_created() -> void:

	print("[Students] Student created. Refreshing student list.")

	# Hide the Add Student panel.
	add_student_panel.hide()

	# Reload students from Firebase.
	load_students()


# ============================================================
# SEARCH / FILTER / SORT
# ============================================================

func _on_search_changed(_text: String) -> void:
	display_students()


func _on_filter_changed(_index: int) -> void:
	display_students()


func _on_sort_changed(_index: int) -> void:
	display_students()


# ============================================================
# ROW MANAGEMENT
# ============================================================

func clear_rows() -> void:
	for child in rows.get_children():
		child.queue_free()


# ============================================================
# LOAD STUDENTS
# ============================================================

func load_students() -> void:

	print("[Students] Requesting student data...")

	clear_rows()
	empty_state.show()

	TeacherDataManager.load_students()


func _on_students_loaded(student_list: Array) -> void:

	print("[Students] Received ", student_list.size(), " students.")

	display_students()


func _on_students_error(error) -> void:

	print("[Students] Firebase error: ", error)

	clear_rows()
	empty_state.show()


# ============================================================
# DISPLAY STUDENTS
# ============================================================

func display_students() -> void:

	clear_rows()

	var all_students: Array[Dictionary] = TeacherDataManager.get_students()
	var filtered_students: Array[Dictionary] = []

	var search_text: String = search_input.text.strip_edges().to_lower()


	# --------------------------------------------------------
	# SEARCH
	# --------------------------------------------------------

	for student_data in all_students:

		var student_name: String = str(
			student_data.get("name", "")
		).to_lower()

		var email: String = str(
			student_data.get("email", "")
		).to_lower()

		if search_text.is_empty():

			filtered_students.append(student_data)
			continue

		if (
			student_name.contains(search_text)
			or email.contains(search_text)
		):

			filtered_students.append(student_data)


	# --------------------------------------------------------
	# FILTER
	# --------------------------------------------------------

	var filter_index: int = filter_button.selected

	if filter_index == 1:

		filtered_students = get_active_students(
			filtered_students
		)

	elif filter_index == 2:

		filtered_students = get_inactive_students(
			filtered_students
		)


	# --------------------------------------------------------
	# SORT
	# --------------------------------------------------------

	var sort_index: int = sort_button.selected

	if sort_index == 0:

		# Name A-Z
		filtered_students.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:

				return str(
					a.get("name", "")
				).to_lower() < str(
					b.get("name", "")
				).to_lower()
		)

	elif sort_index == 1:

		# Progress highest first
		filtered_students.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:

				return get_student_progress(a) > get_student_progress(b)
		)

	elif sort_index == 2:

		# Elements collected highest first
		filtered_students.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:

				return get_elements_collected(a) > get_elements_collected(b)
		)


	# --------------------------------------------------------
	# EMPTY STATE
	# --------------------------------------------------------

	if filtered_students.is_empty():

		empty_state.show()
		return

	empty_state.hide()


	# --------------------------------------------------------
	# CREATE ROWS
	# --------------------------------------------------------

	var number: int = 1

	for student_data in filtered_students:

		var row: Control = STUDENT_ROW.instantiate()

		rows.add_child(row)

		setup_student_row(
			row,
			student_data,
			number
		)

		number += 1


# ============================================================
# PROGRESS
# ============================================================

func get_elements_collected(data: Dictionary) -> int:

	var progress_value = data.get(
		"progress",
		{}
	)

	if not progress_value is Dictionary:
		return 0

	var progress: Dictionary = progress_value

	return clamp(
		int(
			progress.get(
				"elements_collected",
				0
			)
		),
		0,
		118
	)


func get_elements_total(data: Dictionary) -> int:

	var progress_value = data.get(
		"progress",
		{}
	)

	if not progress_value is Dictionary:
		return 118

	var progress: Dictionary = progress_value

	var total := int(
		progress.get(
			"elements_total",
			118
		)
	)

	if total <= 0:
		return 118

	return total


func get_student_progress(data: Dictionary) -> float:

	var collected: int = get_elements_collected(data)
	var total: int = get_elements_total(data)

	if total <= 0:
		return 0.0

	return clamp(
		float(collected) / float(total) * 100.0,
		0.0,
		100.0
	)


# ============================================================
# ACTIVITY FILTER
# ============================================================

func get_active_students(
	student_list: Array[Dictionary]
) -> Array[Dictionary]:

	var result: Array[Dictionary] = []

	# Activity tracking can be implemented later.
	for student_data in student_list:
		result.append(student_data)

	return result


func get_inactive_students(
	student_list: Array[Dictionary]
) -> Array[Dictionary]:

	# Activity tracking is not implemented yet.
	var result: Array[Dictionary] = []

	return result


# ============================================================
# STUDENT ROW
# ============================================================

func setup_student_row(
	row: Control,
	data: Dictionary,
	number: int
) -> void:

	var number_label: Label = row.get_node(
		"MarginContainer/Columns/Control/Number"
	)

	var name_label: Label = row.get_node(
		"MarginContainer/Columns/Control/StudentInfo/Control/Name"
	)

	var email_label: Label = row.get_node(
		"MarginContainer/Columns/Control/StudentInfo/Control/Email"
	)

	var rank_label: Label = row.get_node(
		"MarginContainer/Columns/Control/Rank"
	)

	var elements_label: Label = row.get_node(
		"MarginContainer/Columns/Control/Elements"
	)

	var progress_bar: ProgressBar = row.get_node(
		"MarginContainer/Columns/Control/ProgressContainer/ProgressBar"
	)

	var progress_text: Label = row.get_node(
		"MarginContainer/Columns/Control/ProgressContainer/ProgressText"
	)

	var status_label: Label = row.get_node(
		"MarginContainer/Columns/Control/Status"
	)

	var last_active_label: Label = row.get_node(
		"MarginContainer/Columns/Control/LastActive"
	)


	# --------------------------------------------------------
	# BASIC INFORMATION
	# --------------------------------------------------------

	var student_name: String = str(
		data.get(
			"name",
			"Unknown Student"
		)
	)

	var email: String = str(
		data.get(
			"email",
			"No email"
		)
	)


	# --------------------------------------------------------
	# NUMBER
	# --------------------------------------------------------

	number_label.text = "%02d" % number


	# --------------------------------------------------------
	# NAME / EMAIL
	# --------------------------------------------------------

	name_label.text = student_name
	email_label.text = email


	# --------------------------------------------------------
	# RANK
	# --------------------------------------------------------

	var rank: String = str(
		data.get(
			"rank",
			"-"
		)
	)

	rank_label.text = rank


	# --------------------------------------------------------
	# ELEMENT PROGRESS
	# --------------------------------------------------------

	var collected: int = get_elements_collected(data)
	var total: int = get_elements_total(data)

	var progress_percent: float = get_student_progress(data)

	elements_label.text = "%d / %d" % [
		collected,
		total
	]


	# --------------------------------------------------------
	# PROGRESS BAR
	# --------------------------------------------------------

	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = progress_percent

	progress_text.text = "%d%%" % int(
		round(progress_percent)
	)


	# --------------------------------------------------------
	# STATUS
	# --------------------------------------------------------

	status_label.text = "Active"

	last_active_label.text = "Recently"


func _on_texture_button_pressed() -> void:
	hide()

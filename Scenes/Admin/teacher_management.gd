
extends Control

# ============================================================
# TEACHER MANAGEMENT
# ============================================================

const TEACHER_ROW_SCENE: PackedScene = preload(
	"res://Scenes/Admin/teacher_row.tscn"
)


# ============================================================
# UI REFERENCES
# ============================================================

@onready var rows: VBoxContainer = $PageBackground/MarginContainer/VBoxContainer/TablePanel/MarginContainer/VBoxContainer/ScrollContainer/Rows

@onready var empty_state: Panel = $PageBackground/MarginContainer/VBoxContainer/TablePanel/MarginContainer/VBoxContainer/EmptyState

@onready var search_input: LineEdit = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SearchPanel/SearchInput

@onready var filter_button: OptionButton = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/FilterButton

@onready var sort_button: OptionButton = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SortButton

@onready var refresh_button: Button = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/RefreshButton

@onready var add_teacher_button: Button = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/AddTeacherButton

@onready var add_teacher: Control = $AddTeacher


# ============================================================
# DATA
# ============================================================

var all_teachers: Array[Dictionary] = []


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[TeacherManagement] Teacher Management opened.")

	# --------------------------------------------------------
	# Hide Add Teacher panel initially
	# --------------------------------------------------------

	if add_teacher != null:
		add_teacher.hide()


	# --------------------------------------------------------
	# Refresh
	# --------------------------------------------------------

	if not refresh_button.pressed.is_connected(
		_on_refresh_pressed
	):
		refresh_button.pressed.connect(
			_on_refresh_pressed
		)


	# --------------------------------------------------------
	# Add Teacher
	# --------------------------------------------------------

	if not add_teacher_button.pressed.is_connected(
		_on_add_teacher_pressed
	):
		add_teacher_button.pressed.connect(
			_on_add_teacher_pressed
		)


	# --------------------------------------------------------
	# Search
	# --------------------------------------------------------

	if not search_input.text_changed.is_connected(
		_on_search_changed
	):
		search_input.text_changed.connect(
			_on_search_changed
		)


	# --------------------------------------------------------
	# Filter
	# --------------------------------------------------------

	if not filter_button.item_selected.is_connected(
		_on_filter_changed
	):
		filter_button.item_selected.connect(
			_on_filter_changed
		)


	# --------------------------------------------------------
	# Sort
	# --------------------------------------------------------

	if not sort_button.item_selected.is_connected(
		_on_sort_changed
	):
		sort_button.item_selected.connect(
			_on_sort_changed
		)


	# --------------------------------------------------------
	# Teacher Data Manager
	# --------------------------------------------------------

	if not TeacherDataManager.teachers_loaded.is_connected(
		_on_teachers_loaded
	):
		TeacherDataManager.teachers_loaded.connect(
			_on_teachers_loaded
	)


	if not TeacherDataManager.teachers_error.is_connected(
		_on_teachers_error
	):
		TeacherDataManager.teachers_error.connect(
			_on_teachers_error
	)


	# --------------------------------------------------------
	# Add Teacher signal
	# --------------------------------------------------------

	if add_teacher != null:

		if add_teacher.has_signal("teacher_created"):

			if not add_teacher.teacher_created.is_connected(
				_on_teacher_created
			):
				add_teacher.teacher_created.connect(
					_on_teacher_created
				)


	# --------------------------------------------------------
	# Initial state
	# --------------------------------------------------------

	empty_state.show()

	load_teachers()


# ============================================================
# LOAD TEACHERS
# ============================================================

func load_teachers() -> void:

	print("[TeacherManagement] Requesting teacher data...")

	# Clear current rows.
	clear_rows()

	# Show empty state while loading.
	empty_state.show()

	# Ask TeacherDataManager to load teachers.
	TeacherDataManager.load_teachers()


# ============================================================
# TEACHERS LOADED
# ============================================================

func _on_teachers_loaded(
	teacher_list: Array
) -> void:

	print(
		"[TeacherManagement] Received ",
		teacher_list.size(),
		" teachers."
	)


	all_teachers.clear()


	# --------------------------------------------------------
	# Convert received data into Array[Dictionary]
	# --------------------------------------------------------

	for teacher in teacher_list:

		if teacher is Dictionary:

			all_teachers.append(
				teacher
			)


	print(
		"[TeacherManagement] Internal teacher list: ",
		all_teachers.size()
	)


	# --------------------------------------------------------
	# Display
	# --------------------------------------------------------

	display_teachers()


# ============================================================
# TEACHER LOAD ERROR
# ============================================================

func _on_teachers_error(
	error
) -> void:

	print(
		"[TeacherManagement] Firebase error: ",
		error
	)

	all_teachers.clear()

	clear_rows()

	empty_state.show()


# ============================================================
# DISPLAY TEACHERS
# ============================================================

func display_teachers() -> void:

	print(
		"[TeacherManagement] Displaying teachers..."
	)

	clear_rows()


	var filtered_teachers: Array[Dictionary] = []


	# ========================================================
	# SEARCH
	# ========================================================

	var search_text: String = (
		search_input.text
		.strip_edges()
		.to_lower()
	)


	for teacher_data in all_teachers:

		if not teacher_data is Dictionary:
			continue


		var teacher_name: String = str(
			teacher_data.get(
				"name",
				""
			)
		).to_lower()


		var email: String = str(
			teacher_data.get(
				"email",
				""
			)
		).to_lower()


		var school_year: String = str(
			teacher_data.get(
				"school_year",
				""
			)
		).to_lower()


		var matches_search: bool = true


		if not search_text.is_empty():

			matches_search = (
				teacher_name.contains(search_text)
				or
				email.contains(search_text)
				or
				school_year.contains(search_text)
			)


		if not matches_search:
			continue


		filtered_teachers.append(
			teacher_data
		)


	# ========================================================
	# FILTER BY STATUS
	# ========================================================

	var filter_index: int = filter_button.selected


	if filter_index == 1:

		filtered_teachers = get_active_teachers(
			filtered_teachers
		)


	elif filter_index == 2:

		filtered_teachers = get_inactive_teachers(
			filtered_teachers
		)


	# ========================================================
	# SORT
	# ========================================================

	var sort_index: int = sort_button.selected


	if sort_index == 0:

		filtered_teachers.sort_custom(
			func(
				a: Dictionary,
				b: Dictionary
			) -> bool:

				var name_a: String = str(
					a.get(
						"name",
						""
					)
				).to_lower()


				var name_b: String = str(
					b.get(
						"name",
						""
					)
				).to_lower()


				return name_a < name_b
		)


	# ========================================================
	# EMPTY STATE
	# ========================================================

	if filtered_teachers.is_empty():

		print(
			"[TeacherManagement] No teachers to display."
		)

		empty_state.show()

		return


	empty_state.hide()


	# ========================================================
	# CREATE ROWS
	# ========================================================

	var row_number: int = 1


	for teacher_data in filtered_teachers:

		print(
			"[TeacherManagement] Creating row ",
			row_number,
			": ",
			teacher_data
		)


		var row: Control = TEACHER_ROW_SCENE.instantiate()


		if row == null:

			print(
				"[TeacherManagement] ERROR: Could not instantiate teacher_row.tscn."
			)

			continue


		rows.add_child(
			row
		)


		# ----------------------------------------------------
		# Give data to teacher_row.gd
		# ----------------------------------------------------

		if row.has_method("set_teacher_data"):

			row.set_teacher_data(
				teacher_data,
				row_number
			)

		else:

			print(
				"[TeacherManagement] ERROR: teacher_row.gd does not have set_teacher_data()."
			)


		row_number += 1


	print(
		"[TeacherManagement] Created ",
		filtered_teachers.size(),
		" teacher row(s)."
	)


# ============================================================
# CLEAR ROWS
# ============================================================

func clear_rows() -> void:

	for child in rows.get_children():

		child.queue_free()


# ============================================================
# ACTIVE TEACHERS
# ============================================================

func get_active_teachers(
	teacher_list: Array[Dictionary]
) -> Array[Dictionary]:

	var result: Array[Dictionary] = []


	for teacher_data in teacher_list:

		var status: String = str(
			teacher_data.get(
				"status",
				"inactive"
			)
		).to_lower()


		if status == "active":

			result.append(
				teacher_data
			)


	return result


# ============================================================
# INACTIVE TEACHERS
# ============================================================

func get_inactive_teachers(
	teacher_list: Array[Dictionary]
) -> Array[Dictionary]:

	var result: Array[Dictionary] = []


	for teacher_data in teacher_list:

		var status: String = str(
			teacher_data.get(
				"status",
				"inactive"
			)
		).to_lower()


		if status != "active":

			result.append(
				teacher_data
			)


	return result


# ============================================================
# SEARCH
# ============================================================

func _on_search_changed(
	_text: String
) -> void:

	display_teachers()


# ============================================================
# FILTER
# ============================================================

func _on_filter_changed(
	_index: int
) -> void:

	display_teachers()


# ============================================================
# SORT
# ============================================================

func _on_sort_changed(
	_index: int
) -> void:

	display_teachers()


# ============================================================
# REFRESH
# ============================================================

func _on_refresh_pressed() -> void:

	print(
		"[TeacherManagement] Refresh pressed."
	)

	load_teachers()


# ============================================================
# ADD TEACHER
# ============================================================

func _on_add_teacher_pressed() -> void:

	print(
		"[TeacherManagement] Opening Add Teacher panel."
	)


	if add_teacher == null:
		return


	add_teacher.show()
	add_teacher.move_to_front()


# ============================================================
# TEACHER CREATED
# ============================================================

func _on_teacher_created() -> void:

	print(
		"[TeacherManagement] Teacher created."
	)


	if add_teacher != null:
		add_teacher.hide()


	load_teachers()

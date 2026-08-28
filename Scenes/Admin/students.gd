extends Control


# ============================================================
# UI REFERENCES
# ============================================================

@onready var rows: VBoxContainer = $PageBackground/MarginContainer/VBoxContainer/TablePanel/MarginContainer/VBoxContainer/ScrollContainer/Rows

@onready var empty_state: Panel = $PageBackground/MarginContainer/VBoxContainer/TablePanel/MarginContainer/VBoxContainer/EmptyState

@onready var add_student_button: Button = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/AddStudentButton

@onready var refresh_button: Button = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/RefreshButton

@onready var search_input: LineEdit = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SearchPanel/SearchInput

@onready var filter_button: OptionButton = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/FilterButton

@onready var sort_button: OptionButton = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SortButton

# Import Students button is located in the ImportStudents panel
@onready var import_students_button: Button = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/ImportStudentButton


# ============================================================
# ADD STUDENT PANEL
# ============================================================

@onready var add_student_panel: Control = $AddStudent


# ============================================================
# IMPORT STUDENTS PANEL
# ============================================================

@onready var import_students_panel: Control = $ImportStudents


# ============================================================
# STUDENT PROFILE
# ============================================================

@onready var student_profile: Control = $StudentProfile


# ============================================================
# SCENES
# ============================================================

const STUDENT_ROW = preload(
	"res://Scenes/Admin/student_row.tscn"
)


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	# Hide panels initially
	add_student_panel.hide()
	import_students_panel.hide()
	student_profile.hide()


	# ========================================================
	# REFRESH BUTTON
	# ========================================================

	if not refresh_button.pressed.is_connected(
		_on_refresh_pressed
	):
		refresh_button.pressed.connect(
			_on_refresh_pressed
		)


	# ========================================================
	# ADD STUDENT BUTTON
	# ========================================================

	if not add_student_button.pressed.is_connected(
		_on_add_student_pressed
	):
		add_student_button.pressed.connect(
			_on_add_student_pressed
		)


	# ========================================================
	# IMPORT STUDENTS BUTTON
	# ========================================================

	if not import_students_button.pressed.is_connected(
		_on_import_students_pressed
	):
		import_students_button.pressed.connect(
			_on_import_students_pressed
		)


	# ========================================================
	# SEARCH
	# ========================================================

	if not search_input.text_changed.is_connected(
		_on_search_changed
	):
		search_input.text_changed.connect(
			_on_search_changed
		)


	# ========================================================
	# FILTER
	# ========================================================

	if not filter_button.item_selected.is_connected(
		_on_filter_changed
	):
		filter_button.item_selected.connect(
			_on_filter_changed
		)


	# ========================================================
	# SORT
	# ========================================================

	if not sort_button.item_selected.is_connected(
		_on_sort_changed
	):
		sort_button.item_selected.connect(
			_on_sort_changed
		)


	# ========================================================
	# TEACHER DATA MANAGER
	# ========================================================

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


	# ========================================================
	# ADD STUDENT SIGNAL
	# ========================================================

	if add_student_panel.has_signal(
		"student_created"
	):

		if not add_student_panel.student_created.is_connected(
			_on_student_created
		):

			add_student_panel.student_created.connect(
				_on_student_created
			)


	# ========================================================
	# IMPORT STUDENTS SIGNAL
	# ========================================================

	if import_students_panel.has_signal(
		"students_imported"
	):

		if not import_students_panel.students_imported.is_connected(
			_on_students_imported
		):

			import_students_panel.students_imported.connect(
				_on_students_imported
			)


	# ========================================================
	# INITIAL STATE
	# ========================================================

	empty_state.show()

	load_students()


# ============================================================
# REFRESH
# ============================================================

func _on_refresh_pressed() -> void:

	print(
		"[Students] Refresh button pressed."
	)

	load_students()


# ============================================================
# ADD STUDENT
# ============================================================

func _on_add_student_pressed() -> void:

	print(
		"[Students] Opening Add Student panel."
	)

	# Close Import Students if open
	import_students_panel.hide()

	# Open Add Student
	add_student_panel.show()
	add_student_panel.move_to_front()


# ============================================================
# IMPORT STUDENTS
# ============================================================

func _on_import_students_pressed() -> void:

	print(
		"[Students] Opening Import Students panel."
	)

	# Close Add Student if open
	add_student_panel.hide()

	# Open Import Students
	import_students_panel.show()
	import_students_panel.move_to_front()


# ============================================================
# ADD STUDENT CREATED
# ============================================================

func _on_student_created() -> void:

	print(
		"[Students] Student created."
	)

	# Automatically close Add Student panel
	add_student_panel.hide()

	# Refresh student list
	load_students()


# ============================================================
# STUDENTS IMPORTED
# ============================================================

func _on_students_imported() -> void:

	print(
		"[Students] Students imported successfully."
	)

	# Automatically close Import Students panel
	import_students_panel.hide()

	# Refresh student list
	load_students()


# ============================================================
# SEARCH
# ============================================================

func _on_search_changed(
	_text: String
) -> void:

	display_students()


# ============================================================
# FILTER
# ============================================================

func _on_filter_changed(
	_index: int
) -> void:

	display_students()


# ============================================================
# SORT
# ============================================================

func _on_sort_changed(
	_index: int
) -> void:

	display_students()


# ============================================================
# CLEAR STUDENT ROWS
# ============================================================

func clear_rows() -> void:

	for child in rows.get_children():

		child.queue_free()


# ============================================================
# LOAD STUDENTS
# ============================================================

func load_students() -> void:

	print(
		"[Students] Requesting student data..."
	)

	clear_rows()

	empty_state.show()

	TeacherDataManager.load_students()


# ============================================================
# STUDENTS LOADED
# ============================================================

func _on_students_loaded(
	student_list: Array
) -> void:

	print(
		"[Students] Received ",
		student_list.size(),
		" students."
	)

	display_students()


# ============================================================
# STUDENT LOAD ERROR
# ============================================================

func _on_students_error(
	error
) -> void:

	print(
		"[Students] Firebase error: ",
		error
	)

	clear_rows()

	empty_state.show()


# ============================================================
# DISPLAY STUDENTS
# ============================================================

func display_students() -> void:

	clear_rows()


	var all_students: Array[Dictionary] = (
		TeacherDataManager.get_students()
	)


	var filtered_students: Array[Dictionary] = []


	# ========================================================
	# SEARCH TEXT
	# ========================================================

	var search_text: String = (
		search_input.text
		.strip_edges()
		.to_lower()
	)


	for student_data in all_students:

		var student_name: String = str(
			student_data.get(
				"name",
				""
			)
		).to_lower()


		var email: String = str(
			student_data.get(
				"email",
				""
			)
		).to_lower()


		var student_id: String = str(
			student_data.get(
				"student_id",
				""
			)
		).to_lower()


		var section: String = str(
			student_data.get(
				"section",
				""
			)
		).to_lower()


		var school_year: String = str(
			student_data.get(
				"school_year",
				""
			)
		).to_lower()


		# ----------------------------------------------------
		# NO SEARCH
		# ----------------------------------------------------

		if search_text.is_empty():

			filtered_students.append(
				student_data
			)

			continue


		# ----------------------------------------------------
		# SEARCH
		# ----------------------------------------------------

		if (
			student_name.contains(search_text)
			or email.contains(search_text)
			or student_id.contains(search_text)
			or section.contains(search_text)
			or school_year.contains(search_text)
		):

			filtered_students.append(
				student_data
			)


	# ========================================================
	# FILTER
	# ========================================================

	var filter_index: int = filter_button.selected


	if filter_index == 1:

		filtered_students = get_active_students(
			filtered_students
		)


	elif filter_index == 2:

		filtered_students = get_inactive_students(
			filtered_students
		)


	# ========================================================
	# SORT
	# ========================================================

	var sort_index: int = sort_button.selected


	# --------------------------------------------------------
	# SORT BY NAME
	# --------------------------------------------------------

	if sort_index == 0:

		filtered_students.sort_custom(
			func(
				a: Dictionary,
				b: Dictionary
			) -> bool:

				return str(
					a.get(
						"name",
						""
					)
				).to_lower() < str(
					b.get(
						"name",
						""
					)
				).to_lower()
		)


	# --------------------------------------------------------
	# SORT BY PROGRESS
	# --------------------------------------------------------

	elif sort_index == 1:

		filtered_students.sort_custom(
			func(
				a: Dictionary,
				b: Dictionary
			) -> bool:

				return (
					get_student_progress(a)
					>
					get_student_progress(b)
				)
		)


	# --------------------------------------------------------
	# SORT BY ELEMENTS COLLECTED
	# --------------------------------------------------------

	elif sort_index == 2:

		filtered_students.sort_custom(
			func(
				a: Dictionary,
				b: Dictionary
			) -> bool:

				return (
					get_elements_collected(a)
					>
					get_elements_collected(b)
				)
		)


	# ========================================================
	# EMPTY STATE
	# ========================================================

	if filtered_students.is_empty():

		empty_state.show()

		return


	empty_state.hide()


	# ========================================================
	# CREATE STUDENT ROWS
	# ========================================================

	var number: int = 1


	for student_data in filtered_students:

		var row: Control = STUDENT_ROW.instantiate()

		rows.add_child(
			row
		)


		if row.has_method(
			"setup"
		):

			row.setup(
				student_data,
				number
			)


		if row.has_signal(
			"student_clicked"
		):

			if not row.student_clicked.is_connected(
				_on_student_container_student_clicked
			):

				row.student_clicked.connect(
					_on_student_container_student_clicked
				)


		number += 1


# ============================================================
# STUDENT ID
# ============================================================

func get_student_id(
	data: Dictionary
) -> String:

	return str(
		data.get(
			"student_id",
			""
		)
	)


# ============================================================
# STUDENT NAME
# ============================================================

func get_student_name(
	data: Dictionary
) -> String:

	return str(
		data.get(
			"name",
			"Unknown Student"
		)
	)


# ============================================================
# STUDENT SECTION
# ============================================================

func get_student_section(
	data: Dictionary
) -> String:

	return str(
		data.get(
			"section",
			""
		)
	)


# ============================================================
# SCHOOL YEAR
# ============================================================

func get_school_year(
	data: Dictionary
) -> String:

	return str(
		data.get(
			"school_year",
			""
		)
	)


# ============================================================
# EMAIL
# ============================================================

func get_student_email(
	data: Dictionary
) -> String:

	return str(
		data.get(
			"email",
			"No email"
		)
	)


# ============================================================
# ELEMENTS COLLECTED
# ============================================================

func get_elements_collected(
	data: Dictionary
) -> int:

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


# ============================================================
# ELEMENT TOTAL
# ============================================================

func get_elements_total(
	data: Dictionary
) -> int:

	var progress_value = data.get(
		"progress",
		{}
	)


	if not progress_value is Dictionary:

		return 118


	var progress: Dictionary = progress_value


	var total: int = int(
		progress.get(
			"elements_total",
			118
		)
	)


	if total <= 0:

		return 118


	return total


# ============================================================
# STUDENT PROGRESS
# ============================================================

func get_student_progress(
	data: Dictionary
) -> float:

	var collected: int = get_elements_collected(
		data
	)


	var total: int = get_elements_total(
		data
	)


	if total <= 0:

		return 0.0


	return clamp(
		float(collected)
		/
		float(total)
		*
		100.0,
		0.0,
		100.0
	)


# ============================================================
# GET LAST ACTIVE TIMESTAMP
# ============================================================

func get_last_active_timestamp(
	data: Dictionary
) -> int:

	var value = data.get(
		"last_active",
		0
	)


	# Normal Unix timestamp
	if value is int:

		return int(value)


	# Firebase may return a float
	if value is float:

		return int(value)


	# Numeric string
	if value is String:

		if value.strip_edges().is_valid_int():

			return int(
				value.strip_edges()
			)


		if value.strip_edges().is_valid_float():

			return int(
				float(
					value.strip_edges()
				)
			)


	return 0


# ============================================================
# IS STUDENT CURRENTLY ACTIVE
# ============================================================

func is_student_active(
	data: Dictionary
) -> bool:

	var last_active: int = get_last_active_timestamp(
		data
	)


	if last_active <= 0:

		return false


	var current_time: int = int(
		Time.get_unix_time_from_system()
	)


	var elapsed: int = (
		current_time
		-
		last_active
	)


	# Student is active for 5 minutes
	return (
		elapsed >= 0
		and
		elapsed <= 300
	)


# ============================================================
# ACTIVE STUDENTS
# ============================================================

func get_active_students(
	student_list: Array[Dictionary]
) -> Array[Dictionary]:

	var result: Array[Dictionary] = []


	for student_data in student_list:

		if is_student_active(
			student_data
		):

			result.append(
				student_data
			)


	return result


# ============================================================
# INACTIVE STUDENTS
# ============================================================

func get_inactive_students(
	student_list: Array[Dictionary]
) -> Array[Dictionary]:

	var result: Array[Dictionary] = []


	for student_data in student_list:

		if not is_student_active(
			student_data
		):

			result.append(
				student_data
			)


	return result


# ============================================================
# STUDENT CLICKED
# ============================================================

func _on_student_container_student_clicked(
	student_data: Dictionary
) -> void:

	print(
		"[Students] Student clicked: ",
		get_student_id(
			student_data
		),
		" | ",
		get_student_name(
			student_data
		)
	)


	student_profile.show()

	student_profile.move_to_front()


	if student_profile.has_method(
		"setup"
	):

		student_profile.setup(
			student_data
		)


	elif student_profile.has_method(
		"set_student"
	):

		student_profile.set_student(
			student_data
		)


	else:

		print(
			"[Students] WARNING: StudentProfile has no setup() or set_student() method."
		)


# ============================================================
# CLOSE STUDENT PROFILE
# ============================================================

func close_student_profile() -> void:

	student_profile.hide()

extends Control


# ============================================================
# UI REFERENCES
# ============================================================

@onready var rows: VBoxContainer = $PageBackground/MarginContainer/VBoxContainer/StudentTable/ScrollContainer/Rows

@onready var empty_state: Panel = $PageBackground/MarginContainer/VBoxContainer/StudentTable/EmptyState

@onready var add_student_button = get_node_or_null(
	"PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/AddStudentButton"
)

@onready var search_input: LineEdit = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SearchPanel/SearchInput

@onready var filter_button: OptionButton = $PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/FilterButton

# Import Students button is located in the ImportStudents panel
@onready var import_students_button = get_node_or_null(
	"PageBackground/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/ImportStudentButton"
)


# ============================================================
# ADD STUDENT PANEL
# ============================================================

@onready var add_student_panel = get_node_or_null("AddStudent")


# ============================================================
# IMPORT STUDENTS PANEL
# ============================================================

@onready var import_students_panel = get_node_or_null("ImportStudents")


# ============================================================
# STUDENT PROFILE
# ============================================================

@onready var student_profile: Control = $StudentProfile

# ============================================================
# DELETE CONFIRMATION
# ============================================================

var delete_confirmation: ConfirmationDialog
var pending_delete_student: Dictionary = {}


# ============================================================
# SCENES
# ============================================================

@export var student_row_scene: PackedScene


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# Hide optional panels only when they exist.
	if add_student_panel != null:
		add_student_panel.hide()

	if import_students_panel != null:
		import_students_panel.hide()

	if student_profile != null:
		student_profile.hide()
	
	delete_confirmation = ConfirmationDialog.new()
	delete_confirmation.title = "Delete Student"
	delete_confirmation.dialog_text = (
		"Are you sure you want to delete this student?"
	)
	delete_confirmation.ok_button_text = "Delete"
	delete_confirmation.cancel_button_text = "Cancel"

	add_child(delete_confirmation)

	delete_confirmation.confirmed.connect(
		_on_delete_student_confirmed
	)

	# Connect teacher-only buttons only when they exist.
	if add_student_button != null:
		if not add_student_button.pressed.is_connected(
			_on_add_student_pressed
		):
			add_student_button.pressed.connect(
				_on_add_student_pressed
			)

	if import_students_button != null:
		if not import_students_button.pressed.is_connected(
			_on_import_students_pressed
		):
			import_students_button.pressed.connect(
				_on_import_students_pressed
			)

	# Shared search and filter controls.
	if not search_input.text_changed.is_connected(_on_search_changed):
		search_input.text_changed.connect(_on_search_changed)

	if not filter_button.item_selected.is_connected(_on_filter_changed):
		filter_button.item_selected.connect(_on_filter_changed)

	# Shared student data signals.
	if not TeacherDataManager.students_loaded.is_connected(_on_students_loaded):
		TeacherDataManager.students_loaded.connect(_on_students_loaded)

	if not TeacherDataManager.students_error.is_connected(_on_students_error):
		TeacherDataManager.students_error.connect(_on_students_error)

	# Connect optional panel signals only when those panels exist.
	if add_student_panel != null:
		if add_student_panel.has_signal("student_created"):
			if not add_student_panel.is_connected(
				"student_created",
				Callable(self, "_on_student_created")
			):
				add_student_panel.connect(
					"student_created",
					Callable(self, "_on_student_created")
				)

	if import_students_panel != null:
		if import_students_panel.has_signal("students_imported"):
			if not import_students_panel.is_connected(
				"students_imported",
				Callable(self, "_on_students_imported")
			):
				import_students_panel.connect(
					"students_imported",
					Callable(self, "_on_students_imported")
				)

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
	if add_student_panel == null:
		return

	print("[Students] Opening Add Student panel.")

	if import_students_panel != null:
		import_students_panel.hide()

	add_student_panel.show()
	add_student_panel.move_to_front()


func _on_import_students_pressed() -> void:
	if import_students_panel == null:
		return

	print("[Students] Opening Import Students panel.")

	if add_student_panel != null:
		add_student_panel.hide()

	import_students_panel.show()
	import_students_panel.move_to_front()


func _on_student_created() -> void:
	print("[Students] Student created.")

	if add_student_panel != null:
		add_student_panel.hide()

	load_students()


func _on_students_imported() -> void:
	print("[Students] Students imported successfully.")

	if import_students_panel != null:
		import_students_panel.hide()

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

		if student_row_scene == null:
			push_error(
				"[Students] No student row scene assigned in the Inspector."
			)
			return

		var row: Control = student_row_scene.instantiate()

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


		# Open student profile.
		if row.has_signal("student_clicked"):
			row.student_clicked.connect(
				_on_student_container_student_clicked
			)

		# Update Active/Inactive status.
		if row.has_signal("status_change_requested"):
			row.status_change_requested.connect(
				_on_student_status_change_requested
			)

		# Edit student.
		if row.has_signal("edit_requested"):
			row.edit_requested.connect(
				_on_student_edit_requested
			)

		# Delete student.
		if row.has_signal("delete_requested"):
			row.delete_requested.connect(
				_on_student_delete_requested
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
# ACCOUNT STATUS
# ============================================================

func get_student_status(data: Dictionary) -> String:
	var status: String = str(
		data.get("status", "inactive")
	).strip_edges().to_lower()

	if status.is_empty():
		return "inactive"

	return status


# ============================================================
# ACTIVE STUDENTS
# ============================================================

func get_active_students(
	student_list: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for student_data in student_list:
		if get_student_status(student_data) == "active":
			result.append(student_data)

	return result


# ============================================================
# INACTIVE STUDENTS
# ============================================================

func get_inactive_students(
	student_list: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for student_data in student_list:
		if get_student_status(student_data) == "inactive":
			result.append(student_data)

	return result


# ============================================================
# STUDENT CLICKED
# ============================================================

func _on_student_container_student_clicked(
	student_data: Dictionary
) -> void:
	print("[Students] Student clicked!")

	if not is_instance_valid(student_profile):
		push_error("[Students] StudentProfile reference is invalid.")
		return

	print("[Students] Selected student: ", student_data.get("name", "Unknown Student"))
	print("[Students] Profile path: ", student_profile.get_path())

	# Close other panels.
	if is_instance_valid(add_student_panel):
		add_student_panel.hide()

	if is_instance_valid(import_students_panel):
		import_students_panel.hide()

	# Populate the profile before displaying it.
	if student_profile.has_method("setup"):
		student_profile.setup(student_data)
	elif student_profile.has_method("set_student"):
		student_profile.set_student(student_data)
	else:
		push_error("[Students] StudentProfile has no setup() or set_student() method.")
		return

	# Display the profile above the student list.
	student_profile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	student_profile.z_index = 100
	student_profile.show()
	student_profile.move_to_front()

	print("[Students] Profile visible: ", student_profile.visible)
	print("[Students] Profile size: ", student_profile.size)
	print("[Students] Profile global position: ", student_profile.global_position)


# ============================================================
# CLOSE STUDENT PROFILE
# ============================================================

func close_student_profile() -> void:

	student_profile.hide()


# ============================================================
# UPDATE STUDENT STATUS
# ============================================================

func _on_student_status_change_requested(
	student_data: Dictionary,
	is_active: bool
) -> void:
	var student_uid := str(
		student_data.get("uid", "")
	).strip_edges()

	if student_uid.is_empty():
		push_error(
			"[Students] Cannot update status: student UID is missing."
		)
		load_students()
		return

	var new_status := "active" if is_active else "inactive"

	print(
		"[Students] Updating student ",
		student_uid,
		" status to ",
		new_status
	)

	var result: Dictionary = await TeacherDataManager.update_student_status(
		student_uid,
		new_status
	)

	if not bool(result.get("ok", false)):
		push_error(
			"[Students] Status update failed: "
			+ str(result.get("error", "Unknown error"))
		)

	# Reload so the table displays the confirmed Firebase state.
	load_students()


# ============================================================
# REQUEST STUDENT DELETION
# ============================================================

func _on_student_delete_requested(
	student_data: Dictionary
) -> void:
	pending_delete_student = student_data.duplicate(true)

	var student_name := get_student_name(student_data)

	delete_confirmation.dialog_text = (
		"Are you sure you want to delete "
		+ student_name
		+ "?\n\nThis will delete the student's Firestore record."
	)

	delete_confirmation.popup_centered()


# ============================================================
# CONFIRM STUDENT DELETION
# ============================================================

func _on_delete_student_confirmed() -> void:
	if pending_delete_student.is_empty():
		return

	var student_uid := str(
		pending_delete_student.get("uid", "")
	).strip_edges()

	if student_uid.is_empty():
		push_error(
			"[Students] Cannot delete student: UID is missing."
		)
		return

	print(
		"[Students] Deleting student: ",
		get_student_name(pending_delete_student),
		" | UID: ",
		student_uid
	)

	var result: Dictionary = await TeacherDataManager.delete_student(
		student_uid
	)

	if bool(result.get("ok", false)):
		print("[Students] Student deleted successfully.")

		if student_profile.visible:
			student_profile.hide()

		pending_delete_student.clear()
		load_students()
	else:
		push_error(
			"[Students] Student deletion failed: "
			+ str(result.get("error", "Unknown error"))
		)

# ============================================================
# EDIT STUDENT
# ============================================================

func _on_student_edit_requested(
	student_data: Dictionary
) -> void:
	if add_student_panel == null:
		push_error(
			"[Students] Add Student panel was not found."
		)
		return

	if import_students_panel != null:
		import_students_panel.hide()

	if student_profile != null:
		student_profile.hide()

	add_student_panel.show()
	add_student_panel.move_to_front()

	# Use an edit method if the Add Student panel supports one.
	if add_student_panel.has_method("setup_for_edit"):
		add_student_panel.setup_for_edit(student_data.duplicate(true))
	elif add_student_panel.has_method("set_student"):
		add_student_panel.set_student(student_data.duplicate(true))
	elif add_student_panel.has_method("setup"):
		add_student_panel.setup(student_data.duplicate(true))
	else:
		push_warning(
			"[Students] The Add Student panel does not expose an edit setup method yet."
		)

	print(
		"[Students] Edit requested for: ",
		get_student_name(student_data)
	)

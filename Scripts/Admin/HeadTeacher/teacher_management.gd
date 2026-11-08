
extends Control

const TEACHER_ROW_SCENE: PackedScene = preload(
	"res://Scenes/Admin/HeadTeacher/teacher_row.tscn"
)

const ADD_TEACHER_SCENE: PackedScene = preload(
	"res://Scenes/Admin/HeadTeacher/add_teacher.tscn"
)

signal teacher_edit_requested(teacher_data: Dictionary)
signal teacher_delete_requested(teacher_data: Dictionary)
signal teacher_archive_requested(teacher_data: Dictionary)

# UI references: paths match teacher_management.tscn.
@onready var rows: VBoxContainer = \
	$PageBackground/MarginContainer/VBoxContainer/TeacherTable/ScrollContainer/Rows

@onready var empty_state: Panel = \
	$PageBackground/MarginContainer/VBoxContainer/TeacherTable/EmptyState

@onready var empty_state_label: Label = \
	$PageBackground/MarginContainer/VBoxContainer/TeacherTable/EmptyState/Label

@onready var search_input: LineEdit = \
	$PageBackground/MarginContainer/VBoxContainer/ToolbarPanel2/HBoxContainer/SearchPanel/SearchBar

@onready var filter_button: OptionButton = \
	$PageBackground/MarginContainer/VBoxContainer/ToolbarPanel2/HBoxContainer/FilterPanel/FilterButton

@onready var sort_button: OptionButton = \
	$PageBackground/MarginContainer/VBoxContainer/ToolbarPanel2/HBoxContainer/SortPanel/SortButton

@onready var add_teacher_button: Button = \
	$PageBackground/MarginContainer/VBoxContainer/ToolbarPanel2/HBoxContainer/AddTeacherButton

@onready var add_teacher: Control = $AddTeacher

var all_teachers: Array[Dictionary] = []
var pending_delete_teacher: Dictionary = {}
var delete_confirmation: ConfirmationDialog


func _ready() -> void:
	print("[TeacherManagement] Teacher Management opened.")

	add_teacher.hide()
	
	_create_delete_confirmation()
	
	# Connect toolbar controls.
	if not add_teacher_button.pressed.is_connected(
		_on_add_teacher_button_pressed
	):
		add_teacher_button.pressed.connect(
			_on_add_teacher_button_pressed
		)

	if not search_input.text_changed.is_connected(
		_on_search_changed
	):
		search_input.text_changed.connect(_on_search_changed)

	if not filter_button.item_selected.is_connected(
		_on_filter_changed
	):
		filter_button.item_selected.connect(_on_filter_changed)

	if not sort_button.item_selected.is_connected(
		_on_sort_changed
	):
		sort_button.item_selected.connect(_on_sort_changed)

	# Connect TeacherDataManager signals.
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

	# Connect the embedded Add Teacher form.
	if add_teacher.has_signal("teacher_created"):
		if not add_teacher.teacher_created.is_connected(
			_on_teacher_created
		):
			add_teacher.teacher_created.connect(
				_on_teacher_created
			)

	# Configure sorting choices.
	# The scene already defines these two items.
	empty_state_label.text = "No teachers found."

	empty_state.show()
	load_teachers()


# ============================================================
# LOAD TEACHERS
# ============================================================

func load_teachers() -> void:
	print("[TeacherManagement] Requesting teacher data...")

	clear_rows()
	empty_state.show()
	empty_state_label.text = "Loading teachers..."

	TeacherDataManager.load_teachers()


func _on_teachers_loaded(teacher_list: Array) -> void:
	print("[TeacherManagement] Received ", teacher_list.size(), " teachers.")

	all_teachers.clear()

	for item in teacher_list:
		if item is Dictionary:
			all_teachers.append(item.duplicate(true))

	display_teachers()


func _on_teachers_error(error: Variant) -> void:
	push_error("[TeacherManagement] Failed to load teachers: %s" % str(error))

	all_teachers.clear()
	clear_rows()

	empty_state_label.text = "Unable to load teachers. Please try refreshing."
	empty_state.show()


# ============================================================
# TEACHER NAME HELPERS
# ============================================================

func _get_teacher_display_name(data: Dictionary) -> String:
	var first_name: String = str(data.get("first_name", "")).strip_edges()
	var last_name: String = str(data.get("last_name", "")).strip_edges()

	var full_name: String = (first_name + " " + last_name).strip_edges()

	# Support older teacher documents that only store "name".
	if full_name.is_empty():
		full_name = str(data.get("name", "Unknown")).strip_edges()

	if full_name.is_empty():
		full_name = "Unknown"

	return full_name


# ============================================================
# DISPLAY TEACHERS
# ============================================================

func display_teachers() -> void:
	clear_rows()

	var filtered_teachers: Array[Dictionary] = []
	var search_text: String = search_input.text.strip_edges().to_lower()

	# Search by first name + last name, legacy name, email, ID, or section.
	for teacher_data in all_teachers:
		var teacher_name: String = _get_teacher_display_name(
			teacher_data
		).to_lower()

		var email: String = str(
			teacher_data.get("email", "")
		).to_lower()

		var teacher_id: String = str(
			teacher_data.get("id_number", "")
		).to_lower()

		var sections_text: String = _get_sections_text(
			teacher_data.get("assigned_sections", [])
		).to_lower()

		var matches_search: bool = (
			search_text.is_empty()
			or teacher_name.contains(search_text)
			or email.contains(search_text)
			or teacher_id.contains(search_text)
			or sections_text.contains(search_text)
		)

		if matches_search:
			filtered_teachers.append(teacher_data)

	# Filter by status.
	match filter_button.selected:
		1:
			filtered_teachers = get_teachers_by_status(
				filtered_teachers,
				"active"
			)
		2:
			filtered_teachers = get_teachers_by_status(
				filtered_teachers,
				"inactive"
			)

	# Sort by displayed name or creation date.
	match sort_button.selected:
		0:
			filtered_teachers.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return _get_teacher_display_name(a).to_lower() < \
						_get_teacher_display_name(b).to_lower()
			)
		1:
			filtered_teachers.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return int(a.get("created_at", 0)) > \
						int(b.get("created_at", 0))
			)

	if filtered_teachers.is_empty():
		empty_state_label.text = "No teachers found."
		empty_state.show()
		return

	empty_state.hide()

	var row_number: int = 1

	for teacher_data in filtered_teachers:
		var row_node: Node = TEACHER_ROW_SCENE.instantiate()
		if row_node == null:
			push_error("[TeacherManagement] Could not instantiate teacher_row.tscn.")
			continue

		rows.add_child(row_node)

		if not row_node.has_method("set_teacher_data"):
			push_error(
				"[TeacherManagement] TeacherRow is missing set_teacher_data()."
			)
			row_node.queue_free()
			continue

		row_node.call("set_teacher_data", teacher_data, row_number)

		# Connect actions exposed by teacher_row.gd.
		if row_node.has_signal("edit_requested"):
			row_node.connect(
				"edit_requested",
				_on_teacher_row_edit_requested
			)

		if row_node.has_signal("delete_requested"):
			row_node.connect(
				"delete_requested",
				_on_teacher_row_delete_requested
			)

		if row_node.has_signal("archive_requested"):
			row_node.connect(
				"archive_requested",
				_on_teacher_row_archive_requested
			)
		
		if row_node.has_signal("status_toggle_requested"):
			row_node.status_toggle_requested.connect(
				_on_teacher_status_toggle_requested
			)
		
		row_number += 1

	print("[TeacherManagement] Displayed ", row_number - 1, " teacher row(s).")


func _get_sections_text(value: Variant) -> String:
	if value is Array:
		var section_names: Array[String] = []

		for item in value:
			var section_name: String = str(item).strip_edges()
			if not section_name.is_empty():
				section_names.append(section_name)

		return ", ".join(section_names) if not section_names.is_empty() else "None"

	if value is String:
		var text_value: String = value.strip_edges()
		return text_value if not text_value.is_empty() else "None"

	return "None"


# ============================================================
# STATUS FILTER
# ============================================================

func get_teachers_by_status(
	teacher_list: Array[Dictionary],
	target_status: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for teacher_data in teacher_list:
		var status: String = str(
			teacher_data.get("status", "inactive")
		).strip_edges().to_lower()

		if status == target_status:
			result.append(teacher_data)

	return result


# ============================================================
# CLEAR ROWS
# ============================================================

func clear_rows() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()


# ============================================================
# TOOLBAR EVENTS
# ============================================================

func _on_search_changed(_new_text: String) -> void:
	display_teachers()


func _on_filter_changed(_index: int) -> void:
	display_teachers()


func _on_sort_changed(_index: int) -> void:
	display_teachers()




func _on_add_teacher_button_pressed() -> void:
	print("[TeacherManagement] Opening Add Teacher form.")

	if add_teacher.has_method("open_add_mode"):
		add_teacher.open_add_mode()
	else:
		push_error("AddTeacher is missing open_add_mode().")


func _on_teacher_created() -> void:
	print("[TeacherManagement] Teacher created.")

	add_teacher.hide()
	load_teachers()


func close_add_teacher() -> void:
	if is_instance_valid(add_teacher):
		add_teacher.hide()


# ============================================================
# ROW ACTION EVENTS
# ============================================================

func _on_teacher_row_edit_requested(data: Dictionary) -> void:
	print(
		"[TeacherManagement] Edit requested: ",
		_get_teacher_display_name(data)
	)

	if add_teacher.has_method("open_edit_mode"):
		add_teacher.open_edit_mode(data)
	else:
		push_error("AddTeacher is missing open_edit_mode().")



func _on_teacher_row_delete_requested(data: Dictionary) -> void:
	pending_delete_teacher = data.duplicate(true)

	var teacher_name := _get_teacher_display_name(data)

	delete_confirmation.dialog_text = (
		"Are you sure you want to delete the Firestore record for "
		+ teacher_name
		+ "?\n\nThis action cannot be undone."
	)

	delete_confirmation.popup_centered()


func _on_delete_confirmation_confirmed() -> void:
	var teacher_data := pending_delete_teacher.duplicate(true)

	if teacher_data.is_empty():
		push_warning("[TeacherManagement] No teacher selected for deletion.")
		return

	var teacher_uid := str(teacher_data.get("uid", "")).strip_edges()

	if teacher_uid.is_empty():
		push_error(
			"[TeacherManagement] Cannot delete teacher: UID is missing."
		)
		return

	var teacher_name := _get_teacher_display_name(teacher_data)

	print("[TeacherManagement] Deleting teacher record: ", teacher_name)

	var result: Dictionary = await TeacherDataManager.delete_teacher(
		teacher_uid
	)

	if not bool(result.get("ok", false)):
		var error_message := str(
			result.get("error", "Unknown error")
		)

		push_error(
			"[TeacherManagement] Delete failed: " + error_message
		)

		# Show the error to the user.
		var error_dialog := AcceptDialog.new()
		error_dialog.title = "Delete Failed"
		error_dialog.dialog_text = (
			"Could not delete the teacher record.\n\n"
			+ error_message
		)
		add_child(error_dialog)
		error_dialog.confirmed.connect(
			func() -> void:
				error_dialog.queue_free()
		)
		error_dialog.popup_centered()
		return

	print("[TeacherManagement] Teacher record deleted: ", teacher_uid)

	# Record the successful deletion.
	ActivityLogManager.log_activity(
		"Deleted Teacher Account",
		"Deleted teacher account: " + teacher_name,
		"Teacher Management",
		teacher_uid
	)

	teacher_delete_requested.emit(teacher_data)
	pending_delete_teacher.clear()

	# Reload the list after successful deletion.
	load_teachers()



func _on_teacher_row_archive_requested(data: Dictionary) -> void:
	var teacher_uid: String = str(data.get("uid", "")).strip_edges()

	if teacher_uid.is_empty():
		push_error("[TeacherManagement] Cannot archive teacher: UID is missing.")
		return

	var teacher_name := _get_teacher_display_name(data)

	var result: Dictionary = await TeacherDataManager.update_teacher_status(
		teacher_uid,
        "archived"
	)

	if not bool(result.get("ok", false)):
		push_error(
            "[TeacherManagement] Archive failed: "
			+ str(result.get("error", "Unknown error"))
		)
		return

	# Record the successful archive.
	ActivityLogManager.log_activity(
		"Archived Teacher Account",
		"Archived teacher account: " + teacher_name,
		"Teacher Management",
		teacher_uid
	)

	print("[TeacherManagement] Teacher archived: ", teacher_name)

	teacher_archive_requested.emit(data)
	load_teachers()

func _on_teacher_status_toggle_requested(
	data: Dictionary,
	new_status: String
) -> void:
	var teacher_uid: String = str(data.get("uid", "")).strip_edges()
	var teacher_name := _get_teacher_display_name(data)

	print("[TeacherManagement] Requested status: ", new_status)
	print("[TeacherManagement] Teacher document ID: ", teacher_uid)

	if teacher_uid.is_empty():
		push_error(
            "[TeacherManagement] Cannot update status: teacher UID is empty."
		)
		load_teachers()
		return

	var result: Dictionary = await TeacherDataManager.update_teacher_status(
		teacher_uid,
		new_status
	)

	print("[TeacherManagement] Firestore update result: ", result)

	if not bool(result.get("ok", false)):
		push_error(
            "[TeacherManagement] Status update failed: "
			+ str(result.get("error", "Unknown error"))
		)
		load_teachers()
		return

	# Record the successful status change.
	var activity_action := ""
	var activity_details := ""

	match new_status.to_lower():
		"active":
			activity_action = "Activated Teacher Account"
			activity_details = "Activated teacher account: " + teacher_name

		"inactive":
			activity_action = "Deactivated Teacher Account"
			activity_details = "Deactivated teacher account: " + teacher_name

		_:
			activity_action = "Updated Teacher Status"
			activity_details = (
                "Changed teacher status to "
				+ new_status
				+ ": "
				+ teacher_name
			)

	ActivityLogManager.log_activity(
		activity_action,
		activity_details,
		"Teacher Management",
		teacher_uid
	)

	print("[TeacherManagement] Status saved successfully.")

	load_teachers()

func _create_delete_confirmation() -> void:
	delete_confirmation = ConfirmationDialog.new()
	delete_confirmation.title = "Delete Teacher"
	delete_confirmation.dialog_text = (
		"Are you sure you want to delete this teacher's record?"
	)
	delete_confirmation.ok_button_text = "Delete"
	delete_confirmation.cancel_button_text = "Cancel"

	add_child(delete_confirmation)

	delete_confirmation.confirmed.connect(
		_on_delete_confirmation_confirmed
	)

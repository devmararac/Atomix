
extends Control

const TEACHER_ROW_SCENE: PackedScene = preload(
	"res://Scenes/Admin/HeadTeacher/teacher_row.tscn"
)

signal teacher_edit_requested(teacher_data: Dictionary)
signal teacher_delete_requested(teacher_data: Dictionary)
signal teacher_archive_requested(teacher_data: Dictionary)

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

# ============================================================
# VIEW PANEL
# ============================================================

@onready var view_panel: Control = $PageBackground/ViewPanel

@onready var view_close_button: TextureButton = \
	$PageBackground/ViewPanel/Button

@onready var view_title: Label = \
	$PageBackground/ViewPanel/VBoxContainer/Title

@onready var view_lrn_label: Label = \
	$PageBackground/ViewPanel/VBoxContainer/Panel/VBoxContainer/Display/LRN/Label2

@onready var view_fullname_label: Label = \
	$PageBackground/ViewPanel/VBoxContainer/Panel/VBoxContainer/Display/Fullname/Label2

@onready var view_sections_label: Label = \
	$PageBackground/ViewPanel/VBoxContainer/Panel/VBoxContainer/Display/Sections/Label2

@onready var view_status_label: Label = \
	$PageBackground/ViewPanel/VBoxContainer/Panel/VBoxContainer/Status/Label2

@onready var view_display: Control = \
	$PageBackground/ViewPanel/VBoxContainer/Panel/VBoxContainer/Display

@onready var view_edit: Control = \
	$PageBackground/ViewPanel/VBoxContainer/Panel/VBoxContainer/Edit

@onready var view_action_buttons: HBoxContainer = \
	$PageBackground/ViewPanel/VBoxContainer/Panel/VBoxContainer/ActionButtons

@onready var view_edit_button: Button = \
	$PageBackground/ViewPanel/VBoxContainer/Panel/VBoxContainer/ActionButtons/Edit

@onready var view_activate_button: Button = \
	$PageBackground/ViewPanel/VBoxContainer/Panel/VBoxContainer/ActionButtons/Activate

@onready var view_deactivate_button: Button = \
	$PageBackground/ViewPanel/VBoxContainer/Panel/VBoxContainer/ActionButtons/Deactivate

@onready var view_delete_button: Button = \
	$PageBackground/ViewPanel/VBoxContainer/Panel/VBoxContainer/ActionButtons/Delete


# ============================================================
# DATA
# ============================================================

var all_teachers: Array[Dictionary] = []
var selected_teacher: Dictionary = {}

var pending_delete_teacher: Dictionary = {}
var delete_confirmation: ConfirmationDialog


func _ready() -> void:
	print("[TeacherManagement] Teacher Management opened.")

	add_teacher.hide()
	view_panel.hide()

	_create_delete_confirmation()

	# Toolbar
	if not add_teacher_button.pressed.is_connected(
		_on_add_teacher_button_pressed
	):
		add_teacher_button.pressed.connect(
			_on_add_teacher_button_pressed
		)

	if not search_input.text_changed.is_connected(
		_on_search_changed
	):
		search_input.text_changed.connect(
			_on_search_changed
		)

	if not filter_button.item_selected.is_connected(
		_on_filter_changed
	):
		filter_button.item_selected.connect(
			_on_filter_changed
		)

	if not sort_button.item_selected.is_connected(
		_on_sort_changed
	):
		sort_button.item_selected.connect(
			_on_sort_changed
		)

	# TeacherDataManager
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

	# Add Teacher form
	if add_teacher.has_signal("teacher_created"):
		if not add_teacher.teacher_created.is_connected(
			_on_teacher_created
		):
			add_teacher.teacher_created.connect(
				_on_teacher_created
			)

	# View panel buttons
	if not view_close_button.pressed.is_connected(_on_view_close_pressed):
		view_close_button.pressed.connect(_on_view_close_pressed)

	view_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	view_close_button.disabled = false
	view_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	view_edit_button.pressed.connect(_on_view_edit_pressed)
	view_activate_button.pressed.connect(_on_view_activate_pressed)
	view_deactivate_button.pressed.connect(_on_view_deactivate_pressed)
	view_delete_button.pressed.connect(_on_view_delete_pressed)

	# Sorting choices
	sort_button.clear()
	sort_button.add_item("Name (A-Z)")
	sort_button.add_item("Name (Z-A)")
	sort_button.add_item("Created At (Newest First)")
	sort_button.add_item("Created At (Oldest First)")
	sort_button.select(0)

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
	push_error(
		"[TeacherManagement] Failed to load teachers: %s" % str(error)
	)

	all_teachers.clear()
	clear_rows()

	empty_state_label.text = "Unable to load teachers. Please try refreshing."
	empty_state.show()


# ============================================================
# TEACHER NAME HELPERS
# ============================================================

func _get_teacher_display_name(data: Dictionary) -> String:
	var first_name: String = str(
		data.get("first_name", "")
	).strip_edges()

	var last_name: String = str(
		data.get("last_name", "")
	).strip_edges()

	var full_name: String = (
		first_name + " " + last_name
	).strip_edges()

	if full_name.is_empty():
		full_name = str(
			data.get("name", "Unknown")
	).strip_edges()

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

	for teacher_data in all_teachers:
		var teacher_name: String = \
			_get_teacher_display_name(teacher_data).to_lower()

		var email: String = str(
			teacher_data.get("email", "")
		).to_lower()

		var teacher_id: String = str(
			teacher_data.get("id_number", "")
		).to_lower()

		var sections_text: String = \
			_get_sections_text(
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

	# Status filter
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

	# Sorting
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
					return _get_teacher_display_name(a).to_lower() > \
						_get_teacher_display_name(b).to_lower()
			)

		2:
			filtered_teachers.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return int(a.get("created_at", 0)) > \
						int(b.get("created_at", 0))
			)

		3:
			filtered_teachers.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return int(a.get("created_at", 0)) < \
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
			push_error(
				"[TeacherManagement] Could not instantiate teacher_row.tscn."
			)
			continue

		rows.add_child(row_node)

		if not row_node.has_method("set_teacher_data"):
			push_error(
				"[TeacherManagement] TeacherRow missing set_teacher_data()."
			)
			row_node.queue_free()
			continue

		row_node.call("set_teacher_data", teacher_data, row_number)

		# The only row action is View.
		if row_node.has_signal("view_requested"):
			row_node.view_requested.connect(
				_on_teacher_row_view_requested
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

	if not is_instance_valid(add_teacher):
		push_error("[TeacherManagement] AddTeacher node was freed.")
		return

	if add_teacher.has_method("open_add_mode"):
		add_teacher.open_add_mode()
	else:
		push_error("AddTeacher is missing open_add_mode().")


func _on_teacher_created() -> void:
	print("[TeacherManagement] Teacher created or updated.")

	add_teacher.hide()
	view_panel.hide()
	selected_teacher.clear()

	load_teachers()


func close_add_teacher() -> void:
	if is_instance_valid(add_teacher):
		add_teacher.hide()


# ============================================================
# VIEW PANEL
# ============================================================

func _on_teacher_row_view_requested(data: Dictionary) -> void:
	selected_teacher = data.duplicate(true)
	_update_view_panel()

	view_panel.show()
	view_panel.move_to_front()


func _update_view_panel() -> void:
	if selected_teacher.is_empty():
		return

	view_title.text = _get_teacher_display_name(selected_teacher)

	view_lrn_label.text = str(
		selected_teacher.get(
			"id_number",
			selected_teacher.get("teacher_id", "—")
		 )
	)

	view_fullname_label.text = _get_teacher_display_name(
		selected_teacher
	)

	view_sections_label.text = _get_sections_text(
		selected_teacher.get("assigned_sections", [])
	)

	var status: String = str(
		selected_teacher.get("status", "inactive")
	).strip_edges().to_lower()

	if status.is_empty():
		status = "inactive"

	view_status_label.text = status.capitalize()

	# Display mode only.
	view_display.show()
	view_edit.hide()

	# Status actions.
	var is_active: bool = status == "active"
	var is_inactive: bool = status == "inactive"

	view_activate_button.visible = is_inactive
	view_deactivate_button.visible = is_active

	# Deletion is only available for inactive accounts.
	view_delete_button.visible = is_inactive
	view_delete_button.disabled = not is_inactive

	view_edit_button.visible = true


func _on_view_close_pressed() -> void:
	print("[TeacherManagement] Close button clicked.")
	view_panel.hide()
	selected_teacher.clear()


# ============================================================
# EDIT TEACHER
# ============================================================

func _on_view_edit_pressed() -> void:
	if selected_teacher.is_empty():
		return

	print(
		"[TeacherManagement] Edit requested: ",
		_get_teacher_display_name(selected_teacher)
	)

	# Reuse the existing AddTeacher edit workflow.
	# It updates teachers, users, and D1.
	if add_teacher.has_method("open_edit_mode"):
		view_panel.hide()
		add_teacher.open_edit_mode(selected_teacher)
	else:
		push_error("AddTeacher is missing open_edit_mode().")


# ============================================================
# ACTIVATE / DEACTIVATE
# ============================================================

func _on_view_activate_pressed() -> void:
	if selected_teacher.is_empty():
		return

	if _get_teacher_status(selected_teacher) != "inactive":
		push_warning("[TeacherManagement] Only inactive teachers can be activated.")
		_update_view_panel()
		return

	await _update_selected_teacher_status("active")


func _on_view_deactivate_pressed() -> void:
	if selected_teacher.is_empty():
		return

	if _get_teacher_status(selected_teacher) != "active":
		push_warning("[TeacherManagement] Only active teachers can be deactivated.")
		_update_view_panel()
		return

	await _update_selected_teacher_status("inactive")


func _get_teacher_status(data: Dictionary) -> String:
	return str(
		data.get("status", "inactive")
	).strip_edges().to_lower()


func _update_selected_teacher_status(new_status: String) -> void:
	var teacher_data: Dictionary = selected_teacher.duplicate(true)
	var teacher_uid: String = str(
		teacher_data.get("uid", "")
	).strip_edges()

	if teacher_uid.is_empty():
		push_error("[TeacherManagement] Teacher UID is missing.")
		return

	var teacher_name: String = _get_teacher_display_name(teacher_data)
	var previous_status: String = _get_teacher_status(teacher_data)

	print(
		"[TeacherManagement] Updating status: ",
		teacher_name,
		" -> ",
		new_status
	)

	var result: Dictionary = await TeacherDataManager.update_teacher_status(
		teacher_uid,
		new_status
	)

	if not bool(result.get("ok", false)):
		push_error(
			"[TeacherManagement] Status update failed: "
			+ str(result.get("error", "Unknown error"))
		)
		return

	ActivityLogManager.log_activity(
		"Updated Teacher Account Status",
		"Changed teacher status from "
		+ previous_status
		+ " to "
		+ new_status
		+ ": "
		+ teacher_name,
		"Teacher Management",
		teacher_uid
	)

	# Update local selected data immediately.
	selected_teacher["status"] = new_status
	_update_view_panel()

	# Reload table data from Firestore.
	load_teachers()


# ============================================================
# DELETE TEACHER
# ============================================================

func _on_view_delete_pressed() -> void:
	if selected_teacher.is_empty():
		return

	# First safety check before displaying confirmation.
	if _get_teacher_status(selected_teacher) != "inactive":
		push_warning(
			"[TeacherManagement] Deletion denied: teacher account is not inactive."
		)
		_update_view_panel()
		return

	pending_delete_teacher = selected_teacher.duplicate(true)

	var teacher_name: String = _get_teacher_display_name(
		pending_delete_teacher
	)

	delete_confirmation.dialog_text = (
		"Are you sure you want to permanently delete the teacher account for "
		+ teacher_name
		+ "?\n\n"
		+ "This will permanently delete:\n"
		+ "• Firebase Authentication account\n"
		+ "• Firestore user record\n"
		+ "• Firestore teacher record\n"
		+ "• Account lookup record\n\n"
		+ "This action cannot be undone."
	)

	delete_confirmation.popup_centered()


func _on_delete_confirmation_confirmed() -> void:
	var teacher_data: Dictionary = pending_delete_teacher.duplicate(true)

	if teacher_data.is_empty():
		push_warning("[TeacherManagement] No teacher selected for deletion.")
		return

	# Re-check status immediately before deletion.
	if _get_teacher_status(teacher_data) != "inactive":
		push_error(
			"[TeacherManagement] Deletion blocked. Teacher must be inactive."
		)
		pending_delete_teacher.clear()
		return

	var teacher_uid: String = str(
		teacher_data.get("uid", "")
	).strip_edges()

	if teacher_uid.is_empty():
		push_error("[TeacherManagement] Cannot delete teacher: UID is missing.")
		pending_delete_teacher.clear()
		return

	var teacher_name: String = _get_teacher_display_name(teacher_data)

	print(
		"[TeacherManagement] Permanently deleting inactive teacher: ",
		teacher_name
	)

	var result: Dictionary = await TeacherDataManager.delete_teacher(
		teacher_uid
	)

	if not bool(result.get("ok", false)):
		var error_message: String = str(
			result.get("error", "Unknown error")
		)

		push_error(
			"[TeacherManagement] Account deletion failed: "
			+ error_message
		)

		_show_deletion_error(error_message)
		return

	ActivityLogManager.log_activity(
		"Deleted Teacher Account",
		"Permanently deleted teacher account: " + teacher_name,
		"Teacher Management",
		teacher_uid
	)

	teacher_delete_requested.emit(teacher_data)

	pending_delete_teacher.clear()
	selected_teacher.clear()
	view_panel.hide()

	load_teachers()


func _show_deletion_error(error_message: String) -> void:
	var error_dialog := AcceptDialog.new()
	error_dialog.title = "Account Deletion Failed"
	error_dialog.dialog_text = (
		"Could not permanently delete the teacher account.\n\n"
		+ error_message
	)

	add_child(error_dialog)
	error_dialog.confirmed.connect(
		func() -> void:
			error_dialog.queue_free()
	)
	error_dialog.popup_centered()


# ============================================================
# DELETE CONFIRMATION
# ============================================================

func _create_delete_confirmation() -> void:
	delete_confirmation = ConfirmationDialog.new()
	delete_confirmation.title = "Delete Teacher Account"
	delete_confirmation.dialog_text = (
		"Are you sure you want to permanently delete this teacher's account?"
	)

	delete_confirmation.ok_button_text = "Delete Account"
	delete_confirmation.cancel_button_text = "Cancel"

	add_child(delete_confirmation)

	delete_confirmation.confirmed.connect(
		_on_delete_confirmation_confirmed
	)

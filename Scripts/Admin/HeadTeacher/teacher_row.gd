
extends HBoxContainer
class_name TeacherRow

signal edit_requested(teacher_data: Dictionary)
signal delete_requested(teacher_data: Dictionary)
signal archive_requested(teacher_data: Dictionary)
signal status_toggle_requested(teacher_data: Dictionary, new_status: String)

var teacher_data: Dictionary = {}

@onready var number_label: Label = $Background/HBoxContainer2/Number
@onready var teacher_name_label: Label = $Background/HBoxContainer2/FullName
@onready var lrn_label: Label = $Background/HBoxContainer2/LRN
@onready var section_label: Label = $Background/HBoxContainer2/Section
@onready var status_label: Label = $Background/HBoxContainer2/Status

@onready var edit_button: TextureButton = \
	$Background/HBoxContainer2/HBoxContainer/Edit
@onready var delete_button: TextureButton = \
	$Background/HBoxContainer2/HBoxContainer/Delete
@onready var archive_button: TextureButton = \
	$Background/HBoxContainer2/HBoxContainer/Archive
@onready var status_toggle: CheckButton = \
	$Background/HBoxContainer2/HBoxContainer/StatusToggle

func _ready() -> void:
	if not status_toggle.toggled.is_connected(
		_on_status_toggle_toggled
	):
		status_toggle.toggled.connect(
			_on_status_toggle_toggled
		)

# Call this from teacher_management.gd when creating/populating a row.
func set_teacher_data(data: Dictionary, row_number: int) -> void:
	teacher_data = data.duplicate(true)

	# Build the displayed name from the separate fields created by add_teacher.gd.
	var first_name: String = str(teacher_data.get("first_name", "")).strip_edges()
	var last_name: String = str(teacher_data.get("last_name", "")).strip_edges()

	# Fallback for older documents that only have "name".
	var displayed_name: String = (first_name + " " + last_name).strip_edges()
	if displayed_name.is_empty():
		displayed_name = str(teacher_data.get("name", "Unknown")).strip_edges()

	number_label.text = str(row_number)
	teacher_name_label.text = displayed_name

	# Show the teacher ID in the LRN column.
	lrn_label.text = str(
		teacher_data.get(
			"id_number",
			teacher_data.get("teacher_id", "—")
		)
	)

	# Show the sections assigned in add_teacher.gd.
	section_label.text = _get_sections_text(
		teacher_data.get("assigned_sections", [])
	)

	var status: String = str(
		teacher_data.get("status", "inactive")
	).strip_edges()

	if status.is_empty():
		status = "inactive"

	status_label.text = status.capitalize()
	
	var is_active: bool = status.to_lower() == "active"

	status_toggle.set_pressed_no_signal(is_active)
	status_toggle.text = "Active" if is_active else "Inactive"
	_update_toggle_text_color(is_active)
	
	_update_status_style(status)


func _get_sections_text(value: Variant) -> String:
	if value is Array:
		var section_names: Array[String] = []

		for item in value:
			var section_name: String = str(item).strip_edges()
			if not section_name.is_empty():
				section_names.append(section_name)

		if section_names.is_empty():
			return "None"

		return ", ".join(section_names)

	if value is String:
		var section_string: String = value.strip_edges()
		return section_string if not section_string.is_empty() else "None"

	return "None"


func _update_status_style(status: String) -> void:
	var color := Color(0.47058824, 0.3529412, 0.23529412, 1)

	if status.to_lower() == "active":
		color = Color(0.2, 0.5, 0.25, 1)
	elif status.to_lower() == "archived":
		color = Color(0.5, 0.45, 0.4, 1)
	elif status.to_lower() == "inactive":
		color = Color(0.65, 0.3, 0.2, 1)

	status_label.add_theme_color_override("font_color", color)


func _on_edit_pressed() -> void:
	edit_requested.emit(teacher_data)


func _on_delete_pressed() -> void:
	delete_requested.emit(teacher_data)


func _on_archive_pressed() -> void:
	archive_requested.emit(teacher_data)


func _on_status_toggle_toggled(is_active: bool) -> void:
	var new_status: String = "active" if is_active else "inactive"

	status_toggle.text = "Active" if is_active else "Inactive"
	_update_toggle_text_color(is_active)

	# Ask the parent to save the change to Firestore.
	status_toggle_requested.emit(teacher_data.duplicate(true), new_status)

func _update_toggle_text_color(is_active: bool) -> void:
	var text_color: Color

	if is_active:
		text_color = Color("#2E9D61") # Green
	else:
		text_color = Color("#D9534F") # Red

	status_toggle.add_theme_color_override("font_color", text_color)
	status_toggle.add_theme_color_override("font_hover_color", text_color)
	status_toggle.add_theme_color_override("font_pressed_color", text_color)
	status_toggle.add_theme_color_override("font_hover_pressed_color", text_color)

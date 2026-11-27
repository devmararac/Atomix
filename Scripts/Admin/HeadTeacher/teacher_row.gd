
extends HBoxContainer
class_name TeacherRow

signal view_requested(teacher_data: Dictionary)

var teacher_data: Dictionary = {}

@onready var number_label: Label = $Background/HBoxContainer2/Number
@onready var lrn_label: Label = $Background/HBoxContainer2/LRN
@onready var teacher_name_label: Label = $Background/HBoxContainer2/FullName
@onready var section_label: Label = $Background/HBoxContainer2/Section
@onready var status_label: Label = $Background/HBoxContainer2/Status

@onready var view_button: TextureButton = \
	$Background/HBoxContainer2/HBoxContainer/View


func _ready() -> void:
	if not view_button.pressed.is_connected(_on_view_pressed):
		view_button.pressed.connect(_on_view_pressed)


# ============================================================
# SET TEACHER DATA
# ============================================================

func set_teacher_data(data: Dictionary, row_number: int) -> void:
	teacher_data = data.duplicate(true)

	var first_name := str(
		teacher_data.get("first_name", "")
	).strip_edges()

	var last_name := str(
		teacher_data.get("last_name", "")
	).strip_edges()

	var displayed_name := (
		first_name + " " + last_name
	).strip_edges()

	if displayed_name.is_empty():
		displayed_name = str(
			teacher_data.get("name", "Unknown")
	).strip_edges()

	if displayed_name.is_empty():
		displayed_name = "Unknown"

	number_label.text = str(row_number)
	teacher_name_label.text = displayed_name

	lrn_label.text = str(
		teacher_data.get(
			"id_number",
			teacher_data.get("teacher_id", "—")
		)
	)

	section_label.text = _get_sections_text(
		teacher_data.get("assigned_sections", [])
	)

	var status := str(
		teacher_data.get("status", "inactive")
	).strip_edges().to_lower()

	if status.is_empty():
		status = "inactive"

	status_label.text = status.capitalize()
	_update_status_style(status)


# ============================================================
# SECTION DISPLAY
# ============================================================

func _get_sections_text(value: Variant) -> String:
	if value is Array:
		var section_names: Array[String] = []

		for item in value:
			var section_name := str(item).strip_edges()

			if not section_name.is_empty():
				section_names.append(section_name)

		if section_names.is_empty():
			return "None"

		return ", ".join(section_names)

	if value is String:
		var section_string: String = str(value).strip_edges()

		if section_string.is_empty():
			return "None"

		return section_string

	return "None"


# ============================================================
# STATUS STYLE
# ============================================================

func _update_status_style(status: String) -> void:
	var color := Color(0.47058824, 0.3529412, 0.23529412, 1)

	match status.to_lower():
		"active":
			color = Color(0.2, 0.5, 0.25, 1)

		"inactive":
			color = Color(0.65, 0.3, 0.2, 1)

		"archived":
			color = Color(0.5, 0.45, 0.4, 1)

	status_label.add_theme_color_override(
		"font_color",
		color
	)


# ============================================================
# VIEW BUTTON
# ============================================================

func _on_view_pressed() -> void:
	if teacher_data.is_empty():
		push_error("[TeacherRow] Cannot view teacher: Data is missing.")
		return

	view_requested.emit(teacher_data.duplicate(true))

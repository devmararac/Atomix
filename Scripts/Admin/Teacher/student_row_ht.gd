
extends Panel

signal student_clicked(student_data: Dictionary)

var student_data: Dictionary = {}
var row_number: int = 0

@onready var click_area: Button = $ClickArea
@onready var number_label: Label = $TableHeader/HBoxContainer/Number
@onready var name_label: Label = $TableHeader/HBoxContainer/FullName
@onready var lrn_label: Label = $TableHeader/HBoxContainer/LRN
@onready var section_label: Label = $TableHeader/HBoxContainer/Section
@onready var status_label: Label = $TableHeader/HBoxContainer/Status


func _ready() -> void:
	if not click_area.pressed.is_connected(_on_click_area_pressed):
		click_area.pressed.connect(_on_click_area_pressed)

	if not student_data.is_empty():
		display_student()


# Call this from the student management script when creating each row.
func setup(data: Dictionary, number: int) -> void:
	student_data = data.duplicate(true)
	row_number = number

	if is_node_ready():
		display_student()


func display_student() -> void:
	# Row number
	number_label.text = str(row_number)

	# Student name
	var student_name: String = str(
		student_data.get("name", "")
	).strip_edges()

	if student_name.is_empty():
		var first_name: String = str(
			student_data.get("first_name", "")
		).strip_edges()

		var last_name: String = str(
			student_data.get("last_name", "")
		).strip_edges()

		student_name = (first_name + " " + last_name).strip_edges()

	if student_name.is_empty():
		student_name = "Unknown Student"

	name_label.text = student_name

	# LRN / student ID
	var student_id: String = str(
		student_data.get(
			"lrn",
			student_data.get(
				"student_id",
				student_data.get("id_number", "")
			)
		)
	).strip_edges()

	lrn_label.text = student_id if not student_id.is_empty() else "—"

	# Section
	var section_value: Variant = student_data.get("section", "")
	section_label.text = _get_section_text(section_value)

	# Account status
	var status: String = str(
		student_data.get("status", "inactive")
	).strip_edges().to_lower()

	if status.is_empty():
		status = "inactive"

	status_label.text = status.capitalize()
	_update_status_style(status)


func _get_section_text(value: Variant) -> String:
	if value is Array:
		var names: Array[String] = []

		for item in value:
			var section_name: String = str(item).strip_edges()

			if not section_name.is_empty():
				names.append(section_name)

		return ", ".join(names) if not names.is_empty() else "—"

	if value is Dictionary:
		var section_name: String = str(
			value.get("name", "")
		).strip_edges()

		return section_name if not section_name.is_empty() else "—"

	var section_name: String = str(value).strip_edges()
	return section_name if not section_name.is_empty() else "—"


func _update_status_style(status: String) -> void:
	var color: Color = Color(0.31, 0.22, 0.14, 1)

	match status:
		"active":
			color = Color(0.2, 0.5, 0.25, 1)
		"inactive":
			color = Color(0.65, 0.3, 0.2, 1)
		"archived":
			color = Color(0.5, 0.45, 0.4, 1)

	status_label.add_theme_color_override("font_color", color)


func _on_click_area_pressed() -> void:
	student_clicked.emit(student_data)

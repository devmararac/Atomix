
extends Panel

signal student_clicked(student_data: Dictionary)
signal status_change_requested(student_data: Dictionary, is_active: bool)
signal edit_requested(student_data: Dictionary)
signal delete_requested(student_data: Dictionary)

var student_data: Dictionary = {}
var row_number: int = 0

@onready var click_button: Button = $Button

@onready var number_label: Label = $TableHeader/HBoxContainer/Number
@onready var name_label: Label = $TableHeader/HBoxContainer/FullName
@onready var lrn_label: Label = $TableHeader/HBoxContainer/LRN
@onready var section_label: Label = $TableHeader/HBoxContainer/Section
@onready var status_label: Label = $TableHeader/HBoxContainer/Status

@onready var active_inactive_button: CheckButton = \
	$TableHeader/HBoxContainer/HBoxContainer/Active_Inactive

@onready var edit_button: TextureButton = \
	$Edit

@onready var delete_button: TextureButton = \
	$Delete


func _ready() -> void:
	if not click_button.pressed.is_connected(_on_row_clicked):
		click_button.pressed.connect(_on_row_clicked)

	if not active_inactive_button.toggled.is_connected(_on_status_toggled):
		active_inactive_button.toggled.connect(_on_status_toggled)

	if not edit_button.pressed.is_connected(_on_edit_pressed):
		edit_button.pressed.connect(_on_edit_pressed)

	if not delete_button.pressed.is_connected(_on_delete_pressed):
		delete_button.pressed.connect(_on_delete_pressed)

	if not student_data.is_empty():
		display_student()


# Called by students.gd when creating a row.
func setup(data: Dictionary, number: int) -> void:
	student_data = data.duplicate(true)
	row_number = number

	if is_node_ready():
		display_student()


func display_student() -> void:
	number_label.text = str(row_number)

	# Student name
	var student_name := str(student_data.get("name", "")).strip_edges()

	if student_name.is_empty():
		var first_name := str(student_data.get("first_name", "")).strip_edges()
		var last_name := str(student_data.get("last_name", "")).strip_edges()
		student_name = (first_name + " " + last_name).strip_edges()

	if student_name.is_empty():
		student_name = "Unknown Student"

	name_label.text = student_name

	# Learner Reference Number / student ID
	var student_id := str(
		student_data.get(
			"lrn",
			student_data.get("student_id", student_data.get("id_number", ""))
		)
	).strip_edges()

	lrn_label.text = student_id if not student_id.is_empty() else "—"

	# Section
	section_label.text = _get_section_text(student_data.get("section", ""))

	# Account status
	var status := str(student_data.get("status", "inactive")).strip_edges().to_lower()

	if status.is_empty():
		status = "inactive"

	status_label.text = status.capitalize()

	# Set the CheckButton without emitting a toggled signal.
	active_inactive_button.set_pressed_no_signal(status == "active")
	active_inactive_button.text = "Active" if status == "active" else "Inactive"

	_update_status_style(status)


func _get_section_text(value: Variant) -> String:
	if value is Array:
		var names: Array[String] = []

		for item in value:
			var section_name := str(item).strip_edges()

			if not section_name.is_empty():
				names.append(section_name)

		return ", ".join(names) if not names.is_empty() else "—"

	if value is Dictionary:
		var section_name := str(value.get("name", "")).strip_edges()
		return section_name if not section_name.is_empty() else "—"

	var section_name := str(value).strip_edges()
	return section_name if not section_name.is_empty() else "—"


func _update_status_style(status: String) -> void:
	var color := Color(0.31, 0.22, 0.14, 1)

	match status:
		"active":
			color = Color(0.2, 0.5, 0.25, 1)
		"inactive":
			color = Color(0.65, 0.3, 0.2, 1)
		"archived":
			color = Color(0.5, 0.45, 0.4, 1)

	status_label.add_theme_color_override("font_color", color)


func _on_row_clicked() -> void:
	print("[StudentRow] CLICK DETECTED")
	print("[StudentRow] Student data: ", student_data)
	student_clicked.emit(student_data)


func _on_status_toggled(is_pressed: bool) -> void:
	active_inactive_button.text = "Active" if is_pressed else "Inactive"

	# Request the parent page to update Firebase.
	status_change_requested.emit(student_data, is_pressed)


func _on_edit_pressed() -> void:
	edit_requested.emit(student_data)


func _on_delete_pressed() -> void:
	delete_requested.emit(student_data)

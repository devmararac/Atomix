
extends Panel
class_name ClassCards

signal assign_requested(section_id: String, section_name: String)
signal edit_requested(section_id: String, section_name: String)
signal delete_requested(section_id: String, section_name: String)

@onready var section_label: Label = $VBoxContainer/HBoxContainer/VBoxContainer/Section
@onready var total_students_label: Label = $VBoxContainer/HBoxContainer/VBoxContainer/TotalStudents
@onready var teacher_label: Label = $VBoxContainer/HBoxContainer/VBoxContainer/Teacher
@onready var assign_button: Button = $VBoxContainer/HBoxContainer2/Assign
@onready var edit_button: Button = $VBoxContainer/HBoxContainer2/Edit
@onready var delete_button: Button = $VBoxContainer/HBoxContainer2/Delete

var section_id: String = ""
var section_name: String = ""
var total_students: int = 0
var teacher_name: String = ""

func _ready() -> void:
	assign_button.pressed.connect(_on_assign_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	_refresh_display()


func _on_assign_pressed() -> void:
	assign_requested.emit(section_id, section_name)

func setup(
	new_section_id: String,
	new_section_name: String,
	new_total_students: int = 0
) -> void:
	section_id = new_section_id
	section_name = new_section_name
	total_students = new_total_students

	if is_node_ready():
		_refresh_display()


func _refresh_display() -> void:
	section_label.text = section_name
	total_students_label.text = "Students: %d" % total_students
	
	if teacher_name.is_empty():
		teacher_label.text = "Teacher: Unassigned"
	else:
		teacher_label.text = "Teacher: " + teacher_name

func set_teacher(new_teacher_name: String) -> void:
	teacher_name = new_teacher_name.strip_edges()

	if is_node_ready():
		_refresh_display()

func set_total_students(count: int) -> void:
	total_students = maxi(count, 0)
	_refresh_display()


func _on_edit_pressed() -> void:
	edit_requested.emit(section_id, section_name)


func _on_delete_pressed() -> void:
	delete_requested.emit(section_id, section_name)


extends Panel

signal section_selected(section_name: String, record_type: String)

var section_name: String = ""
var student_count: int = 0
var record_type: String = "quiz"


func _ready() -> void:
	$VBoxContainer/NumberofStudents.text = str(student_count)
	$VBoxContainer.get_node("Section Name").text = section_name

	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			section_selected.emit(section_name, record_type)
			accept_event()

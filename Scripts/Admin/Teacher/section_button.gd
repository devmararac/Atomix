extends Button

signal section_selected(section_name: String, record_type: String)

var section_name: String = ""
var student_count: int = 0
var record_type: String = "quiz"

var progress_percentage: float = 0.0


func _ready() -> void:
	_update_display()

	pressed.connect(_on_pressed)

func _update_display() -> void:
	# Section name
	$VBoxContainer/Header.get_node("Section Name").text = section_name

	# Number of students
	$VBoxContainer/Header/NumberofStudents.text = "%d students" % student_count

	# Progress label
	if record_type == "atomon":
		$VBoxContainer/Details/ProgressLabel.text = "Overall Atomon Collection"
	else:
		$VBoxContainer/Details/ProgressLabel.text = "Overall Quiz Completion"

	# Progress bar
	$VBoxContainer/VBoxContainer/ProgressBar.max_value = 100
	$VBoxContainer/VBoxContainer/ProgressBar.value = progress_percentage

	# Percentage
	$VBoxContainer/VBoxContainer/Percentage.text = "%.1f%%" % progress_percentage


func _on_pressed() -> void:
	section_selected.emit(section_name, record_type)

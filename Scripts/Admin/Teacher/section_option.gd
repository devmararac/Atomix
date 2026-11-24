extends Panel

signal selection_changed(section_name: String, selected: bool)

@onready var section_checkbox: CheckBox = $HBoxContainer/SectionCheckBox

var section_name: String = ""


func setup(display_name: String, selected: bool = false) -> void:
	section_name = display_name

	if is_node_ready():
		section_checkbox.text = section_name
		section_checkbox.set_pressed_no_signal(selected)


func _ready() -> void:
	section_checkbox.text = section_name
	section_checkbox.toggled.connect(_on_checkbox_toggled)


func _on_checkbox_toggled(button_pressed: bool) -> void:
	selection_changed.emit(section_name, button_pressed)


func is_selected() -> bool:
	return section_checkbox.button_pressed

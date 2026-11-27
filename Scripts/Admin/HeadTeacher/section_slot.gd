extends Panel

signal selection_changed(section_name: String, selected: bool)

@onready var checkbox: CheckBox = $HBoxContainer/CheckBox

var section_name: String = ""


func _ready() -> void:
	checkbox.toggled.connect(_on_checkbox_toggled)


func setup(section_name_value: String) -> void:
	section_name = section_name_value
	checkbox.text = section_name_value
	checkbox.button_pressed = false


func is_selected() -> bool:
	return checkbox.button_pressed


func _on_checkbox_toggled(pressed: bool) -> void:
	selection_changed.emit(section_name, pressed)

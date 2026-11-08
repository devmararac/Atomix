
extends Panel
class_name ArchiveSlot

signal slot_selected(year_id: String)

var year_id: String = ""
var is_selectable: bool = false
var is_selected: bool = false

@onready var year_label: Label = $HBoxContainer/VBoxContainer/Year
@onready var subtitle_label: Label = $HBoxContainer/VBoxContainer/Subtitle
@onready var status_label: Label = $HBoxContainer/Panel
@onready var select_button: Button = $Button


func _ready() -> void:
	select_button.pressed.connect(_on_select_button_pressed)


func setup(year_data: Dictionary) -> void:
	year_id = str(year_data.get("id", ""))
	var year_name := str(year_data.get("name", "Unnamed school year"))
	var is_archived := bool(year_data.get("archived", false))
	var is_active := bool(year_data.get("active", false))

	is_selectable = not is_archived and not is_active

	year_label.text = year_name

	if is_archived:
		subtitle_label.text = "This school year is already archived."
		status_label.text = "Archived"
	elif is_active:
		subtitle_label.text = "The active school year cannot be archived."
		status_label.text = "Active"
	else:
		subtitle_label.text = "Select this school year to archive it."
		status_label.text = "Inactive"

	select_button.disabled = not is_selectable
	_update_selection_style()


func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_selection_style()


func _on_select_button_pressed() -> void:
	if not is_selectable or year_id.is_empty():
		return

	slot_selected.emit(year_id)


func _update_selection_style() -> void:
	if is_selected:
		modulate = Color("#D6E8C8")
	elif not is_selectable:
		modulate = Color("#D5D0C8")
	else:
		modulate = Color.WHITE

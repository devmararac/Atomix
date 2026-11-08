
extends Panel

signal assign_requested(lesson_data: Dictionary)
signal view_requested(lesson_data: Dictionary)
signal edit_requested(lesson_data: Dictionary)
signal delete_requested(lesson_data: Dictionary)

@onready var title_label: Label = $VBoxContainer/LessonTitle
@onready var sections_label: Label = $VBoxContainer/ListAssignedSections

@onready var assign_button: Button = \
	$VBoxContainer/HBoxContainer/AssignButton
@onready var view_button: Button = \
	$VBoxContainer/HBoxContainer/ViewButton
@onready var edit_button: Button = \
	$VBoxContainer/HBoxContainer/EditButton
@onready var delete_button: Button = \
	$VBoxContainer/HBoxContainer/DeleteButton

var lesson_data: Dictionary = {}


func _ready() -> void:
	if not assign_button.pressed.is_connected(_on_assign_pressed):
		assign_button.pressed.connect(_on_assign_pressed)

	if not view_button.pressed.is_connected(_on_view_pressed):
		view_button.pressed.connect(_on_view_pressed)

	if not edit_button.pressed.is_connected(_on_edit_pressed):
		edit_button.pressed.connect(_on_edit_pressed)

	if not delete_button.pressed.is_connected(_on_delete_pressed):
		delete_button.pressed.connect(_on_delete_pressed)


func setup_lesson(data: Dictionary) -> void:
	lesson_data = data.duplicate(true)

	var fields: Dictionary = lesson_data.get("fields", {})

	title_label.text = _get_string_field(
		fields,
		"title",
		"Untitled Lesson"
	)

	var sections: Array[String] = _get_assigned_sections(fields)

	if sections.is_empty():
		sections_label.text = "Not assigned to any section"
	else:
		sections_label.text = "Assigned: " + ", ".join(sections)


func _get_string_field(
	fields: Dictionary,
	field_name: String,
	default_value: String = ""
) -> String:
	var field_data: Variant = fields.get(field_name, {})

	if field_data is Dictionary:
		if field_data.has("stringValue"):
			return str(field_data["stringValue"])

	return default_value


func _get_assigned_sections(fields: Dictionary) -> Array[String]:
	var result: Array[String] = []

	var assigned_data: Variant = fields.get("assigned_sections", {})

	if assigned_data is Dictionary:
		var array_data: Variant = assigned_data.get("arrayValue", {})

		if array_data is Dictionary:
			var values: Variant = array_data.get("values", [])

			if values is Array:
				for value in values:
					if value is Dictionary and value.has("stringValue"):
						var section_name := str(value["stringValue"])

						if not section_name.is_empty():
							result.append(section_name)

	# Support older lesson documents that use a single section field.
	if result.is_empty():
		var old_section := _get_string_field(fields, "section", "")

		if not old_section.is_empty():
			result.append(old_section)

	return result


func _on_assign_pressed() -> void:
	assign_requested.emit(lesson_data)


func _on_view_pressed() -> void:
	view_requested.emit(lesson_data)


func _on_edit_pressed() -> void:
	edit_requested.emit(lesson_data)


func _on_delete_pressed() -> void:
	delete_requested.emit(lesson_data)

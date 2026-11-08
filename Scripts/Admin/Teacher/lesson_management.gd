
extends Control

const ADD_LESSON: PackedScene = preload("res://Scenes/Admin/Teacher/add_lesson.tscn")
const LESSON_CARD: PackedScene = preload("res://Scenes/Admin/Teacher/lesson_cards.tscn")

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

@onready var lesson_list: GridContainer = $MarginContainer/VBoxContainer/LessonScroll/CenterContainer/LessonList
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var empty_label: Label = $MarginContainer/VBoxContainer/EmptyLabel
@onready var lesson_scroll: ScrollContainer = $MarginContainer/VBoxContainer/LessonScroll
@onready var search_bar: LineEdit = $MarginContainer/VBoxContainer/ToolbarPanel/HBoxContainer/SearchPanel/SearchBar
@onready var filter_button: OptionButton = $MarginContainer/VBoxContainer/ToolbarPanel/HBoxContainer/FilterPanel/FilterButton

@onready var section_selection: Panel = $MarginContainer/SectionSelection
@onready var section_title: Label = $MarginContainer/SectionSelection/VBoxContainer/Title
@onready var section_subtitle: Label = $MarginContainer/SectionSelection/VBoxContainer/Subtitle
@onready var section_checkbox_container: CenterContainer = $MarginContainer/SectionSelection/VBoxContainer/ScrollContainer/CenterContainer
@onready var cancel_assign_button: Button = $MarginContainer/SectionSelection/VBoxContainer/HBoxContainer/Cancel
@onready var confirm_assign_button: Button = $MarginContainer/SectionSelection/VBoxContainer/HBoxContainer/Confirm

var firestore_url: String
var all_teacher_lessons: Array[Dictionary] = []
var assign_lesson_data: Dictionary = {}
var assign_section_checkboxes: Array[CheckBox] = []


func _ready() -> void:
	firestore_url = "https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents/lessons" % [
		PROJECT_ID,
		DATABASE_ID
	]

	section_selection.hide()
	empty_label.hide()
	status_label.hide()

	if not cancel_assign_button.pressed.is_connected(_on_cancel_assign_pressed):
		cancel_assign_button.pressed.connect(_on_cancel_assign_pressed)

	if not confirm_assign_button.pressed.is_connected(_on_confirm_assign_pressed):
		confirm_assign_button.pressed.connect(_on_confirm_assign_pressed)

	if not search_bar.text_changed.is_connected(_on_search_text_changed):
		search_bar.text_changed.connect(_on_search_text_changed)

	if not filter_button.item_selected.is_connected(_on_filter_selected):
		filter_button.item_selected.connect(_on_filter_selected)

	load_lessons()


func _on_add_lesson_button_pressed() -> void:
	var add_lesson := ADD_LESSON.instantiate()
	add_child(add_lesson)

	if add_lesson.has_signal("lesson_created"):
		if not add_lesson.lesson_created.is_connected(_on_lesson_created):
			add_lesson.lesson_created.connect(_on_lesson_created)


func _on_lesson_created() -> void:
	load_lessons()


func _on_refresh_button_pressed() -> void:
	load_lessons()


func load_lessons() -> void:
	status_label.text = "Loading lessons..."
	status_label.show()
	empty_label.hide()
	all_teacher_lessons.clear()
	_clear_lesson_cards()

	var id_token := _get_id_token()
	if id_token.is_empty():
		status_label.text = "Unable to authenticate with Firebase."
		return

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_lessons_request_completed.bind(http))

	var headers := PackedStringArray([
		"Authorization: Bearer " + id_token,
		"Content-Type: application/json"
	])

	var error := http.request(
		firestore_url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		http.queue_free()
		status_label.text = "Could not start the lesson request."


func _get_id_token() -> String:
	var auth_manager := get_node_or_null("/root/AuthManager")
	if auth_manager == null or not auth_manager.is_logged_in():
		return ""

	var auth_data: Dictionary = auth_manager.current_user
	var token := str(auth_data.get("idtoken", ""))

	if token.is_empty():
		token = str(auth_data.get("idToken", ""))

	return token


func _get_current_teacher_id() -> String:
	var auth_manager := get_node_or_null("/root/AuthManager")
	if auth_manager == null or not auth_manager.is_logged_in():
		return ""

	return str(auth_manager.get_uid()).strip_edges()


func _on_lessons_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:
	var response_text := body.get_string_from_utf8()
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		status_label.text = "Could not connect to Firestore."
		return

	if response_code != 200:
		push_error("Failed to load lessons. HTTP %s: %s" % [
			response_code,
			response_text
		])
		status_label.text = "Failed to load lessons."
		return

	var json := JSON.new()
	if json.parse(response_text) != OK or not json.data is Dictionary:
		status_label.text = "Invalid response from Firestore."
		return

	var documents: Array = json.data.get("documents", [])
	var current_teacher_id := _get_current_teacher_id()

	if current_teacher_id.is_empty():
		status_label.text = "Unable to identify the teacher account."
		return

	for document in documents:
		if not document is Dictionary:
			continue

		var fields: Dictionary = document.get("fields", {})
		var owner_id := get_firestore_string(fields, "teacher_id", "").strip_edges()

		if owner_id != current_teacher_id:
			continue

		all_teacher_lessons.append(document)

	_apply_filters()


func _on_search_text_changed(_new_text: String) -> void:
	_apply_filters()


func _on_filter_selected(_index: int) -> void:
	_apply_filters()


func _apply_filters() -> void:
	_clear_lesson_cards()
	empty_label.hide()

	var search_text := search_bar.text.strip_edges().to_lower()
	var filter_index := filter_button.selected
	var visible_lessons: Array[Dictionary] = []

	for document in all_teacher_lessons:
		var fields: Dictionary = document.get("fields", {})
		var title := _get_lesson_title(document)
		var assigned_sections := _get_lesson_assigned_sections(fields)
		var is_assigned := not assigned_sections.is_empty()

		if filter_index == 1 and not is_assigned:
			continue

		if filter_index == 2 and is_assigned:
			continue

		if not search_text.is_empty():
			var searchable_text := title.to_lower()
			if not searchable_text.contains(search_text):
				continue

		visible_lessons.append(document)

	if visible_lessons.is_empty():
		empty_label.text = "No lessons match your search or filter."
		empty_label.show()
		status_label.text = "No matching lessons."
		return

	for document in visible_lessons:
		create_lesson_card(document)

	status_label.text = "%d lesson(s) shown." % visible_lessons.size()


func _clear_lesson_cards() -> void:
	for child in lesson_list.get_children():
		lesson_list.remove_child(child)
		child.queue_free()


func create_lesson_card(document: Dictionary) -> void:
	var card := LESSON_CARD.instantiate()

	if not card.has_method("setup_lesson"):
		push_error("Lesson card is missing setup_lesson().")
		card.free()
		return

	lesson_list.add_child(card)
	card.setup_lesson(document)

	if card.has_signal("assign_requested"):
		card.assign_requested.connect(_on_card_assign_requested)
	if card.has_signal("view_requested"):
		card.view_requested.connect(_on_card_view_requested)
	if card.has_signal("edit_requested"):
		card.edit_requested.connect(_on_card_edit_requested)
	if card.has_signal("delete_requested"):
		card.delete_requested.connect(_on_card_delete_requested)


func _on_card_assign_requested(lesson_data: Dictionary) -> void:
	assign_lesson_data = lesson_data.duplicate(true)
	var fields: Dictionary = assign_lesson_data.get("fields", {})

	section_title.text = "Assign Lesson"
	section_subtitle.text = "Select sections for: " + _get_lesson_title(assign_lesson_data)
	lesson_scroll.hide()
	section_selection.show()

	for child in section_checkbox_container.get_children():
		child.queue_free()

	assign_section_checkboxes.clear()
	confirm_assign_button.disabled = true
	_set_status_message("Loading your assigned sections...")

	var sections: Array = await TeacherDataManager.get_current_teacher_sections()
	_set_status_message("")

	if not is_instance_valid(section_selection):
		return

	if sections.is_empty():
		var message := Label.new()
		message.text = "No sections are assigned to your teacher account."
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section_checkbox_container.add_child(message)
		return

	var existing_sections := _get_lesson_assigned_sections(fields)
	var checkbox_list := VBoxContainer.new()
	checkbox_list.add_theme_constant_override("separation", 12)
	checkbox_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_checkbox_container.add_child(checkbox_list)

	for section_value in sections:
		var section_name := ""

		if section_value is Dictionary:
			section_name = str(section_value.get("name", "")).strip_edges()
		else:
			section_name = str(section_value).strip_edges()

		if section_name.is_empty():
			continue

		var checkbox := CheckBox.new()
		checkbox.text = section_name
		checkbox.button_pressed = existing_sections.has(section_name)
		checkbox.add_theme_font_size_override("font_size", 24)
		checkbox.add_theme_color_override("font_color", Color("#785A3C"))
		checkbox.add_theme_color_override("font_hover_color", Color("#A77B50"))
		checkbox.add_theme_color_override("font_pressed_color", Color("#785A3C"))
		checkbox.add_theme_color_override("font_focus_color", Color("#785A3C"))
		checkbox.custom_minimum_size = Vector2(400, 45)

		checkbox_list.add_child(checkbox)
		assign_section_checkboxes.append(checkbox)

	confirm_assign_button.disabled = assign_section_checkboxes.is_empty()


func _on_card_view_requested(lesson_data: Dictionary) -> void:
	var lesson_title := _get_lesson_title(lesson_data)
	var lesson_id := str(lesson_data.get("name", "")).get_file()

	ActivityLogManager.log_activity(
		"Viewed Lesson",
		"Viewed lesson: " + lesson_title,
		"Lesson Management",
		lesson_id
	)

	_open_lesson_form(2, lesson_data)


func _on_card_edit_requested(lesson_data: Dictionary) -> void:
	var lesson_title := _get_lesson_title(lesson_data)
	var lesson_id := str(lesson_data.get("name", "")).get_file()

	ActivityLogManager.log_activity(
		"Opened Lesson for Editing",
		"Opened lesson for editing: " + lesson_title,
		"Lesson Management",
		lesson_id
	)

	_open_lesson_form(1, lesson_data)


func _open_lesson_form(mode: int, lesson_data: Dictionary) -> void:
	var form := ADD_LESSON.instantiate()

	# Configure the form before adding it to the scene tree.
	if form.has_method("setup_form"):
		form.setup_form(mode, lesson_data)

	if form.has_signal("lesson_created"):
		form.lesson_created.connect(_on_lesson_form_saved)

	get_tree().root.add_child(form)


func _on_lesson_form_saved() -> void:
	await load_lessons()


func _on_card_delete_requested(lesson_data: Dictionary) -> void:
	push_warning("Lesson deletion has not been implemented: " + _get_lesson_title(lesson_data))


func _get_lesson_title(lesson_data: Dictionary) -> String:
	var fields: Dictionary = lesson_data.get("fields", {})
	return get_firestore_string(fields, "title", "Untitled Lesson")


func get_firestore_string(
	fields: Dictionary,
	field_name: String,
	default_value: String = ""
) -> String:
	var value: Variant = fields.get(field_name, {})

	if value is Dictionary:
		if value.has("stringValue"):
			return str(value["stringValue"])
		if value.has("value"):
			return str(value["value"])
		return default_value

	if value is String:
		return value

	return default_value


func _get_lesson_assigned_sections(fields: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var assigned_data: Variant = fields.get("assigned_sections", {})

	if assigned_data is Dictionary:
		var array_data: Variant = assigned_data.get("arrayValue", {})
		if array_data is Dictionary:
			var values: Variant = array_data.get("values", [])
			if values is Array:
				for value in values:
					var section_name := ""

					if value is Dictionary:
						section_name = str(value.get("stringValue", value.get("value", ""))).strip_edges()
					elif value is String:
						section_name = value.strip_edges()

					if not section_name.is_empty() and not result.has(section_name):
						result.append(section_name)

	elif assigned_data is Array:
		for value in assigned_data:
			var section_name := str(value).strip_edges()
			if not section_name.is_empty() and not result.has(section_name):
				result.append(section_name)

	if result.is_empty():
		var old_section: Variant = fields.get("section", {})
		var section_name := ""

		if old_section is Dictionary:
			section_name = str(old_section.get("stringValue", old_section.get("value", ""))).strip_edges()
		elif old_section is String:
			section_name = old_section.strip_edges()

		if not section_name.is_empty():
			result.append(section_name)

	return result


func _on_confirm_assign_pressed() -> void:
	if assign_lesson_data.is_empty():
		_set_status_message("No lesson selected.")
		return

	var selected_sections: Array[String] = []
	for checkbox in assign_section_checkboxes:
		if checkbox.button_pressed:
			selected_sections.append(checkbox.text)

	if selected_sections.is_empty():
		_set_status_message("Please select at least one section.")
		return

	var document_path := str(assign_lesson_data.get("name", ""))
	var document_id := document_path.get_file()

	if document_id.is_empty():
		_set_status_message("Unable to identify this lesson.")
		return

	var token := ""
	if Firebase.Firestore.auth is Dictionary:
		var auth_data: Dictionary = Firebase.Firestore.auth
		token = str(auth_data.get("idtoken", auth_data.get("idToken", "")))

	if token.is_empty():
		_set_status_message("Authentication token is missing. Please sign in again.")
		return

	confirm_assign_button.disabled = true
	_set_status_message("Saving lesson assignment...")

	var project_id := str(assign_lesson_data.get("project_id", PROJECT_ID))
	var url := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/lessons/%s?updateMask.fieldPaths=assigned_sections" % [
		project_id,
		document_id.uri_encode()
	]

	var section_values: Array[Dictionary] = []
	for section_name in selected_sections:
		section_values.append({"stringValue": section_name})

	var request_body := {
		"fields": {
			"assigned_sections": {
				"arrayValue": {
					"values": section_values
				}
			}
		}
	}

	var http := HTTPRequest.new()
	add_child(http)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	])

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_PATCH,
		JSON.stringify(request_body)
	)

	if error != OK:
		http.queue_free()
		confirm_assign_button.disabled = false
		_set_status_message("Could not send the assignment request.")
		return

	var response: Array = await http.request_completed
	var response_code := int(response[1])
	var response_text := (response[3] as PackedByteArray).get_string_from_utf8()
	http.queue_free()

	if response_code < 200 or response_code >= 300:
		push_error("Assignment failed. HTTP %s: %s" % [response_code, response_text])
		confirm_assign_button.disabled = false
		_set_status_message("Failed to save assignment.")
		return

	# ========================================================
	# ACTIVITY LOG — LESSON ASSIGNMENT
	# ========================================================

	var lesson_title := _get_lesson_title(assign_lesson_data)

	ActivityLogManager.log_activity(
		"Assigned Lesson",
		"Assigned lesson: " + lesson_title
			+ " | Sections: " + ", ".join(selected_sections),
		"Lesson Management",
		document_id
	)

	print("[LessonManagement] Activity log recorded: Lesson assigned.")

	section_selection.hide()
	lesson_scroll.show()
	assign_lesson_data.clear()
	assign_section_checkboxes.clear()
	confirm_assign_button.disabled = false
	_set_status_message("Lesson assigned successfully.")

	await load_lessons()


func _show_assignment_message(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Lesson Assignment"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
	)
	dialog.popup_centered()


func _on_cancel_assign_pressed() -> void:
	section_selection.hide()
	lesson_scroll.show()
	assign_lesson_data.clear()
	assign_section_checkboxes.clear()
	confirm_assign_button.disabled = false
	_set_status_message("")


func _set_status_message(message: String) -> void:
	status_label.text = message
	status_label.visible = not message.is_empty()
	if message.is_empty():
		status_label.hide()


func _get_string_field(
	fields: Dictionary,
	field_name: String,
	default_value: String = ""
) -> String:
	return get_firestore_string(fields, field_name, default_value)

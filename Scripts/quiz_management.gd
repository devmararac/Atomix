
extends Control

# ============================================================
# SCENES
# ============================================================

const QUIZ_CARD = preload("res://Scenes/Admin/Teacher/quiz_card.tscn")
const QUIZ_CHOICES = preload("res://Scenes/Admin/Teacher/quiz_choises.tscn")
const MULTIPLE_CHOICE_CREATOR = preload("res://Scenes/Admin/Teacher/quiz_creator.tscn")
const ENUMERATION_CREATOR = preload("res://Scenes/Admin/Teacher/enumeration_creator.tscn")
const IDENTIFICATION_CREATOR: PackedScene = preload("res://Scenes/Admin/Teacher/identification_creator.tscn")
const TRUE_FALSE_CREATOR: PackedScene = preload("res://Scenes/Admin/Teacher/true_false_creator.tscn")

signal create_quiz_selected

# ============================================================
# FIRESTORE
# ============================================================

const PROJECT_ID := "atomix-f6c6b"
const DATABASE_ID := "(default)"

var firestore_url: String
var quizzes: Array[Dictionary] = []
var filtered_quizzes: Array[Dictionary] = []

# ============================================================
# NODE REFERENCES
# ============================================================

@onready var quiz_grid: GridContainer = \
	$QuizPanel/MarginContainer/VBoxContainer/ScrollContainer/CenterContainer/QuizGrid

@onready var search_bar: LineEdit = \
	$QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SearchPanel/SearchBar

@onready var filter_option: OptionButton = \
	$QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/AddQuizPanel2/OptionButton

@onready var add_quiz_button: Button = \
	$QuizPanel/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/AddQuizPanel/AddQuizButton

@onready var back_button: Button = \
	$QuizPanel/MarginContainer/VBoxContainer/Icon_QuizButton/BackButton

@onready var assign_panel: Control = \
	$QuizPanel/AssignQuizPanel

@onready var assign_title: Label = \
	$QuizPanel/AssignQuizPanel/VBoxContainer/Title

@onready var assign_subtitle: Label = \
	$QuizPanel/AssignQuizPanel/VBoxContainer/Subtitle

@onready var assign_sections_container: Control = \
	$QuizPanel/AssignQuizPanel/VBoxContainer/ScrollContainer/CenterContainer

@onready var assign_cancel_button: Button = \
	$QuizPanel/AssignQuizPanel/VBoxContainer/HBoxContainer/Cancel

@onready var assign_confirm_button: Button = \
	$QuizPanel/AssignQuizPanel/VBoxContainer/HBoxContainer/Confirm

# ============================================================
# STATE
# ============================================================

var current_assign_quiz: Dictionary = {}
var section_checkboxes: Array[CheckBox] = []

var request_in_progress := false

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	add_to_group("quiz_management")

	firestore_url = (
        "https://firestore.googleapis.com/v1/projects/"
		+ PROJECT_ID
		+ "/databases/"
		+ DATABASE_ID
		+ "/documents/quizzes"
	)

	_setup_filters()
	_connect_buttons()

	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)

	load_quizzes()

func _connect_buttons() -> void:
	if not search_bar.text_changed.is_connected(_on_search_text_changed):
		search_bar.text_changed.connect(_on_search_text_changed)

	if not filter_option.item_selected.is_connected(_on_filter_selected):
		filter_option.item_selected.connect(_on_filter_selected)

	# Connect this button only once.
	if not add_quiz_button.pressed.is_connected(_on_add_quiz_button_pressed):
		add_quiz_button.pressed.connect(_on_add_quiz_button_pressed)

	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)

	if not assign_cancel_button.pressed.is_connected(_on_assign_cancel_pressed):
		assign_cancel_button.pressed.connect(_on_assign_cancel_pressed)

	if not assign_confirm_button.pressed.is_connected(_on_assign_confirm_pressed):
		assign_confirm_button.pressed.connect(_on_assign_confirm_pressed)


# ============================================================
# FILTERS
# ============================================================

func _setup_filters() -> void:
	filter_option.clear()

	filter_option.add_item("All Quiz")
	filter_option.add_item("Multiple Choice")
	filter_option.add_item("Enumeration")
	filter_option.add_item("Identification")
	filter_option.add_item("True/False")


func _on_search_text_changed(_new_text: String) -> void:
	display_quizzes()


func _on_filter_selected(_index: int) -> void:
	display_quizzes()


func _apply_search_filter(quiz: Dictionary) -> bool:
	var search_text := search_bar.text.strip_edges().to_lower()

	if search_text.is_empty():
		return true

	var title := str(quiz.get("title", "")).to_lower()
	var quiz_id := str(quiz.get("quiz_id", "")).to_lower()

	return title.contains(search_text) or quiz_id.contains(search_text)


func _apply_type_filter(quiz: Dictionary) -> bool:
	var selected_filter := filter_option.get_item_text(
		filter_option.selected
	)

	if selected_filter == "All Quiz":
		return true

	var quiz_type := str(quiz.get("quiz_type", "")).to_lower()

	match selected_filter:
		"Multiple Choice":
			return quiz_type == "multiple_choice"
		"Enumeration":
			return quiz_type == "enumeration"
		"Identification":
			return quiz_type == "identification"
		"True/False":
			return quiz_type == "true_false"

	return true


# ============================================================
# LOAD QUIZZES FROM FIRESTORE
# ============================================================

func load_quizzes() -> void:
	if request_in_progress:
		return

	var id_token := _get_id_token()

	if id_token.is_empty():
		push_error("[QuizManagement] Firebase ID token is empty.")
		return

	request_in_progress = true

	var http := HTTPRequest.new()
	add_child(http)

	var headers := PackedStringArray([
		"Authorization: Bearer " + id_token
	])

	var error := http.request(
		firestore_url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		push_error(
			"[QuizManagement] Failed to start quiz request: "
			+ str(error)
		)
		http.queue_free()
		request_in_progress = false
		return

	var result: Array = await http.request_completed
	http.queue_free()

	request_in_progress = false

	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]

	if response_code < 200 or response_code >= 300:
		push_error(
			"[QuizManagement] Firestore quiz loading failed. HTTP "
			+ str(response_code)
			+ ": "
			+ response_body.get_string_from_utf8()
		)
		return

	var parsed: Variant = JSON.parse_string(
		response_body.get_string_from_utf8()
	)

	if not parsed is Dictionary:
		push_error("[QuizManagement] Firestore returned invalid JSON.")
		return

	quizzes.clear()

	var documents: Array = parsed.get("documents", [])
	var current_teacher_id := _get_current_teacher_id()

	for document_variant in documents:
		if not document_variant is Dictionary:
			continue

		var document: Dictionary = document_variant
		var quiz := _firestore_document_to_quiz(document)

		# Only show quizzes belonging to the signed-in teacher.
		# Firestore security rules must also enforce this.
		if current_teacher_id.is_empty():
			push_warning(
				"[QuizManagement] Teacher UID is unavailable; "
				+ "quiz ownership cannot be verified."
			)
			continue

		if str(quiz.get("teacher_id", "")) != current_teacher_id:
			continue

		quizzes.append(quiz)

	display_quizzes()


# ============================================================
# CONVERT FIRESTORE DOCUMENT TO A NORMAL DICTIONARY
# ============================================================

func _firestore_document_to_quiz(document: Dictionary) -> Dictionary:
	var fields: Dictionary = document.get("fields", {})

	var quiz_id := _firestore_string(fields.get("quiz_id", {}))
	var title := _firestore_string(fields.get("title", {}))
	var teacher_id := _firestore_string(fields.get("teacher_id", {}))
	var quiz_type := _firestore_string(fields.get("quiz_type", {}))
	var question_count := _firestore_integer(
		fields.get("question_count", {})
	)
	var created_at := _firestore_string(fields.get("created_at", {}))

	# Preserve the actual Firestore document path for PATCH and DELETE.
	var document_path := str(document.get("name", ""))

	# Support both newer assigned_sections and older section fields.
	var assigned_sections: Array[String] = []

	var assigned_value: Dictionary = fields.get("assigned_sections", {})
	var assigned_array: Array = assigned_value.get(
		"arrayValue", {}
	).get("values", [])

	for section_value in assigned_array:
		if section_value is Dictionary:
			var section_name := _firestore_string(section_value)
			if not section_name.is_empty():
				assigned_sections.append(section_name)

	if assigned_sections.is_empty():
		var legacy_section := _firestore_string(
			fields.get("section", {})
		)

		if not legacy_section.is_empty():
			assigned_sections.append(legacy_section)

	var questions: Array[Dictionary] = []
	var questions_array: Array = fields.get(
		"questions", {}
	).get("arrayValue", {}).get("values", [])

	for question_variant in questions_array:
		if not question_variant is Dictionary:
			continue

		var question_map: Dictionary = question_variant.get(
			"mapValue", {}
		).get("fields", {})

		var question_text := _firestore_string(
			question_map.get("question", {})
		)

		var question_type := _firestore_string(
			question_map.get("type", {})
		)

		var answers: Array[String] = []
		var answer_values: Array = question_map.get(
			"answers", {}
		).get("arrayValue", {}).get("values", [])

		for answer_variant in answer_values:
			if answer_variant is Dictionary:
				answers.append(_firestore_string(answer_variant))

		var correct_answers: Array[int] = []
		var correct_values: Array = question_map.get(
			"correct_answers", {}
		).get("arrayValue", {}).get("values", [])

		for correct_variant in correct_values:
			if correct_variant is Dictionary:
				correct_answers.append(
					_firestore_integer(correct_variant)
				)

		questions.append({
			"question": question_text,
			"type": question_type,
			"answers": answers,
			"correct_answers": correct_answers
		})

	return {
		"document_path": document_path,
		"document_id": document_path.get_file(),
		"quiz_id": quiz_id,
		"title": title,
		"teacher_id": teacher_id,
		"quiz_type": quiz_type,
		"question_count": question_count,
		"created_at": created_at,
		"questions": questions,
		"assigned_sections": assigned_sections
	}


func _firestore_string(value: Dictionary) -> String:
	if value.has("stringValue"):
		return str(value["stringValue"])

	if value.has("integerValue"):
		return str(value["integerValue"])

	if value.has("doubleValue"):
		return str(value["doubleValue"])

	if value.has("booleanValue"):
		return str(value["booleanValue"])

	return ""


func _firestore_integer(value: Dictionary) -> int:
	if value.has("integerValue"):
		return int(value["integerValue"])

	if value.has("doubleValue"):
		return int(float(value["doubleValue"]))

	return 0


# ============================================================
# DISPLAY QUIZ CARDS
# ============================================================

func display_quizzes() -> void:
	for child in quiz_grid.get_children():
		child.queue_free()

	filtered_quizzes.clear()

	for quiz in quizzes:
		if not _apply_search_filter(quiz):
			continue

		if not _apply_type_filter(quiz):
			continue

		filtered_quizzes.append(quiz)

	for quiz in filtered_quizzes:
		var card := QUIZ_CARD.instantiate()
		quiz_grid.add_child(card)

		card.setup_quiz(quiz)

		if not card.assign_requested.is_connected(
			_on_card_assign_requested
		):
			card.assign_requested.connect(_on_card_assign_requested)

		if not card.view_requested.is_connected(
			_on_card_view_requested
		):
			card.view_requested.connect(_on_card_view_requested)

		if not card.edit_requested.is_connected(
			_on_card_edit_requested
		):
			card.edit_requested.connect(_on_card_edit_requested)

		if not card.delete_requested.is_connected(
			_on_card_delete_requested
		):
			card.delete_requested.connect(_on_card_delete_requested)

	print(
		"[QuizManagement] Displayed ",
		filtered_quizzes.size(),
		" quiz cards."
	)


# ============================================================
# ASSIGN BUTTON
# ============================================================

func _on_card_assign_requested(quiz_data: Dictionary) -> void:
	current_assign_quiz = quiz_data.duplicate(true)

	assign_title.text = "Assign: " + str(
		current_assign_quiz.get("title", "Untitled Quiz")
	)

	assign_subtitle.text = (
		"Select the sections that should receive this quiz."
	)

	_build_section_checkboxes()
	assign_panel.visible = true


func _build_section_checkboxes() -> void:
	section_checkboxes.clear()

	for child in assign_sections_container.get_children():
		child.queue_free()

	var teacher_sections: Array[String] = await _get_teacher_sections()

	if teacher_sections.is_empty():
		var message := Label.new()
		message.text = (
			"No sections were found for your teacher account."
		)
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		assign_sections_container.add_child(message)
		assign_confirm_button.disabled = true
		return

	assign_confirm_button.disabled = false

	var already_assigned: Array = current_assign_quiz.get(
		"assigned_sections", []
	)

	var list := VBoxContainer.new()
	list.name = "SectionCheckboxList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assign_sections_container.add_child(list)

	for section_name in teacher_sections:
		var checkbox := CheckBox.new()
		checkbox.text = section_name
		checkbox.add_theme_color_override("font_color", Color("#3b2618"))
		checkbox.add_theme_color_override("font_hover_color", Color("#5a3a26"))
		checkbox.add_theme_color_override("font_pressed_color", Color("#3b2618"))
		checkbox.add_theme_color_override("font_focus_color", Color("#3b2618"))
		checkbox.button_pressed = already_assigned.has(section_name)
		list.add_child(checkbox)
		section_checkboxes.append(checkbox)


func _on_assign_cancel_pressed() -> void:
	assign_panel.visible = false
	current_assign_quiz.clear()
	section_checkboxes.clear()


func _on_assign_confirm_pressed() -> void:
	if current_assign_quiz.is_empty():
		return

	var selected_sections: Array[String] = []

	for checkbox in section_checkboxes:
		if checkbox.button_pressed:
			selected_sections.append(checkbox.text)

	if selected_sections.is_empty():
		push_warning(
			"[QuizManagement] Select at least one section before assigning."
		)
		assign_subtitle.text = "Select at least one section."
		return

	var document_path := str(
		current_assign_quiz.get("document_path", "")
	)

	if document_path.is_empty():
		push_error(
			"[QuizManagement] Cannot assign quiz: missing Firestore document path."
		)
		return

	var id_token := _get_id_token()

	if id_token.is_empty():
		push_error("[QuizManagement] Cannot assign quiz: missing ID token.")
		return

	var url := "https://firestore.googleapis.com/v1/" + document_path

	var fields := {
		"assigned_sections": {
			"arrayValue": {
				"values": []
			}
		},
		# Keep the old field populated for older parts of the project.
		"section": {
			"stringValue": selected_sections[0]
		}
	}

	var section_values: Array[Dictionary] = []

	for section_name in selected_sections:
		section_values.append({
			"stringValue": section_name
		})

	fields["assigned_sections"]["arrayValue"]["values"] = section_values

	var payload := JSON.stringify({
		"fields": fields
	})

	var headers := PackedStringArray([
		"Authorization: Bearer " + id_token,
		"Content-Type: application/json"
	])

	var http := HTTPRequest.new()
	add_child(http)

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_PATCH,
		payload
	)

	if error != OK:
		push_error(
			"[QuizManagement] Could not start assignment request: "
			+ str(error)
		)
		http.queue_free()
		return

	assign_confirm_button.disabled = true

	var result: Array = await http.request_completed
	http.queue_free()

	assign_confirm_button.disabled = false

	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]

	if response_code < 200 or response_code >= 300:
		push_error(
			"[QuizManagement] Assignment failed. HTTP "
			+ str(response_code)
			+ ": "
			+ response_body.get_string_from_utf8()
		)
		assign_subtitle.text = "Assignment failed. Please try again."
		return

	# ========================================================
	# ACTIVITY LOG — QUIZ ASSIGNMENT
	# ========================================================

	var quiz_title := str(
		current_assign_quiz.get("title", "Untitled Quiz")
	)

	var quiz_id := str(
		current_assign_quiz.get("document_id", current_assign_quiz.get("quiz_id", ""))
	)

	ActivityLogManager.log_activity(
		"Assigned Quiz",
		"Assigned quiz: " + quiz_title
			+ " | Sections: " + ", ".join(selected_sections),
		"Quiz Management",
		quiz_id
	)

	print("[QuizManagement] Activity log recorded: Quiz assigned.")

	print(
		"[QuizManagement] Quiz assigned to sections: ",
		selected_sections
	)

	assign_panel.visible = false
	current_assign_quiz.clear()
	load_quizzes()


# ============================================================
# VIEW BUTTON
# ============================================================
func _on_card_view_requested(quiz_data: Dictionary) -> void:
	var quiz_title := str(quiz_data.get("title", "Untitled Quiz"))
	var quiz_id := str(quiz_data.get("document_id", quiz_data.get("quiz_id", "")))

	ActivityLogManager.log_activity(
		"Viewed Quiz",
		"Viewed quiz: " + quiz_title,
		"Quiz Management",
		quiz_id
	)

	var quiz_type := str(quiz_data.get("quiz_type", ""))

	if quiz_type == "multiple_choice":
		_open_multiple_choice_creator(quiz_data, true)
		return
	
	if quiz_type == "enumeration":
		_open_enumeration_creator(quiz_data, true) # View
		return
	
	if quiz_type == "identification":
		_open_identification_creator(quiz_data, true)
		return
	
	if str(quiz_data.get("quiz_type", "")) == "true_false":
		_open_true_false_creator(quiz_data, true)
		return
	
	# Other quiz types will be connected after Multiple Choice is tested.
	var dialog := AcceptDialog.new()
	dialog.title = "View Quiz"
	dialog.dialog_text = (
		"View mode is not connected yet for "
		+ quiz_type.replace("_", " ").capitalize()
		+ "."
	)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


# ============================================================
# EDIT BUTTON
# ============================================================
func _on_card_edit_requested(quiz_data: Dictionary) -> void:
	var quiz_title := str(quiz_data.get("title", "Untitled Quiz"))
	var quiz_id := str(quiz_data.get("document_id", quiz_data.get("quiz_id", "")))

	ActivityLogManager.log_activity(
		"Opened Quiz for Editing",
		"Opened quiz for editing: " + quiz_title,
		"Quiz Management",
		quiz_id
	)
	var quiz_type := str(quiz_data.get("quiz_type", ""))

	if quiz_type == "multiple_choice":
		_open_multiple_choice_creator(quiz_data, false)
		return
	
	if quiz_type == "enumeration":
		_open_enumeration_creator(quiz_data, false) # Edit
		return
	
	if quiz_type == "identification":
		_open_identification_creator(quiz_data, false)
		return
	
	if str(quiz_data.get("quiz_type", "")) == "true_false":
		_open_true_false_creator(quiz_data, false)
		return
	
	# Other quiz types will be connected after Multiple Choice is tested.
	var dialog := AcceptDialog.new()
	dialog.title = "Edit Quiz"
	dialog.dialog_text = (
		"Edit mode is not connected yet for "
		+ quiz_type.replace("_", " ").capitalize()
		+ "."
	)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _open_multiple_choice_creator(
	quiz_data: Dictionary,
	read_only: bool
) -> void:
	var document_path := str(quiz_data.get("document_path", ""))

	if document_path.is_empty():
		push_error("[QuizManagement] Missing Firestore document path.")
		return

	var creator_scene := MULTIPLE_CHOICE_CREATOR.instantiate()
	add_child(creator_scene)

	# Find the QuizCreator node inside the scene.
	var creator: Node = creator_scene.find_child("QuizCreator", true, false)

	if creator == null:
		push_error("[QuizManagement] Could not find the QuizCreator node.")
		creator_scene.queue_free()
		return

	if read_only:
		if creator.has_method("open_view_mode"):
			creator.call("open_view_mode", quiz_data)
		else:
			push_error("[QuizManagement] open_view_mode() is missing.")
			creator_scene.queue_free()
	else:
		if creator.has_method("open_edit_mode"):
			creator.call("open_edit_mode", quiz_data)
		else:
			push_error("[QuizManagement] open_edit_mode() is missing.")
			creator_scene.queue_free()


func _open_enumeration_creator(
	quiz_data: Dictionary,
	read_only: bool
) -> void:
	var creator_scene: PackedScene = ENUMERATION_CREATOR

	if creator_scene == null:
		push_error("[QuizManagement] Enumeration creator scene is not assigned.")
		return

	var instance: Node = creator_scene.instantiate()

	if instance == null:
		push_error("[QuizManagement] Failed to instantiate enumeration creator.")
		return

	add_child(instance)

	# The script might be attached to the root or to a child node.
	var creator: Node = null
	var expected_script: Script = load(
		"res://Scripts/enumeration_creator.gd"
	)

	if instance.get_script() == expected_script:
		creator = instance
	else:
		creator = instance.find_child("EnumerationCreator", true, false)

	# If the node has a different name, search its descendants by script.
	if creator == null:
		for node in instance.find_children("*", "", true, false):
			if node.get_script() == expected_script:
				creator = node
				break

	if creator == null:
		push_error(
			"[QuizManagement] Could not find a node using enumeration_creator.gd. "
			+ "Check the script attached to enumeration_creator.tscn."
		)
		instance.queue_free()
		return

	if read_only:
		if creator.has_method("open_view_mode"):
			creator.call("open_view_mode", quiz_data)
		else:
			push_error("[QuizManagement] Enumeration creator is missing open_view_mode().")
			instance.queue_free()
	else:
		if creator.has_method("open_edit_mode"):
			creator.call("open_edit_mode", quiz_data)
		else:
			push_error("[QuizManagement] Enumeration creator is missing open_edit_mode().")
			instance.queue_free()


func _open_identification_creator(
	quiz_data: Dictionary,
	read_only: bool
) -> void:
	var instance: Node = IDENTIFICATION_CREATOR.instantiate()
	if instance == null:
		push_error("[QuizManagement] Failed to open identification creator.")
		return

	add_child(instance)

	var expected_script: Script = load(
		"res://Scripts/identification_creator.gd"
	)
	var creator: Node = null

	if instance.get_script() == expected_script:
		creator = instance
	else:
		for node in instance.find_children("*", "", true, false):
			if node.get_script() == expected_script:
				creator = node
				break

	if creator == null:
		push_error("[QuizManagement] Could not find identification_creator.gd.")
		instance.queue_free()
		return

	if read_only:
		creator.call("open_view_mode", quiz_data)
	else:
		creator.call("open_edit_mode", quiz_data)

func _open_true_false_creator(quiz_data: Dictionary, read_only: bool) -> void:
	var creator_scene := TRUE_FALSE_CREATOR.instantiate()
	get_tree().root.add_child(creator_scene)

	var creator := creator_scene.find_child("TrueFalseCreator", true, false)

	if creator == null:
		var nodes := creator_scene.find_children("*", "PanelContainer", true, false)
		for node in nodes:
			if node.get_script() == load("res://Scripts/true_false_creator.gd"):
				creator = node
				break

	if creator == null:
		push_error("Could not find the True/False creator script node.")
		creator_scene.queue_free()
		return

	if read_only:
		creator.open_view_mode(quiz_data)
	else:
		creator.open_edit_mode(quiz_data)

# ============================================================
# DELETE BUTTON
# ============================================================

func _on_card_delete_requested(quiz_data: Dictionary) -> void:
	var document_path := str(quiz_data.get("document_path", ""))

	if document_path.is_empty():
		push_error(
			"[QuizManagement] Cannot delete quiz: missing Firestore document path."
		)
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Quiz"
	dialog.dialog_text = (
		"Delete \"" + str(quiz_data.get("title", "Untitled Quiz"))
		+ "\"?\nThis action cannot be undone."
	)

	add_child(dialog)

	dialog.confirmed.connect(
		_delete_quiz.bind(quiz_data.duplicate(true), dialog)
	)

	dialog.canceled.connect(dialog.queue_free)

	dialog.popup_centered()


func _delete_quiz(quiz_data: Dictionary, dialog: ConfirmationDialog) -> void:
	dialog.queue_free()

	var id_token := _get_id_token()

	if id_token.is_empty():
		push_error("[QuizManagement] Cannot delete quiz: missing ID token.")
		return

	var document_path := str(quiz_data.get("document_path", ""))
	var url := "https://firestore.googleapis.com/v1/" + document_path

	var http := HTTPRequest.new()
	add_child(http)

	var headers := PackedStringArray([
		"Authorization: Bearer " + id_token
	])

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_DELETE
	)

	if error != OK:
		push_error(
			"[QuizManagement] Could not start delete request: "
			+ str(error)
		)
		http.queue_free()
		return

	var result: Array = await http.request_completed
	http.queue_free()

	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]

	if response_code < 200 or response_code >= 300:
		push_error(
			"[QuizManagement] Delete failed. HTTP "
			+ str(response_code)
			+ ": "
			+ response_body.get_string_from_utf8()
		)
		return

	# ========================================================
	# ACTIVITY LOG — QUIZ DELETION
	# ========================================================

	var quiz_title := str(
		quiz_data.get("title", "Untitled Quiz")
	)

	var quiz_id := str(
		quiz_data.get("document_id", quiz_data.get("quiz_id", ""))
	)

	ActivityLogManager.log_activity(
		"Deleted Quiz",
		"Deleted quiz: " + quiz_title,
		"Quiz Management",
		quiz_id
	)

	print("[QuizManagement] Activity log recorded: Quiz deleted.")

	print(
		"[QuizManagement] Deleted quiz: ",
		quiz_title
	)

	load_quizzes()


# ============================================================
# ADD QUIZ
# ============================================================

func _on_add_quiz_button_pressed() -> void:
	create_quiz_selected.emit()

	var dashboard := get_parent().get_parent()

	if dashboard == null:
		push_error("[QuizManagement] Could not find the dashboard parent.")
		return

	var choices_instance := QUIZ_CHOICES.instantiate()
	dashboard.add_child(choices_instance)

	# Keep the existing slide-in behavior.
	if choices_instance is Control:
		var control := choices_instance as Control
		var target_position := control.position
		control.position.x = -600

		var tween := create_tween()
		tween.tween_property(
			control,
			"position",
			target_position,
			0.3
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ============================================================
# BACK BUTTON
# ============================================================

func _on_back_button_pressed() -> void:
	var scene_path := "res://Scenes/Admin/Teacher/quiz_mode.tscn"

	if not ResourceLoader.exists(scene_path):
		push_error("[QuizManagement] Scene not found: " + scene_path)
		return

	var quiz_mode_scene := load(scene_path)
	var dashboard := get_parent().get_parent()

	if dashboard != null and dashboard.has_method("show_page"):
		dashboard.show_page(quiz_mode_scene)
	else:
		push_error(
			"[QuizManagement] Dashboard does not have show_page()."
		)


# ============================================================
# TEACHER SECTIONS
# ============================================================

func _get_teacher_sections() -> Array[String]:
	var sections: Array[String] = []

	if not is_instance_valid(TeacherDataManager):
		push_warning(
			"[QuizManagement] TeacherDataManager is unavailable."
		)
		return sections

	if not TeacherDataManager.has_method("get_current_teacher_sections"):
		push_warning(
			"[QuizManagement] TeacherDataManager is missing "
			+ "get_current_teacher_sections()."
		)
		return sections

	var result: Variant = await TeacherDataManager.get_current_teacher_sections()

	if result is Array:
		for item in result:
			var section_name := str(item).strip_edges()

			if not section_name.is_empty() and not sections.has(section_name):
				sections.append(section_name)

	return sections



# ============================================================
# AUTHENTICATION HELPERS
# ============================================================

func _get_id_token() -> String:
	if not is_instance_valid(Firebase.Auth):
		return ""

	var auth_data: Dictionary = Firebase.Auth.auth

	if auth_data.has("idtoken"):
		return str(auth_data["idtoken"])

	if auth_data.has("idToken"):
		return str(auth_data["idToken"])

	return ""


func _get_current_teacher_id() -> String:
	if is_instance_valid(AuthManager):
		if AuthManager.has_method("get_uid"):
			return str(AuthManager.get_uid())

	# Fallback to Firebase Auth if AuthManager has no UID.
	if is_instance_valid(Firebase.Auth):
		var auth_data: Dictionary = Firebase.Auth.auth

		if auth_data.has("localid"):
			return str(auth_data["localid"])

		if auth_data.has("localId"):
			return str(auth_data["localId"])

	return ""

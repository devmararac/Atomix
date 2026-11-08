
extends Control

const PROJECT_ID := "atomix-f6c6b"
const FIRESTORE_BASE := "https://firestore.googleapis.com/v1/projects/"
const SCHOOL_YEARS_COLLECTION := "/databases/(default)/documents/school_years"

const CLASS_CARD_SCENE: PackedScene = preload(
	"res://Scenes/Admin/HeadTeacher/class_cards.tscn"
)

@onready var add_year_button: Button = get_node(
	"Background/ScrollContainer/CenterContainer/VBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer/AddSYButton"
)
@onready var archive_button: Button = get_node(
	"Background/ScrollContainer/CenterContainer/VBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer/ArchiveButton"
)
@onready var year_selector: OptionButton = get_node(
	"Background/ScrollContainer/CenterContainer/VBoxContainer/VBoxContainer/HBoxContainer/OptionButton"
)
@onready var active_year_label: Label = get_node(
	"Background/ScrollContainer/CenterContainer/VBoxContainer/VBoxContainer/VBoxContainer/Panel/HBoxContainer/VBoxContainer/Label2"
)
@onready var status_label: Label = get_node(
	"Background/ScrollContainer/CenterContainer/VBoxContainer/VBoxContainer/VBoxContainer/Panel/HBoxContainer/Label2"
)
@onready var add_year_panel: Panel = get_node("Background/AddSchoolYear")
@onready var add_year_input: LineEdit = get_node(
	"Background/AddSchoolYear/VBoxContainer/LineEdit"
)
@onready var create_year_button: Button = get_node(
	"Background/AddSchoolYear/VBoxContainer/HBoxContainer/Create"
)
@onready var cancel_year_button: Button = get_node(
	"Background/AddSchoolYear/VBoxContainer/HBoxContainer/Cancel"
)
@onready var section_input: LineEdit = get_node(
	"Background/ScrollContainer/CenterContainer/VBoxContainer/VBoxContainer2/VBoxContainer/Panel/LineEdit"
)
@onready var add_section_button: Button = get_node(
	"Background/ScrollContainer/CenterContainer/VBoxContainer/VBoxContainer2/VBoxContainer/HBoxContainer/AddSectionButton"
)
@onready var section_grid: GridContainer = get_node(
	"Background/ScrollContainer/CenterContainer/VBoxContainer/VBoxContainer2/VBoxContainer/GridContainer"
)

@onready var archive_menu: Panel = get_node("Background/ArchiveMenu")
@onready var archive_slots_container: VBoxContainer = get_node(
	"Background/ArchiveMenu/VBoxContainer/ScrollContainer/CenterContainer/VBoxContainer"
)
@onready var archive_cancel_button: Button = get_node(
	"Background/ArchiveMenu/HBoxContainer/Cancel"
)
@onready var archive_continue_button: Button = get_node(
	"Background/ArchiveMenu/HBoxContainer/Continue"
)
@onready var archive_button_label: Label = get_node(
	"Background/ScrollContainer/CenterContainer/VBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer/ArchiveButton/HBoxContainer2/Label2"
)

@onready var teacher_selection: Panel = $Background/TeacherSelection
	
@onready var teacher_selection_title: Label = $Background/TeacherSelection/VBoxContainer/Title

@onready var teacher_selection_subtitle: Label = $Background/TeacherSelection/VBoxContainer/Subtitle

@onready var teacher_list: CenterContainer = $Background/TeacherSelection/VBoxContainer/ScrollContainer/CenterContainer

@onready var teacher_cancel_button: Button = $Background/TeacherSelection/VBoxContainer/HBoxContainer/Cancel

@onready var teacher_confirm_button: Button = $Background/TeacherSelection/VBoxContainer/HBoxContainer/Confirm

var http: HTTPRequest

var auth_token := ""
var current_uid := ""

var school_years: Array[Dictionary] = []
var sections: Array[Dictionary] = []
var students: Array[Dictionary] = []

var active_year_id := ""
var selected_year_id := ""
var editing_section_id := ""

var selected_archive_year_id := ""

var pending_action := ""
var request_context: Dictionary = {}
var request_queue: Array[Dictionary] = []

var teachers: Array[Dictionary] = []
var assignment_checkboxes: Array[CheckBox] = []
var assignment_jobs: Array[Dictionary] = []

var assignment_button_group: ButtonGroup

var assignment_dialog: ConfirmationDialog
var assignment_section_id := ""
var assignment_section_name := ""
var assignment_year_id := ""
var assignment_year_name := ""


func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)

	if not add_section_button.pressed.is_connected(_on_add_section_pressed):
		add_section_button.pressed.connect(_on_add_section_pressed)

	if not year_selector.item_selected.is_connected(_on_school_year_selected):
		year_selector.item_selected.connect(_on_school_year_selected)

	archive_menu.hide()

	if not archive_cancel_button.pressed.is_connected(_on_archive_menu_cancel_pressed):
		archive_cancel_button.pressed.connect(_on_archive_menu_cancel_pressed)

	if not archive_continue_button.pressed.is_connected(_on_archive_menu_continue_pressed):
		archive_continue_button.pressed.connect(_on_archive_menu_continue_pressed)

	add_year_panel.hide()
	add_year_input.placeholder_text = "Enter starting year (e.g. 2026)"
	section_input.placeholder_text = "Section Name"

	auth_token = _get_id_token()
	current_uid = _get_uid()

	if auth_token.is_empty():
		_show_error("Firebase ID token not found. Please sign in again.")
		return

	if current_uid.is_empty():
		_show_error("User UID not found. Please sign in again.")
		return

	_load_school_years()

	teacher_selection.hide()

	teacher_cancel_button.pressed.connect(
		_on_teacher_assignment_cancelled
	)

	teacher_confirm_button.pressed.connect(
		_on_teacher_assignments_confirmed
	)

# --------------------------------------------------
# AUTHENTICATION
# --------------------------------------------------

func _get_id_token() -> String:
	if Firebase.Auth == null:
		return ""

	var auth_data: Dictionary = Firebase.Auth.auth
	var token := str(auth_data.get("idtoken", ""))

	if token.is_empty():
		token = str(auth_data.get("idToken", ""))

	return token


func _get_uid() -> String:
	if has_node("/root/AuthManager"):
		var manager := get_node("/root/AuthManager")
		if manager.has_method("get_uid"):
			var uid := str(manager.call("get_uid"))
			if not uid.is_empty():
				return uid

	if Firebase.Auth != null:
		var auth_data: Dictionary = Firebase.Auth.auth
		var uid := str(auth_data.get("localid", ""))

		if uid.is_empty():
			uid = str(auth_data.get("localId", ""))

		return uid

	return ""


# --------------------------------------------------
# FIRESTORE HELPERS
# --------------------------------------------------

func _firestore_url(path: String) -> String:
	return FIRESTORE_BASE + PROJECT_ID + path


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + auth_token
	])


func _send_request(
	action: String,
	method: HTTPClient.Method,
	url: String,
	body: Dictionary = {},
	context: Dictionary = {}
) -> void:
	if not is_instance_valid(http):
		return

	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		push_warning("[SchoolYearSections] A request is already running: " + action)
		return

	pending_action = action
	request_context = context.duplicate(true)

	var request_body := ""
	if not body.is_empty():
		request_body = JSON.stringify(body)

	var error := http.request(url, _headers(), method, request_body)

	if error != OK:
		push_error("[SchoolYearSections] Could not start request: %s" % error)
		pending_action = ""
		request_context.clear()
		_set_busy(false)
		_show_error("Could not start the Firebase request.")


func _send_patch(
	action: String,
	document_path: String,
	fields: Dictionary,
	context: Dictionary = {}
) -> void:
	var masks: Array[String] = []

	for field_name in fields.keys():
		masks.append("updateMask.fieldPaths=" + str(field_name).uri_encode())

	var url := _firestore_url(document_path)
	if not masks.is_empty():
		url += "?" + "&".join(masks)

	var body: Dictionary = {"fields": {}}
	for field_name in fields.keys():
		body["fields"][field_name] = _to_firestore_value(fields[field_name])

	_send_request(action, HTTPClient.METHOD_PATCH, url, body, context)


func _to_firestore_value(value: Variant) -> Dictionary:
	if value is bool:
		return {"booleanValue": value}

	if value is int:
		return {"integerValue": str(value)}

	if value is float:
		return {"doubleValue": value}

	if value is String:
		return {"stringValue": value}

	if value == null:
		return {"nullValue": null}

	if value is Array:
		var values: Array = []

		for item in value:
			values.append(_to_firestore_value(item))

		return {"arrayValue": {"values": values}}

	if value is Dictionary:
		var fields: Dictionary = {}

		for key in value.keys():
			fields[str(key)] = _to_firestore_value(value[key])

		return {"mapValue": {"fields": fields}}

	return {"stringValue": str(value)}


func _from_firestore_value(value: Dictionary) -> Variant:
	if value.has("stringValue"):
		return value["stringValue"]
	if value.has("booleanValue"):
		return value["booleanValue"]
	if value.has("integerValue"):
		return int(value["integerValue"])
	if value.has("doubleValue"):
		return float(value["doubleValue"])
	if value.has("timestampValue"):
		return value["timestampValue"]
	if value.has("nullValue"):
		return null

	if value.has("arrayValue"):
		var result: Array = []
		for item in value["arrayValue"].get("values", []):
			if item is Dictionary:
				result.append(_from_firestore_value(item))
		return result

	if value.has("mapValue"):
		var result: Dictionary = {}
		var fields: Dictionary = value["mapValue"].get("fields", {})
		for field_name in fields.keys():
			if fields[field_name] is Dictionary:
				result[str(field_name)] = _from_firestore_value(fields[field_name])
		return result

	return null


func _parse_document(document: Dictionary) -> Dictionary:
	var full_name := str(document.get("name", ""))
	var parts := full_name.split("/", false)
	var document_id := ""

	if not parts.is_empty():
		document_id = str(parts[parts.size() - 1])

	var result: Dictionary = {
		"id": document_id,
		"name": "",
		"active": false,
		"archived": false
	}

	var fields: Dictionary = document.get("fields", {})
	for field_name in fields.keys():
		if fields[field_name] is Dictionary:
			result[str(field_name)] = _from_firestore_value(fields[field_name])

	return result


# --------------------------------------------------
# SCHOOL YEARS
# --------------------------------------------------

func _load_school_years() -> void:
	_set_busy(true)
	_send_request(
		"load_years",
		HTTPClient.METHOD_GET,
		_firestore_url(SCHOOL_YEARS_COLLECTION)
	)


func _parse_school_years(response: Dictionary) -> void:
	school_years.clear()

	for document in response.get("documents", []):
		if document is Dictionary:
			var year := _parse_document(document)
			if not str(year.get("id", "")).is_empty():
				school_years.append(year)

	active_year_id = ""

	for year in school_years:
		if bool(year.get("active", false)) and not bool(year.get("archived", false)):
			active_year_id = str(year.get("id", ""))
			break

	_populate_year_selector()

	# Prefer the active year. If none is active, select the first non-archived year.
	selected_year_id = active_year_id

	if selected_year_id.is_empty():
		for year in school_years:
			if not bool(year.get("archived", false)):
				selected_year_id = str(year.get("id", ""))
				break

	_select_year_in_option_button(selected_year_id)
	_update_active_year_display()
	_update_archive_button()

	# Do not silently activate a year here. The dropdown selection and the
	# Firestore active flag are separate; activation is handled by the selector.
	_load_sections()


func _populate_year_selector() -> void:
	year_selector.clear()
	year_selector.add_item("Select School Year")
	year_selector.set_item_metadata(0, "")

	for year in school_years:
		var year_id := str(year.get("id", ""))
		var year_name := str(year.get("name", "Unnamed school year"))
		var is_archived: bool = bool(year.get("archived", false))

		if is_archived:
			year_name += " (Archived)"
		elif year_id == active_year_id:
			year_name += " (Active)"

		year_selector.add_item(year_name)
		year_selector.set_item_metadata(
			year_selector.item_count - 1,
			year_id
		)


func _select_year_in_option_button(year_id: String) -> void:
	for index in range(year_selector.item_count):
		if str(year_selector.get_item_metadata(index)) == year_id:
			year_selector.select(index)
			return

	year_selector.select(0)


func _on_school_year_selected(index: int) -> void:
	if index < 0 or index >= year_selector.item_count:
		return

	var year_id := str(year_selector.get_item_metadata(index))

	if year_id.is_empty():
		selected_year_id = ""
		_update_active_year_display()
		_update_archive_button()
		_load_sections()
		return

	selected_year_id = year_id

	if _is_year_archived(year_id):
		_update_active_year_display()
		_update_archive_button()
		_load_sections()
		return

	if selected_year_id != active_year_id:
		_activate_school_year(selected_year_id)
	else:
		_update_active_year_display()
		_update_archive_button()
		_load_sections()


func _is_year_archived(year_id: String) -> bool:
	for year in school_years:
		if str(year.get("id", "")) == year_id:
			return bool(year.get("archived", false))

	return false


func _update_archive_button() -> void:
	# This button always opens the selection menu.
	archive_button_label.text = "Archive School Year"

func _update_active_year_display() -> void:
	var displayed_name := "No school year selected"
	var status_text := ""

	for year in school_years:
		if str(year.get("id", "")) == selected_year_id:
			displayed_name = str(year.get("name", "Unnamed school year"))
			status_text = "Active" if selected_year_id == active_year_id else "Not active"
			break

	active_year_label.text = displayed_name
	status_label.text = status_text


# --------------------------------------------------
# ADD SCHOOL YEAR PANEL
# --------------------------------------------------

func _on_add_sy_button_pressed() -> void:
	var current_year := int(
		Time.get_date_dict_from_system().get("year", 0)
	)

	if current_year <= 0:
		_show_error("Unable to determine the current year.")
		return

	add_year_input.text = "%d-%d" % [
		current_year,
		current_year + 1
	]

	add_year_panel.show()
	add_year_input.grab_focus()
	add_year_input.select_all()


func _on_create_pressed() -> void:
	var year_text := add_year_input.text.strip_edges()

	var current_year := int(
		Time.get_date_dict_from_system().get("year", 0)
	)

	if current_year <= 0:
		_show_error("Unable to determine the current year.")
		return

	var starting_year := 0
	var ending_year := 0

	# Accept either:
	# 2026
	# 2026-2027

	if year_text.is_valid_int() and year_text.length() == 4:
		starting_year = int(year_text)
		ending_year = starting_year + 1

	else:
		var year_parts := year_text.split("-")

		if year_parts.size() != 2:
			_show_error(
				"Enter a valid school year, such as 2026-2027."
			)
			add_year_input.grab_focus()
			return

		var start_text := str(year_parts[0]).strip_edges()
		var end_text := str(year_parts[1]).strip_edges()

		if (
			start_text.length() != 4
			or end_text.length() != 4
			or not start_text.is_valid_int()
			or not end_text.is_valid_int()
		):
			_show_error(
				"Enter a valid four-digit year range, such as 2026-2027."
			)
			add_year_input.grab_focus()
			return

		starting_year = int(start_text)
		ending_year = int(end_text)

	# Only accept the current year or a future starting year.
	if starting_year < current_year:
		_show_error(
			"Past school years cannot be created. "
			+ "Enter %d or a later year." % current_year
		)
		add_year_input.grab_focus()
		return

	# School years must be consecutive.
	if ending_year != starting_year + 1:
		_show_error(
			"The ending year must be exactly one year after the starting year."
		)
		add_year_input.grab_focus()
		return

	var year_name := "%d-%d" % [
		starting_year,
		ending_year
	]

	# Prevent duplicate school years.
	for year in school_years:
		if (
			str(year.get("name", "")).strip_edges().to_lower()
			== year_name.to_lower()
		):
			_show_error(
				"School year %s already exists." % year_name
			)
			add_year_input.grab_focus()
			return

	_create_year(year_name)



func _on_cancel_pressed() -> void:
	add_year_panel.hide()
	add_year_input.clear()


func _create_year(year_name: String) -> void:
	var new_id := year_name.replace("/", "-").replace(" ", "_")
	var document_path := SCHOOL_YEARS_COLLECTION + "/" + new_id

	var make_active := active_year_id.is_empty()

	var body: Dictionary = {
		"fields": {
			"name": {"stringValue": year_name},
			"active": {"booleanValue": make_active},
			"archived": {"booleanValue": false},
			"created_by": {"stringValue": current_uid}
		}
	}

	add_year_panel.hide()
	_set_busy(true)

	_send_request(
		"create_year",
		HTTPClient.METHOD_PATCH,
		_firestore_url(document_path),
		body,
		{"year_id": new_id}
	)


# --------------------------------------------------
# ACTIVATE SCHOOL YEAR
# --------------------------------------------------

func _activate_school_year(year_id: String) -> void:
	if year_id.is_empty():
		return

	for year in school_years:
		if str(year.get("id", "")) == year_id and bool(year.get("archived", false)):
			_show_error("Archived school years cannot be activated.")
			return

	request_queue.clear()
	assignment_jobs.clear()

	for year in school_years:
		var other_id := str(year.get("id", ""))
		if other_id != year_id and bool(year.get("active", false)):
			request_queue.append({
				"action": "deactivate_year",
				"path": SCHOOL_YEARS_COLLECTION + "/" + other_id,
				"fields": {"active": false}
			})

	request_queue.append({
		"action": "activate_year",
		"path": SCHOOL_YEARS_COLLECTION + "/" + year_id,
		"fields": {"active": true},
		"context": {"year_id": year_id}
	})

	_set_busy(true)
	_send_next_queued_request()


func _send_next_queued_request() -> void:
	if request_queue.is_empty():
		_load_school_years()
		return

	var job: Dictionary = request_queue.pop_front()
	_send_patch(
		str(job.get("action", "")),
		str(job.get("path", "")),
		job.get("fields", {}),
		job.get("context", {})
	)

func _populate_archive_menu() -> void:
	# Remove old slots before rebuilding the list.
	for child in archive_slots_container.get_children():
		archive_slots_container.remove_child(child)
		child.queue_free()

	selected_archive_year_id = ""

	for year in school_years:
		var slot := preload(
			"res://Scenes/Admin/HeadTeacher/archive_slot.tscn"
		).instantiate() as ArchiveSlot

		archive_slots_container.add_child(slot)
		slot.setup(year)

		if slot.slot_selected.is_connected(_on_archive_slot_selected):
			slot.slot_selected.disconnect(_on_archive_slot_selected)

		slot.slot_selected.connect(_on_archive_slot_selected)

	if school_years.is_empty():
		_show_error("No school years were found.")


func _on_archive_slot_selected(year_id: String) -> void:
	selected_archive_year_id = year_id

	for child in archive_slots_container.get_children():
		if child is ArchiveSlot:
			child.set_selected(child.year_id == selected_archive_year_id)


func _on_archive_menu_cancel_pressed() -> void:
	selected_archive_year_id = ""
	archive_menu.hide()


func _on_archive_menu_continue_pressed() -> void:
	if selected_archive_year_id.is_empty():
		_show_error("Select an inactive school year first.")
		return

	var selected_year: Dictionary = {}

	for year in school_years:
		if str(year.get("id", "")) == selected_archive_year_id:
			selected_year = year
			break

	if selected_year.is_empty():
		_show_error("The selected school year could not be found.")
		return

	if bool(selected_year.get("archived", false)):
		_show_error("This school year is already archived.")
		return

	if bool(selected_year.get("active", false)):
		_show_error("The active school year cannot be archived.")
		return

	var year_id := selected_archive_year_id
	var year_name := str(selected_year.get("name", year_id))

	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm Archive"
	dialog.dialog_text = (
		"Are you sure you want to archive %s?\n"
		+ "Its historical records should be preserved."
	) % year_name

	add_child(dialog)

	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		archive_menu.hide()
		_archive_school_year(year_id)
	)

	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	dialog.popup_centered()

# --------------------------------------------------
# ARCHIVE SCHOOL YEAR
# --------------------------------------------------

func _on_archive_button_pressed() -> void:
	selected_archive_year_id = ""
	_populate_archive_menu()
	archive_menu.show()


func _archive_school_year(year_id: String) -> void:
	_set_busy(true)
	_send_patch(
		"archive_year",
		SCHOOL_YEARS_COLLECTION + "/" + year_id,
		{"archived": true, "active": false},
		{"year_id": year_id}
	)


# --------------------------------------------------
# SECTION MANAGEMENT
# --------------------------------------------------

func _resolve_selected_year_id() -> String:
	var index := year_selector.selected

	if index >= 0 and index < year_selector.item_count:
		var dropdown_id := str(year_selector.get_item_metadata(index))
		if not dropdown_id.is_empty():
			selected_year_id = dropdown_id
			return dropdown_id

	if not active_year_id.is_empty():
		for year in school_years:
			if str(year.get("id", "")) == active_year_id and not bool(year.get("archived", false)):
				selected_year_id = active_year_id
				return active_year_id

	for year in school_years:
		if not bool(year.get("archived", false)):
			var year_id := str(year.get("id", ""))
			if not year_id.is_empty():
				selected_year_id = year_id
				return year_id

	return ""


func _on_add_section_pressed() -> void:
	var year_id := _resolve_selected_year_id()

	if year_id.is_empty():
		_show_error("Select or create a school year first.")
		return

	if _is_year_archived(year_id):
		_show_error(
			"Archived school years are read-only. Restore the year before editing sections."
		)
		return

	var section_name := section_input.text.strip_edges()

	if section_name.is_empty():
		_show_error("Enter a section name.")
		section_input.grab_focus()
		return

	for section in sections:
		if str(section.get("name", "")).strip_edges().to_lower() == section_name.to_lower():
			if editing_section_id.is_empty() or str(section.get("id", "")) != editing_section_id:
				_show_error("That section already exists in this school year.")
				return

	if editing_section_id.is_empty():
		_create_section_for_year(year_id, section_name)
	else:
		_update_section_for_year(year_id, editing_section_id, section_name)

func _create_section_for_year(year_id: String, section_name: String) -> void:
	var section_id := section_name.replace("/", "-").replace(" ", "_")
	var path := (
		SCHOOL_YEARS_COLLECTION
		+ "/" + year_id
		+ "/sections/" + section_id
	)

	var body: Dictionary = {
		"fields": {
			"name": {"stringValue": section_name},
			"student_count": {"integerValue": "0"},
			"created_by": {"stringValue": current_uid}
		}
	}

	print("[SchoolYearSections] Creating section under year ID: ", year_id)
	print("[SchoolYearSections] Firestore path: ", path)

	_set_busy(true)
	_send_request(
		"create_section",
		HTTPClient.METHOD_PATCH,
		_firestore_url(path),
		body,
		{
			"year_id": year_id,
			"section_id": section_id,
			"section_name": section_name
		}
	)


func _update_section_for_year(
	year_id: String,
	section_id: String,
	section_name: String
) -> void:
	var path := (
		SCHOOL_YEARS_COLLECTION
		+ "/" + year_id
		+ "/sections/" + section_id
	)

	_set_busy(true)
	_send_patch(
		"update_section",
		path,
		{"name": section_name},
		{
			"year_id": year_id,
			"section_id": section_id,
			"section_name": section_name
		}
	)


func _load_sections() -> void:
	sections.clear()
	_clear_section_cards()

	if selected_year_id.is_empty():
		_set_busy(false)
		return

	var path := SCHOOL_YEARS_COLLECTION + "/" + selected_year_id + "/sections"

	_send_request(
		"load_sections",
		HTTPClient.METHOD_GET,
		_firestore_url(path)
	)


func _parse_sections(response: Dictionary) -> void:
	sections.clear()

	for document in response.get("documents", []):
		if document is Dictionary:
			var section := _parse_document(document)
			section["student_count"] = int(section.get("student_count", 0))
			sections.append(section)

	_refresh_section_cards()
	_set_busy(false)


func _clear_section_cards() -> void:
	for child in section_grid.get_children():
		section_grid.remove_child(child)
		child.queue_free()

func _get_section_teacher_name(section: Dictionary) -> String:
	var assigned_ids: Array = section.get("assigned_teacher_ids", [])

	for teacher in teachers:
		var teacher_uid := str(teacher.get("uid", ""))

		if assigned_ids.has(teacher_uid):
			return str(teacher.get("name", "Unnamed teacher"))

	return "Unassigned"

func _refresh_section_cards() -> void:
	_clear_section_cards()

	for section in sections:
		var card: Node = CLASS_CARD_SCENE.instantiate()
		section_grid.add_child(card)

		if card.has_method("setup"):
			card.call(
				"setup",
				str(section.get("id", "")),
				str(section.get("name", "Unnamed section")),
				int(section.get("student_count", 0))
			)

		# Display the assigned teacher's name on the card.
		if card.has_method("set_teacher"):
			card.call(
				"set_teacher",
				_get_section_teacher_name(section)
			)

		if card.has_signal("assign_requested"):
			if not card.assign_requested.is_connected(
				_on_section_assign_requested
			):
				card.assign_requested.connect(
					_on_section_assign_requested
				)

		if card.has_signal("edit_requested"):
			if not card.edit_requested.is_connected(
				_on_section_edit_requested
			):
				card.edit_requested.connect(
					_on_section_edit_requested
				)

		if card.has_signal("delete_requested"):
			if not card.delete_requested.is_connected(
				_on_section_delete_requested
			):
				card.delete_requested.connect(
					_on_section_delete_requested
				)

func _set_section_button_label(new_text: String) -> void:
	add_section_button.text = new_text

	for child in add_section_button.find_children("*", "Label", true, false):
		if child is Label:
			child.text = new_text

func _on_section_edit_requested(section_id: String, section_name: String) -> void:
	if _is_year_archived(selected_year_id):
		_show_error("Archived school years are read-only.")
		return

	editing_section_id = section_id
	section_input.text = section_name
	_set_section_button_label("Update Section")
	section_input.grab_focus()


func _reset_section_button() -> void:
	editing_section_id = ""
	section_input.clear()
	_set_section_button_label("Add Section")


func _on_section_delete_requested(section_id: String, section_name: String) -> void:
	if _is_year_archived(selected_year_id):
		_show_error("Archived school years are read-only.")
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Section"
	dialog.dialog_text = "Delete section %s?" % section_name
	add_child(dialog)

	var year_id := selected_year_id
	dialog.confirmed.connect(func() -> void:
		_delete_section(section_id, year_id, section_name)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	dialog.popup_centered()


func _delete_section(
	section_id: String,
	year_id: String,
	section_name: String
) -> void:
	if year_id.is_empty():
		_show_error("Select a school year first.")
		return

	var path := SCHOOL_YEARS_COLLECTION + "/" + year_id + "/sections/" + section_id

	_set_busy(true)
	_send_request(
		"delete_section",
		HTTPClient.METHOD_DELETE,
		_firestore_url(path),
		{},
		{
			"year_id": year_id,
			"section_id": section_id,
			"section_name": section_name
		}
	)

func _on_section_assign_requested(
	section_id: String,
	section_name: String
) -> void:
	if selected_year_id.is_empty():
		_show_error("Select a school year first.")
		return

	if _is_year_archived(selected_year_id):
		_show_error("Archived school years cannot be modified.")
		return

	if not pending_action.is_empty():
		_show_error("Please wait for the current Firebase request to finish.")
		return

	assignment_section_id = section_id
	assignment_section_name = section_name
	assignment_year_id = selected_year_id
	assignment_year_name = _get_school_year_name(selected_year_id)

	_set_busy(true)

	_send_request(
		"load_teachers_for_assignment",
		HTTPClient.METHOD_GET,
		_firestore_url("/databases/(default)/documents/teachers")
	)
	
func _get_school_year_name(year_id: String) -> String:
	for year in school_years:
		if str(year.get("id", "")) == year_id:
			return str(year.get("name", ""))

	return year_id
	
func _parse_teachers_for_assignment(response: Dictionary) -> void:
	teachers.clear()

	for document in response.get("documents", []):
		if not document is Dictionary:
			continue

		var teacher := _parse_document(document)
		var uid := str(teacher.get("uid", teacher.get("id", "")))
		var role := str(teacher.get("role", "teacher")).to_lower()
		var status := str(teacher.get("status", "active")).to_lower()

		if uid.is_empty():
			continue

		if role != "teacher" or status != "active":
			continue

		teacher["uid"] = uid
		teachers.append(teacher)

	_set_busy(false)
	_show_teacher_assignment_dialog()


func _show_teacher_assignment_dialog() -> void:
	teacher_selection_title.text = "Assign Teachers"

	teacher_selection_subtitle.text = (
		"Section: %s | School Year: %s"
		% [assignment_section_name, assignment_year_name]
	)

	_populate_teacher_list()
	teacher_selection.show()


func _on_teacher_assignment_cancelled() -> void:
	teacher_selection.hide()
	_set_busy(false)


func _on_teacher_assignments_confirmed() -> void:
	teacher_selection.hide()
	if assignment_year_id.is_empty() or assignment_section_id.is_empty():
		_show_error("The selected section is no longer valid.")
		return

	var selected_uids: Array[String] = []

	for checkbox in assignment_checkboxes:
		if checkbox.button_pressed:
			var uid := str(checkbox.get_meta("teacher_uid", ""))

			if not uid.is_empty():
				selected_uids.append(uid)

			# A section can have only one teacher.
			break

	# Save the teacher-side assignments first.
	assignment_jobs.clear()

	for teacher in teachers:
		var uid := str(teacher.get("uid", ""))
		var teacher_year_id := str(teacher.get("school_year_id", ""))

		var teacher_section_ids: Array = teacher.get(
			"assigned_section_ids",
			[]
		)

		var was_assigned: bool = (
			teacher_section_ids.has(assignment_section_id)
			and teacher_year_id == assignment_year_id
		)
		var should_be_assigned := uid in selected_uids

		if not was_assigned and not should_be_assigned:
			continue

		var section_ids: Array = teacher.get("assigned_section_ids", [])
		var section_names: Array = teacher.get("assigned_sections", [])

		# A teacher assigned to a different school year starts a fresh
		# assignment list when selected for this year.
		if should_be_assigned and teacher_year_id != assignment_year_id:
			section_ids = []
			section_names = []

		section_ids = section_ids.duplicate()
		section_names = section_names.duplicate()

		if should_be_assigned:
			if assignment_section_id not in section_ids:
				section_ids.append(assignment_section_id)

			if assignment_section_name not in section_names:
				section_names.append(assignment_section_name)
		else:
			section_ids.erase(assignment_section_id)
			section_names.erase(assignment_section_name)

		var fields: Dictionary = {
			"assigned_section_ids": section_ids,
			"assigned_sections": section_names,
		}

		if should_be_assigned:
			fields["school_year_id"] = assignment_year_id
			fields["school_year"] = assignment_year_name

		assignment_jobs.append({
			"path": "/databases/(default)/documents/teachers/" + uid,
			"fields": fields,
		})

	# Save the section-side assignment list last.
	assignment_jobs.append({
		"path": (
			SCHOOL_YEARS_COLLECTION
			+ "/" + assignment_year_id
			+ "/sections/" + assignment_section_id
		),
		"fields": {
			"assigned_teacher_ids": selected_uids
		},
		"is_section": true,
		"context": {
			"section_id": assignment_section_id,
			"section_name": assignment_section_name,
			"year_id": assignment_year_id,
			"year_name": assignment_year_name
		}
	})

	_set_busy(true)
	_send_next_assignment_job()
	
func _send_next_assignment_job() -> void:
	if assignment_jobs.is_empty():
		_set_busy(false)
		_load_sections()
		return

	var job: Dictionary = assignment_jobs.pop_front()
	var is_section: bool = bool(job.get("is_section", false))

	_send_patch(
		"assignment_section_write" if is_section else "assignment_teacher_write",
		str(job.get("path", "")),
		job.get("fields", {}),
		job.get("context", {})
	)

# --------------------------------------------------
# HTTP RESPONSE HANDLER
# --------------------------------------------------

func _on_request_completed(
	result: int,
	response_code: int,
	_headers_received: PackedStringArray,
	body: PackedByteArray
) -> void:
	var action := pending_action
	var context := request_context.duplicate(true)
	pending_action = ""
	request_context.clear()

	var response_text := body.get_string_from_utf8()
	var response: Dictionary = {}

	if not response_text.is_empty():
		var parsed: Variant = JSON.parse_string(response_text)
		if parsed is Dictionary:
			response = parsed

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_error(
			"Firestore request failed. Action: %s, HTTP: %d, Response: %s"
			% [action, response_code, response_text]
		)
		request_queue.clear()
		_set_busy(false)
		_show_error(
			"Firebase request failed (%d). Check the debugger and Firestore rules."
			% response_code
		)
		return

	match action:
		"load_years":
			_parse_school_years(response)

		"create_year":
			var created_year_id := str(context.get("year_id", ""))

			ActivityLogManager.log_activity(
				"Created School Year",
				"Created school year: " + created_year_id,
				"School Year",
				created_year_id
			)

			_load_school_years()

		"deactivate_year":
			_send_next_queued_request()

		"activate_year":
			var activated_year_id := str(context.get("year_id", ""))

			ActivityLogManager.log_activity(
				"Activated School Year",
				"Activated school year: " + activated_year_id,
				"School Year",
				activated_year_id
			)

			_load_school_years()

		"archive_year":
			var archived_year_id := str(context.get("year_id", ""))

			ActivityLogManager.log_activity(
				"Archived School Year",
				"Archived school year: " + archived_year_id,
				"School Year",
				archived_year_id
			)

			selected_archive_year_id = ""
			archive_menu.hide()
			_load_school_years()

		"load_sections":
			_parse_sections(response)

			if not selected_year_id.is_empty():
				_send_request(
					"load_teachers_for_cards",
					HTTPClient.METHOD_GET,
					_firestore_url("/databases/(default)/documents/teachers")
				)

		"load_teachers_for_cards":
			_parse_teachers_for_cards(response)

			# Load students after the sections and teachers.
			_send_request(
				"load_students_for_cards",
				HTTPClient.METHOD_GET,
				_firestore_url("/databases/(default)/documents/students")
			)

		"load_students_for_cards":
			_parse_students_for_cards(response)

		"restore_year":
			var restored_year_id := str(context.get("year_id", ""))

			ActivityLogManager.log_activity(
				"Restored School Year",
				"Restored school year: " + restored_year_id,
				"School Year",
				restored_year_id
			)

			_load_school_years()

		"create_section":
			var created_section_year_id := str(context.get("year_id", ""))
			var section_id := str(context.get("section_id", ""))
			var section_name := str(context.get("section_name", ""))

			ActivityLogManager.log_activity(
				"Created Section",
				"Created section '%s' in school year %s"
				% [section_name, created_section_year_id],
				"Sections",
				section_id
			)

			_reset_section_button()
			_load_sections()

		"update_section":
			var updated_section_year_id := str(context.get("year_id", ""))
			var section_id := str(context.get("section_id", ""))
			var section_name := str(context.get("section_name", ""))

			ActivityLogManager.log_activity(
				"Updated Section",
				"Updated section '%s' in school year %s"
				% [section_name, updated_section_year_id],
				"Sections",
				section_id
			)

			_reset_section_button()
			_load_sections()

		"delete_section":
			var deleted_section_year_id := str(context.get("year_id", ""))
			var section_id := str(context.get("section_id", ""))
			var section_name := str(context.get("section_name", section_id))

			ActivityLogManager.log_activity(
				"Deleted Section",
				"Deleted section '%s' from school year %s"
				% [section_name, deleted_section_year_id],
				"Sections",
				section_id
			)

			_reset_section_button()
			_load_sections()

		"load_teachers_for_assignment":
			_parse_teachers_for_assignment(response)

		"assignment_teacher_write":
			_send_next_assignment_job()

		"assignment_section_write":
			ActivityLogManager.log_activity(
				"Updated Teacher Assignment",
				"Updated teacher assignment for section '%s' in school year '%s'"
				% [assignment_section_name, assignment_year_name],
				"Teacher Assignment",
				assignment_section_id
			)

			assignment_jobs.clear()
			_set_busy(false)
			_load_sections()
	
# --------------------------------------------------
# UI HELPERS
# --------------------------------------------------

func _set_busy(busy: bool) -> void:
	add_year_button.disabled = busy
	archive_button.disabled = busy
	add_section_button.disabled = busy
	year_selector.disabled = busy
	create_year_button.disabled = busy
	cancel_year_button.disabled = busy


func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "School Year / Sections"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	dialog.popup_centered()

func _confirm_restore_school_year(year_id: String) -> void:
	var year_name := year_id

	for year in school_years:
		if str(year.get("id", "")) == year_id:
			year_name = str(year.get("name", year_id))
			break

	var dialog := ConfirmationDialog.new()
	dialog.title = "Restore School Year"
	dialog.dialog_text = (
		"Restore %s?\nIt will remain inactive until you select it as the active year."
		% year_name
	)
	add_child(dialog)

	dialog.confirmed.connect(func() -> void:
		_restore_school_year(year_id)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	dialog.popup_centered()


func _restore_school_year(year_id: String) -> void:
	if year_id.is_empty():
		return

	_set_busy(true)

	_send_patch(
		"restore_year",
		SCHOOL_YEARS_COLLECTION + "/" + year_id,
		{
			"archived": false,
			"active": false
		},
		{"year_id": year_id}
	)

func _clear_teacher_list() -> void:
	for child in teacher_list.get_children():
		teacher_list.remove_child(child)
		child.queue_free()


func _populate_teacher_list() -> void:
	_clear_teacher_list()
	assignment_checkboxes.clear()
	
	# Only one teacher can be selected for this section.
	assignment_button_group = ButtonGroup.new()
	assignment_button_group.allow_unpress = true

	var list := VBoxContainer.new()
	list.name = "TeacherList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)

	teacher_list.add_child(list)

	var section_data: Dictionary = {}

	for section in sections:
		if str(section.get("id", "")) == assignment_section_id:
			section_data = section
			break

	var assigned_ids: Array = section_data.get(
		"assigned_teacher_ids",
		[]
	)

	for teacher in teachers:
		var uid := str(teacher.get("uid", ""))
		var teacher_name := str(teacher.get("name", "Unnamed teacher"))
		var email := str(teacher.get("email", ""))

		var checkbox := CheckBox.new()
		checkbox.text = teacher_name + " (" + email + ")"

		# Make the teacher selections mutually exclusive.
		checkbox.button_group = assignment_button_group

		checkbox.add_theme_font_size_override("font_size", 16)
		checkbox.add_theme_color_override("font_color", Color("#5b4030"))
		checkbox.add_theme_color_override("font_hover_color", Color("#181a29"))
		checkbox.add_theme_color_override("font_pressed_color", Color("#e08f0b"))
		checkbox.add_theme_color_override("font_disabled_color", Color("#8a7765"))

		checkbox.set_meta("teacher_uid", uid)
		checkbox.custom_minimum_size = Vector2(450, 45)
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.button_pressed = assigned_ids.has(uid)

		assignment_checkboxes.append(checkbox)
		list.add_child(checkbox)

	if teachers.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No active teachers found."
		list.add_child(empty_label)

func _parse_teachers_for_cards(response: Dictionary) -> void:
	teachers.clear()

	for document in response.get("documents", []):
		if not document is Dictionary:
			continue

		var teacher := _parse_document(document)
		var uid := str(teacher.get("uid", teacher.get("id", "")))

		if uid.is_empty():
			continue
			
		if str(teacher.get("status", "active")).to_lower() != "active":
			continue

		if str(teacher.get("role", "")).to_lower() != "teacher":
			continue

		teacher["uid"] = uid
		teachers.append(teacher)

	_refresh_section_cards()

func _parse_students_for_cards(response: Dictionary) -> void:
	students.clear()

	for document in response.get("documents", []):
		if document is Dictionary:
			var student := _parse_document(document)
			students.append(student)

	_update_section_student_counts()

	_refresh_section_cards()
	_set_busy(false)


func _update_section_student_counts() -> void:
	var selected_school_year := selected_year_id.strip_edges()

	for section in sections:
		var section_name := str(
			section.get("name", "")
		).strip_edges()

		var count := 0

		for student in students:
			var student_section := str(
				student.get("section", "")
			).strip_edges()

			var student_school_year := str(
				student.get("school_year", "")
			).strip_edges()

			var student_status := str(
				student.get("status", "")
			).strip_edges().to_lower()

			if (
				student_section == section_name
				and student_school_year == selected_school_year
				and student_status == "active"
			):
				count += 1

		section["student_count"] = count

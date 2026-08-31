extends Panel

signal student_clicked(student_data: Dictionary)

var student_data: Dictionary = {}
var row_number: int = 0

@onready var click_area: Button = $ClickArea

@onready var number_label: Label = $MarginContainer/Columns/Control/Number

@onready var student_id_label: Label = $MarginContainer/Columns/Control/StudentInfo/Control/StudentID
@onready var name_label: Label = $MarginContainer/Columns/Control/StudentInfo/Control/Name
@onready var email_label: Label = $MarginContainer/Columns/Control/Email
@onready var section_label: Label = $MarginContainer/Columns/Control/Section

@onready var elements_label: Label = $MarginContainer/Columns/Control/Elements

@onready var progress_bar: ProgressBar = $MarginContainer/Columns/Control/ProgressContainer/ProgressBar
@onready var progress_text: Label = $MarginContainer/Columns/Control/ProgressContainer/ProgressText

@onready var status_label: Label = $MarginContainer/Columns/Control/Status
@onready var last_active_label: Label = $MarginContainer/Columns/Control/LastActive


func _ready() -> void:
	if not click_area.pressed.is_connected(_on_click_area_pressed):
		click_area.pressed.connect(_on_click_area_pressed)

	if not student_data.is_empty():
		display_student()


func setup(data: Dictionary, number: int) -> void:
	student_data = data
	row_number = number

	if is_node_ready():
		display_student()


func display_student() -> void:

	# ========================================================
	# BASIC INFORMATION
	# ========================================================

	var student_id := str(
		student_data.get("student_id", "")
	)

	var student_name := str(
		student_data.get("name", "Unknown Student")
	)

	var email := str(
		student_data.get("email", "No email")
	)

	var section := str(
		student_data.get("section", "")
	)


	# ========================================================
	# NUMBER
	# ========================================================

	number_label.text = "%02d" % row_number


	# ========================================================
	# STUDENT INFORMATION
	# ========================================================

	student_id_label.text = student_id
	name_label.text = student_name
	email_label.text = email
	section_label.text = section


	# ========================================================
	# ELEMENT PROGRESS
	# ========================================================

	var collected := get_elements_collected()
	var total := get_elements_total()
	var progress_percent := get_student_progress()


	elements_label.text = "%d / %d" % [
		collected,
		total
	]


	# ========================================================
	# PROGRESS BAR
	# ========================================================

	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = progress_percent

	progress_text.text = "%d%%" % int(
		round(progress_percent)
	)


	# ========================================================
	# STATUS / LAST ACTIVE
	# ========================================================

	var last_active := int(
		student_data.get("last_active", 0)
	)

	if last_active <= 0:

		status_label.text = "Inactive"
		last_active_label.text = "Never"

	else:

		var current_time := int(
			Time.get_unix_time_from_system()
		)

		var elapsed := current_time - last_active

		if elapsed <= 300:
			status_label.text = "Active"
		else:
			status_label.text = "Inactive"

		last_active_label.text = format_last_active(last_active)


	# ========================================================
	# DEBUG
	# ========================================================

	print(
		"[StudentRow] ",
		student_id,
		" | ",
		student_name,
		" | ",
		section
	)


# ============================================================
# ELEMENT PROGRESS
# ============================================================

func get_elements_collected() -> int:

	var progress_value = student_data.get(
		"progress",
		{}
	)

	if not progress_value is Dictionary:
		return 0

	var progress: Dictionary = progress_value

	return clamp(
		int(
			progress.get(
				"elements_collected",
				0
			)
		),
		0,
		118
	)


func get_elements_total() -> int:

	var progress_value = student_data.get(
		"progress",
		{}
	)

	if not progress_value is Dictionary:
		return 118

	var progress: Dictionary = progress_value

	var total := int(
		progress.get(
			"elements_total",
			118
		)
	)

	if total <= 0:
		return 118

	return total


func get_student_progress() -> float:

	var collected := get_elements_collected()
	var total := get_elements_total()

	if total <= 0:
		return 0.0

	return clamp(
		float(collected) / float(total) * 100.0,
		0.0,
		100.0
	)


# ============================================================
# LAST ACTIVE
# ============================================================

func format_last_active(timestamp: int) -> String:

	if timestamp <= 0:
		return "Never"

	var current_time := int(
		Time.get_unix_time_from_system()
	)

	var elapsed := current_time - timestamp

	if elapsed < 0:
		return "Just now"

	if elapsed < 60:
		return "Just now"

	if elapsed < 3600:

		var minutes := int(elapsed / 60)

		return "%d min ago" % minutes

	if elapsed < 86400:

		var hours := int(elapsed / 3600)

		return "%d hr ago" % hours

	if elapsed < 604800:

		var days := int(elapsed / 86400)

		return "%d day%s ago" % [
			days,
			"" if days == 1 else "s"
		]

	var datetime := Time.get_datetime_dict_from_unix_time(
		timestamp
	)

	return "%04d-%02d-%02d" % [
		datetime.year,
		datetime.month,
		datetime.day
	]


# ============================================================
# ROW CLICK
# ============================================================

func _on_click_area_pressed() -> void:

	student_clicked.emit(student_data)

	

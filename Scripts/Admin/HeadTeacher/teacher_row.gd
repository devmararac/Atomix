
extends HBoxContainer

# ============================================================
# TEACHER ROW
# ============================================================

var teacher_data: Dictionary = {}


# ============================================================
# UI REFERENCES
# ============================================================

@onready var number_label: Label = $Control/Number
@onready var teacher_label: Label = $Control/Teacher
@onready var email_label: Label = $Control/Email
@onready var school_year_label: Label = $Control/SchoolYear
@onready var sections_label: Label = $Control/Sections
@onready var status_label: Label = $Control/Status
@onready var last_active_label: Label = $Control/LastActive


# ============================================================
# SET TEACHER DATA
# ============================================================

func set_teacher_data(
	data: Dictionary,
	row_number: int
) -> void:

	teacher_data = data.duplicate(true)

	# --------------------------------------------------------
	# Basic information
	# --------------------------------------------------------

	var teacher_name: String = str(
		teacher_data.get(
			"name",
			"Unknown"
		)
	)

	var email: String = str(
		teacher_data.get(
			"email",
			"No email"
		)
	)

	var school_year: String = str(
		teacher_data.get(
			"school_year",
			""
		)
	)

	# --------------------------------------------------------
	# Status
	# --------------------------------------------------------

	var status: String = str(
		teacher_data.get(
			"status",
			"inactive"
		)
	)

	if status.is_empty():
		status = "inactive"


	# --------------------------------------------------------
	# Assigned sections
	# --------------------------------------------------------

	var sections_text: String = "None"

	var sections_value = teacher_data.get(
		"assigned_sections",
		[]
	)

	if sections_value is Array:

		var sections: Array = sections_value

		if not sections.is_empty():

			var section_names: Array[String] = []

			for section in sections:

				section_names.append(
					str(section)
				)

			sections_text = ", ".join(
				section_names
			)

	elif sections_value is String:

		var section_string: String = str(
			sections_value
		)

		if not section_string.is_empty():

			sections_text = section_string


	# --------------------------------------------------------
	# Last active
	# --------------------------------------------------------

	var last_active_value = teacher_data.get(
		"last_active",
		0
	)

	var last_active_text: String = _format_last_active(
		last_active_value
	)


	# ========================================================
	# UPDATE UI
	# ========================================================

	number_label.text = str(
		row_number
	)

	teacher_label.text = teacher_name

	email_label.text = email

	school_year_label.text = school_year

	sections_label.text = sections_text

	status_label.text = status.capitalize()

	last_active_label.text = last_active_text


	# --------------------------------------------------------
	# Optional status styling
	# --------------------------------------------------------

	_update_status_style(status)


# ============================================================
# STATUS STYLE
# ============================================================

func _update_status_style(
	status: String
) -> void:

	# Keep the same base color as your existing design.
	status_label.add_theme_color_override(
		"font_color",
		Color(
			0.47058824,
			0.3529412,
			0.23529412,
			1
		)
	)


# ============================================================
# FORMAT LAST ACTIVE
# ============================================================

func _format_last_active(
	value
) -> String:

	if value == null:
		return "Never"


	var timestamp: int = 0


	# --------------------------------------------------------
	# Integer
	# --------------------------------------------------------

	if value is int:

		timestamp = int(value)


	# --------------------------------------------------------
	# Float
	# --------------------------------------------------------

	elif value is float:

		timestamp = int(value)


	# --------------------------------------------------------
	# String
	# --------------------------------------------------------

	elif value is String:

		var text_value: String = value.strip_edges()

		if text_value.is_valid_int():

			timestamp = int(
				text_value
			)

		elif text_value.is_valid_float():

			timestamp = int(
				float(text_value)
			)


	# --------------------------------------------------------
	# Firestore timestamp dictionary
	# --------------------------------------------------------

	elif value is Dictionary:

		if value.has("seconds"):

			var seconds_value = value.get(
				"seconds",
				0
			)

			if seconds_value is int:

				timestamp = int(
					seconds_value
				)

			elif seconds_value is float:

				timestamp = int(
					seconds_value
				)

			elif seconds_value is String:

				if seconds_value.is_valid_int():

					timestamp = int(
						seconds_value
					)


	# --------------------------------------------------------
	# No valid timestamp
	# --------------------------------------------------------

	if timestamp <= 0:

		return "Never"


	# ========================================================
	# CALCULATE TIME DIFFERENCE
	# ========================================================

	var current_time: int = int(
		Time.get_unix_time_from_system()
	)

	var difference: int = (
		current_time
		-
		timestamp
	)


	if difference < 0:

		return "Just now"


	# --------------------------------------------------------
	# Less than one minute
	# --------------------------------------------------------

	if difference < 60:

		return "Just now"


	# --------------------------------------------------------
	# Minutes
	# --------------------------------------------------------

	if difference < 3600:

		var minutes: int = int(
			difference / 60
		)

		if minutes == 1:

			return "1 minute ago"

		return str(minutes) + " minutes ago"


	# --------------------------------------------------------
	# Hours
	# --------------------------------------------------------

	if difference < 86400:

		var hours: int = int(
			difference / 3600
		)

		if hours == 1:

			return "1 hour ago"

		return str(hours) + " hours ago"


	# --------------------------------------------------------
	# Days
	# --------------------------------------------------------

	if difference < 604800:

		var days: int = int(
			difference / 86400
		)

		if days == 1:

			return "Yesterday"

		return str(days) + " days ago"


	# --------------------------------------------------------
	# Older than one week
	# --------------------------------------------------------

	var date: Dictionary = (
		Time.get_date_dict_from_unix_time(
			timestamp
		)
	)

	return "%04d-%02d-%02d" % [
		int(date.get("year", 0)),
		int(date.get("month", 0)),
		int(date.get("day", 0))
	]

extends Panel

signal student_clicked(student_data: Dictionary)

var student_data: Dictionary = {}
var row_number: int = 0

@onready var click_button: Button = $Button

@onready var view_button: TextureButton = \
	$TableHeader/HBoxContainer/HBoxContainer/TextureButton

@onready var number_label: Label = \
	$TableHeader/HBoxContainer/Number

@onready var name_label: Label = \
	$TableHeader/HBoxContainer/FullName

@onready var lrn_label: Label = \
	$TableHeader/HBoxContainer/LRN

@onready var section_label: Label = \
	$TableHeader/HBoxContainer/Section

@onready var status_label: Label = \
	$TableHeader/HBoxContainer/Status


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	# The row itself is no longer clickable.
	if is_instance_valid(click_button):
		click_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect only the View button.
	if is_instance_valid(view_button):
		if not view_button.pressed.is_connected(_on_view_pressed):
			view_button.pressed.connect(_on_view_pressed)

	if not student_data.is_empty():
		display_student()


# ============================================================
# SETUP
# ============================================================

func setup(data: Dictionary, number: int) -> void:

	student_data = data.duplicate(true)
	row_number = number

	if is_node_ready():
		display_student()


# ============================================================
# DISPLAY STUDENT
# ============================================================

func display_student() -> void:

	number_label.text = str(row_number)

	# --------------------------------------------------------
	# NAME
	# --------------------------------------------------------

	var student_name: String = str(
		student_data.get("name", "")
	).strip_edges()

	if student_name.is_empty():

		var first_name: String = str(
			student_data.get("first_name", "")
		).strip_edges()

		var last_name: String = str(
			student_data.get("last_name", "")
		).strip_edges()

		student_name = (
			first_name + " " + last_name
		).strip_edges()

	if student_name.is_empty():
		student_name = "Unknown Student"

	name_label.text = student_name

	# --------------------------------------------------------
	# LRN / STUDENT ID
	# --------------------------------------------------------

	var student_id: String = str(
		student_data.get(
			"lrn",
			student_data.get(
				"student_id",
				student_data.get("id_number", "")
			)
		)
	).strip_edges()

	lrn_label.text = (
		student_id if not student_id.is_empty() else "—"
	)

	# --------------------------------------------------------
	# SECTION
	# --------------------------------------------------------

	section_label.text = _get_section_text(
		student_data.get("section", "")
	)

	# --------------------------------------------------------
	# STATUS
	# --------------------------------------------------------

	var status: String = str(
		student_data.get("status", "inactive")
	).strip_edges().to_lower()

	if status.is_empty():
		status = "inactive"

	status_label.text = status.capitalize()

	_update_status_style(status)


# ============================================================
# SECTION FORMATTER
# ============================================================

func _get_section_text(value: Variant) -> String:

	if value is Array:

		var names: Array[String] = []

		for item in value:

			var section_name: String = str(
				item
			).strip_edges()

			if not section_name.is_empty():
				names.append(section_name)

		return (
			", ".join(names)
			if not names.is_empty()
			else "—"
		)

	if value is Dictionary:

		var section_name: String = str(
			value.get("name", "")
		).strip_edges()

		return (
			section_name
			if not section_name.is_empty()
			else "—"
		)

	var section_name: String = str(
		value
	).strip_edges()

	return (
		section_name
		if not section_name.is_empty()
		else "—"
	)


# ============================================================
# STATUS STYLE
# ============================================================

func _update_status_style(status: String) -> void:

	var color: Color = Color("#8B8178")

	match status:

		"active":
			color = Color("#22C55E")

		"inactive":
			color = Color("#EF4444")

		"archived":
			color = Color("#9CA3AF")

	status_label.add_theme_color_override(
		"font_color",
		color
	)


# ============================================================
# VIEW STUDENT
# ============================================================

func _on_view_pressed() -> void:

	print("[StudentRow] View clicked.")
	print("[StudentRow] Student: ", student_data)

	student_clicked.emit(
		student_data
	)

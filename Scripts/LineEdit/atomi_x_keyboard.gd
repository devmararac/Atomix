extends Control

var target_line_edit: LineEdit = null
var shift_enabled: bool = false
var number_mode: bool = false

# ============================================================
# KEYBOARD LAYOUT
# ============================================================

const SIDE_MARGIN := 18.0
const KEY_GAP := 8.0

const TOP_MARGIN := 78.0
const BOTTOM_MARGIN := 6.0

const PREVIEW_HEIGHT := 62.0
const PREVIEW_TOP := 8.0

const ROW_GAP := 7.0

# Width of each row relative to the keyboard.
# 1.0 = full available width.
const QWERTY_WIDTH := 1.0
const HOME_WIDTH := 0.92
const BOTTOM_WIDTH := 0.78


func _ready() -> void:
	hide()

	_connect_keyboard_buttons()

	resized.connect(_update_keyboard_layout)

	call_deferred("_update_keyboard_layout")


# ============================================================
# BUTTON CONNECTION
# ============================================================

func _connect_keyboard_buttons() -> void:
	for child in get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_NONE
			child.pressed.connect(_on_key_pressed.bind(child))


# ============================================================
# SHOW / HIDE
# ============================================================

func show_for(line_edit: LineEdit) -> void:
	if line_edit == null:
		return

	line_edit.virtual_keyboard_enabled = false
	line_edit.virtual_keyboard_show_on_focus = false

	DisplayServer.virtual_keyboard_hide()

	target_line_edit = line_edit
	shift_enabled = false
	number_mode = false
	
	_update_input_preview()
	_update_letter_keys()
	_update_keyboard_visibility()
	_update_keyboard_layout()

	show()

func _disable_native_keyboard(line_edit: LineEdit) -> void:
	if line_edit == null:
		return

	line_edit.virtual_keyboard_enabled = false
	line_edit.virtual_keyboard_show_on_focus = false

func hide_keyboard() -> void:
	target_line_edit = null
	hide()


# ============================================================
# RESPONSIVE KEYBOARD LAYOUT
# ============================================================

# ============================================================
# RESPONSIVE KEYBOARD LAYOUT
# ============================================================

func _update_keyboard_layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	_update_preview_layout()

	if number_mode:
		_layout_number_keyboard()
	else:
		_layout_letter_keyboard()

# ============================================================
# INPUT PREVIEW LAYOUT
# ============================================================

func _update_preview_layout() -> void:
	var preview := get_node_or_null("InputPreview") as LineEdit

	if preview == null:
		return

	preview.position = Vector2(
		SIDE_MARGIN,
		PREVIEW_TOP
	)

	preview.size = Vector2(
		size.x - (SIDE_MARGIN * 2.0),
		PREVIEW_HEIGHT
	)

func _update_input_preview() -> void:
	if target_line_edit == null:
		return

	var preview := get_node_or_null("InputPreview") as LineEdit

	if preview == null:
		return

	# If the target is a password field, mask the preview.
	if target_line_edit.secret:
		preview.text = "•".repeat(target_line_edit.text.length())
	else:
		preview.text = target_line_edit.text

	# Keep the preview cursor at the end.
	preview.caret_column = preview.text.length()

# ============================================================
# LETTER KEYBOARD
# ============================================================

func _layout_letter_keyboard() -> void:

	var available_width := size.x - (SIDE_MARGIN * 2.0)

	var row_count := 4
	var total_gaps := ROW_GAP * float(row_count - 1)

	var available_height := (
		size.y
		- TOP_MARGIN
		- BOTTOM_MARGIN
		- total_gaps
	)

	var key_height := available_height / float(row_count)

	key_height = clamp(key_height, 50.0, 76.0)

	var keyboard_height := (
		key_height * row_count
		+ total_gaps
	)

	var start_y := TOP_MARGIN


	# --------------------------------------------------------
	# QWERTY
	# --------------------------------------------------------

	_layout_row(
		[
			"Q", "W", "E", "R", "T",
			"Y", "U", "I", "O", "P"
		],
		available_width,
		key_height,
		start_y
	)


	# --------------------------------------------------------
	# HOME
	# --------------------------------------------------------

	_layout_row(
		[
			"A", "S", "D", "F", "G",
			"H", "J", "K", "L"
		],
		available_width * HOME_WIDTH,
		key_height,
		start_y + key_height + ROW_GAP
	)


	# --------------------------------------------------------
	# BOTTOM LETTERS
	# --------------------------------------------------------

	_layout_row(
		[
			"Z", "X", "C", "V",
			"B", "N", "M"
		],
		available_width * BOTTOM_WIDTH,
		key_height,
		start_y + (key_height + ROW_GAP) * 2.0
	)


	# --------------------------------------------------------
	# FUNCTION ROW
	# --------------------------------------------------------

	_layout_letter_function_row(
		key_height,
		start_y + (key_height + ROW_GAP) * 3.0
	)


# ============================================================
# NUMBER / SYMBOL KEYBOARD
# ============================================================

func _layout_number_keyboard() -> void:

	var available_width := size.x - (SIDE_MARGIN * 2.0)

	var row_count := 4
	var total_gaps := ROW_GAP * float(row_count - 1)

	var available_height := (
		size.y
		- TOP_MARGIN
		- BOTTOM_MARGIN
		- total_gaps
	)

	var key_height := available_height / float(row_count)

	key_height = clamp(key_height, 50.0, 76.0)

	var keyboard_height := (
		key_height * row_count
		+ total_gaps
	)

	var start_y := TOP_MARGIN


	# --------------------------------------------------------
	# NUMBERS
	# --------------------------------------------------------

	_layout_row(
		[
			"N1", "N2", "N3", "N4", "N5",
			"N6", "N7", "N8", "N9", "N0"
		],
		available_width,
		key_height,
		start_y
	)


	# --------------------------------------------------------
	# SYMBOL ROW 1
	# --------------------------------------------------------

	_layout_row(
		[
			"At",
			"Hash",
			"Dollar",
			"Percent",
			"Ampersand",
			"Asterisk",
			"Minus",
			"Plus",
			"LeftParen",
			"RightParen"
		],
		available_width,
		key_height,
		start_y + key_height + ROW_GAP
	)


	# --------------------------------------------------------
	# SYMBOL ROW 2
	# --------------------------------------------------------

	_layout_row(
		[
			"Exclamation",
			"Quote",
			"Apostrophe",
			"Colon",
			"Semicolon",
			"Slash",
			"Question",
			"Comma"
		],
		available_width * 0.82,
		key_height,
		start_y + (key_height + ROW_GAP) * 2.0
	)


	# --------------------------------------------------------
	# FUNCTION ROW
	# --------------------------------------------------------

	_layout_number_function_row(
		key_height,
		start_y + (key_height + ROW_GAP) * 3.0
	)


# ============================================================
# GENERIC ROW
# ============================================================

func _layout_row(
	keys: Array[String],
	row_width: float,
	key_height: float,
	y: float
) -> void:

	var gap_count := keys.size() - 1

	var key_width := (
		row_width
		- KEY_GAP * gap_count
	) / float(keys.size())

	var start_x := (
		size.x - row_width
	) / 2.0


	for i in range(keys.size()):

		var button := get_node_or_null(keys[i]) as Button

		if button == null:
			continue

		button.visible = true

		button.position = Vector2(
			start_x + i * (key_width + KEY_GAP),
			y
		)

		button.size = Vector2(
			key_width,
			key_height
		)


# ============================================================
# LETTER FUNCTION ROW
# ============================================================

func _layout_letter_function_row(
	key_height: float,
	y: float
) -> void:

	var keys := [
		["Shift", 1.35],
		["Mode", 1.0],
		["At", 0.75],
		["Dot", 0.75],
		["Space", 2.8],
		["Backspace", 1.25],
		["Enter", 1.25]
	]

	_layout_weighted_row(
		keys,
		key_height,
		y
	)


# ============================================================
# NUMBER FUNCTION ROW
# ============================================================

func _layout_number_function_row(
	key_height: float,
	y: float
) -> void:

	var keys := [
		["Mode", 1.25],
		["Space", 3.2],
		["Backspace", 1.4],
		["Enter", 1.4]
	]

	_layout_weighted_row(
		keys,
		key_height,
		y
	)


# ============================================================
# WEIGHTED ROW
# ============================================================

func _layout_weighted_row(
	keys: Array,
	key_height: float,
	y: float
) -> void:

	var available_width := size.x - (SIDE_MARGIN * 2.0)

	var gap_count := keys.size() - 1

	var usable_width := (
		available_width
		- KEY_GAP * gap_count
	)

	var total_weight := 0.0

	for item in keys:
		total_weight += float(item[1])


	var unit_width := (
		usable_width / total_weight
	)

	var current_x := (
		size.x - available_width
	) / 2.0


	for item in keys:

		var button_name: String = item[0]
		var width_weight: float = item[1]

		var button := get_node_or_null(button_name) as Button

		if button == null:
			continue

		button.visible = true

		var button_width := (
			unit_width * width_weight
		)

		button.position = Vector2(
			current_x,
			y
		)

		button.size = Vector2(
			button_width,
			key_height
		)

		current_x += (
			button_width + KEY_GAP
		)

func _layout_letter_row(
	keys: Array[String],
	row_width: float,
	key_height: float,
	y: float
) -> void:

	var gap_count := keys.size() - 1

	var key_width := (
		row_width
		- KEY_GAP * gap_count
	) / keys.size()

	var start_x := (
		size.x - row_width
	) / 2.0


	for i in range(keys.size()):

		var button := get_node_or_null(keys[i]) as Button

		if button == null:
			continue

		button.position = Vector2(
			start_x + i * (key_width + KEY_GAP),
			y
		)

		button.size = Vector2(
			key_width,
			key_height
		)


func _layout_function_row(
	key_height: float,
	y: float
) -> void:

	# Relative widths.
	var keys := [
		["Shift", 1.45],
		["At", 0.75],
		["Dot", 0.75],
		["Space", 2.8],
		["Backspace", 1.25],
		["Enter", 1.25]
	]

	var available_width := size.x - (SIDE_MARGIN * 2.0)

	var gap_count := keys.size() - 1

	var usable_width := (
		available_width
		- KEY_GAP * gap_count
	)

	var total_weight := 0.0

	for item in keys:
		total_weight += float(item[1])


	var unit_width := usable_width / total_weight

	var start_x := (
		size.x - available_width
	) / 2.0

	var current_x := start_x


	for item in keys:

		var button_name: String = item[0]
		var width_weight: float = item[1]

		var button := get_node_or_null(button_name) as Button

		if button == null:
			continue

		var button_width := (
			unit_width * width_weight
		)

		button.position = Vector2(
			current_x,
			y
		)

		button.size = Vector2(
			button_width,
			key_height
		)

		current_x += button_width + KEY_GAP


# ============================================================
# KEY INPUT
# ============================================================

func _on_key_pressed(button: Button) -> void:
	if target_line_edit == null:
		return

	var key := button.name

	match key:
		"Shift":
			_toggle_shift()

		"Mode":
			_toggle_number_mode()

		"Backspace":
			_handle_backspace()

		"Space":
			_insert_text(" ")

		"At":
			_insert_text("@")

		"Dot":
			_insert_text(".")

		"Enter":
			_handle_enter()

		_:
			_insert_text(_get_key_text(button))

func _toggle_number_mode() -> void:
	number_mode = !number_mode

	_update_keyboard_visibility()

	var mode_button := get_node_or_null("Mode") as Button

	if mode_button:
		if number_mode:
			mode_button.text = "ABC"
		else:
			mode_button.text = "123"

	_update_keyboard_layout()

func _update_keyboard_visibility() -> void:
	var letter_keys := [
		"Q", "W", "E", "R", "T",
		"Y", "U", "I", "O", "P",
		"A", "S", "D", "F", "G",
		"H", "J", "K", "L",
		"Z", "X", "C", "V", "B", "N", "M"
	]

	var number_keys := [
		"N1", "N2", "N3", "N4", "N5",
		"N6", "N7", "N8", "N9", "N0",
		"Hash", "Dollar", "Percent", "Ampersand",
		"Asterisk", "Minus", "Plus",
		"LeftParen", "RightParen",
		"Exclamation", "Quote", "Apostrophe",
		"Colon", "Semicolon", "Slash",
		"Question", "Comma"
	]

	for key in letter_keys:
		var button := get_node_or_null(key) as Button

		if button:
			button.visible = not number_mode

	for key in number_keys:
		var button := get_node_or_null(key) as Button

		if button:
			button.visible = number_mode

	var shift_button := get_node_or_null("Shift") as Button
	var at_button := get_node_or_null("At") as Button
	var dot_button := get_node_or_null("Dot") as Button

	if shift_button:
		shift_button.visible = not number_mode

	if at_button:
		at_button.visible = true

	if dot_button:
		dot_button.visible = not number_mode

# ============================================================
# LETTER CASE
# ============================================================

func _get_key_text(button: Button) -> String:
	var key := button.name

	match key:
		"N1": return "1"
		"N2": return "2"
		"N3": return "3"
		"N4": return "4"
		"N5": return "5"
		"N6": return "6"
		"N7": return "7"
		"N8": return "8"
		"N9": return "9"
		"N0": return "0"

		"Hash": return "#"
		"Dollar": return "$"
		"Percent": return "%"
		"Ampersand": return "&"
		"Asterisk": return "*"
		"Minus": return "-"
		"Plus": return "+"
		"LeftParen": return "("
		"RightParen": return ")"

		"Exclamation": return "!"
		"Quote": return "\""
		"Apostrophe": return "'"
		"Colon": return ":"
		"Semicolon": return ";"
		"Slash": return "/"
		"Question": return "?"
		"Comma": return ","

		_:
			if shift_enabled:
				return key.to_upper()

			return key.to_lower()


func _toggle_shift() -> void:
	shift_enabled = !shift_enabled

	_update_letter_keys()


func _update_letter_keys() -> void:
	for child in get_children():

		if child is Button:

			var key := child.name

			if key.length() == 1 and key.to_upper() != key.to_lower():

				if shift_enabled:
					child.text = key.to_upper()
				else:
					child.text = key.to_lower()


# ============================================================
# TEXT INSERTION
# ============================================================

func _insert_text(value: String) -> void:
	if target_line_edit == null:
		return

	var cursor_position := target_line_edit.caret_column

	target_line_edit.text = target_line_edit.text.insert(
		cursor_position,
		value
	)

	target_line_edit.caret_column = (
		cursor_position + value.length()
	)
	
	_update_input_preview()


# ============================================================
# BACKSPACE
# ============================================================

func _handle_backspace() -> void:
	if target_line_edit == null:
		return

	var cursor_position := target_line_edit.caret_column

	if cursor_position <= 0:
		return

	target_line_edit.text = target_line_edit.text.erase(
		cursor_position - 1,
		1
	)

	target_line_edit.caret_column = (
		cursor_position - 1
	)
	
	_update_input_preview()


# ============================================================
# ENTER
# ============================================================

func _handle_enter() -> void:
	if target_line_edit == null:
		return

	var line_edit := target_line_edit

	hide_keyboard()

	line_edit.release_focus()

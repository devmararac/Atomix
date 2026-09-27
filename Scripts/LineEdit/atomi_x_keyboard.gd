extends Control

# ============================================================
# STATE
# ============================================================

var target_line_edit: LineEdit = null

var shift_enabled: bool = false
var number_mode: bool = false
var all_text_selected: bool = false

var caret_blink_timer: float = 0.0
var caret_visible: bool = true

var preview_press_timer: float = 0.0
var preview_pressing: bool = false

var keyboard_rest_position: Vector2
var keyboard_tween: Tween


# ============================================================
# ANIMATION
# ============================================================

const KEYBOARD_ANIMATION_TIME := 0.25
const KEYBOARD_START_OFFSET := 120.0


# ============================================================
# HORIZONTAL LAYOUT
# ============================================================

const SIDE_MARGIN := 4.0
const KEY_GAP := 7.0


# ============================================================
# VERTICAL LAYOUT
# ============================================================

const TOP_MARGIN := 116.0
const BOTTOM_MARGIN := 4.0
const ROW_GAP := 7.0


# ============================================================
# INPUT PREVIEW
# ============================================================

const PREVIEW_TOP := 8.0
const PREVIEW_HEIGHT := 74.0


# ============================================================
# ROW WIDTHS
# ============================================================

const QWERTY_WIDTH := 1.0
const HOME_WIDTH := 0.96
const BOTTOM_WIDTH := 0.90


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	keyboard_rest_position = position

	hide()

	_connect_keyboard_buttons()

	var preview := get_node_or_null("InputPreview") as LineEdit

	if preview:
		preview.gui_input.connect(_on_preview_gui_input)

	resized.connect(_update_keyboard_layout)

	call_deferred("_update_keyboard_layout")


# ============================================================
# PREVIEW LONG PRESS
# ============================================================

func _on_preview_gui_input(event: InputEvent) -> void:

	if event is InputEventMouseButton:

		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			preview_pressing = true
			preview_press_timer = 0.0
		else:
			preview_pressing = false
			preview_press_timer = 0.0

	elif event is InputEventScreenTouch:

		if event.pressed:
			preview_pressing = true
			preview_press_timer = 0.0
		else:
			preview_pressing = false
			preview_press_timer = 0.0


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	# --------------------------------------------------------
	# LONG PRESS SELECT ALL
	# --------------------------------------------------------

	if preview_pressing:

		preview_press_timer += delta

		if preview_press_timer >= 0.6:

			preview_pressing = false
			preview_press_timer = 0.0

			var preview := get_node_or_null("InputPreview") as LineEdit

			if preview and not preview.text.is_empty():

				all_text_selected = true

				preview.select_all()

				if target_line_edit:
					target_line_edit.select_all()

				var caret := get_node_or_null("PreviewCaret") as ColorRect

				if caret:
					caret.visible = false


	# --------------------------------------------------------
	# NO TARGET
	# --------------------------------------------------------

	if target_line_edit == null:
		return


	# --------------------------------------------------------
	# SELECTION ACTIVE
	# --------------------------------------------------------

	if all_text_selected:
		return


	# --------------------------------------------------------
	# CARET BLINK
	# --------------------------------------------------------

	var caret := get_node_or_null("PreviewCaret") as ColorRect

	if caret == null:
		return

	caret_blink_timer += delta

	if caret_blink_timer >= 0.5:

		caret_blink_timer = 0.0
		caret_visible = not caret_visible

		caret.visible = caret_visible


# ============================================================
# CONNECT BUTTONS
# ============================================================

func _connect_keyboard_buttons() -> void:

	for child in get_children():

		if child is Button:

			child.focus_mode = Control.FOCUS_NONE

			child.pressed.connect(
				_on_key_pressed.bind(child)
			)


# ============================================================
# SHOW KEYBOARD
# ============================================================

func show_for(line_edit: LineEdit) -> void:

	if line_edit == null:
		return


	# --------------------------------------------------------
	# DISABLE NATIVE KEYBOARD
	# --------------------------------------------------------

	line_edit.virtual_keyboard_enabled = false
	line_edit.virtual_keyboard_show_on_focus = false

	DisplayServer.virtual_keyboard_hide()


	# --------------------------------------------------------
	# SET TARGET
	# --------------------------------------------------------

	target_line_edit = line_edit

	shift_enabled = false
	number_mode = false
	all_text_selected = false

	caret_blink_timer = 0.0
	caret_visible = true


	# --------------------------------------------------------
	# UPDATE UI
	# --------------------------------------------------------

	_update_input_preview()
	_update_letter_keys()
	_update_keyboard_visibility()
	_update_keyboard_layout()


	# --------------------------------------------------------
	# STOP PREVIOUS ANIMATION
	# --------------------------------------------------------

	if keyboard_tween and keyboard_tween.is_valid():
		keyboard_tween.kill()


	# --------------------------------------------------------
	# ALWAYS START FROM FIXED HIDDEN POSITION
	# --------------------------------------------------------

	var hidden_position := (
		keyboard_rest_position
		+ Vector2(0.0, KEYBOARD_START_OFFSET)
	)

	position = hidden_position

	show()


	# --------------------------------------------------------
	# SLIDE UP
	# --------------------------------------------------------

	keyboard_tween = create_tween()

	keyboard_tween.set_trans(Tween.TRANS_QUAD)
	keyboard_tween.set_ease(Tween.EASE_OUT)

	keyboard_tween.tween_property(
		self,
		"position",
		keyboard_rest_position,
		KEYBOARD_ANIMATION_TIME
	)


# ============================================================
# HIDE KEYBOARD
# ============================================================

func hide_keyboard() -> void:

	if not visible:

		target_line_edit = null
		return


	if keyboard_tween and keyboard_tween.is_valid():
		keyboard_tween.kill()


	target_line_edit = null
	preview_pressing = false
	preview_press_timer = 0.0
	all_text_selected = false


	var hidden_position := (
		keyboard_rest_position
		+ Vector2(0.0, KEYBOARD_START_OFFSET)
	)


	keyboard_tween = create_tween()

	keyboard_tween.set_trans(Tween.TRANS_QUAD)
	keyboard_tween.set_ease(Tween.EASE_IN)

	keyboard_tween.tween_property(
		self,
		"position",
		hidden_position,
		KEYBOARD_ANIMATION_TIME
	)

	keyboard_tween.tween_callback(hide)


# ============================================================
# RESPONSIVE LAYOUT
# ============================================================

func _update_keyboard_layout() -> void:

	if size.x <= 0.0:
		return

	if size.y <= 0.0:
		return


	_update_preview_layout()


	if number_mode:
		_layout_number_keyboard()
	else:
		_layout_letter_keyboard()


# ============================================================
# PREVIEW LAYOUT
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
		max(
			0.0,
			size.x - SIDE_MARGIN * 2.0
		),
		PREVIEW_HEIGHT
	)


# ============================================================
# UPDATE PREVIEW TEXT
# ============================================================

func _update_input_preview() -> void:

	if target_line_edit == null:
		return


	var preview := get_node_or_null("InputPreview") as LineEdit

	if preview == null:
		return


	# --------------------------------------------------------
	# PASSWORD MASKING
	# --------------------------------------------------------

	if target_line_edit.secret:

		preview.text = "•".repeat(
			target_line_edit.text.length()
		)

	else:

		preview.text = target_line_edit.text


	# --------------------------------------------------------
	# PREVIEW CARET
	# --------------------------------------------------------

	preview.caret_column = preview.text.length()

	_update_preview_caret()


	# --------------------------------------------------------
	# RESET CARET
	# --------------------------------------------------------

	caret_blink_timer = 0.0
	caret_visible = true


	var caret := get_node_or_null("PreviewCaret") as ColorRect

	if caret:
		caret.visible = true


# ============================================================
# UPDATE CUSTOM CARET
# ============================================================

func _update_preview_caret() -> void:

	var preview := get_node_or_null("InputPreview") as LineEdit
	var caret := get_node_or_null("PreviewCaret") as ColorRect

	if preview == null:
		return

	if caret == null:
		return


	var font := preview.get_theme_font("font")
	var font_size := preview.get_theme_font_size("font_size")


	if font == null:
		return


	var text_width := font.get_string_size(
		preview.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	).x


	caret.position = Vector2(
		preview.position.x + 12.0 + text_width,
		preview.position.y + 15.0
	)


# ============================================================
# LETTER KEYBOARD
# ============================================================

func _layout_letter_keyboard() -> void:

	var available_width := (
		size.x - SIDE_MARGIN * 2.0
	)


	var row_count := 4

	var total_gaps := (
		ROW_GAP * float(row_count - 1)
	)


	var available_height := (
		size.y
		- TOP_MARGIN
		- BOTTOM_MARGIN
		- total_gaps
	)
	
	var key_height := available_height / float(row_count)


	var start_y := TOP_MARGIN


	# --------------------------------------------------------
	# QWERTY
	# --------------------------------------------------------

	_layout_row(
		[
			"Q", "W", "E", "R", "T",
			"Y", "U", "I", "O", "P"
		],
		available_width * QWERTY_WIDTH,
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
	# BOTTOM
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
# NUMBER KEYBOARD
# ============================================================

func _layout_number_keyboard() -> void:

	var available_width := (
		size.x - SIDE_MARGIN * 2.0
	)


	var row_count := 4

	var total_gaps := (
		ROW_GAP * float(row_count - 1)
	)


	var available_height := (
		size.y
		- TOP_MARGIN
		- BOTTOM_MARGIN
		- total_gaps
	)
	
	var key_height := available_height / float(row_count)

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
	# SYMBOLS 1
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
	# SYMBOLS 2
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
		available_width * 0.90,
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
# NORMAL ROW
# ============================================================

func _layout_row(
	keys: Array[String],
	row_width: float,
	key_height: float,
	y: float
) -> void:

	if keys.is_empty():
		return


	var gap_count := keys.size() - 1


	var usable_width := (
		row_width
		- KEY_GAP * gap_count
	)


	var key_width := (
		usable_width / float(keys.size())
	)


	var start_x := (
		size.x - row_width
	) / 2.0


	for i in range(keys.size()):

		var button := (
			get_node_or_null(keys[i])
			as Button
		)


		if button == null:
			continue


		button.visible = true


		button.position = Vector2(
			start_x + i * (
				key_width + KEY_GAP
			),
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
		["Shift", 1.45],
		["Mode", 1.10],
		["At", 0.85],
		["Dot", 0.85],
		["Space", 3.20],
		["Backspace", 1.40],
		["Enter", 1.40]
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
		["Mode", 1.30],
		["Space", 3.50],
		["Backspace", 1.50],
		["Enter", 1.50]
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

	if keys.is_empty():
		return


	var available_width := (
		size.x - SIDE_MARGIN * 2.0
	)


	var valid_keys: Array = []


	# --------------------------------------------------------
	# ONLY INCLUDE BUTTONS THAT ACTUALLY EXIST
	# --------------------------------------------------------

	for item in keys:

		var button := (
			get_node_or_null(item[0])
			as Button
		)

		if button != null:
			valid_keys.append(item)


	if valid_keys.is_empty():
		return


	# --------------------------------------------------------
	# CALCULATE GAPS
	# --------------------------------------------------------

	var gap_count := (
		valid_keys.size() - 1
	)


	var usable_width := (
		available_width
		- KEY_GAP * gap_count
	)


	# --------------------------------------------------------
	# TOTAL WEIGHT
	# --------------------------------------------------------

	var total_weight := 0.0


	for item in valid_keys:

		total_weight += float(
			item[1]
		)


	if total_weight <= 0.0:
		return


	var unit_width := (
		usable_width / total_weight
	)


	var current_x := (
		size.x - available_width
	) / 2.0


	# --------------------------------------------------------
	# CREATE BUTTONS
	# --------------------------------------------------------

	for item in valid_keys:

		var button_name: String = item[0]

		var width_weight: float = (
			float(item[1])
		)


		var button := (
			get_node_or_null(button_name)
			as Button
		)


		if button == null:
			continue


		var button_width := (
			unit_width * width_weight
		)


		button.visible = true


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


# ============================================================
# KEY PRESS
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
			_insert_text(
				_get_key_text(button)
			)


# ============================================================
# NUMBER / LETTER MODE
# ============================================================

func _toggle_number_mode() -> void:

	number_mode = not number_mode


	# Reset shift when entering symbols.
	if number_mode:
		shift_enabled = false


	_update_keyboard_visibility()
	_update_letter_keys()
	_update_keyboard_layout()


	var mode_button := (
		get_node_or_null("Mode")
		as Button
	)


	if mode_button:

		if number_mode:
			mode_button.text = "ABC"
		else:
			mode_button.text = "123"


# ============================================================
# KEY VISIBILITY
# ============================================================

func _update_keyboard_visibility() -> void:

	var letter_keys := [
		"Q", "W", "E", "R", "T",
		"Y", "U", "I", "O", "P",
		"A", "S", "D", "F", "G",
		"H", "J", "K", "L",
		"Z", "X", "C", "V",
		"B", "N", "M"
	]


	var number_keys := [
		"N1", "N2", "N3", "N4", "N5",
		"N6", "N7", "N8", "N9", "N0",

		"Hash",
		"Dollar",
		"Percent",
		"Ampersand",
		"Asterisk",
		"Minus",
		"Plus",
		"LeftParen",
		"RightParen",

		"Exclamation",
		"Quote",
		"Apostrophe",
		"Colon",
		"Semicolon",
		"Slash",
		"Question",
		"Comma"
	]


	# --------------------------------------------------------
	# LETTER KEYS
	# --------------------------------------------------------

	for key in letter_keys:

		var button := (
			get_node_or_null(key)
			as Button
		)

		if button:
			button.visible = not number_mode


	# --------------------------------------------------------
	# NUMBER / SYMBOL KEYS
	# --------------------------------------------------------

	for key in number_keys:

		var button := (
			get_node_or_null(key)
			as Button
		)

		if button:
			button.visible = number_mode


	# --------------------------------------------------------
	# SPECIAL LETTER MODE BUTTONS
	# --------------------------------------------------------

	var shift_button := (
		get_node_or_null("Shift")
		as Button
	)


	var at_button := (
		get_node_or_null("At")
		as Button
	)


	var dot_button := (
		get_node_or_null("Dot")
		as Button
	)


	if shift_button:
		shift_button.visible = not number_mode


	if at_button:
		# At exists in both modes.
		at_button.visible = true


	if dot_button:
		dot_button.visible = not number_mode


# ============================================================
# GET KEY TEXT
# ============================================================

func _get_key_text(button: Button) -> String:

	var key := button.name


	match key:

		"N1":
			return "1"

		"N2":
			return "2"

		"N3":
			return "3"

		"N4":
			return "4"

		"N5":
			return "5"

		"N6":
			return "6"

		"N7":
			return "7"

		"N8":
			return "8"

		"N9":
			return "9"

		"N0":
			return "0"


		"Hash":
			return "#"

		"Dollar":
			return "$"

		"Percent":
			return "%"

		"Ampersand":
			return "&"

		"Asterisk":
			return "*"

		"Minus":
			return "-"

		"Plus":
			return "+"

		"LeftParen":
			return "("

		"RightParen":
			return ")"


		"Exclamation":
			return "!"

		"Quote":
			return "\""

		"Apostrophe":
			return "'"

		"Colon":
			return ":"

		"Semicolon":
			return ";"

		"Slash":
			return "/"

		"Question":
			return "?"

		"Comma":
			return ","


		_:

			if shift_enabled:
				return key.to_upper()

			return key.to_lower()


# ============================================================
# SHIFT
# ============================================================

func _toggle_shift() -> void:

	shift_enabled = not shift_enabled

	_update_letter_keys()


func _update_letter_keys() -> void:

	for child in get_children():

		if child is not Button:
			continue


		var key := child.name


		if key.length() != 1:
			continue


		if key.to_upper() == key.to_lower():
			continue


		if shift_enabled:
			child.text = key.to_upper()
		else:
			child.text = key.to_lower()


# ============================================================
# INSERT TEXT
# ============================================================

func _insert_text(value: String) -> void:

	if target_line_edit == null:
		return


	# --------------------------------------------------------
	# REPLACE SELECTED TEXT
	# --------------------------------------------------------

	if all_text_selected:

		target_line_edit.text = value

		target_line_edit.caret_column = (
			value.length()
		)

		all_text_selected = false

		_update_input_preview()

		return


	# --------------------------------------------------------
	# NORMAL INSERTION
	# --------------------------------------------------------

	var cursor_position := (
		target_line_edit.caret_column
	)


	target_line_edit.text = (
		target_line_edit.text.insert(
			cursor_position,
			value
		)
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


	# --------------------------------------------------------
	# DELETE SELECTION
	# --------------------------------------------------------

	if all_text_selected:

		target_line_edit.text = ""
		target_line_edit.caret_column = 0

		all_text_selected = false

		_update_input_preview()

		return


	# --------------------------------------------------------
	# NORMAL BACKSPACE
	# --------------------------------------------------------

	var cursor_position := (
		target_line_edit.caret_column
	)


	if cursor_position <= 0:
		return


	target_line_edit.text = (
		target_line_edit.text.erase(
			cursor_position - 1,
			1
		)
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

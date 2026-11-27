extends Node

# =========================================================
# VIRTUAL KEYBOARD MANAGER
# GLOBAL DIM + SCROLL SUPPORT + KEYBOARD ANIMATION
# =========================================================
# Supported:
# LineEdit, TextEdit, CodeEdit, SpinBox
#
# The ScrollContainer we operate on is the OUTERMOST one so the
# whole panel can move up — not just the inner scroller's content.
# =========================================================


# ---------------------------------------------------------
# INPUT TRACKING
# ---------------------------------------------------------

var focused_input: Control = null

var original_global_position: Vector2 = Vector2.ZERO

var keyboard_visible: bool = false

var focused_scroll_container: ScrollContainer = null

var original_scroll_vertical: int = 0
var original_scroll_horizontal: int = 0

var scroll_content: Control = null
var extra_scroll_space: Control = null

# TRUE maximum scroll position (max_value - page).
var original_scroll_maximum: float = 0.0

var adjusting_scroll: bool = false

var pending_keyboard_height: int = 0
var adjustment_pending: bool = false

var last_keyboard_height: int = -1
var last_target_scroll: float = -1.0

const INPUT_MARGIN: float = 24.0
const EXTRA_SPACE_BUFFER: float = 40.0


# ---------------------------------------------------------
# DIM OVERLAY
# ---------------------------------------------------------

var dim_layer: CanvasLayer = null
var dim_rect: ColorRect = null

const DIM_LAYER_INDEX: int = 100
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)


# ---------------------------------------------------------
# READY
# ---------------------------------------------------------

func _ready() -> void:
	_create_dim_overlay()


# ---------------------------------------------------------
# PROCESS
# ---------------------------------------------------------

func _process(_delta: float) -> void:

	var platform: String = OS.get_name()

	if platform != "Android" and platform != "iOS":

		if keyboard_visible or focused_input != null or focused_scroll_container != null:
			_restore_previous_input()
			_restore_scroll_container()
			keyboard_visible = false
			_set_dim_visible(false)

		return


	var keyboard_height: int = DisplayServer.virtual_keyboard_get_height()
	var is_keyboard_open: bool = keyboard_height > 0


	var focus_owner: Control = get_viewport().gui_get_focus_owner()

	var new_input: Control = null

	if _is_supported_input(focus_owner):
		new_input = focus_owner


	# -----------------------------------------------------
	# FOCUS CHANGED
	# -----------------------------------------------------

	if new_input != focused_input:

		_restore_previous_input()
		_restore_scroll_container()

		focused_input = new_input

		last_keyboard_height = -1
		last_target_scroll = -1.0
		adjustment_pending = false

		if focused_input != null and is_instance_valid(focused_input):

			original_global_position = focused_input.global_position

			focused_scroll_container = _find_scroll_container(focused_input)

			if focused_scroll_container != null:

				original_scroll_vertical = focused_scroll_container.scroll_vertical
				original_scroll_horizontal = focused_scroll_container.scroll_horizontal

				_prepare_scroll_content()

				print("[Keyboard] Focused input: ", focused_input.name)
				print("[Keyboard] ScrollContainer: ", focused_scroll_container.name)

			else:

				print("[Keyboard] No ScrollContainer found for: ", focused_input.name)


	# -----------------------------------------------------
	# KEYBOARD CLOSED
	# -----------------------------------------------------

	if not is_keyboard_open:

		if keyboard_visible:

			_restore_previous_input()
			_restore_scroll_container()

		keyboard_visible = false
		last_keyboard_height = -1
		last_target_scroll = -1.0
		adjustment_pending = false

		_set_dim_visible(false)
		return


	# -----------------------------------------------------
	# KEYBOARD OPEN
	# -----------------------------------------------------

	keyboard_visible = true
	_set_dim_visible(true)

	if focused_input == null:
		return

	if not is_instance_valid(focused_input):
		focused_input = null
		return


	if keyboard_height != last_keyboard_height:

		last_keyboard_height = keyboard_height

		pending_keyboard_height = keyboard_height
		adjustment_pending = true

		if not adjusting_scroll:
			_process_pending_adjustments()


# ---------------------------------------------------------
# PROCESS PENDING ADJUSTMENTS
# ---------------------------------------------------------

func _process_pending_adjustments() -> void:

	if adjusting_scroll:
		return

	adjusting_scroll = true

	while adjustment_pending:

		adjustment_pending = false

		var height_to_process: int = pending_keyboard_height

		if focused_input == null or not is_instance_valid(focused_input):
			break

		if not keyboard_visible:
			break

		if (
			focused_scroll_container != null
			and is_instance_valid(focused_scroll_container)
		):

			await _adjust_scroll_for_keyboard(height_to_process)

		else:

			_move_input_above_keyboard(height_to_process)


	adjusting_scroll = false

	if adjustment_pending:
		_process_pending_adjustments()


# ---------------------------------------------------------
# SUPPORTED INPUT TYPES
# ---------------------------------------------------------

func _is_supported_input(control: Control) -> bool:

	if control == null:
		return false

	return (
		control is LineEdit
		or control is TextEdit
		or control is CodeEdit
		or control is SpinBox
	)


# ---------------------------------------------------------
# FIND OUTERMOST SCROLL CONTAINER
# ---------------------------------------------------------
# Returning the OUTERMOST ScrollContainer lets us scroll the whole
# panel content, not just an inner AnswerScroll that is buried
# below the keyboard top.
# ---------------------------------------------------------

func _find_scroll_container(control: Control) -> ScrollContainer:

	var topmost: ScrollContainer = null
	var parent: Node = control.get_parent()

	while parent != null:

		if parent is ScrollContainer:
			topmost = parent as ScrollContainer

		parent = parent.get_parent()

	return topmost


# ---------------------------------------------------------
# PREPARE SCROLL CONTENT
# ---------------------------------------------------------

func _prepare_scroll_content() -> void:

	if focused_scroll_container == null:
		return

	if not is_instance_valid(focused_scroll_container):
		return

	if focused_scroll_container.get_child_count() == 0:
		return

	scroll_content = focused_scroll_container.get_child(0) as Control

	if scroll_content == null:
		return

	var scrollbar: VScrollBar = focused_scroll_container.get_v_scroll_bar()

	original_scroll_maximum = maxf(
		0.0,
		scrollbar.max_value - scrollbar.page
	)

	extra_scroll_space = null

	print("[Keyboard] Original scroll maximum: ", original_scroll_maximum)


# ---------------------------------------------------------
# FIND TARGET CONTAINER FOR SPACER
# ---------------------------------------------------------
# If the scroll content is a CenterContainer (or nests one before
# reaching a normal VBox/VBoxContainer), adding a spacer there
# re-centres all children and defeats the scroll. Walk down the
# chain (through lone-child wrappers) until we reach a Container
# that top-aligns children.
# ---------------------------------------------------------

func _find_spacer_target() -> Control:

	if scroll_content == null:
		return null

	var node: Node = scroll_content

	# If the immediate content is a CenterContainer, descend to its
	# only child (if any), which will be the real content.
	while node != null:

		if node is CenterContainer:
			# CenterContainer centers everything, including our spacer.
			# Try to go one level deeper to find the real content.
			if node.get_child_count() > 0:
				node = node.get_child(0)
				continue
			else:
				return null

		# VBoxContainer / VBox are top-aligned — good.
		if node is VBoxContainer or node is Container and not (node is CenterContainer):
			break

		if node.get_child_count() > 0:
			node = node.get_child(0)
		else:
			break

	if node is Control:
		return node as Control

	return null


# ---------------------------------------------------------
# CREATE / UPDATE TEMPORARY SCROLL SPACE
# ---------------------------------------------------------

func _update_extra_scroll_space(target_scroll: float) -> void:

	if scroll_content == null or not is_instance_valid(scroll_content):
		return


	var spacer_target: Control = _find_spacer_target()

	if spacer_target == null:
		# Fall back to the direct scroll content if we couldn't find a
		# top-aligning container.
		spacer_target = scroll_content


	var extra_needed: float = maxf(
		0.0,
		target_scroll - original_scroll_maximum + EXTRA_SPACE_BUFFER
	)


	if extra_scroll_space == null:

		extra_scroll_space = Control.new()
		extra_scroll_space.name = "TemporaryKeyboardScrollSpace"

		extra_scroll_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		extra_scroll_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		spacer_target.add_child(extra_scroll_space)


	# Monotonic grow only (shrinking triggers relayout → scroll reset).
	if extra_scroll_space.custom_minimum_size.y < extra_needed:

		extra_scroll_space.custom_minimum_size = Vector2(
			0.0,
			extra_needed
		)


# ---------------------------------------------------------
# APPLY SCROLL HELPER
# ---------------------------------------------------------

func _apply_scroll_value(target: int) -> void:

	if focused_scroll_container == null or not is_instance_valid(focused_scroll_container):
		return

	focused_scroll_container.scroll_vertical = target

	await get_tree().process_frame

	if focused_scroll_container == null or not is_instance_valid(focused_scroll_container):
		return

	if absf(float(focused_scroll_container.scroll_vertical) - float(target)) > 2.0:
		focused_scroll_container.scroll_vertical = target


# ---------------------------------------------------------
# ADJUST SCROLL FOR KEYBOARD
# ---------------------------------------------------------

func _adjust_scroll_for_keyboard(keyboard_height: int) -> void:

	if focused_input == null or focused_scroll_container == null:
		return

	if not is_instance_valid(focused_input):
		return

	if not is_instance_valid(focused_scroll_container):
		return


	await get_tree().process_frame

	if not is_instance_valid(focused_input):
		return
	if not is_instance_valid(focused_scroll_container):
		return
	if not keyboard_visible:
		return


	# -----------------------------------------------------
	# CALCULATE KEYBOARD TOP
	# -----------------------------------------------------

	var viewport_height: float = get_viewport().get_visible_rect().size.y
	var window_height: float = float(get_window().size.y)

	if window_height <= 0.0:
		return

	var scale_factor: float = viewport_height / window_height
	var keyboard_height_viewport: float = float(keyboard_height) * scale_factor
	var keyboard_top: float = viewport_height - keyboard_height_viewport


	# -----------------------------------------------------
	# CALCULATE REQUIRED SCROLL
	# -----------------------------------------------------

	var input_bottom: float = original_global_position.y + focused_input.size.y

	var required_scroll: float = maxf(
		0.0,
		input_bottom - keyboard_top + INPUT_MARGIN
	)

	var target_scroll: float = float(original_scroll_vertical) + required_scroll


	# -----------------------------------------------------
	# ADD TEMPORARY SPACE
	# -----------------------------------------------------

	_update_extra_scroll_space(target_scroll)


	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	if not is_instance_valid(focused_scroll_container):
		return
	if not keyboard_visible:
		return


	var scrollbar: VScrollBar = focused_scroll_container.get_v_scroll_bar()


	# -----------------------------------------------------
	# CORRECT SPACER IF NEEDED (grow-only)
	# -----------------------------------------------------

	var maximum_scroll: float = maxf(
		0.0,
		scrollbar.max_value - scrollbar.page
	)

	if maximum_scroll < target_scroll:

		var missing_space: float = (
			target_scroll - maximum_scroll + EXTRA_SPACE_BUFFER
		)

		if extra_scroll_space != null and is_instance_valid(extra_scroll_space):
			extra_scroll_space.custom_minimum_size.y += missing_space

		await get_tree().process_frame
		await get_tree().process_frame

		maximum_scroll = maxf(0.0, scrollbar.max_value - scrollbar.page)


	# -----------------------------------------------------
	# APPLY SCROLL
	# -----------------------------------------------------

	var final_target: float = minf(target_scroll, maximum_scroll)

	# Compare against CURRENT value — engine may reset scroll to 0.
	if absf(float(focused_scroll_container.scroll_vertical) - final_target) > 2.0:

		await _apply_scroll_value(int(final_target))

		last_target_scroll = final_target


	print("--------------------------------")
	print("[Keyboard] Input: ", focused_input.name)
	print("[Keyboard] Keyboard top: ", keyboard_top)
	print("[Keyboard] Required scroll: ", required_scroll)
	print("[Keyboard] Target scroll: ", target_scroll)
	print("[Keyboard] Scroll maximum: ", maximum_scroll)
	print("[Keyboard] Scrollbar value: ", scrollbar.value)
	print("[Keyboard] ScrollContainer value: ", focused_scroll_container.scroll_vertical)
	print("--------------------------------")


# ---------------------------------------------------------
# RESTORE SCROLL CONTAINER
# ---------------------------------------------------------

func _restore_scroll_container() -> void:

	if focused_scroll_container != null and is_instance_valid(focused_scroll_container):

		if extra_scroll_space != null and is_instance_valid(extra_scroll_space):
			extra_scroll_space.queue_free()

		focused_scroll_container.scroll_vertical = original_scroll_vertical
		focused_scroll_container.scroll_horizontal = original_scroll_horizontal

	focused_scroll_container = null
	scroll_content = null
	extra_scroll_space = null

	original_scroll_maximum = 0.0

	last_target_scroll = -1.0
	last_keyboard_height = -1


# ---------------------------------------------------------
# CREATE GLOBAL DIM OVERLAY
# ---------------------------------------------------------

func _create_dim_overlay() -> void:

	if dim_layer != null:
		return

	dim_layer = CanvasLayer.new()
	dim_layer.name = "GlobalKeyboardDim"
	dim_layer.layer = DIM_LAYER_INDEX
	add_child(dim_layer)

	dim_rect = ColorRect.new()
	dim_rect.name = "BackgroundDim"
	dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_rect.color = DIM_COLOR
	dim_rect.visible = false
	dim_layer.add_child(dim_rect)

	print("[VirtualKeyboard] Global dim overlay created.")


# ---------------------------------------------------------
# TOGGLE DIM
# ---------------------------------------------------------

func _set_dim_visible(enabled: bool) -> void:

	if dim_rect == null:
		return

	dim_rect.visible = enabled


# ---------------------------------------------------------
# MOVE NON-SCROLL INPUT ABOVE KEYBOARD
# ---------------------------------------------------------

func _move_input_above_keyboard(keyboard_height: int) -> void:

	if focused_input == null or not is_instance_valid(focused_input):
		return

	var viewport_height: float = get_viewport().get_visible_rect().size.y
	var window_height: float = float(get_window().size.y)

	if window_height <= 0.0:
		return

	var scale_factor: float = viewport_height / window_height
	var keyboard_height_viewport: float = float(keyboard_height) * scale_factor
	var keyboard_top: float = viewport_height - keyboard_height_viewport

	var target_y: float = keyboard_top - focused_input.size.y - INPUT_MARGIN

	if original_global_position.y + focused_input.size.y > keyboard_top:
		focused_input.global_position = Vector2(
			original_global_position.x,
			target_y
		)


# ---------------------------------------------------------
# RESTORE FOCUSED INPUT
# ---------------------------------------------------------

func _restore_previous_input() -> void:

	if focused_input != null and is_instance_valid(focused_input):
		if focused_scroll_container == null:
			focused_input.global_position = original_global_position

	focused_input = null

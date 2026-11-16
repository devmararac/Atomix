
extends Node

# Supports both LineEdit and TextEdit.
var focused_input: Control = null

var original_global_position: Vector2 = Vector2.ZERO
var keyboard_visible: bool = false

const INPUT_MARGIN := 24.0


func _process(_delta: float) -> void:

	# Only check the virtual keyboard on mobile platforms.
	var platform := OS.get_name()

	if platform != "Android" and platform != "iOS":
		if focused_input != null:
			_restore_previous_input()

		keyboard_visible = false
		return

	var keyboard_height := DisplayServer.virtual_keyboard_get_height()
	var is_keyboard_open := keyboard_height > 0

	var focus_owner := get_viewport().gui_get_focus_owner()

	var new_input: Control = null

	if focus_owner is LineEdit or focus_owner is TextEdit:
		new_input = focus_owner as Control

	# Detect when focus moves to another input.
	if new_input != focused_input:

		_restore_previous_input()

		focused_input = new_input

		if focused_input != null:
			original_global_position = focused_input.global_position

	# Restore the input when the keyboard closes.
	if not is_keyboard_open:

		if keyboard_visible:
			_restore_previous_input()

		keyboard_visible = false
		return

	keyboard_visible = true

	if focused_input == null:
		return

	if not is_instance_valid(focused_input):
		focused_input = null
		return

	_move_input_above_keyboard(keyboard_height)


func _move_input_above_keyboard(keyboard_height: int) -> void:

	if focused_input == null:
		return

	var viewport_height := get_viewport().get_visible_rect().size.y
	var window_height := float(get_window().size.y)

	if window_height <= 0.0:
		return

	# Convert keyboard height into viewport coordinates.
	var scale_factor := viewport_height / window_height

	var keyboard_height_viewport := (
		float(keyboard_height) * scale_factor
	)

	var keyboard_top := viewport_height - keyboard_height_viewport

	# Calculate the input's target position.
	var target_y := (
		keyboard_top
		- focused_input.size.y
		- INPUT_MARGIN
	)

	# Move the input only when it would be covered.
	if original_global_position.y + focused_input.size.y > keyboard_top:

		focused_input.global_position = Vector2(
			original_global_position.x,
			target_y
		)


func _restore_previous_input() -> void:

	if focused_input != null and is_instance_valid(focused_input):

		focused_input.global_position = original_global_position

	focused_input = null

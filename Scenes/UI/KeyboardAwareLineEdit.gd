@tool
extends LineEdit
class_name KeyboardAwareLineEdit

var original_position: Vector2
var keyboard_was_visible := false

const INPUT_MARGIN := 24.0


func _ready() -> void:
	original_position = global_position


func _process(_delta: float) -> void:

	var keyboard_height := DisplayServer.virtual_keyboard_get_height()
	var is_keyboard_visible := keyboard_height > 0

	if is_keyboard_visible:
		_move_above_keyboard(keyboard_height)
		keyboard_was_visible = true

	elif keyboard_was_visible:
		global_position = original_position
		keyboard_was_visible = false


func _move_above_keyboard(keyboard_height: int) -> void:

	var viewport_height := get_viewport().get_visible_rect().size.y
	var window_height := float(get_window().size.y)

	if window_height <= 0:
		return

	var scale_factor := viewport_height / window_height
	var keyboard_top := viewport_height - (keyboard_height * scale_factor)

	var target_y := keyboard_top - size.y - INPUT_MARGIN

	if global_position.y + size.y > keyboard_top:
		global_position.y = target_y

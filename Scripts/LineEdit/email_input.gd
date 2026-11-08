extends LineEdit


var original_position: Vector2
var keyboard_offset: float = 0.0


func _ready() -> void:
	original_position = position

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)


func _process(_delta: float) -> void:

	var keyboard_height := DisplayServer.virtual_keyboard_get_height()

	if keyboard_height > 0 and has_focus():
		_move_above_keyboard(keyboard_height)
	else:
		_restore_position()


func _move_above_keyboard(keyboard_height: float) -> void:

	var viewport_height := get_viewport_rect().size.y
	var field_bottom := global_position.y + size.y

	var safe_bottom := viewport_height - keyboard_height - 20.0

	if field_bottom > safe_bottom:

		keyboard_offset = field_bottom - safe_bottom

		position = original_position
		position.y -= keyboard_offset


func _restore_position() -> void:

	if keyboard_offset != 0.0:
		position = original_position
		keyboard_offset = 0.0


func _on_focus_entered() -> void:
	pass


func _on_focus_exited() -> void:
	_restore_position()

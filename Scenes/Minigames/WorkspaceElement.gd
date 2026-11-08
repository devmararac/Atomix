class_name WorkspaceElement
extends PanelContainer


var dragging = false
var drag_offset = Vector2.ZERO


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	gui_input.connect(_on_gui_input)


func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:
				_start_drag(event)

			else:
				_stop_drag()


func _start_drag(event):
	dragging = true

	drag_offset = global_position - event.global_position

	move_to_front()


func _stop_drag():
	if not dragging:
		return

	dragging = false

	_check_combination()


func _process(_delta):
	if not dragging:
		return

	var mouse_position = get_global_mouse_position()

	global_position = mouse_position + drag_offset


func _check_combination():
	var parent_node = get_parent()

	if parent_node == null:
		return

	for other in parent_node.get_children():

		if other == self:
			continue

		if not other is WorkspaceElement:
			continue

		if _is_overlapping(other):
			_try_combine(other)
			return


func _is_overlapping(other):
	var my_rect = get_global_rect()
	var other_rect = other.get_global_rect()

	return my_rect.intersects(other_rect)


func _try_combine(other):
	var my_symbol = get_meta("element_symbol")
	var other_symbol = other.get_meta("element_symbol")

	print(
		"Attempting combination: ",
		my_symbol,
		" + ",
		other_symbol
	)

	var combination_manager = get_node_or_null(
		"/root/CombinationManager"
	)

	if combination_manager == null:
		print("CombinationManager not found.")
		return

	var result = combination_manager.try_combine(
		my_symbol,
		other_symbol
	)

	if result == null:
		print(
			"No valid combination: ",
			my_symbol,
			" + ",
			other_symbol
		)
		return

	print(
		"Combination created: ",
		result.formula
	)

	_create_result(result, other)


func _create_result(compound_data, other):
	var result = PanelContainer.new()

	result.custom_minimum_size = Vector2(130, 130)
	result.name = "Compound_" + compound_data.formula

	var label = Label.new()

	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	label.text = compound_data.formula
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.add_theme_font_size_override(
		"font_size",
		36
	)

	result.add_child(label)

	result.set_meta(
		"compound_data",
		compound_data
	)

	var result_script = preload(
		"res://Scenes/Minigames/WorkspaceCompound.gd"
	)

	result.set_script(result_script)

	var parent_node = get_parent()

	var result_position = global_position

	parent_node.add_child(result)

	result.global_position = result_position

	queue_free()
	other.queue_free()

	var lab = parent_node.get_parent()

	if lab is CompoundLab:
		lab.discover_compound(compound_data)

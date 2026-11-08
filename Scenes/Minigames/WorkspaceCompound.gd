func _create_element_object(element_symbol):
	var element = PanelContainer.new()

	element.custom_minimum_size = Vector2(110, 110)
	element.name = "Element_" + element_symbol

	element.mouse_filter = Control.MOUSE_FILTER_STOP

	var label = Label.new()

	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	label.text = element_symbol
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.add_theme_font_size_override(
		"font_size",
		36
	)

	element.add_child(label)

	element.set_meta(
		"element_symbol",
		element_symbol
	)

	var drag_script = preload(
		"res://Scenes/Minigames/WorkspaceElement.gd"
	)

	element.set_script(drag_script)

	return element

extends Control

@onready var panel = $CanvasLayer/Panel
@onready var dialouge_speaker = $CanvasLayer/Panel/DialougeBox/DialougeSpeaker
@onready var dialouge_text = $CanvasLayer/Panel/DialougeBox/DialougeText
@onready var dialouge_options = $CanvasLayer/Panel/DialougeBox/DialougeOptions

func _ready():
	hide_dialouge()

# Show Dialogue
func show_dialouge(speaker, text, options):
	panel.visible = true

	# Dialogue Animation
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.98, 0.98)

	var tween = create_tween()
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.06)
	tween.parallel().tween_property(panel, "scale", Vector2(1.01, 1.01), 0.06)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.04)

	# Dialogue Contents
	dialouge_speaker.text = speaker
	dialouge_text.text = text

	# Clear previous buttons
	for child in dialouge_options.get_children():
		child.queue_free()

	# Continue button
	if options.is_empty():
		var button = Button.new()
		button.text = "Continue"
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_on_continue_pressed)
		dialouge_options.add_child(button)
		return

	# Dialogue options
	for option in options.keys():
		var button = Button.new()
		button.text = option
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_on_option_selected.bind(option))
		dialouge_options.add_child(button)

func _on_continue_pressed():
	var npc = get_parent().npc

	match npc.current_state:
		"end":
			if npc.current_branch_index < npc.dialouge_resource.get_npc_dialouge(npc.npc_id).size() - 1:
				npc.set_dialouge_branch(npc.current_branch_index + 1)

			npc.set_dialouge_state("start")
			get_parent().hide_dialouge()

		"exit":
			npc.set_dialouge_state("start")
			get_parent().hide_dialouge()

# Handle Response Selections
func _on_option_selected(option):
	get_parent().handle_dialouge_choice(option)

# Hide Dialogue
func hide_dialouge():
	panel.visible = false
	global.player.can_move = true

# Close Dialogue
func _on_close_button_pressed() -> void:
	hide_dialouge()

extends Control

const MAX_ROUNDS: int = 6
const SCORE_PER_ROUND: int = 150

var compounds: Array[Dictionary] = [
	{
		"name": "Water",
		"formula": "H₂O",
		"elements": ["H", "H", "O"]
	},
	{
		"name": "Hydrogen Chloride",
		"formula": "HCl",
		"elements": ["H", "Cl"]
	},
	{
		"name": "Sodium Chloride",
		"formula": "NaCl",
		"elements": ["Na", "Cl"]
	},
	{
		"name": "Hydrogen Gas",
		"formula": "H₂",
		"elements": ["H", "H"]
	},
	{
		"name": "Oxygen Gas",
		"formula": "O₂",
		"elements": ["O", "O"]
	},
	{
		"name": "Nitrogen Gas",
		"formula": "N₂",
		"elements": ["N", "N"]
	}
]

var available_elements: Array[String] = [
	"H",
	"O",
	"Cl",
	"Na",
	"N"
]

var current_round: int = 0
var score: int = 0
var current_compound: Dictionary = {}
var placed_atomons: Array[Button] = []
var game_started: bool = false
var round_locked: bool = false

var dragging_atomon: Button = null
var drag_offset: Vector2 = Vector2.ZERO
var drag_start_position: Vector2 = Vector2.ZERO
var was_placed_before_drag: bool = false

@onready var score_label: Label = $MarginContainer/MainVBox/Header/ScoreLabel
@onready var round_label: Label = $MarginContainer/MainVBox/Header/RoundLabel
@onready var target_name: Label = $MarginContainer/MainVBox/TargetPanel/TargetVBox/TargetName
@onready var target_formula: Label = $MarginContainer/MainVBox/TargetPanel/TargetVBox/TargetFormula
@onready var atom_tray: HBoxContainer = $MarginContainer/MainVBox/AtomTray
@onready var bonding_area: Panel = $MarginContainer/MainVBox/BondingArea
@onready var bonded_atomons: Control = $MarginContainer/MainVBox/BondingArea/BondedAtomons
@onready var status_label: Label = $MarginContainer/MainVBox/StatusLabel
@onready var clear_button: Button = $MarginContainer/MainVBox/BottomBar/ClearButton
@onready var build_button: Button = $MarginContainer/MainVBox/BottomBar/BuildButton
@onready var start_button: Button = $MarginContainer/MainVBox/StartButton


func _ready() -> void:
	clear_button.pressed.connect(_on_clear_pressed)
	build_button.pressed.connect(_on_build_pressed)
	start_button.pressed.connect(_on_start_pressed)
	show_start_screen()


func show_start_screen() -> void:
	game_started = false
	round_locked = true
	current_round = 0
	score = 0

	score_label.text = "SCORE: 0"
	round_label.text = "ROUND: 0/%d" % MAX_ROUNDS
	target_name.text = "BUILD A MOLECULE"
	target_formula.text = "?"
	status_label.text = "Drag Atomon into the bonding area."

	clear_button.disabled = true
	build_button.disabled = true
	start_button.visible = true

	clear_atom_tray()
	clear_bonding_area()


func _on_start_pressed() -> void:
	score = 0
	current_round = 0
	game_started = true
	round_locked = false

	score_label.text = "SCORE: 0"
	start_button.visible = false
	clear_button.disabled = false
	build_button.disabled = false

	next_round()


func next_round() -> void:
	if current_round >= MAX_ROUNDS:
		finish_game()
		return

	current_round += 1
	current_compound = compounds[current_round - 1]
	round_locked = false

	round_label.text = "ROUND: %d/%d" % [current_round, MAX_ROUNDS]
	target_name.text = current_compound["name"]
	target_formula.text = current_compound["formula"]
	status_label.text = "Drag the required Atomon into the bonding area."

	clear_bonding_area()
	create_atom_tray()


func create_atom_tray() -> void:
	clear_atom_tray()

	var elements: Array[String] = []

	for element in current_compound["elements"]:
		elements.append(element)

	for element in available_elements:
		if not elements.has(element):
			elements.append(element)

	elements.shuffle()

	for element in elements:
		var atomon: Button = create_atomon(element)
		atom_tray.add_child(atomon)


func create_atomon(element: String) -> Button:
	var atomon: Button = Button.new()

	atomon.text = element
	atomon.custom_minimum_size = Vector2(90, 70)
	atomon.add_theme_font_size_override("font_size", 26)
	atomon.focus_mode = Control.FOCUS_NONE

	atomon.gui_input.connect(_on_atomon_input.bind(atomon))

	return atomon


func _on_atomon_input(event: InputEvent, atomon: Button) -> void:
	if not game_started or round_locked:
		return

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			start_drag(atomon, event.position)
		else:
			end_drag()

	elif event is InputEventMouseMotion:
		if dragging_atomon == atomon:
			update_drag_position()


func start_drag(atomon: Button, local_position: Vector2) -> void:
	dragging_atomon = atomon
	drag_offset = local_position
	drag_start_position = atomon.global_position
	was_placed_before_drag = placed_atomons.has(atomon)

	atomon.z_index = 100


func update_drag_position() -> void:
	if dragging_atomon == null:
		return

	var mouse_position: Vector2 = get_viewport().get_mouse_position()

	dragging_atomon.global_position = mouse_position - drag_offset


func end_drag() -> void:
	if dragging_atomon == null:
		return

	var atomon: Button = dragging_atomon
	var dropped_inside: bool = bonding_area.get_global_rect().has_point(
		get_viewport().get_mouse_position()
	)

	dragging_atomon = null
	atomon.z_index = 0

	if dropped_inside:
		place_atomon(atomon)
	elif was_placed_before_drag:
		atomon.global_position = drag_start_position
	else:
		return_atomon_to_tray(atomon)

	update_status()


func place_atomon(atomon: Button) -> void:
	if atomon.get_parent() != bonded_atomons:
		var global_position: Vector2 = atomon.global_position

		atomon.reparent(bonded_atomons)

		atomon.global_position = global_position

	if not placed_atomons.has(atomon):
		placed_atomons.append(atomon)

	keep_atomon_inside_area(atomon)


func return_atomon_to_tray(atomon: Button) -> void:
	if atomon.get_parent() != atom_tray:
		var global_position: Vector2 = atomon.global_position

		atomon.reparent(atom_tray)

		atomon.global_position = global_position

		atom_tray.move_child(atomon, atom_tray.get_child_count() - 1)

	placed_atomons.erase(atomon)


func keep_atomon_inside_area(atomon: Button) -> void:
	var area_size: Vector2 = bonded_atomons.size
	var atom_size: Vector2 = atomon.size

	var position: Vector2 = atomon.position

	position.x = clamp(
		position.x,
		0.0,
		max(0.0, area_size.x - atom_size.x)
	)

	position.y = clamp(
		position.y,
		0.0,
		max(0.0, area_size.y - atom_size.y)
	)

	atomon.position = position


func remove_atomon(atomon: Button) -> void:
	placed_atomons.erase(atomon)
	atomon.queue_free()


func update_status() -> void:
	if placed_atomons.is_empty():
		status_label.text = "Drag Atomon into the bonding area."
	else:
		status_label.text = "%d Atomon placed. Arrange them and build the molecule." % placed_atomons.size()


func _on_clear_pressed() -> void:
	if round_locked:
		return

	clear_bonding_area()
	status_label.text = "Bonding area cleared."


func _on_build_pressed() -> void:
	if round_locked:
		return

	if placed_atomons.is_empty():
		status_label.text = "Place Atomon in the bonding area first."
		return

	var selected_elements: Array[String] = []

	for atomon in placed_atomons:
		selected_elements.append(atomon.text)

	if not same_elements(selected_elements, current_compound["elements"]):
		status_label.text = "The molecule is not stable. Check the Atomon you used."
		return

	round_locked = true
	score += SCORE_PER_ROUND

	score_label.text = "SCORE: %d" % score
	status_label.text = "%s built successfully! +%d points" % [
		current_compound["formula"],
		SCORE_PER_ROUND
	]

	await get_tree().create_timer(1.2).timeout

	if game_started:
		next_round()


func same_elements(first: Array[String], second: Array) -> bool:
	if first.size() != second.size():
		return false

	var first_sorted: Array[String] = first.duplicate()
	var second_sorted: Array[String] = []

	for element in second:
		second_sorted.append(element)

	first_sorted.sort()
	second_sorted.sort()

	return first_sorted == second_sorted


func clear_atom_tray() -> void:
	for child in atom_tray.get_children():
		child.queue_free()


func clear_bonding_area() -> void:
	for atomon in placed_atomons:
		if is_instance_valid(atomon):
			atomon.queue_free()

	placed_atomons.clear()


func finish_game() -> void:
	game_started = false
	round_locked = true

	clear_atom_tray()
	clear_bonding_area()

	target_name.text = "CHEMISTRY COMPLETE"
	target_formula.text = "✓"
	status_label.text = "Final Score: %d" % score

	clear_button.disabled = true
	build_button.disabled = true

	start_button.text = "PLAY AGAIN"
	start_button.visible = true

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/minigames.tscn")

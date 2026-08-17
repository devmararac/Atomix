
extends CanvasLayer


const TYPE_BACKGROUNDS = {
	"Nonmetal": preload("res://Assets/UX/Icons/nonmetal.png"),
	"Post-transition Metal": preload("res://Assets/UX/Icons/post_transition_metal.png"),
	"Metalloid": preload("res://Assets/UX/Icons/metalloids.png"),
	"Noble Gas": preload("res://Assets/UX/Icons/noble_gas.png"),
	"Halogen": preload("res://Assets/UX/Icons/halogen.png"),
	"Alkali Metal": preload("res://Assets/UX/Icons/akali_metals.png"),
	"Alkaline Earth Metal": preload("res://Assets/UX/Icons/alkaline_metal.png"),
	"Transition Metal": preload("res://Assets/UX/Icons/transition_metal.png"),
	"Lanthanide": preload("res://Assets/UX/Icons/lanthanide.png"),
	"Actinide": preload("res://Assets/UX/Icons/actinide.png")
}

var selected_element: AtomonData

@onready var info_panel = $"TextureRect/Info Panel"
@onready var element_background = $"TextureRect/Info Panel/TextureRect/Container/TextureRect2"


@onready var atomic_symbol = $"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Atomic Symbol"
@onready var atomic_number = $"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Atomic Number"
@onready var atomic_mass = $"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Atomic Mass"
@onready var atomic_name = $"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Atomic Name"
@onready var element_type = $"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Type"
@onready var craft_button = $"TextureRect/Info Panel/Control/Craft Button"

@onready var density_value = $"TextureRect/Info Panel/TextureRect/Container/GridContainer/Density Value"
@onready var ie_value = $"TextureRect/Info Panel/TextureRect/Container/GridContainer/IE Value"
@onready var electronegativity_value = $"TextureRect/Info Panel/TextureRect/Container/GridContainer/Electronegativity Value"
@onready var ea_value = $"TextureRect/Info Panel/TextureRect/Container/GridContainer/EA Value"
@onready var valence_electrons_value = $"TextureRect/Info Panel/TextureRect/Container/GridContainer/VE Value"
@onready var phase_value = $"TextureRect/Info Panel/TextureRect/Container/GridContainer/Phase Value"
@onready var period_value = $"TextureRect/Info Panel/TextureRect/Container/GridContainer/Period Value"
@onready var block_value = $"TextureRect/Info Panel/TextureRect/Container/GridContainer/Block Value"
@onready var radioactive_value = $"TextureRect/Info Panel/TextureRect/Container/GridContainer/Radioactive Value"



func _ready():
	print("CRAFTING UI READY")

	setup_element_buttons()
	connect_element_buttons($TextureRect/PeriodicTableScroll/Container)
	craft_button.pressed.connect(_on_craft_pressed)

func setup_element_buttons():
	var buttons: Array[Node] = []

	collect_element_buttons(
		$TextureRect/PeriodicTableScroll/Container,
		buttons
	)

	print("FOUND ELEMENT BUTTONS: ", buttons.size())

	for button in buttons:
		var symbol := button.name

		if AtomonDatabase.ELEMENTS.has(symbol):
			var element: AtomonData = AtomonDatabase.ELEMENTS[symbol]

			button.set_element(element)

			print(
				"ASSIGNED: ",
				button.name,
				" -> ",
				element.atom_name,
				" (#",
				element.atomic_number,
				")"
			)
		else:
			print("NO DATA FOR BUTTON: ", button.name)

func collect_element_buttons(parent: Node, buttons: Array[Node]):
	for child in parent.get_children():

		if child is TextureButton and child.has_method("set_element"):
			buttons.append(child)

		if child.get_child_count() > 0:
			collect_element_buttons(child, buttons)


func connect_element_buttons(parent: Node):
	for child in parent.get_children():

		if child.has_signal("element_selected"):
			print("CONNECTING: ", child.name)

			if not child.element_selected.is_connected(_on_element_selected):
				child.element_selected.connect(_on_element_selected)

		if child.get_child_count() > 0:
			connect_element_buttons(child)


func _on_element_selected(element: AtomonData, crafted: bool):
	print("SELECTED ELEMENT: ", element.atom_name)
	print("CRAFTED: ", crafted)

	selected_element = element
	info_panel.visible = true

	if !crafted:
		# Uncrafted → use the neutral/default background
		element_background.texture = preload("res://Assets/UX/HUD/Panels/slot.png")

		atomic_symbol.text = "44"
		atomic_number.text = "???"
		atomic_mass.text = "?.?????????"
		atomic_name.text = "????????????"
		element_type.text = "???????????"

		density_value.text = "????????"
		ie_value.text = "????????"
		electronegativity_value.text = "????????"
		ea_value.text = "????????"
		valence_electrons_value.text = "???"
		phase_value.text = "????????"
		period_value.text = "???"
		block_value.text = "?"
		radioactive_value.text = "???"

		print("This element has not been crafted yet.")
		return

	# Crafted → now show the element's colored type background
	element_background.texture = TYPE_BACKGROUNDS.get(element.element_type)

	atomic_symbol.text = element.chemical_symbol
	atomic_number.text = str(element.atomic_number)
	atomic_mass.text = str(element.atomic_mass)
	atomic_name.text = element.atom_name
	element_type.text = element.element_type

	density_value.text = str(element.density)
	ie_value.text = str(element.ionization_energy)
	electronegativity_value.text = str(element.electronegativity)
	ea_value.text = str(element.electron_affinity)
	valence_electrons_value.text = str(element.valence_electrons)
	phase_value.text = str(element.state)
	period_value.text = str(element.period)
	block_value.text = str(element.block)
	radioactive_value.text = "Yes" if element.radioactive else "No"
	
	
func _on_craft_pressed() -> void:
	if selected_element == null:
		return

	print("CRAFTING: ", selected_element.atom_name)
	print("SYMBOL: ", selected_element.chemical_symbol)

	# Check party capacity first
	if PartyManager.party.size() >= PartyManager.MAX_PARTY_SIZE:
		print("PARTY IS FULL")
		return

	var buttons: Array[Node] = []

	collect_element_buttons(
		$TextureRect/PeriodicTableScroll/Container,
		buttons
	)

	# Check if already crafted
	for button in buttons:
		if button.element_data == selected_element:
			if button.is_crafted:
				print(
					"ALREADY CRAFTED: ",
					selected_element.atom_name
				)
				return
			break

	# Create the Atomon
	var new_atomon: AtomonInstance = PartyManager.add_species(
		selected_element
	)

	if new_atomon == null:
		print(
			"FAILED TO CRAFT: ",
			selected_element.atom_name
		)
		return

	# Mark the button as crafted
	for button in buttons:
		if button.element_data == selected_element:
			button.set_crafted(true)
			break

	print("CRAFTED: ", selected_element.atom_name)

	# ========================================================
	# SAVE THE ACTUAL ELEMENT SYMBOL
	# ========================================================

	await StudentDataManager.collect_element(
		selected_element.chemical_symbol
	)

	print(
		"[CraftingUI] Saved element: ",
		selected_element.chemical_symbol
	)

	print(
		"[CraftingUI] Collected elements: ",
		StudentDataManager.get_collected_elements()
	)

	# Immediately update the currently open info panel
	_on_element_selected(
		selected_element,
		true
	)


func _on_close_button_pressed() -> void:
	info_panel.visible = false


func _on_close_crafting_pressed() -> void:
	print("CLOSING CRAFTING UI")
	queue_free()
	if global.player:
		global.player.can_move = true

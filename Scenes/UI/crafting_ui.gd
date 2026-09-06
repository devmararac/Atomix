extends CanvasLayer

# ============================================================

# TYPE BACKGROUNDS

# ============================================================

const TYPE_BACKGROUNDS = {
"Nonmetal": preload("res://Assets/UX/Icons/nonmetal.png"),
"Post-Transition Metal": preload("res://Assets/UX/Icons/post_transition_metal.png"),
"Metalloid": preload("res://Assets/UX/Icons/metalloids.png"),
"Noble Gas": preload("res://Assets/UX/Icons/noble_gas.png"),
"Halogen": preload("res://Assets/UX/Icons/halogen.png"),
"Alkali Metal": preload("res://Assets/UX/Icons/akali_metals.png"),
"Alkaline Earth Metal": preload("res://Assets/UX/Icons/alkaline_metal.png"),
"Transition Metal": preload("res://Assets/UX/Icons/transition_metal.png"),
"Lanthanide": preload("res://Assets/UX/Icons/lanthanide.png"),
"Actinide": preload("res://Assets/UX/Icons/actinide.png")
}

# ============================================================
# STATE
# ============================================================

var selected_element: AtomonData

# ============================================================
# UI REFERENCES
# ============================================================

@onready var info_panel = $"TextureRect/Info Panel"
@onready var element_background = ($"TextureRect/Info Panel/TextureRect/Container/TextureRect2")
@onready var atomic_symbol = ($"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Atomic Symbol")
@onready var atomic_number = ($"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Atomic Number")
@onready var atomic_mass = ($"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Atomic Mass")
@onready var atomic_name = ($"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Atomic Name")
@onready var element_type = ($"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Type")
@onready var craft_button = ($"TextureRect/Info Panel/Control/Craft Button")
@onready var proton_count = ($"TextureRect/Info Panel/Control2/Materials/Proton/Proton Count")
@onready var electron_count = ($"TextureRect/Info Panel/Control2/Materials/Electron/Electron Count")
@onready var neutron_count = ($"TextureRect/Info Panel/Control2/Materials/Neutron/Neutron Count")
@onready var atomic_core_count = ($"TextureRect/Info Panel/Control2/Materials/Atomic Core/Atomic Core Count")
@onready var material_status = ($"TextureRect/Info Panel/Control2/Material Status")
@onready var density_value = ($"TextureRect/Info Panel/TextureRect/Container/GridContainer/Density Value")
@onready var ie_value = ($"TextureRect/Info Panel/TextureRect/Container/GridContainer/IE Value")
@onready var electronegativity_value = ($"TextureRect/Info Panel/TextureRect/Container/GridContainer/Electronegativity Value")
@onready var ea_value = ($"TextureRect/Info Panel/TextureRect/Container/GridContainer/EA Value")
@onready var valence_electrons_value = ($"TextureRect/Info Panel/TextureRect/Container/GridContainer/VE Value")
@onready var phase_value = ($"TextureRect/Info Panel/TextureRect/Container/GridContainer/Phase Value")
@onready var period_value = ($"TextureRect/Info Panel/TextureRect/Container/GridContainer/Period Value")
@onready var block_value = ($"TextureRect/Info Panel/TextureRect/Container/GridContainer/Block Value")
@onready var radioactive_value = ($"TextureRect/Info Panel/TextureRect/Container/GridContainer/Radioactive Value")

@export var hud: CanvasLayer

# ============================================================
# READY
# ============================================================

func _ready() -> void:

	add_to_group("CraftingUI")
	
	print("CRAFTING UI READY")

	setup_element_buttons()

	connect_element_buttons(
		$TextureRect/PeriodicTableScroll/Container
	)

	if not craft_button.pressed.is_connected(
		_on_craft_pressed
	):

		craft_button.pressed.connect(
			_on_craft_pressed
		)


	_refresh_all_crafted_buttons()
	
	if hud:
		hud.hide()
	
	if global.player:
		global.player.can_move = false
	
	# ============================================================

	# SETUP ELEMENT BUTTONS

	# ============================================================

func setup_element_buttons() -> void:


	var buttons: Array[Node] = []

	collect_element_buttons(
		$TextureRect/PeriodicTableScroll/Container,
		buttons
	)

	print(
		"FOUND ELEMENT BUTTONS: ",
		buttons.size()
	)


	for button in buttons:

		var symbol := button.name

		if AtomonDatabase.ELEMENTS.has(symbol):

			var element: AtomonData = (
				AtomonDatabase.ELEMENTS[symbol]
			)

			button.set_element(
				element
			)

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

			print(
				"NO DATA FOR BUTTON: ",
				button.name
			)


	# ============================================================

	# COLLECT ELEMENT BUTTONS

	# ============================================================

func collect_element_buttons(
	parent: Node,
	buttons: Array[Node]
	) -> void:


	for child in parent.get_children():

		if (
			child is TextureButton
			and child.has_method("set_element")
		):

			buttons.append(
				child
			)

		if child.get_child_count() > 0:

			collect_element_buttons(
				child,
				buttons
			)


	# ============================================================

	# CONNECT ELEMENT BUTTONS

	# ============================================================

func connect_element_buttons(
	parent: Node
	) -> void:


	for child in parent.get_children():

		if child.has_signal(
			"element_selected"
		):

			print(
				"CONNECTING: ",
				child.name
			)

			if not child.element_selected.is_connected(
				_on_element_selected
			):

				child.element_selected.connect(
					_on_element_selected
				)


		if child.get_child_count() > 0:

			connect_element_buttons(
				child
			)


	# ============================================================

	# CHECK LOCAL CRAFTED STATE

	# ============================================================

func is_element_crafted(
	element: AtomonData
	) -> bool:


	if element == null:
		return false

	var symbol := str(
		element.chemical_symbol
	).strip_edges()

	if symbol.is_empty():
		return false


	for atomon in PartyManager.party:

		if atomon == null:
			continue

		if atomon.data == null:
			continue

		if (
			str(
				atomon.data.chemical_symbol
			).strip_edges()
			== symbol
		):

			return true


	return false


	# ============================================================

	# REFRESH ALL CRAFTED BUTTONS

	# ============================================================

func _refresh_all_crafted_buttons() -> void:


	var buttons: Array[Node] = []

	collect_element_buttons(
		$TextureRect/PeriodicTableScroll/Container,
		buttons
	)


	for button in buttons:

		if button.element_data == null:
			continue


		var crafted := is_element_crafted(
			button.element_data
		)


		button.set_crafted(
			crafted
		)


	print(
		"[CraftingUI] Refreshed crafted states from current party."
	)


	# ============================================================
	# UPDATE CRAFTING RECIPE
	# ============================================================

func _update_crafting_recipe(
	element: AtomonData
	) -> void:

	if element == null:

		proton_count.text = "0"
		electron_count.text = "0"
		neutron_count.text = "0"
		atomic_core_count.text = "0"

		return


	var proton_required: int = (
		element.atomic_number
	)

	var electron_required: int = (
		element.atomic_number
	)

	var neutron_required: int = (
		element.mass_number
		- element.atomic_number
	)

	var atomic_core_required: int = 1


	var proton_available: int = (
		InventoryManager.get_item_count("proton")
	)

	var electron_available: int = (
		InventoryManager.get_item_count("electron")
	)

	var neutron_available: int = (
		InventoryManager.get_item_count("neutron")
	)

	var atomic_core_available: int = (
		InventoryManager.get_item_count("atomic_core")
	)


	proton_count.text = _format_material_count(
		proton_available,
		proton_required
	)

	electron_count.text = _format_material_count(
		electron_available,
		electron_required
	)

	neutron_count.text = _format_material_count(
		neutron_available,
		neutron_required
	)

	atomic_core_count.text = _format_material_count(
		atomic_core_available,
		atomic_core_required
	)


	print(
		"[CraftingUI] Recipe for ",
		element.atom_name,
		": Proton × ",
		proton_required,
		", Electron × ",
		electron_required,
		", Neutron × ",
		neutron_required,
		", Atomic Core × ",
		atomic_core_required
	)

func _format_material_count(
	have: int,
	required: int
	) -> String:

	if have >= required:

		return (
			str(have)
			+ " / "
			+ str(required)
			+ "  Ready"
		)


	var missing: int = (
		required - have
	)

	return (
		str(have)
		+ " / "
		+ str(required)
		+ "  Missing "
		+ str(missing)
	)


# ============================================================
# UPDATE MATERIAL STATUS
# ============================================================

func _update_material_status(
	element: AtomonData
	) -> void:

	if element == null:

		material_status.text = (
			"Select an element to see material requirements."
		)

		return


	var requirements: Dictionary = (
		_get_crafting_requirements(element)
	)


	var all_materials_available: bool = (
		_has_required_materials(requirements)
	)


	if all_materials_available:

		material_status.text = (
			"READY TO CRAFT"
		)

	else:

		material_status.text = (
			"INSUFFICIENT MATERIALS"
		)

func _update_craft_button() -> void:

	if selected_element == null:
		craft_button.disabled = true
		return

	# Party is full
	if PartyManager.party.size() >= PartyManager.MAX_PARTY_SIZE:
		craft_button.disabled = true
		return

	# Check materials
	var requirements: Dictionary = _get_crafting_requirements(
		selected_element
	)

	if not _has_required_materials(requirements):
		craft_button.disabled = true
		return

	# Everything is ready
	craft_button.disabled = false


# ============================================================

# ELEMENT SELECTED

# ============================================================

func _on_element_selected(
	element: AtomonData,
	crafted: bool
	) -> void:


	print(
		"SELECTED ELEMENT: ",
		element.atom_name
	)

	_update_crafting_recipe(
		element
	)

	_update_material_status(
		element
	)

	print(
		"BUTTON CRAFTED STATE: ",
		crafted
	)

	selected_element = element
	
	_update_craft_button()
	
	info_panel.visible = true


	var actual_crafted := is_element_crafted(
		element
	)

	print(
		"[CraftingUI] Actual local crafted state: ",
		actual_crafted
	)


	if not actual_crafted:

		element_background.texture = preload(
			"res://Assets/UX/HUD/Panels/slot.png"
		)

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

		print(
			"[CraftingUI] Element has NOT been crafted."
		)

		return


	element_background.texture = (
		TYPE_BACKGROUNDS.get(
			element.element_type
		)
	)

	atomic_symbol.text = (
		element.chemical_symbol
	)

	atomic_number.text = (
		str(element.atomic_number)
	)

	atomic_mass.text = (
		str(element.atomic_mass)
	)

	atomic_name.text = (
		element.atom_name
	)

	element_type.text = (
		element.element_type
	)

	density_value.text = (
		str(element.density)
	)

	ie_value.text = (
		str(element.ionization_energy)
	)

	electronegativity_value.text = (
		str(element.electronegativity)
	)

	ea_value.text = (
		str(element.electron_affinity)
	)

	valence_electrons_value.text = (
		str(element.valence_electrons)
	)

	phase_value.text = (
		str(element.state)
	)

	period_value.text = (
		str(element.period)
	)

	block_value.text = (
		str(element.block)
	)

	radioactive_value.text = (
		"Yes"
		if element.radioactive
		else
		"No"
	)

	print(
		"[CraftingUI] Showing crafted element: ",
		element.chemical_symbol
	)


	# ============================================================

	# GET CRAFTING REQUIREMENTS

	# ============================================================

func _get_crafting_requirements(
	element: AtomonData
	) -> Dictionary:


	if element == null:
		return {}


	var requirements := {
		"proton": element.atomic_number,
		"electron": element.atomic_number,
		"neutron": (
			element.mass_number
			- element.atomic_number
		),
		"atomic_core": 1
	}

	return requirements


	# ============================================================

	# CHECK CRAFTING MATERIALS

	# ============================================================

func _has_required_materials(
	requirements: Dictionary
	) -> bool:


	for item_id in requirements:

		var required_amount: int = (
			int(requirements[item_id])
		)

		var available_amount: int = (
			InventoryManager.get_item_count(
				str(item_id)
			)
		)

		print(
			"[CraftingUI] Material check: ",
			item_id,
			" required=",
			required_amount,
			" available=",
			available_amount
		)

		if available_amount < required_amount:

			print(
				"[CraftingUI] NOT ENOUGH ",
				item_id,
				". Required: ",
				required_amount,
				" Available: ",
				available_amount
			)

			return false


	return true


	# ============================================================

	# CONSUME CRAFTING MATERIALS

	# ============================================================

func _consume_crafting_materials(
	requirements: Dictionary
	) -> bool:


	for item_id in requirements:

		var required_amount: int = (
			int(requirements[item_id])
		)

		var success := InventoryManager.remove_item_by_id(
			str(item_id),
			required_amount
		)

		if not success:

			print(
				"[CraftingUI] FAILED TO CONSUME: ",
				item_id
			)

			return false

		print(
			"[CraftingUI] CONSUMED ",
			item_id,
			" × ",
			required_amount
		)


	return true


	# ============================================================

	# CRAFT

	# ============================================================

func _on_craft_pressed() -> void:

	if selected_element == null:

		print(
			"[CraftingUI] No element selected."
		)

		return


	print(
		"[CraftingUI] CRAFTING: ",
		selected_element.atom_name
	)

	print(
		"[CraftingUI] SYMBOL: ",
		selected_element.chemical_symbol
	)


	# ========================================================
	# CHECK PARTY CAPACITY
	# ========================================================

	if (
		PartyManager.party.size()
		>= PartyManager.MAX_PARTY_SIZE
	):

		print(
			"[CraftingUI] PARTY IS FULL"
		)

		return




	# ========================================================
	# GET MATERIAL REQUIREMENTS
	# ========================================================

	var requirements := _get_crafting_requirements(
		selected_element
	)


	# ========================================================
	# CHECK MATERIALS
	# ========================================================

	if not _has_required_materials(
		requirements
	):

		print(
			"[CraftingUI] CRAFTING CANCELLED: insufficient materials."
		)

		return


	# ========================================================
	# CONSUME MATERIALS
	# ========================================================

	if not _consume_crafting_materials(
		requirements
	):

		print(
			"[CraftingUI] CRAFTING CANCELLED: material consumption failed."
		)

		return


	# ========================================================
	# CREATE ATOMON
	# ========================================================

	var new_atomon: AtomonInstance = (
		PartyManager.add_species(
			selected_element
		)
	)


	if new_atomon == null:

		print(
			"[CraftingUI] FAILED TO CRAFT: ",
			selected_element.atom_name
		)

		return


	# ========================================================
	# MARK BUTTON AS CRAFTED
	# ========================================================

	var buttons: Array[Node] = []

	collect_element_buttons(
		$TextureRect/PeriodicTableScroll/Container,
		buttons
	)


	for button in buttons:

		if button.element_data == selected_element:

			button.set_crafted(
				true
			)

			break


	# ========================================================
	# CRAFT SUCCESS
	# ========================================================

	print(
		"[CraftingUI] Atomon added to LOCAL PARTY."
	)

	print(
		"[CraftingUI] Materials successfully consumed."
	)

	print(
		"[CraftingUI] Current party size: ",
		PartyManager.party.size()
	)

	
	# ========================================================
	# AUTOMATICALLY SAVE CRAFTING PROGRESS
	# ========================================================

	print(
		"[CraftingUI] Saving progress after successful crafting..."
	)

	await SaveManager.auto_save("Crafted Atomon: " + selected_element.chemical_symbol)

	print(
		"[CraftingUI] Crafting progress saved successfully."
	)
	
	# ========================================================
	# UPDATE INFO PANEL
	# ========================================================

	_on_element_selected(
		selected_element,
		true
	)
	

	# ============================================================

	# CLOSE INFO PANEL

	# ============================================================
func _on_close_button_pressed() -> void:


	info_panel.visible = false


	# ============================================================

	# CLOSE CRAFTING UI

	# ============================================================

func _on_close_crafting_pressed() -> void:


	print(
		"CLOSING CRAFTING UI"
	)
	if hud:
		hud.show()
	
	if global.player:
		global.player.can_move = true
	
	queue_free()

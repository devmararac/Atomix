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

@onready var element_background = (
	$"TextureRect/Info Panel/TextureRect/Container/TextureRect2"
)

@onready var atomic_symbol = (
	$"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Atomic Symbol"
)

@onready var atomic_number = (
	$"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Atomic Number"
)

@onready var atomic_mass = (
	$"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Atomic Mass"
)

@onready var atomic_name = (
	$"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Atomic Name"
)

@onready var element_type = (
	$"TextureRect/Info Panel/TextureRect/Container/TextureRect2/Type"
)

@onready var craft_button = (
	$"TextureRect/Info Panel/Control/Craft Button"
)


@onready var density_value = (
	$"TextureRect/Info Panel/TextureRect/Container/GridContainer/Density Value"
)

@onready var ie_value = (
	$"TextureRect/Info Panel/TextureRect/Container/GridContainer/IE Value"
)

@onready var electronegativity_value = (
	$"TextureRect/Info Panel/TextureRect/Container/GridContainer/Electronegativity Value"
)

@onready var ea_value = (
	$"TextureRect/Info Panel/TextureRect/Container/GridContainer/EA Value"
)

@onready var valence_electrons_value = (
	$"TextureRect/Info Panel/TextureRect/Container/GridContainer/VE Value"
)

@onready var phase_value = (
	$"TextureRect/Info Panel/TextureRect/Container/GridContainer/Phase Value"
)

@onready var period_value = (
	$"TextureRect/Info Panel/TextureRect/Container/GridContainer/Period Value"
)

@onready var block_value = (
	$"TextureRect/Info Panel/TextureRect/Container/GridContainer/Block Value"
)

@onready var radioactive_value = (
	$"TextureRect/Info Panel/TextureRect/Container/GridContainer/Radioactive Value"
)


# ============================================================
# READY
# ============================================================

func _ready() -> void:

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


	# --------------------------------------------------------
	# IMPORTANT
	#
	# Do NOT call StudentDataManager.load_student() here.
	#
	# Do NOT download Firebase data here.
	#
	# The crafting UI only displays the current runtime state.
	#
	# SaveManager.load_game() is responsible for restoring
	# saved data.
	# --------------------------------------------------------

	_refresh_all_crafted_buttons()


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


	# --------------------------------------------------------
	# IMPORTANT:
	#
	# The party is the current runtime source of truth.
	#
	# If the player crafted an Atomon this session,
	# it exists here.
	#
	# If SaveManager.load_game() restored an Atomon,
	# it also exists here.
	#
	# Firebase itself is NOT queried.
	# --------------------------------------------------------

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

	print(
		"BUTTON CRAFTED STATE: ",
		crafted
	)

	selected_element = element

	info_panel.visible = true


	# --------------------------------------------------------
	# ALWAYS VERIFY AGAINST CURRENT PARTY
	# --------------------------------------------------------

	var actual_crafted := is_element_crafted(
		element
	)

	print(
		"[CraftingUI] Actual local crafted state: ",
		actual_crafted
	)


	if not actual_crafted:

		# ====================================================
		# UNCRAFTED
		# ====================================================

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


	# ========================================================
	# CRAFTED
	# ========================================================

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
	# CHECK IF ALREADY CRAFTED
	# ========================================================

	if is_element_crafted(
		selected_element
	):

		print(
			"[CraftingUI] ALREADY CRAFTED: ",
			selected_element.atom_name
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
	# IMPORTANT:
	#
	# DO NOT CALL:
	#
	# await StudentDataManager.collect_element(...)
	#
	# Crafting must NOT save to Firebase.
	#
	# SaveManager.save_game() will register the element
	# and upload it when the player actually presses SAVE.
	# ========================================================

	print(
		"[CraftingUI] Atomon added to LOCAL PARTY."
	)

	print(
		"[CraftingUI] Firebase was NOT updated."
	)

	print(
		"[CraftingUI] Current party size: ",
		PartyManager.party.size()
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

	queue_free()

	if global.player:

		global.player.can_move = true

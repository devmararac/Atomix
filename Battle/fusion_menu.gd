extends CanvasLayer

signal fusion_components_selected(
	recipe: FusionRecipe,
	selected_atomons: Array[AtomonInstance]
)

# Emitted ONLY when the player manually closes/cancels
# the Fusion Menu.
signal fusion_menu_cancelled


const RECIPE_SLOT_SCENE := preload(
	"res://Battle/recipe_slot.tscn"
)

const GENERIC_MOLECULE_SCENE := preload(
	"res://Resources/Fusion/Molecules/generic_molecule.tscn"
)


# ============================================================
# UI REFERENCES
# ============================================================

# Main recipe section
@onready var recipe_title: Label = \
	$FusionPanel/RecipeSection/SectionTitle

@onready var recipe_hint: Label = \
	$FusionPanel/RecipeSection/SectionHint

@onready var fusion_title: Label = \
	$FusionPanel/Title

@onready var recipe_section: Panel = \
	$FusionPanel/RecipeSection

@onready var cancel = $CancelButton


# Recipe selection
@onready var recipe_scroll: ScrollContainer = \
	$FusionPanel/RecipeScroll

@onready var recipe_grid: GridContainer = \
	$FusionPanel/RecipeScroll/RecipeGrid

@onready var no_recipes_label: Label = \
	$Overlay/NoRecipesLabel

@onready var molecule_panel: Panel = \
	$FusionPanel/AtomonSelectionPanel/MoleculePanel


# Atomon selection
@onready var atomon_selection_panel: Control = \
	$FusionPanel/AtomonSelectionPanel

@onready var selection_header: Label = \
	$FusionPanel/AtomonSelectionPanel/SelectionHeader

@onready var selection_hint: Label = \
	$FusionPanel/AtomonSelectionPanel/SelectionHint

@onready var party_list: GridContainer = \
	$FusionPanel/AtomonSelectionPanel/SelectionScroll/PartyList

@onready var selection_status: Label = \
	$FusionPanel/AtomonSelectionPanel/SelectionStatusPanel/SelectionStatus

@onready var confirm_button: Button = \
	$FusionPanel/AtomonSelectionPanel/ConfirmButton


# General
@onready var cancel_button: Button = \
	$CancelButton


# ============================================================
# FUSION STATE
# ============================================================

var selected_recipe: FusionRecipe = null

var selected_atomons: Array[AtomonInstance] = []

var required_counts: Dictionary = {}

var selection_mode := false

# Currently displayed molecular formation scene.
var current_molecule_scene: Control = null


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[FusionMenu] Fusion Menu opened.")

	# Prevent player movement while Fusion Menu is open.
	if global.player != null:
		global.player.can_move = false

	# Start in recipe selection mode.
	show_recipe_selection()

	no_recipes_label.visible = false

	# Hide Atomon selection until a recipe is chosen.
	atomon_selection_panel.visible = false

	confirm_button.disabled = true

	selection_status.text = ""

	populate_fusion_recipes()


# ============================================================
# RECIPE SELECTION
# ============================================================

func populate_fusion_recipes() -> void:

	var available_recipes: Array[FusionRecipe] = \
		FusionManager.get_available_fusion_recipes()

	print(
		"[FusionMenu] Available Fusion Recipes: ",
		available_recipes.size()
	)


	# --------------------------------------------------------
	# Clear existing dynamically-created recipe slots
	# --------------------------------------------------------

	for child in recipe_grid.get_children():
		child.queue_free()


	# --------------------------------------------------------
	# No available recipes
	# --------------------------------------------------------

	if available_recipes.is_empty():

		no_recipes_label.visible = true
		recipe_scroll.visible = false

		return


	# --------------------------------------------------------
	# Recipes available
	# --------------------------------------------------------

	no_recipes_label.visible = false
	recipe_scroll.visible = true


	# --------------------------------------------------------
	# Create one RecipeSlot for every available recipe
	# --------------------------------------------------------

	for recipe in available_recipes:

		if recipe == null:
			continue

		var slot := RECIPE_SLOT_SCENE.instantiate()

		# Add slot to the GridContainer
		recipe_grid.add_child(slot)


		# Keep every slot at 468 × 120
		if slot is Control:

			slot.custom_minimum_size = Vector2(
				468,
				120
			)

			slot.size_flags_horizontal = \
				Control.SIZE_SHRINK_BEGIN

			slot.size_flags_vertical = \
				Control.SIZE_SHRINK_BEGIN


		# Configure RecipeSlot
		if slot.has_method("setup"):

			slot.setup(recipe)

		else:

			push_warning(
				"[FusionMenu] RecipeSlot has no setup(recipe) method."
			)

			continue


		# Connect button
		if slot is BaseButton:

			slot.pressed.connect(
				_on_recipe_selected.bind(recipe)
			)


		print(
			"[FusionMenu] Added RecipeSlot: ",
			recipe.compound_name,
			" | ",
			recipe.chemical_formula,
			" | Skill: ",
			recipe.fusion_skill_id
		)


# ============================================================
# RECIPE SELECTED
# ============================================================

func _on_recipe_selected(
	recipe: FusionRecipe
) -> void:

	if recipe == null:
		return

	selected_recipe = recipe

	selected_atomons.clear()

	required_counts = \
		recipe.get_required_element_counts()

	selection_mode = true


	print(
		"[FusionMenu] Selected Fusion: ",
		recipe.chemical_formula
	)

	print(
		"[FusionMenu] Compound: ",
		recipe.compound_name
	)

	print(
		"[FusionMenu] Requirements: ",
		required_counts
	)


	open_atomon_selection()


# ============================================================
# RECIPE UI VISIBILITY
# ============================================================

func show_recipe_selection() -> void:

	fusion_title.visible = true
	recipe_section.visible = true
	recipe_scroll.visible = true
	cancel.visible = true


func hide_recipe_selection() -> void:

	fusion_title.visible = false
	recipe_section.visible = false
	recipe_scroll.visible = false
	cancel.visible = false


# ============================================================
# OPEN ATOMON SELECTION
# ============================================================

func open_atomon_selection() -> void:

	if selected_recipe == null:
		return


	# --------------------------------------------------------
	# Hide recipe-selection interface.
	# --------------------------------------------------------

	hide_recipe_selection()

	no_recipes_label.visible = false


	# --------------------------------------------------------
	# Show Atomon selection.
	# --------------------------------------------------------

	atomon_selection_panel.visible = true


	# --------------------------------------------------------
	# LOAD GENERIC MOLECULAR FORMATION
	# --------------------------------------------------------

	load_molecule_scene(
		selected_recipe
	)


	# --------------------------------------------------------
	# Update selection UI.
	# --------------------------------------------------------

	selection_header.text = "BUILD MOLECULE"

	selection_hint.text = \
		"Drag the required Atomons into the molecular positions."


	selected_atomons.clear()

	required_counts = \
		selected_recipe.get_required_element_counts()


	confirm_button.disabled = true

	selection_status.text = \
		"Place all required Atomons."


	# --------------------------------------------------------
	# Load carried Atomons.
	# --------------------------------------------------------

	setup_party_slots()


	# --------------------------------------------------------
	# Listen for molecule changes.
	# --------------------------------------------------------

	connect_molecule_signals()

	update_selection_status()


# ============================================================
# MOLECULE SCENE
# ============================================================
# Every Fusion Skill now uses the same generic molecule scene.
#
# The generic molecule script receives the selected recipe and
# automatically creates the required FusionMoleculeSlot nodes.
#
# Example:
#
# H2O
#   H ×2
#   O ×1
#
# creates:
#   H slot
#   O slot
#   H slot
#
# CH4
#   C ×1
#   H ×4
#
# creates:
#   C slot
#   H slot
#   H slot
#   H slot
#   H slot
#
# No individual molecule .tscn is required.
# ============================================================

func load_molecule_scene(
	recipe: FusionRecipe
) -> void:

	if recipe == null:

		push_warning(
			"[FusionMenu] Cannot load molecule scene: "
			+ "recipe is null."
		)

		return


	# --------------------------------------------------------
	# Remove previous molecule.
	# --------------------------------------------------------

	clear_molecule_scene()


	# --------------------------------------------------------
	# Instantiate generic molecule builder.
	# --------------------------------------------------------

	var molecule_instance: Node = \
		GENERIC_MOLECULE_SCENE.instantiate()


	if not molecule_instance is Control:

		push_warning(
			"[FusionMenu] Generic molecule scene root "
			+ "must inherit Control."
		)

		molecule_instance.queue_free()

		return


	current_molecule_scene = \
		molecule_instance as Control


	# --------------------------------------------------------
	# Add to Molecule Panel.
	# --------------------------------------------------------

	molecule_panel.add_child(
		current_molecule_scene
	)


	# --------------------------------------------------------
	# GIVE THE RECIPE TO THE GENERIC MOLECULE BUILDER
	# --------------------------------------------------------

	if current_molecule_scene.has_method(
		"setup_recipe"
	):

		current_molecule_scene.setup_recipe(
			recipe
		)

	else:

		push_warning(
			"[FusionMenu] generic_molecule.gd does not "
			+ "have setup_recipe(recipe)."
		)


	print(
		"[FusionMenu] Generic molecule loaded: ",
		recipe.chemical_formula,
		" | ",
		recipe.compound_name
	)

	print(
		"[FusionMenu] Required elements: ",
		recipe.get_required_element_counts()
	)


# ============================================================
# CLEAR MOLECULE
# ============================================================

func clear_molecule_scene() -> void:

	if current_molecule_scene == null:
		return

	if is_instance_valid(
		current_molecule_scene
	):

		current_molecule_scene.queue_free()

	current_molecule_scene = null


# ============================================================
# CONNECT MOLECULE SIGNALS
# ============================================================

func connect_molecule_signals() -> void:

	if current_molecule_scene == null:
		return


	if not current_molecule_scene.has_signal(
		"molecule_changed"
	):

		return


	var callback := Callable(
		self,
		"_on_molecule_changed"
	)


	if not current_molecule_scene.is_connected(
		"molecule_changed",
		callback
	):

		current_molecule_scene.connect(
			"molecule_changed",
			callback
		)


	# Immediately synchronize UI.
	_on_molecule_changed()


# ============================================================
# MOLECULE CHANGED
# ============================================================

func _on_molecule_changed() -> void:

	if current_molecule_scene == null:

		confirm_button.disabled = true

		selection_status.text = \
			"Build the molecule."

		return


	if not current_molecule_scene.has_method(
		"is_complete"
	):

		confirm_button.disabled = true

		selection_status.text = \
			"Molecule unavailable."

		return


	var complete: bool = \
		current_molecule_scene.is_complete()


	# --------------------------------------------------------
	# Molecule incomplete.
	# --------------------------------------------------------

	if not complete:

		confirm_button.disabled = true

		selection_status.text = \
			"Place all required Atomons."

		return


	# --------------------------------------------------------
	# Molecule complete.
	# --------------------------------------------------------

	confirm_button.disabled = false

	selection_status.text = \
		"Molecule complete!"


# ============================================================
# SET UP EXISTING PARTY SLOTS
# ============================================================

func setup_party_slots() -> void:

	var party: Array[AtomonInstance] = \
		PartyManager.get_carried_party()


	print(
		"[FusionMenu] Loading carried Atomons into Fusion slots."
	)

	print(
		"[FusionMenu] Carried party size: ",
		party.size()
	)


	var slots := party_list.get_children()


	for i in range(
		slots.size()
	):

		var slot = slots[i]

		if slot == null:
			continue


		# ----------------------------------------------------
		# RESET SLOT
		# ----------------------------------------------------

		if slot.has_method("clear_slot"):

			slot.clear_slot()


		if slot.has_method("set_selected"):

			slot.set_selected(false)


		# ----------------------------------------------------
		# ENABLE DRAG MODE
		# ----------------------------------------------------

		if slot.has_method("set_draggable"):

			slot.set_draggable(true)


		# ----------------------------------------------------
		# NO ATOMON FOR THIS SLOT
		# ----------------------------------------------------

		if i >= party.size():
			continue


		var atomon: AtomonInstance = \
			party[i]

		if atomon == null:
			continue

		if atomon.data == null:
			continue


		# ----------------------------------------------------
		# DISPLAY ATOMON
		# ----------------------------------------------------

		if slot.has_method("set_atomon"):

			slot.set_atomon(
				atomon
			)


		print(
			"[FusionMenu] Carried Slot ",
			i + 1,
			" = ",
			atomon.data.chemical_symbol
		)


# ============================================================
# SELECTION STATUS
# ============================================================

func update_selection_status() -> void:

	if selected_recipe == null:
		return


	if current_molecule_scene == null:

		selection_status.text = \
			"Build the molecule."

		confirm_button.disabled = true

		return


	if not current_molecule_scene.has_method(
		"is_complete"
	):

		selection_status.text = \
			"Build the molecule."

		confirm_button.disabled = true

		return


	var complete: bool = \
		current_molecule_scene.is_complete()


	if not complete:

		selection_status.text = \
			"Place all required Atomons."

		confirm_button.disabled = true

		return


	selection_status.text = \
		"Molecule complete!"

	confirm_button.disabled = false


# ============================================================
# GET SELECTED ATOMONS FROM MOLECULE
# ============================================================

func get_molecule_atomons() -> Array[AtomonInstance]:

	var atomons: Array[AtomonInstance] = []


	if current_molecule_scene == null:
		return atomons


	if not current_molecule_scene.has_method(
		"get_selected_atomons"
	):

		push_warning(
			"[FusionMenu] Molecule scene does not support "
			+ "get_selected_atomons()."
		)

		return atomons


	var result = \
		current_molecule_scene.get_selected_atomons()


	for atomon in result:

		if atomon == null:
			continue

		if atomon.data == null:
			continue

		if atomon in atomons:
			continue

		atomons.append(
			atomon
		)


	return atomons


# ============================================================
# GET SELECTED ELEMENT COUNTS
# ============================================================

func get_selected_counts() -> Dictionary:

	var counts: Dictionary = {}


	for atomon in selected_atomons:

		if atomon == null:
			continue

		if atomon.data == null:
			continue


		var symbol: String = \
			atomon.data.chemical_symbol


		counts[symbol] = \
			int(
				counts.get(
					symbol,
					0
				)
			) + 1


	return counts


# ============================================================
# CONFIRM FUSION
# ============================================================

func _on_confirm_pressed() -> void:

	if selected_recipe == null:
		return

	if current_molecule_scene == null:
		return


	# --------------------------------------------------------
	# CHECK MOLECULE COMPLETION
	# --------------------------------------------------------

	if not current_molecule_scene.has_method(
		"is_complete"
	):

		push_warning(
			"[FusionMenu] Molecule scene does not support "
			+ "is_complete()."
		)

		return


	if not current_molecule_scene.is_complete():

		selection_status.text = \
			"Complete the molecular formation first."

		return


	# --------------------------------------------------------
	# GET ATOMONS FROM MOLECULE
	# --------------------------------------------------------

	selected_atomons = \
		get_molecule_atomons()


	if selected_atomons.is_empty():

		selection_status.text = \
			"No Atomons placed."

		return


	print(
		"[FusionMenu] Confirm Fusion pressed."
	)


	var selected_counts := \
		get_selected_counts()


	print(
		"[FusionMenu] Required: ",
		required_counts
	)

	print(
		"[FusionMenu] Selected: ",
		selected_counts
	)


	# --------------------------------------------------------
	# EXACT CHEMICAL COMPOSITION
	# --------------------------------------------------------

	if not selection_matches_recipe():

		handle_wrong_selection()

		return


	# --------------------------------------------------------
	# CORRECT COMBINATION
	# --------------------------------------------------------

	handle_correct_selection()


# ============================================================
# CHECK EXACT CHEMICAL COMPOSITION
# ============================================================

func selection_matches_recipe() -> bool:

	if selected_recipe == null:
		return false


	var selected_counts := \
		get_selected_counts()


	# --------------------------------------------------------
	# CHECK 1
	# Exact total number of Atomons.
	# --------------------------------------------------------

	var required_total: int = 0


	for symbol in required_counts:

		required_total += \
			int(
				required_counts[symbol]
			)


	if selected_atomons.size() != required_total:

		print(
			"[FusionMenu] Wrong total number of Atomons."
		)

		return false


	# --------------------------------------------------------
	# CHECK 2
	# Exact quantity for every required element.
	# --------------------------------------------------------

	for symbol in required_counts:

		var required_amount: int = \
			int(
				required_counts[symbol]
			)

		var selected_amount: int = \
			int(
				selected_counts.get(
					symbol,
					0
				)
			)


		if selected_amount != required_amount:

			print(
				"[FusionMenu] Wrong amount of ",
				symbol,
				". Required: ",
				required_amount,
				" | Selected: ",
				selected_amount
			)

			return false


	# --------------------------------------------------------
	# CHECK 3
	# No unexpected elements.
	# --------------------------------------------------------

	for symbol in selected_counts:

		if not required_counts.has(symbol):

			print(
				"[FusionMenu] Unexpected element selected: ",
				symbol
			)

			return false


	return true


# ============================================================
# WRONG SELECTION
# ============================================================

func handle_wrong_selection() -> void:

	print(
		"[FusionMenu] Fusion Failed."
	)


	selection_status.text = \
		"Fusion Failed! Wrong Atomon combination."


	confirm_button.disabled = true


	await get_tree().create_timer(
		1.5
	).timeout


	if not is_inside_tree():
		return


	selected_atomons.clear()


	# --------------------------------------------------------
	# Clear the molecule instead of party-slot highlights.
	# --------------------------------------------------------

	if current_molecule_scene != null:

		if current_molecule_scene.has_method(
			"clear_atomons"
		):

			current_molecule_scene.clear_atomons()


	update_selection_status()


# ============================================================
# CORRECT SELECTION
# ============================================================

func handle_correct_selection() -> void:

	print(
		"[FusionMenu] Correct Atomon combination!"
	)

	print(
		"[FusionMenu] Fusion: ",
		selected_recipe.chemical_formula
	)


	for atomon in selected_atomons:

		if atomon == null:
			continue

		if atomon.data == null:
			continue


		print(
			"[FusionMenu] Fusion Component: ",
			atomon.data.chemical_symbol
		)


	selection_status.text = \
		"Correct combination!"


	confirm_button.disabled = true


	# --------------------------------------------------------
	# IMPORTANT
	#
	# The Fusion Menu only validates the chemical composition.
	#
	# It does NOT:
	# - consume Atomons
	# - consume Fusion
	# - perform the attack
	#
	# Those actions happen after the Octet Rule Challenge.
	# --------------------------------------------------------

	fusion_components_selected.emit(
		selected_recipe,
		selected_atomons
	)


	# Correct fusion is NOT cancellation.
	close_menu()


# ============================================================
# BUILD REQUIREMENT TEXT
# ============================================================

func build_requirement_text(
	recipe: FusionRecipe
) -> String:

	if recipe == null:
		return ""


	var parts: Array[String] = []


	for requirement in recipe.requirements:

		if requirement == null:
			continue

		if requirement.element == null:
			continue


		var symbol: String = \
			requirement.element.chemical_symbol

		var amount: int = \
			requirement.amount


		if amount == 1:

			parts.append(
				symbol
			)

		else:

			parts.append(
				symbol
				+ " ×"
				+ str(amount)
			)


	return \
		"Requires: " \
		+ " + ".join(parts)


# ============================================================
# CLOSE
# ============================================================

func _on_close_pressed() -> void:

	print(
		"[FusionMenu] Fusion Menu cancelled by player."
	)


	fusion_menu_cancelled.emit()

	close_menu()


func close_menu() -> void:

	print(
		"[FusionMenu] Closing Fusion Menu."
	)


	selection_mode = false

	clear_molecule_scene()


	# --------------------------------------------------------
	# Restore player movement.
	# --------------------------------------------------------

	if global.player != null:
		global.player.can_move = true


	queue_free()

extends CanvasLayer

signal fusion_components_selected(
	recipe: FusionRecipe,
	selected_atomons: Array[AtomonInstance]
)

# Emitted ONLY when the player manually closes/cancels
# the Fusion Menu.
signal fusion_menu_cancelled

const RECIPE_SLOT_SCENE := preload("res://Battle/recipe_slot.tscn")

@onready var title_label: Label = $FusionPanel/Title
@onready var subtitle_label: Label = $FusionPanel/Subtitle

# Recipe selection UI
@onready var recipe_scroll: ScrollContainer = $FusionPanel/RecipeScroll
@onready var recipe_list: Control = $FusionPanel/RecipeScroll/RecipeList
@onready var no_recipes_label: Label = $FusionPanel/NoRecipesLabel

# Atomon selection UI
@onready var atomon_selection_panel: Control = $FusionPanel/AtomonSelectionPanel
@onready var party_list: GridContainer = $FusionPanel/AtomonSelectionPanel/SelectionScroll/PartyList
@onready var selection_status: Label = $FusionPanel/AtomonSelectionPanel/SelectionStatus
@onready var confirm_button: Button = $FusionPanel/AtomonSelectionPanel/ConfirmButton

# General UI
@onready var cancel_button: Button = $FusionPanel/CancelButton


var selected_recipe: FusionRecipe = null

var selected_atomons: Array[AtomonInstance] = []

var required_counts: Dictionary = {}

var selection_mode := false


func _ready() -> void:
	print("[FusionMenu] Fusion Menu opened.")

	# Prevent the player from moving while Fusion Menu is open.
	if global.player != null:
		global.player.can_move = false

	# Start with recipe selection visible.
	recipe_scroll.visible = true
	no_recipes_label.visible = false

	# Atomon selection is hidden until a recipe is chosen.
	atomon_selection_panel.visible = false

	confirm_button.disabled = true

	selection_status.text = ""

	populate_fusion_recipes()


# ============================================================
# RECIPE LIST
# ============================================================

func populate_fusion_recipes() -> void:
	clear_recipe_list()

	var available_recipes: Array[FusionRecipe] = \
		FusionManager.get_available_fusion_recipes()

	print(
		"[FusionMenu] Available Fusion Recipes: ",
		available_recipes.size()
	)

	if available_recipes.is_empty():
		no_recipes_label.visible = true
		return

	no_recipes_label.visible = false

	for recipe in available_recipes:
		if recipe == null:
			continue

		create_recipe_slot(recipe)


func create_recipe_slot(recipe: FusionRecipe) -> void:
	var slot := RECIPE_SLOT_SCENE.instantiate()

	recipe_list.add_child(slot)

	var slot_index := recipe_list.get_child_count() - 1

	slot.position = Vector2(
		58.0,
		8.0 + (slot_index * 128.0)
	)

	var compound_name_label := \
		slot.get_node_or_null(
			"CompoundName/CompundName"
		) as Label

	var requirements_label := \
		slot.get_node_or_null(
			"CompundName"
		) as Label

	if compound_name_label != null:
		compound_name_label.text = recipe.compound_name

	if requirements_label != null:
		requirements_label.text = build_requirement_text(recipe)

	if slot is BaseButton:
		slot.pressed.connect(
			_on_recipe_selected.bind(recipe)
		)

	print(
		"[FusionMenu] Created Recipe Slot: ",
		recipe.chemical_formula
	)


# ============================================================
# RECIPE SELECTED
# ============================================================

func _on_recipe_selected(recipe: FusionRecipe) -> void:
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
# OPEN ATOMON SELECTION
# ============================================================

func open_atomon_selection() -> void:
	if selected_recipe == null:
		return

	# Hide recipe selection.
	recipe_scroll.visible = false
	no_recipes_label.visible = false

	# Show Atomon selection.
	atomon_selection_panel.visible = true

	title_label.text = "SELECT ATOMONS"

	subtitle_label.text = \
		"Choose the Atomons needed for " + \
		selected_recipe.chemical_formula

	selected_atomons.clear()

	required_counts = \
		selected_recipe.get_required_element_counts()

	confirm_button.disabled = true

	selection_status.text = "Selected: None"

	setup_party_slots()

	update_selection_status()


# ============================================================
# SET UP EXISTING PARTY SLOTS
# ============================================================

func setup_party_slots() -> void:
	var party: Array[AtomonInstance] = PartyManager.get_carried_party()

	print("[FusionMenu] Loading carried Atomons into Fusion slots.")
	print("[FusionMenu] Carried party size: ", party.size())

	var slots := party_list.get_children()

	for i in range(slots.size()):
		var slot := slots[i]

		if slot == null:
			continue

		# Clear the slot first.
		if slot.has_method("clear_slot"):
			slot.clear_slot()

		# Remove previous selection highlight.
		if slot.has_method("set_selected"):
			slot.set_selected(false)

		# We only have up to 8 carried Atomons.
		if i >= party.size():
			continue

		var atomon := party[i]

		if atomon == null:
			continue

		if atomon.data == null:
			continue

		# Display the carried Atomon.
		if slot.has_method("set_atomon"):
			slot.set_atomon(atomon)

		# Connect the slot click.
		if slot.has_signal("slot_clicked"):
			if not slot.slot_clicked.is_connected(_on_atomon_slot_clicked):
				slot.slot_clicked.connect(_on_atomon_slot_clicked)

		print(
			"[FusionMenu] Carried Slot ",
			i + 1,
			" = ",
			atomon.data.chemical_symbol
		)


# ============================================================
# ATOMON SLOT CLICKED
# ============================================================

func _on_atomon_slot_clicked(atomon: AtomonInstance) -> void:
	if not selection_mode:
		return

	if atomon == null:
		return

	if atomon.data == null:
		return

	var symbol := atomon.data.chemical_symbol

	print(
		"[FusionMenu] Atomon slot clicked: ",
		symbol
	)

	# Clicking an already-selected Atomon removes it.
	if atomon in selected_atomons:
		selected_atomons.erase(atomon)

		set_slot_selected_state(atomon, false)

		print(
			"[FusionMenu] Removed from selection: ",
			symbol
		)

	else:
		# Add this exact AtomonInstance.
		selected_atomons.append(atomon)

		set_slot_selected_state(atomon, true)

		print(
			"[FusionMenu] Added to selection: ",
			symbol
		)

	update_selection_status()


# ============================================================
# VISUAL SELECTION STATE
# ============================================================

func set_slot_selected_state(
	atomon: AtomonInstance,
	selected: bool
) -> void:

	var slots := party_list.get_children()

	for slot in slots:
		if slot == null:
			continue

		# The party slot script may support selection visuals.
		if slot.has_method("set_selected"):
			# We need to determine which slot contains
			# this exact AtomonInstance.
			if slot.has_method("get_atomon"):
				var slot_atomon = slot.get_atomon()

				if slot_atomon == atomon:
					slot.set_selected(selected)

			# If get_atomon() isn't available, the visual
			# selection is handled by party_slot.gd itself.


# ============================================================
# SELECTION STATUS
# ============================================================

func update_selection_status() -> void:
	if selected_recipe == null:
		return

	var selected_counts := get_selected_counts()

	if selected_atomons.is_empty():
		selection_status.text = "Selected: None"
		confirm_button.disabled = true
		return

	selection_status.text = \
		"Selected: " + build_counts_text(selected_counts)

	confirm_button.disabled = false


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

		var symbol := \
			atomon.data.chemical_symbol

		counts[symbol] = \
			int(counts.get(symbol, 0)) + 1

	return counts


func build_counts_text(counts: Dictionary) -> String:
	if counts.is_empty():
		return "None"

	var parts: Array[String] = []

	for symbol in counts:
		var amount: int = int(counts[symbol])

		if amount == 1:
			parts.append(symbol)
		else:
			parts.append(
				symbol + " ×" + str(amount)
			)

	return " + ".join(parts)


# ============================================================
# CONFIRM FUSION
# ============================================================

func _on_confirm_pressed() -> void:
	if selected_recipe == null:
		return

	if selected_atomons.is_empty():
		return

	print(
		"[FusionMenu] Confirm Fusion pressed."
	)

	var selected_counts := get_selected_counts()

	print(
		"[FusionMenu] Required: ",
		required_counts
	)

	print(
		"[FusionMenu] Selected: ",
		selected_counts
	)

	# Check the student's exact combination.
	if not selection_matches_recipe():
		handle_wrong_selection()
		return

	# Correct combination.
	handle_correct_selection()


# ============================================================
# CHECK EXACT CHEMICAL COMPOSITION
# ============================================================

func selection_matches_recipe() -> bool:
	if selected_recipe == null:
		return false

	var selected_counts := get_selected_counts()

	# --------------------------------------------------------
	# CHECK 1
	# Total number of Atomons must be exact.
	#
	# Example:
	# H2O = 2 H + 1 O = 3 Atomons
	# --------------------------------------------------------

	var required_total := 0

	for symbol in required_counts:
		required_total += \
			int(required_counts[symbol])

	if selected_atomons.size() != required_total:
		print(
			"[FusionMenu] Wrong total number of Atomons."
		)

		return false


	# --------------------------------------------------------
	# CHECK 2
	# Every required element must have the exact amount.
	# --------------------------------------------------------

	for symbol in required_counts:
		var required_amount: int = \
			int(required_counts[symbol])

		var selected_amount: int = \
			int(selected_counts.get(symbol, 0))

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
	# Student cannot include an unexpected element.
	#
	# Example:
	# H + H + O + C
	# is invalid for H2O because C isn't required.
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

	# Do NOT consume Fusion.
	#
	# The student is allowed to try again.
	confirm_button.disabled = true

	await get_tree().create_timer(1.5).timeout

	if not is_inside_tree():
		return

	# Clear the previous attempt.
	selected_atomons.clear()

	reset_party_slot_visuals()

	update_selection_status()


# ============================================================
# RESET PARTY SLOT VISUALS
# ============================================================

func reset_party_slot_visuals() -> void:
	var slots := party_list.get_children()

	for slot in slots:
		if slot == null:
			continue

		if slot.has_method("set_selected"):
			slot.set_selected(false)


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
	# IMPORTANT:
	#
	# This is ONLY the chemical-composition check.
	#
	# We have NOT consumed Fusion yet.
	# We have NOT performed the attack yet.
	#
	# The next step is the Octet Rule Challenge.
	# --------------------------------------------------------

	fusion_components_selected.emit(
		selected_recipe,
		selected_atomons
	)

	# This is NOT considered a cancellation.
	#
	# Therefore we intentionally do NOT emit
	# fusion_menu_cancelled here.
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

		var symbol := \
			requirement.element.chemical_symbol

		var amount := \
			requirement.amount

		if amount == 1:
			parts.append(symbol)
		else:
			parts.append(
				symbol + " ×" + str(amount)
			)

	return "Requires: " + " + ".join(parts)


# ============================================================
# CLEAR RECIPE LIST
# ============================================================

func clear_recipe_list() -> void:
	for child in recipe_list.get_children():
		child.queue_free()


# ============================================================
# CLOSE
# ============================================================

func _on_close_pressed() -> void:
	# This means the player intentionally cancelled/closed
	# the Fusion Menu.
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

	if global.player != null:
		global.player.can_move = true

	queue_free()

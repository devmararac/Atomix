extends Control

signal molecule_changed


# ============================================================
# CONFIGURATION
# ============================================================

const MOLECULE_SLOT_SCENE := preload(
	"res://Resources/Fusion/fusion_molecule_slot.tscn"
)

const SLOT_SIZE := 90.0
const SLOT_HALF := 45.0

# Actual scrollable molecule workspace.
const MOLECULE_WIDTH := 700.0
const MOLECULE_HEIGHT := 500.0

const BOND_WIDTH := 8.0
const BOND_COLOR := Color(0.78, 0.72, 0.58, 0.9)


# ============================================================
# NODES
# ============================================================

@onready var formula_label: Label = $Formula

@onready var slot_container: Control = (
	$MoleculeScroll/MoleculeContent/SlotContainer
)

@onready var bond_container: Control = (
	$MoleculeScroll/MoleculeContent/BondContainer
)


# ============================================================
# STATE
# ============================================================

var recipe: FusionRecipe = null

var molecule_slots: Array[FusionMoleculeSlot] = []


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# FusionMenu supplies the recipe through setup_recipe().
	pass


# ============================================================
# SETUP RECIPE
# ============================================================

func setup_recipe(
	new_recipe: FusionRecipe
) -> void:

	recipe = new_recipe

	if recipe == null:
		return

	call_deferred(
		"build_molecule"
	)


# ============================================================
# BUILD MOLECULE
# ============================================================

func build_molecule() -> void:

	if recipe == null:
		return

	if slot_container == null:
		return

	clear_molecule()


	# --------------------------------------------------------
	# UPDATE FORMULA
	# --------------------------------------------------------

	formula_label.text = (
		recipe.chemical_formula
		+ "  •  "
		+ recipe.compound_name.to_upper()
	)


	# --------------------------------------------------------
	# CREATE REQUIRED SLOTS
	# --------------------------------------------------------

	for requirement in recipe.requirements:

		if requirement == null:
			continue

		if requirement.element == null:
			continue

		var symbol: String = (
			requirement.element.chemical_symbol
		)

		var amount: int = (
			requirement.amount
		)

		for i in range(amount):

			create_slot(
				symbol
			)


	# --------------------------------------------------------
	# AUTOMATIC POSITIONING
	# --------------------------------------------------------

	position_slots()


	# --------------------------------------------------------
	# AUTOMATIC BONDS
	# --------------------------------------------------------

	create_bonds()


	molecule_changed.emit()


# ============================================================
# CREATE ONE MOLECULE SLOT
# ============================================================

func create_slot(
	required_element: String
) -> void:

	var slot_instance := (
		MOLECULE_SLOT_SCENE.instantiate()
	)

	if not slot_instance is FusionMoleculeSlot:

		push_warning(
			"[GenericMolecule] "
			+ "fusion_molecule_slot.tscn "
			+ "does not contain FusionMoleculeSlot."
		)

		slot_instance.queue_free()

		return


	var slot: FusionMoleculeSlot = (
		slot_instance as FusionMoleculeSlot
	)


	# Set this before adding the slot to the tree.
	slot.required_element = required_element


	slot_container.add_child(
		slot
	)


	# Listen for Atomons being placed or removed.
	slot.atomon_placed.connect(
		_on_slot_changed
	)

	slot.atomon_removed.connect(
		_on_slot_changed
	)


	molecule_slots.append(
		slot
	)


# ============================================================
# SLOT CHANGED
# ============================================================

func _on_slot_changed(
	_atomon: AtomonInstance,
	_slot: FusionMoleculeSlot
) -> void:

	remove_duplicate_atomons()

	molecule_changed.emit()


# ============================================================
# REMOVE DUPLICATE ATOMONS
# ============================================================

func remove_duplicate_atomons() -> void:

	var used_atomons: Array[AtomonInstance] = []

	for slot in molecule_slots:

		if slot == null:
			continue

		var atomon: AtomonInstance = (
			slot.get_atomon()
		)

		if atomon == null:
			continue

		if atomon in used_atomons:

			slot.remove_atomon()

		else:

			used_atomons.append(
				atomon
			)


# ============================================================
# AUTOMATIC POSITIONING
# ============================================================

func position_slots() -> void:

	var count: int = molecule_slots.size()

	if count <= 0:
		return


	# --------------------------------------------------------
	# ONE ATOM
	# --------------------------------------------------------

	if count == 1:

		set_slot_position(
			molecule_slots[0],
			Vector2(
				305.0,
				205.0
			)
		)

		return


	# --------------------------------------------------------
	# DETERMINE MAIN ELEMENT
	# --------------------------------------------------------

	var primary_symbol: String = (
		get_primary_element_symbol()
	)

	var primary_slots: Array[FusionMoleculeSlot] = (
		get_slots_for_element(
			primary_symbol
		)
	)


	# --------------------------------------------------------
	# ONE MAIN ATOM
	# --------------------------------------------------------

	if primary_symbol != "" and primary_slots.size() == 1:

		position_single_primary(
			primary_slots[0]
		)

		return


	# --------------------------------------------------------
	# MULTIPLE MAIN ATOMS
	# --------------------------------------------------------

	if primary_symbol != "" and primary_slots.size() >= 2:

		position_primary_chain(
			primary_slots
		)

		return


	# --------------------------------------------------------
	# NO SPECIAL MAIN ELEMENT
	# --------------------------------------------------------

	position_simple_chain()


# ============================================================
# GET PRIMARY ELEMENT
# ============================================================

func get_primary_element_symbol() -> String:

	var counts: Dictionary = (
		get_element_counts()
	)

	if counts.is_empty():
		return ""


	if counts.size() == 1:
		return ""


	# --------------------------------------------------------
	# If hydrogen exists, prefer a non-hydrogen element.
	# --------------------------------------------------------

	if counts.has("H"):

		var best_symbol: String = ""
		var best_count: int = 999999

		for symbol in counts.keys():

			var current_symbol: String = (
				str(symbol)
			)

			if current_symbol == "H":
				continue

			var current_count: int = (
				int(counts[current_symbol])
			)

			if current_count < best_count:

				best_count = current_count
				best_symbol = current_symbol


		return best_symbol


	# --------------------------------------------------------
	# No hydrogen.
	# Choose the element appearing the fewest times.
	# --------------------------------------------------------

	var selected_symbol: String = ""
	var selected_count: int = 999999

	for symbol in counts.keys():

		var current_symbol: String = (
			str(symbol)
		)

		var current_count: int = (
			int(counts[current_symbol])
		)

		if current_count < selected_count:

			selected_count = current_count
			selected_symbol = current_symbol


	return selected_symbol


# ============================================================
# GET ELEMENT COUNTS
# ============================================================

func get_element_counts() -> Dictionary:

	var counts: Dictionary = {}

	for slot in molecule_slots:

		if slot == null:
			continue

		var symbol: String = (
			slot.required_element
		)

		if symbol.is_empty():
			continue

		if not counts.has(symbol):

			counts[symbol] = 0


		counts[symbol] += 1


	return counts


# ============================================================
# POSITION SINGLE PRIMARY ELEMENT
# ============================================================

func position_single_primary(
	primary_slot: FusionMoleculeSlot
) -> void:

	if primary_slot == null:
		return


	# --------------------------------------------------------
	# CENTER OF SCROLLABLE WORKSPACE
	# --------------------------------------------------------

	var center_position := Vector2(
		305.0,
		205.0
	)

	set_slot_position(
		primary_slot,
		center_position
	)


	# --------------------------------------------------------
	# GET OUTER SLOTS
	# --------------------------------------------------------

	var outer_slots: Array[FusionMoleculeSlot] = []

	for slot in molecule_slots:

		if slot == null:
			continue

		if slot == primary_slot:
			continue

		outer_slots.append(
			slot
		)


	# --------------------------------------------------------
	# SURROUNDING POSITIONS
	# --------------------------------------------------------

	var surrounding_positions: Array[Vector2] = [

		Vector2(
			305.0,
			105.0
		),

		Vector2(
			155.0,
			205.0
		),

		Vector2(
			455.0,
			205.0
		),

		Vector2(
			305.0,
			305.0
		),

		Vector2(
			155.0,
			105.0
		),

		Vector2(
			455.0,
			105.0
		),

		Vector2(
			155.0,
			305.0
		),

		Vector2(
			455.0,
			305.0
		)
	]


	for i in range(
		outer_slots.size()
	):

		var position_index: int = (
			i % surrounding_positions.size()
		)

		set_slot_position(
			outer_slots[i],
			surrounding_positions[position_index]
		)


# ============================================================
# POSITION MULTIPLE PRIMARY ELEMENTS
# ============================================================

func position_primary_chain(
	primary_slots: Array[FusionMoleculeSlot]
) -> void:

	var primary_count: int = (
		primary_slots.size()
	)

	if primary_count <= 0:
		return


	# --------------------------------------------------------
	# CALCULATE SPACING
	# --------------------------------------------------------

	var available_width: float = (
		MOLECULE_WIDTH - SLOT_SIZE
	)

	var gap: float = (
		available_width
		/ float(max(primary_count - 1, 1))
	)

	gap = min(
		gap,
		150.0
	)


	var total_width: float = (
		SLOT_SIZE
		+ gap * float(primary_count - 1)
	)

	var start_x: float = (
		(MOLECULE_WIDTH - total_width)
		/ 2.0
	)


	# --------------------------------------------------------
	# PLACE PRIMARY ELEMENTS
	# --------------------------------------------------------

	for i in range(primary_count):

		var x: float = (
			start_x
			+ gap * float(i)
		)

		set_slot_position(
			primary_slots[i],
			Vector2(
				x,
				205.0
			)
		)


	# --------------------------------------------------------
	# GET OUTER ELEMENTS
	# --------------------------------------------------------

	var outer_slots: Array[FusionMoleculeSlot] = []

	for slot in molecule_slots:

		if slot == null:
			continue

		if slot in primary_slots:
			continue

		outer_slots.append(
			slot
		)


	# --------------------------------------------------------
	# DISTRIBUTE OUTER ELEMENTS
	# --------------------------------------------------------

	var assigned_counts: Array[int] = []

	for i in range(primary_count):

		assigned_counts.append(0)


	for outer_slot in outer_slots:

		var best_index: int = 0
		var best_count: int = assigned_counts[0]

		for i in range(
			1,
			primary_count
		):

			if assigned_counts[i] < best_count:

				best_index = i
				best_count = assigned_counts[i]


		var local_index: int = (
			assigned_counts[best_index]
		)

		var offset: Vector2 = (
			get_outer_offset(
				best_index,
				local_index,
				primary_count
			)
		)


		var primary_position: Vector2 = (
			primary_slots[best_index].position
		)


		set_slot_position(
			outer_slot,
			primary_position + offset
		)


		assigned_counts[best_index] += 1


# ============================================================
# GET OUTER OFFSET
# ============================================================

func get_outer_offset(
	primary_index: int,
	local_index: int,
	primary_count: int
) -> Vector2:

	if local_index == 0:

		return Vector2(
			0.0,
			-90.0
		)


	if local_index == 1:

		return Vector2(
			0.0,
			90.0
		)


	if local_index == 2:

		if primary_index == 0:

			return Vector2(
				-90.0,
				0.0
			)

		if primary_index == primary_count - 1:

			return Vector2(
				90.0,
				0.0
			)

		return Vector2(
			90.0,
			0.0
		)


	var direction: float = 1.0

	if primary_index == 0:

		direction = -1.0


	return Vector2(
		90.0 * direction,
		45.0
	)


# ============================================================
# SIMPLE CHAIN
# ============================================================

func position_simple_chain() -> void:

	var count: int = (
		molecule_slots.size()
	)

	if count <= 0:
		return


	# --------------------------------------------------------
	# SMALL MOLECULES
	# --------------------------------------------------------

	if count <= 4:

		var gap: float = 110.0

		var total_width: float = (
			SLOT_SIZE
			+ gap * float(count - 1)
		)

		var start_x: float = (
			(MOLECULE_WIDTH - total_width)
			/ 2.0
		)


		for i in range(count):

			set_slot_position(
				molecule_slots[i],
				Vector2(
					start_x + gap * float(i),
					205.0
				)
			)

		return


	# --------------------------------------------------------
	# LARGER MOLECULES
	# --------------------------------------------------------

	var columns: int = 4

	var horizontal_gap: float = 110.0

	var total_row_width: float = (
		SLOT_SIZE
		+ horizontal_gap * float(columns - 1)
	)

	var start_x: float = (
		(MOLECULE_WIDTH - total_row_width)
		/ 2.0
	)


	for i in range(count):

		var row: int = (
			i / columns
		)

		var column: int = (
			i % columns
		)

		var x: float = (
			start_x
			+ horizontal_gap * float(column)
		)

		var y: float = (
			100.0
			+ float(row) * 100.0
		)


		set_slot_position(
			molecule_slots[i],
			Vector2(
				x,
				y
			)
		)


# ============================================================
# CREATE BONDS
# ============================================================

func create_bonds() -> void:

	if bond_container == null:
		return


	clear_bonds()


	if molecule_slots.size() < 2:
		return


	# --------------------------------------------------------
	# DETERMINE MAIN ELEMENT
	# --------------------------------------------------------

	var primary_symbol: String = (
		get_primary_element_symbol()
	)


	var primary_slots: Array[FusionMoleculeSlot] = (
		get_slots_for_element(
			primary_symbol
		)
	)


	# --------------------------------------------------------
	# MULTIPLE MAIN ELEMENTS
	# --------------------------------------------------------

	if primary_slots.size() >= 2:

		for i in range(
			primary_slots.size() - 1
		):

			create_bond_between(
				primary_slots[i],
				primary_slots[i + 1]
			)


		for slot in molecule_slots:

			if slot == null:
				continue

			if slot in primary_slots:
				continue

			var nearest_primary: FusionMoleculeSlot = (
				get_nearest_slot(
					slot,
					primary_slots
				)
			)


			if nearest_primary != null:

				create_bond_between(
					nearest_primary,
					slot
				)

		return


	# --------------------------------------------------------
	# ONE MAIN ELEMENT
	# --------------------------------------------------------

	if primary_slots.size() == 1:

		var primary_slot: FusionMoleculeSlot = (
			primary_slots[0]
		)


		for slot in molecule_slots:

			if slot == null:
				continue

			if slot == primary_slot:
				continue


			create_bond_between(
				primary_slot,
				slot
			)

		return


	# --------------------------------------------------------
	# NO MAIN ELEMENT
	# --------------------------------------------------------

	for i in range(
		molecule_slots.size() - 1
	):

		create_bond_between(
			molecule_slots[i],
			molecule_slots[i + 1]
		)


# ============================================================
# GET NEAREST SLOT
# ============================================================

func get_nearest_slot(
	target_slot: FusionMoleculeSlot,
	candidates: Array[FusionMoleculeSlot]
) -> FusionMoleculeSlot:

	if target_slot == null:
		return null

	if candidates.is_empty():
		return null


	var nearest: FusionMoleculeSlot = (
		candidates[0]
	)

	var nearest_distance: float = (
		target_slot.position.distance_squared_to(
			nearest.position
		)
	)


	for i in range(
		1,
		candidates.size()
	):

		var candidate: FusionMoleculeSlot = (
			candidates[i]
		)

		if candidate == null:
			continue


		var distance: float = (
			target_slot.position.distance_squared_to(
				candidate.position
			)
		)


		if distance < nearest_distance:

			nearest = candidate
			nearest_distance = distance


	return nearest


# ============================================================
# CREATE ONE BOND
# ============================================================

func create_bond_between(
	first_slot: FusionMoleculeSlot,
	second_slot: FusionMoleculeSlot
) -> void:

	if first_slot == null:
		return

	if second_slot == null:
		return

	if bond_container == null:
		return


	var first_center: Vector2 = (
		get_slot_center(
			first_slot
		)
	)

	var second_center: Vector2 = (
		get_slot_center(
			second_slot
		)
	)

	var bond := Line2D.new()

	bond.name = "Bond"

	bond.width = BOND_WIDTH

	bond.default_color = BOND_COLOR

	bond.antialiased = true


	bond.add_point(
		first_center
	)

	bond.add_point(
		second_center
	)


	bond_container.add_child(
		bond
	)


# ============================================================
# GET SLOT CENTER
# ============================================================

func get_slot_center(
	slot: FusionMoleculeSlot
) -> Vector2:

	if slot == null:
		return Vector2.ZERO


	return (
		slot.position
		+ Vector2(
			SLOT_HALF,
			SLOT_HALF
		)
	)


# ============================================================
# GET SLOTS FOR ELEMENT
# ============================================================

func get_slots_for_element(
	symbol: String
) -> Array[FusionMoleculeSlot]:

	var result: Array[FusionMoleculeSlot] = []

	if symbol.is_empty():
		return result


	for slot in molecule_slots:

		if slot == null:
			continue

		if slot.required_element == symbol:

			result.append(
				slot
			)


	return result


# ============================================================
# CLEAR BONDS
# ============================================================

func clear_bonds() -> void:

	if bond_container == null:
		return


	for child in bond_container.get_children():

		if child == null:
			continue

		child.queue_free()


# ============================================================
# SET SLOT POSITION
# ============================================================

func set_slot_position(
	slot: FusionMoleculeSlot,
	position: Vector2
) -> void:

	if slot == null:
		return

	slot.position = position


# ============================================================
# CHECK COMPLETION
# ============================================================

func is_complete() -> bool:

	if molecule_slots.is_empty():
		return false


	for slot in molecule_slots:

		if slot == null:
			return false

		if not slot.is_occupied():
			return false


	return true


# ============================================================
# GET SELECTED ATOMONS
# ============================================================

func get_selected_atomons() -> Array[AtomonInstance]:

	var atomons: Array[AtomonInstance] = []


	for slot in molecule_slots:

		if slot == null:
			continue


		var atomon: AtomonInstance = (
			slot.get_atomon()
		)


		if atomon == null:
			continue


		if atomon in atomons:
			continue


		atomons.append(
			atomon
		)


	return atomons


# ============================================================
# CLEAR ATOMONS
# ============================================================

func clear_atomons() -> void:

	for slot in molecule_slots:

		if slot == null:
			continue

		slot.remove_atomon()


	molecule_changed.emit()


# ============================================================
# CLEAR MOLECULE
# ============================================================

func clear_molecule() -> void:

	clear_bonds()


	for slot in molecule_slots:

		if slot == null:
			continue

		if is_instance_valid(slot):

			slot.queue_free()


	molecule_slots.clear()

extends Control

signal molecule_changed


# ============================================================
# MOLECULE SLOTS
# ============================================================

@onready var hydrogen_slot_01: FusionMoleculeSlot = \
	$HydrogenSlot01

@onready var oxygen_slot: FusionMoleculeSlot = \
	$OxygenSlot

@onready var hydrogen_slot_02: FusionMoleculeSlot = \
	$HydrogenSlot02


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	# --------------------------------------------------------
	# Listen for changes from every molecular slot.
	# --------------------------------------------------------

	hydrogen_slot_01.atomon_placed.connect(
		_on_slot_changed
	)

	hydrogen_slot_01.atomon_removed.connect(
		_on_slot_changed
	)

	oxygen_slot.atomon_placed.connect(
		_on_slot_changed
	)

	oxygen_slot.atomon_removed.connect(
		_on_slot_changed
	)

	hydrogen_slot_02.atomon_placed.connect(
		_on_slot_changed
	)

	hydrogen_slot_02.atomon_removed.connect(
		_on_slot_changed
	)


	# --------------------------------------------------------
	# Tell FusionMenu the initial molecule state.
	# --------------------------------------------------------

	molecule_changed.emit()


# ============================================================
# SLOT CHANGED
# ============================================================

func _on_slot_changed(
	_atomon: AtomonInstance,
	_slot: FusionMoleculeSlot
) -> void:

	molecule_changed.emit()


# ============================================================
# CHECK COMPLETION
# ============================================================

func is_complete() -> bool:

	return (
		hydrogen_slot_01.is_occupied()
		and oxygen_slot.is_occupied()
		and hydrogen_slot_02.is_occupied()
	)


# ============================================================
# GET SELECTED ATOMONS
# ============================================================

func get_selected_atomons() -> Array[AtomonInstance]:

	var atomons: Array[AtomonInstance] = []

	var slots: Array[FusionMoleculeSlot] = [
		hydrogen_slot_01,
		oxygen_slot,
		hydrogen_slot_02
	]


	for slot in slots:

		if slot == null:
			continue

		var atomon: AtomonInstance = \
			slot.get_atomon()

		if atomon == null:
			continue

		if atomon in atomons:
			continue

		atomons.append(atomon)


	return atomons


# ============================================================
# CLEAR ATOMONS
# ============================================================

func clear_atomons() -> void:

	hydrogen_slot_01.remove_atomon()
	oxygen_slot.remove_atomon()
	hydrogen_slot_02.remove_atomon()

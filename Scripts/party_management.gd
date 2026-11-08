extends Control

signal atomon_selected(atomon: AtomonInstance)

const PARTY_SLOT_SCENE := preload(
	"res://Scenes/UI/party_slot.tscn"
)

@onready var grid_container: GridContainer = (
	$Panel/ScrollContainer/GridContainer
)

@onready var selection_count: Label = (
	$Panel/SelectionCount
)

@onready var instruction: Label = (
	$Panel/Instruction
)

@onready var switch_button: TextureButton = (
	$Panel/SwitchButton
)

@onready var cancel_button: TextureButton = (
	$Panel/CancelButton
)


# ============================================================
# PARTY MANAGEMENT STATE
# ============================================================

# The carried-party slot that the player clicked.
#
# 0-4 = Battle Party
# 5-7 = Reserve
var target_index: int = -1


# The Atomon currently selected from the collection.
var selected_atomon: AtomonInstance = null


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	switch_button.pressed.connect(
		_on_switch_pressed
	)

	cancel_button.pressed.connect(
		_on_cancel_pressed
	)

	# Do NOT build the collection here.
	#
	# PlayerPage calls set_target_index() immediately after
	# creating this scene. The collection needs to be built
	# only after we know which slot is being changed.
	_update_selection_display()


# ============================================================
# TARGET SLOT
# ============================================================

func set_target_index(index: int) -> void:

	if index < 0:
		return

	if index >= PartyManager.MAX_CARRIED_ATOMONS:
		return

	target_index = index

	# Clear any previous selection.
	selected_atomon = null

	print(
		"[PartyManagement] Target carried slot: ",
		index + 1
	)

	var current_atomon := (
		PartyManager.get_carried_atomon(index)
	)

	if current_atomon != null:
		print(
			"[PartyManagement] Current Atomon: ",
			current_atomon.data.chemical_symbol,
			" - ",
			current_atomon.data.atom_name
		)

	_update_selection_display()

	# Build the collection only after the target slot
	# is known.
	build_collection()


# ============================================================
# BUILD COLLECTION
# ============================================================

func build_collection() -> void:

	# --------------------------------------------------------
	# CLEAR EXISTING DISPLAY
	# --------------------------------------------------------

	for child in grid_container.get_children():
		child.queue_free()

	await get_tree().process_frame

	# --------------------------------------------------------
	# GET FULL COLLECTION
	# --------------------------------------------------------

	var collection: Array[AtomonInstance] = (
		PartyManager.get_collection()
	)

	print(
		"[PartyManagement] Collection size before filtering: ",
		collection.size()
	)

	# --------------------------------------------------------
	# SORT ALPHABETICALLY
	# --------------------------------------------------------
	#
	# Atomons are sorted by their element name.
	#
	# Example:
	#
	# Aluminum
	# Argon
	# Beryllium
	# Boron
	# Carbon
	# Chlorine
	# ...
	#
	# The GridContainer will then automatically arrange
	# them into the 2-column layout.
	# --------------------------------------------------------

	collection.sort_custom(
		func(a: AtomonInstance, b: AtomonInstance) -> bool:
			return (
				a.data.atom_name.to_lower()
				< b.data.atom_name.to_lower()
			)
	)

	# --------------------------------------------------------
	# GET CURRENT ATOMON
	# --------------------------------------------------------
	#
	# This is the Atomon currently occupying the slot that
	# the player clicked.
	#
	# It should NOT appear in the selection list.
	# --------------------------------------------------------

	var current_atomon: AtomonInstance = null

	if target_index >= 0:
		current_atomon = (
			PartyManager.get_carried_atomon(target_index)
		)

	# --------------------------------------------------------
	# CREATE COLLECTION SLOTS
	# --------------------------------------------------------

	for atomon in collection:

		if atomon == null:
			continue

		# ----------------------------------------------------
		# HIDE THE ATOMON ALREADY IN THE TARGET SLOT
		# ----------------------------------------------------

		if current_atomon != null and atomon == current_atomon:

			print(
				"[PartyManagement] Hiding current target Atomon: ",
				atomon.data.chemical_symbol,
				" - ",
				atomon.data.atom_name
			)

			continue

		# ----------------------------------------------------
		# CREATE SLOT
		# ----------------------------------------------------

		var slot = PARTY_SLOT_SCENE.instantiate()

		grid_container.add_child(slot)

		if slot.has_method("set_atomon"):
			slot.set_atomon(atomon)

		if slot.has_signal("slot_clicked"):

			slot.slot_clicked.connect(
				_on_collection_slot_clicked
			)

	print(
		"[PartyManagement] Collection displayed alphabetically."
	)


# ============================================================
# ATOMON SELECTED
# ============================================================

func _on_collection_slot_clicked(
	atomon: AtomonInstance
) -> void:

	if atomon == null:
		return

	if target_index < 0:

		print(
			"[PartyManagement] No target slot."
		)

		return

	# --------------------------------------------------------
	# SAFETY CHECK
	# --------------------------------------------------------
	#
	# The current Atomon should already be hidden from the
	# collection, but check again here in case the collection
	# changes while this screen is open.
	# --------------------------------------------------------

	var current_atomon := (
		PartyManager.get_carried_atomon(target_index)
	)

	if atomon == current_atomon:

		print(
			"[PartyManagement] Atomon is already in target slot."
		)

		return

	# --------------------------------------------------------
	# STORE SELECTION
	# --------------------------------------------------------

	selected_atomon = atomon

	print(
		"[PartyManagement] Selected ",
		atomon.data.chemical_symbol,
		" - ",
		atomon.data.atom_name,
		" for carried slot ",
		target_index + 1
	)

	_update_selection_display()


# ============================================================
# UPDATE SELECTION DISPLAY
# ============================================================

func _update_selection_display() -> void:

	if target_index < 0:

		selection_count.text = "TARGET SLOT: NONE"

		instruction.text = (
			"Select a carried slot first."
		)

		switch_button.disabled = true

		return

	# --------------------------------------------------------
	# GET TARGET NAME
	# --------------------------------------------------------

	var target_name := "SLOT %d" % (
		target_index + 1
	)

	if target_index < PartyManager.MAX_BATTLE_PARTY_SIZE:

		target_name = "BATTLE %d" % (
			target_index + 1
		)

	else:

		target_name = "RESERVE %d" % (
			target_index
			- PartyManager.MAX_BATTLE_PARTY_SIZE
			+ 1
		)

	# --------------------------------------------------------
	# GET CURRENT ATOMON
	# --------------------------------------------------------

	var current_atomon := (
		PartyManager.get_carried_atomon(target_index)
	)

	var current_name := "EMPTY"

	if current_atomon != null:

		current_name = (
			current_atomon.data.chemical_symbol
			+ " - "
			+ current_atomon.data.atom_name
		)

	# --------------------------------------------------------
	# NOTHING SELECTED
	# --------------------------------------------------------

	if selected_atomon == null:

		selection_count.text = (
			"TARGET: %s   |   CURRENT: %s   |   SELECTED: NONE"
			% [
				target_name,
				current_name
			]
		)

		instruction.text = (
			"Select an Atomon to move into this slot."
		)

		switch_button.disabled = true

		return

	# --------------------------------------------------------
	# ATOMON SELECTED
	# --------------------------------------------------------

	var selected_name := (
		selected_atomon.data.chemical_symbol
		+ " - "
		+ selected_atomon.data.atom_name
	)

	selection_count.text = (
		"TARGET: %s   |   CURRENT: %s   |   SELECTED: %s"
		% [
			target_name,
			current_name,
			selected_name
		]
	)

	# --------------------------------------------------------
	# CHECK WHETHER SELECTED ATOMON IS ALREADY CARRIED
	# --------------------------------------------------------

	var selected_current_index := (
		PartyManager.get_carried_party().find(
			selected_atomon
		)
	)

	if selected_current_index >= 0:

		instruction.text = (
			"Press SWITCH to move "
			+ selected_name
			+ " to "
			+ target_name
			+ ". Their positions will be swapped."
		)

	else:

		instruction.text = (
			"Press SWITCH to place "
			+ selected_name
			+ " in "
			+ target_name
			+ "."
		)

	switch_button.disabled = false


# ============================================================
# SWITCH
# ============================================================

func _on_switch_pressed() -> void:

	if selected_atomon == null:

		print(
			"[PartyManagement] No Atomon selected."
		)

		return

	if target_index < 0:

		print(
			"[PartyManagement] No target slot."
		)

		return

	# --------------------------------------------------------
	# SAFETY CHECK
	# --------------------------------------------------------

	var current_atomon := (
		PartyManager.get_carried_atomon(target_index)
	)

	if selected_atomon == current_atomon:

		print(
			"[PartyManagement] Selected Atomon is already "
			+ "in the target slot."
		)

		return

	print(
		"[PartyManagement] Moving ",
		selected_atomon.data.chemical_symbol,
		" - ",
		selected_atomon.data.atom_name,
		" into carried slot ",
		target_index + 1
	)

	# --------------------------------------------------------
	# SEND THE SELECTED ATOMON BACK TO PLAYER PAGE
	# --------------------------------------------------------
	#
	# PlayerPage will call:
	#
	# PartyManager.set_atomon_in_carried_slot(
	#     selected_party_slot_index,
	#     atomon
	# )
	#
	# PartyManager is responsible for:
	#
	# 1. Putting the selected Atomon in target_index.
	# 2. Finding its old carried position.
	# 3. Swapping the old positions when necessary.
	# --------------------------------------------------------

	atomon_selected.emit(
		selected_atomon
	)

	queue_free()


# ============================================================
# CANCEL
# ============================================================

func _on_cancel_pressed() -> void:

	print(
		"[PartyManagement] Selection cancelled."
	)

	queue_free()

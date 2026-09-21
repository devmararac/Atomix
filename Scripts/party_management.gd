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

var target_index: int = -1
var selected_atomon: AtomonInstance = null


func _ready() -> void:

	switch_button.pressed.connect(
		_on_switch_pressed
	)

	cancel_button.pressed.connect(
		_on_cancel_pressed
	)

	_update_selection_display()

	build_collection()


# ============================================================
# TARGET SLOT
# ============================================================

func set_target_index(index: int) -> void:

	target_index = index

	print(
		"[PartyManagement] Target carried slot: ",
		index + 1
	)

	_update_selection_display()


# ============================================================
# BUILD COLLECTION
# ============================================================

func build_collection() -> void:

	for child in grid_container.get_children():
		child.queue_free()

	await get_tree().process_frame

	var collection: Array[AtomonInstance] = (
		PartyManager.get_collection()
	)

	print(
		"[PartyManagement] Collection size: ",
		collection.size()
	)

	for atomon in collection:

		if atomon == null:
			continue

		var slot = (
			PARTY_SLOT_SCENE.instantiate()
		)

		grid_container.add_child(slot)

		if slot.has_method("set_atomon"):
			slot.set_atomon(atomon)

		if slot.has_signal("slot_clicked"):

			slot.slot_clicked.connect(
				_on_collection_slot_clicked
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

	selected_atomon = atomon

	print(
		"[PartyManagement] Selected ",
		atomon.data.alias,
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
		instruction.text = "Select a carried slot first."

		switch_button.disabled = true

		return

	var target_name := "SLOT %d" % (target_index + 1)

	if target_index < 5:
		target_name = "BATTLE %d" % (target_index + 1)
	else:
		target_name = "RESERVE %d" % (target_index - 4)

	if selected_atomon == null:

		selection_count.text = (
			"TARGET: %s   |   SELECTED: NONE"
			% target_name
		)

		instruction.text = (
			"Select an Atomon, then press SWITCH."
		)

		switch_button.disabled = true

	else:

		selection_count.text = (
			"TARGET: %s   |   SELECTED: %s"
			% [
				target_name,
				selected_atomon.data.alias
			]
		)

		instruction.text = (
			"Press SWITCH to place this Atomon in the selected slot."
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

	print(
		"[PartyManagement] Switching ",
		selected_atomon.data.alias,
		" into carried slot ",
		target_index + 1
	)

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

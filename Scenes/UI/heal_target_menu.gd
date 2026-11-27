extends Control

signal target_selected(atomon: AtomonInstance)
signal cancelled


@onready var target_container: VBoxContainer = \
	$Panel/VBoxContainer/ScrollContainer/CenterContainer/VBoxContainer

@onready var cancel_button: Button = \
	$Panel/VBoxContainer/Button


const PARTY_SLOT_SCENE := \
	preload("res://Scenes/UI/party_slot.tscn")


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	cancel_button.pressed.connect(_on_cancel_pressed)

	load_targets()


# ============================================================
# LOAD HEALING TARGETS
# ============================================================

func load_targets() -> void:

	# Clear old slots
	for child in target_container.get_children():
		child.queue_free()


	# Get carried Atomons (battle party + reserves)
	var carried_atomons := \
		PartyManager.get_carried_party()


	for atomon in carried_atomons:

		if atomon == null:
			continue

		if atomon.data == null:
			continue


		# Skip Atomons already at full HP
		var max_hp: int = \
			StatCalculator.get_hp(atomon.data)

		if atomon.current_hp >= max_hp:
			continue


		# Create Party Slot
		var slot = PARTY_SLOT_SCENE.instantiate()

		target_container.add_child(slot)


		# Populate slot
		slot.set_atomon(atomon)


		# Connect actual signal from party_slot.gd
		slot.slot_clicked.connect(_on_slot_clicked)


# ============================================================
# ATOMON SELECTED
# ============================================================

func _on_slot_clicked(atomon: AtomonInstance) -> void:

	target_selected.emit(atomon)

	queue_free()


# ============================================================
# CANCEL
# ============================================================

func _on_cancel_pressed() -> void:

	cancelled.emit()

	queue_free()

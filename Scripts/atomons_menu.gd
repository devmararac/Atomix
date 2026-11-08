extends CanvasLayer


# ============================================================
# PARTY UI
# ============================================================

@onready var party_grid: GridContainer = $Party/TextureRect/PartySlot


# ============================================================
# DETAILS UI
# ============================================================

@onready var preview: AnimatedSprite2D = (
	$Details/Sprite/AtomonAnimatedSprite
)

@onready var atomon_panel: Panel = (
	$Details/Sprite
)

@onready var atomon_name: Label = (
	$Details/AtomonDetails/AtomonName
)

@onready var atomon_nickname: Label = (
	$Details/Sprite/AtomonNickname
)

@onready var atomon_symbol: TextureRect = (
	$Details/Sprite/Symbol
)

@onready var atomon_description: RichTextLabel = (
	$Details/Description
)

@onready var atomon_details: Panel = (
	$Details/AtomonDetails
)


# ============================================================
# PARTY SLOTS
# ============================================================

var slots: Array[TextureButton] = []


# ============================================================
# SWAP SYSTEM
# ============================================================

var selected_index: int = -1


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	# Hide details initially
	atomon_details.visible = false
	atomon_nickname.visible = false
	atomon_panel.visible = false
	atomon_description.visible = false
	atomon_symbol.visible = false
	atomon_name.visible = false

	# Get all party slots
	for child in party_grid.get_children():

		var slot: TextureButton = child

		slots.append(slot)

		slot.slot_clicked.connect(_on_slot_clicked)

	refresh_party()


# ============================================================
# REFRESH PARTY UI
# ============================================================

func refresh_party() -> void:
	var party: Array[AtomonInstance] = PartyManager.get_party()

	for i: int in range(slots.size()):

		# Clear the slot first
		slots[i].clear_slot()

		# Then assign the new Atomon
		if i < party.size():
			slots[i].set_atomon(party[i])


# ============================================================
# SLOT CLICKED
# ============================================================

func _on_slot_clicked(atomon: AtomonInstance) -> void:

	if atomon == null:
		return

	var party: Array[AtomonInstance] = PartyManager.get_party()

	var clicked_index: int = party.find(atomon)

	if clicked_index == -1:
		return


	# ========================================================
	# FIRST CLICK
	# ========================================================

	if selected_index == -1:
		selected_index = clicked_index
		show_atomon_details(atomon)
		print("Selected Atomon at position: ", selected_index + 1)
		return

	# ========================================================
	# SECOND CLICK
	# ========================================================
	if selected_index != clicked_index:
		var swap_successful: bool = (PartyManager.swap_atomon_positions(selected_index, clicked_index))
		if swap_successful:
			print("Swapped positions ", selected_index + 1, " and ", clicked_index + 1)
			refresh_party()
	selected_index = -1

# ============================================================
# SHOW ATOMON DETAILS
# ============================================================

func show_atomon_details(
	atomon: AtomonInstance
) -> void:

	if atomon == null:
		return

	var data: AtomonData = atomon.data

	if data == null:
		return


	# Show UI
	atomon_details.visible = true
	atomon_nickname.visible = true
	atomon_panel.visible = true
	atomon_name.visible = true
	atomon_description.visible = true


	# Name
	atomon_nickname.text = data.alias
	atomon_name.text = data.atom_name


	# Symbol
	if data.symbol != null:

		atomon_symbol.visible = true
		atomon_symbol.texture = data.symbol

	else:

		atomon_symbol.visible = false


	# Description
	atomon_description.text = data.description


	# Preview
	preview.sprite_frames = data.sprite_frames
	preview.play("idle")


# ============================================================
# CLOSE BUTTON
# ============================================================

func _on_button_pressed() -> void:

	queue_free()

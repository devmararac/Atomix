extends Panel
class_name FusionMoleculeSlot


signal atomon_placed(
	atomon: AtomonInstance,
	slot: FusionMoleculeSlot
)

signal atomon_removed(
	atomon: AtomonInstance,
	slot: FusionMoleculeSlot
)


# ============================================================
# CONFIGURATION
# ============================================================

@export var required_element: String = ""


# ============================================================
# NODES
# ============================================================

@onready var atomon_sprite: AnimatedSprite2D = $AtomonPortrait
@onready var element_label: Label = $ElementLabel


# ============================================================
# STATE
# ============================================================

var placed_atomon: AtomonInstance = null


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_STOP

	update_visual()


# ============================================================
# DRAG VALIDATION
# ============================================================

func _can_drop_data(
	_at_position: Vector2,
	data: Variant
) -> bool:

	if placed_atomon != null:
		return false

	if typeof(data) != TYPE_DICTIONARY:
		return false

	if not data.has("type"):
		return false

	if data["type"] != "fusion_atomon":
		return false

	if not data.has("atomon"):
		return false

	var atomon = data["atomon"]

	if atomon == null:
		return false

	if not atomon is AtomonInstance:
		return false

	if atomon.data == null:
		return false

	var symbol: String = str(
		atomon.data.chemical_symbol
	)

	return symbol == required_element


# ============================================================
# DROP
# ============================================================

func _drop_data(
	_at_position: Vector2,
	data: Variant
) -> void:

	if not _can_drop_data(
		_at_position,
		data
	):
		return

	var atomon: AtomonInstance = data["atomon"]

	place_atomon(atomon)


# ============================================================
# PLACE ATOMON
# ============================================================

func place_atomon(
	new_atomon: AtomonInstance
) -> void:

	if new_atomon == null:
		return

	if new_atomon.data == null:
		return

	if placed_atomon != null:
		return

	var symbol: String = str(
		new_atomon.data.chemical_symbol
	)

	if symbol != required_element:
		return

	placed_atomon = new_atomon

	update_visual()

	atomon_placed.emit(
		new_atomon,
		self
	)


# ============================================================
# REMOVE ATOMON
# ============================================================

func remove_atomon() -> AtomonInstance:

	if placed_atomon == null:
		return null

	var removed: AtomonInstance = placed_atomon

	placed_atomon = null

	update_visual()

	atomon_removed.emit(
		removed,
		self
	)

	return removed


# ============================================================
# GET ATOMON
# ============================================================

func get_atomon() -> AtomonInstance:

	return placed_atomon


# ============================================================
# OCCUPIED
# ============================================================

func is_occupied() -> bool:

	return placed_atomon != null


# ============================================================
# REQUIRED ELEMENT
# ============================================================

func get_required_element() -> String:

	return required_element


# ============================================================
# VISUAL
# ============================================================

func update_visual() -> void:

	# --------------------------------------------------------
	# EMPTY SLOT
	# --------------------------------------------------------

	if placed_atomon == null:

		atomon_sprite.stop()
		atomon_sprite.sprite_frames = null

		element_label.text = required_element

		tooltip_text = \
			"Place " + \
			required_element + \
			" here."

		return


	# --------------------------------------------------------
	# ATOMON PLACED
	# --------------------------------------------------------

	var frames: SpriteFrames = \
		placed_atomon.data.sprite_frames

	if frames != null and \
		frames.has_animation(&"idle"):

		atomon_sprite.sprite_frames = frames
		atomon_sprite.animation = &"idle"
		atomon_sprite.play()

	else:

		atomon_sprite.stop()
		atomon_sprite.sprite_frames = null


	# Hide the placeholder element
	# once the actual Atomon is present.

	element_label.text = ""


	tooltip_text = \
		"Placed: " + \
		str(
			placed_atomon.data.chemical_symbol
		)

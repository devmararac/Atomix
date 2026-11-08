extends TextureButton

signal slot_clicked(instance: AtomonInstance)


@onready var atomon_sprite: AnimatedSprite2D = $"Atomon BG/AtomonPortrait"
@onready var name_label: Label = $Name

@onready var hp_label: Label = $HPContainer/HPHeader/HPLabel
@onready var hp_value: Label = $HPContainer/HPHeader/HPValue
@onready var hp_bar: TextureProgressBar = $HPContainer/HPBar


# ============================================================
# CONFIGURATION
# ============================================================

@export var draggable: bool = false


# ============================================================
# STATE
# ============================================================

var atomon: AtomonInstance = null


# ============================================================
# SET ATOMON
# ============================================================

func set_atomon(
	new_atomon: AtomonInstance
) -> void:

	atomon = new_atomon

	if atomon == null:
		clear_slot()
		return


	# --------------------------------------------------------
	# NAME
	# --------------------------------------------------------

	name_label.text = atomon.data.alias


	# --------------------------------------------------------
	# HP
	# --------------------------------------------------------

	var max_hp: int = \
		StatCalculator.get_hp(atomon.data)

	var current_hp: int = \
		atomon.current_hp

	hp_label.text = "HP"
	hp_value.text = \
		"%d / %d" % [current_hp, max_hp]

	hp_bar.max_value = max_hp
	hp_bar.value = current_hp


	# --------------------------------------------------------
	# SPRITE / PORTRAIT
	# --------------------------------------------------------

	var frames: SpriteFrames = \
		atomon.data.sprite_frames

	if frames and frames.has_animation("idle"):

		atomon_sprite.sprite_frames = frames
		atomon_sprite.animation = &"idle"
		atomon_sprite.stop()
		atomon_sprite.frame = 0


# ============================================================
# CLEAR
# ============================================================

func clear_slot() -> void:

	atomon = null

	atomon_sprite.stop()
	atomon_sprite.sprite_frames = null

	name_label.text = ""

	hp_label.text = ""
	hp_value.text = ""

	hp_bar.max_value = 1
	hp_bar.value = 0


# ============================================================
# CLICK
# ============================================================

func _pressed() -> void:

	if atomon:
		slot_clicked.emit(atomon)


# ============================================================
# DRAG
# ============================================================

func _get_drag_data(
	_at_position: Vector2
) -> Variant:

	# Normal PartySlots remain click-only.
	if not draggable:
		return null

	if atomon == null:
		return null

	if atomon.data == null:
		return null


	# --------------------------------------------------------
	# DRAG PREVIEW
	# --------------------------------------------------------

	var preview := TextureRect.new()

	preview.custom_minimum_size = Vector2(64, 64)

	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frames: SpriteFrames = \
		atomon.data.sprite_frames

	if frames != null and frames.has_animation("idle"):

		var texture := \
			frames.get_frame_texture(
				&"idle",
				0
			)

		preview.texture = texture


	set_drag_preview(preview)


	# --------------------------------------------------------
	# DRAG DATA
	# --------------------------------------------------------

	return {
		"type": "fusion_atomon",
		"atomon": atomon
	}


# ============================================================
# DRAG CONTROL
# ============================================================

func set_draggable(
	value: bool
) -> void:

	draggable = value


func is_draggable() -> bool:

	return draggable


# ============================================================
# DATA
# ============================================================

func get_atomon() -> AtomonInstance:

	return atomon

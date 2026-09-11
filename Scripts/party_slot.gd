extends TextureButton

signal slot_clicked(instance: AtomonInstance)

@onready var atomon_sprite: AnimatedSprite2D = $"Atomon BG/AtomonPortrait"
@onready var name_label: Label = $Name

@onready var hp_label: Label = $HPContainer/HPHeader/HPLabel
@onready var hp_value: Label = $HPContainer/HPHeader/HPValue
@onready var hp_bar: TextureProgressBar = $HPContainer/HPBar

var atomon: AtomonInstance = null


func set_atomon(new_atomon: AtomonInstance) -> void:

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

	var max_hp: int = StatCalculator.get_hp(atomon.data)
	var current_hp: int = atomon.current_hp

	hp_label.text = "HP"
	hp_value.text = "%d / %d" % [current_hp, max_hp]

	hp_bar.max_value = max_hp
	hp_bar.value = current_hp


	# --------------------------------------------------------
	# SPRITE / PORTRAIT
	# --------------------------------------------------------

	var frames: SpriteFrames = atomon.data.sprite_frames

	if frames and frames.has_animation("idle"):
		atomon_sprite.sprite_frames = frames
		atomon_sprite.animation = &"idle"
		atomon_sprite.stop()
		atomon_sprite.frame = 0


func clear_slot() -> void:

	atomon = null

	atomon_sprite.stop()
	atomon_sprite.sprite_frames = null

	name_label.text = ""

	hp_label.text = ""
	hp_value.text = ""

	hp_bar.max_value = 1
	hp_bar.value = 0


func _pressed() -> void:

	if atomon:
		slot_clicked.emit(atomon)

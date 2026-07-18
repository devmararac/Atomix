extends TextureButton

signal slot_clicked(instance: AtomonInstance)

@onready var atomon_sprite: AnimatedSprite2D = $AtomonSprite
@onready var name_label: Label = $Name
@onready var hp_label: Label = $HP

var atomon: AtomonInstance = null


func set_atomon(new_atomon: AtomonInstance):

	atomon = new_atomon

	if atomon == null:
		clear_slot()
		return

	name_label.text = atomon.data.atom_name

	hp_label.text = "%d/%d" % [
		atomon.current_hp,
		StatCalculator.get_hp(atomon.data)
	]

	var frames = atomon.data.sprite_frames

	if frames:
		atomon_sprite.sprite_frames = frames

		if frames.has_animation("idle"):
			atomon_sprite.play("idle")


func clear_slot():

	atomon = null

	atomon_sprite.stop()
	atomon_sprite.sprite_frames = null
	name_label.text = ""
	hp_label.text = ""

func _pressed():

	if atomon:
		slot_clicked.emit(atomon)

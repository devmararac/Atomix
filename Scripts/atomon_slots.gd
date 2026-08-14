extends TextureButton


signal slot_clicked(instance: AtomonInstance)

@onready var atomon_sprite: TextureRect = $AtomonSprite

var atomon: AtomonInstance = null

func set_atomon(new_atomon: AtomonInstance) -> void:
	atomon = new_atomon
	if atomon == null:
		clear_slot()
		return
		
	if atomon.data == null:
		clear_slot()
		return

	var frames: SpriteFrames = (atomon.data.sprite_frames)
	if frames != null and frames.has_animation("idle"):
		atomon_sprite.texture = (frames.get_frame_texture("idle", 0))
	else:
		atomon_sprite.texture = null

func clear_slot() -> void:
	atomon = null
	atomon_sprite.texture = null

func _pressed() -> void:
	
	if atomon != null:
		slot_clicked.emit(atomon)

	if atomon:
		SfxManager.play_slot_click()
	

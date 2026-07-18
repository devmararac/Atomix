extends CharacterBody2D

@export var data = NPCData

@onready var sprite = $NpcSprite
@onready var name_label = $NpcSprite/NpcName
@onready var indicator = $NpcSprite/Indicator


func _ready():
	setup_npc()

func setup_npc():

	if data == null:
		push_warning("NPCData missing.")
		return

	name_label.text = data.display_name

	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames

	sprite.flip_h = data.facing_direction == NPCData.FacingDirection.LEFT

func interact():
	pass

func show_indicator():
	indicator.visible = true

func hide_indicator():
	indicator.visible = false

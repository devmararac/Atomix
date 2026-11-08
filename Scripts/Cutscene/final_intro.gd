extends Node2D

@onready var overlay: ColorRect = $Overlay
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_play_animation()

func _process(delta: float) -> void:
	pass

func _play_animation() -> void:
	if anim_player.has_animation("Fade IN"):
		anim_player.play("Fade IN")
	else:
		push_error("Animation 'Fade_IN' not found. Check the AnimationPlayer's animation list.")

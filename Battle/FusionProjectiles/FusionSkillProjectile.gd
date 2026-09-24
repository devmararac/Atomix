extends Node2D
class_name FusionSkillProjectile

signal projectile_finished

@export var travel_duration: float = 0.5

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	animated_sprite.animation = &"default"
	animated_sprite.play()


func launch(
	start_position: Vector2,
	target_position: Vector2
) -> void:

	global_position = start_position

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		self,
		"global_position",
		target_position,
		travel_duration
	)

	tween.finished.connect(_on_travel_finished)


func _on_travel_finished() -> void:
	projectile_finished.emit()

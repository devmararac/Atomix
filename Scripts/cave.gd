extends Node2D

@onready var player: Node2D = $Player
@onready var cave_overlay: ColorRect = $Shader

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if player == null or cave_overlay == null:
		return

	var material: ShaderMaterial = cave_overlay.material as ShaderMaterial

	if material == null:
		return

	# Player position in screen/canvas coordinates.
	var screen_position: Vector2 = player.get_global_transform_with_canvas().origin

	# Size of the current viewport.
	var viewport_size: Vector2 = get_viewport_rect().size

	# Convert to 0.0 - 1.0 UV coordinates.
	var player_uv: Vector2 = screen_position / viewport_size

	# Send the player's position to the cave shader.
	material.set_shader_parameter(
		"player_light_position",
		player_uv
	)

extends CanvasLayer

@export var player_path: NodePath

@onready var player_marker: TextureRect = $MinimapUI/PlayerMarker
@onready var minimap_camera: Camera2D = $MinimapUI/Map/SubViewport/Camera2D
@onready var map_texture: Sprite2D = $MinimapUI/Map/SubViewport/MapTexture

func _ready() -> void:
	var player = get_node_or_null(player_path)

	if player:
		minimap_camera.position = player.position
	else:
		push_warning("Minimap: Player not found.")

func _process(_delta: float) -> void:
	var player = get_node_or_null(player_path)

	if not player:
		return
	# Make the minimap camera follow the player.
	minimap_camera.position = player.position

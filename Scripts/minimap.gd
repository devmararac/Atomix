extends CanvasLayer

@export var player_path: NodePath
@export var map_texture_path: Texture2D

@onready var player_marker: TextureRect = $MinimapUI/PlayerMarker
@onready var minimap_camera: Camera2D = $MinimapUI/Map/SubViewport/Camera2D
@onready var map_texture: Sprite2D = $MinimapUI/Map/SubViewport/MapTexture

func _ready() -> void:
	var player = get_node_or_null(player_path)

	if player:
		minimap_camera.position = player.position
	else:
		push_warning("Minimap: Player not found.")

	# Set the area's minimap
	if map_texture_path:
		set_map(map_texture_path)
	
	Dialogic.timeline_started.connect(_on_dialogue_started)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)

func _on_dialogue_started() -> void:
	visible = false

func _on_dialogue_ended() -> void:
	visible = true

func _process(_delta: float) -> void:
	var player = get_node_or_null(player_path)

	if not player:
		return

	# Make the minimap camera follow the player.
	minimap_camera.position = player.position

func set_map(texture: Texture2D) -> void:
	map_texture.texture = texture

func _on_open_map_button_pressed() -> void:
	pass # Replace with function body.

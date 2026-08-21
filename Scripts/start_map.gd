extends Node2D

@onready var hud = $HUD
@onready var mini_map = $Minimap

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mini_map.visible = true
	hud.visible = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

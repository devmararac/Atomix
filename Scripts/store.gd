extends StaticBody2D

const SHOP_UI = preload("res://Scenes/UI/shop_ui.tscn")

var current_shop_ui: CanvasLayer = null


func _ready() -> void:
	$Highlight.visible = false


func interact() -> void:
	# Don't open another shop if one is already open
	if current_shop_ui != null:
		return

	print("STORE INTERACTED")

	# Stop player movement
	if global.player:
		global.player.can_move = false

	# Open the Shop UI directly
	current_shop_ui = SHOP_UI.instantiate()
	get_tree().current_scene.add_child(current_shop_ui)

	print("OPENING SHOP UI")

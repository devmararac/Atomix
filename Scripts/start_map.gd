extends Node2D

@onready var hud = $HUD
@onready var mini_map = $Minimap

var flashback = null
var hidden_nodes: Dictionary = {}


func _ready() -> void:
	hud.visible = true
	mini_map.visible = true

	Dialogic.signal_event.connect(_on_dialogic_signal)


func _process(_delta: float) -> void:
	pass


func play_atomon_origin() -> void:
	# =========================================================
	# HIDE HUD AND MINIMAP EXPLICITLY
	# =========================================================

	hud.visible = false
	mini_map.visible = false


	# =========================================================
	# HIDE EVERYTHING ELSE IN STARTING MAP
	# =========================================================

	hidden_nodes.clear()

	for child in get_children():
		if child != flashback:
			hide_visual_tree(child)


	# =========================================================
	# FORCE HUD AND MINIMAP HIDDEN
	# =========================================================

	hud.visible = false
	mini_map.visible = false


	# =========================================================
	# PAUSE GAME
	# =========================================================

	get_tree().paused = true


	# =========================================================
	# CREATE FLASHBACK
	# =========================================================

	flashback = preload(
		"res://Scenes/Cutscenes/atomon_origin.tscn"
	).instantiate()

	flashback.process_mode = Node.PROCESS_MODE_ALWAYS

	add_child(flashback)


	# =========================================================
	# ATOMON ORIGIN CAMERA TAKES OVER
	# =========================================================

	var flashback_camera = flashback.get_node("Camera2D")

	flashback_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	flashback_camera.enabled = true
	flashback_camera.make_current()


	# =========================================================
	# WAIT FOR FLASHBACK
	# =========================================================

	await flashback.cutscene_finished


	# =========================================================
	# REMOVE FLASHBACK
	# =========================================================

	flashback.queue_free()
	flashback = null


	# =========================================================
	# RESTORE ORIGINAL VISIBILITY
	# =========================================================

	for node in hidden_nodes:
		if is_instance_valid(node):
			node.visible = hidden_nodes[node]

	hidden_nodes.clear()

	# =========================================================
	# FORCE HUD AND MINIMAP BACK ON
	# =========================================================

	hud.visible = true
	mini_map.visible = true
	
	# =========================================================
	# RESUME GAME
	# =========================================================

	get_tree().paused = false


func hide_visual_tree(node: Node) -> void:
	# CanvasLayer has its own visibility system
	if node is CanvasLayer:
		hidden_nodes[node] = node.visible
		node.visible = false

		for child in node.get_children():
			hide_visual_tree(child)

		return


	# Controls, Node2D, Sprite2D, etc.
	if node is CanvasItem:
		hidden_nodes[node] = node.visible
		node.visible = false

		for child in node.get_children():
			hide_visual_tree(child)

		return


	# Plain Node: it has no visible property,
	# so continue looking for visual children.
	for child in node.get_children():
		hide_visual_tree(child)


func _on_dialogic_signal(argument: String) -> void:
	if argument == "play_atomon_origin":
		play_atomon_origin()

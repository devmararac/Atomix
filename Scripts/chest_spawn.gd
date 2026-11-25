extends Node2D

const CHEST_SCENE = preload("res://Scenes/Objects/Structures/Exteriors/chest_body.tscn")  # change this path

var markers: Array = []
var occupied: Dictionary = {}   # Marker2D -> bool
var chest_counter: int = 0

func _ready() -> void:
	# Wait one frame so all scene nodes are in the tree and groups are registered
	await get_tree().process_frame

	markers = get_tree().get_nodes_in_group("ChestSpawn")

	if markers.is_empty():
		push_warning("ChestSpawner: no nodes found in group 'ChestSpawn'.")
		return

	for m in markers:
		if m is Marker2D:
			occupied[m] = false
		else:
			push_warning("ChestSpawner: node '%s' is in group 'ChestSpawn' but is not a Marker2D." % m.name)

	spawn_chest()

func spawn_chest() -> void:
	var free_markers: Array = []
	for m in markers:
		if occupied.has(m) and not occupied[m]:
			free_markers.append(m)

	if free_markers.is_empty():
		return

	var chosen: Marker2D = free_markers.pick_random()
	occupied[chosen] = true

	chest_counter += 1
	var chest = CHEST_SCENE.instantiate()
	chest.chest_id = "chest_%d_%d" % [Time.get_ticks_msec(), chest_counter]
	chest.global_position = chosen.global_position
	chest.chest_opened.connect(_on_chest_opened.bind(chosen))
	add_child(chest)

func _on_chest_opened(_chest_node: Node, marker: Marker2D) -> void:
	occupied[marker] = false
	spawn_chest()

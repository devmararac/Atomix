extends Node

var items: Dictionary = {}

# Explicitly load all ItemData resources
var item_resources: Array[ItemData] = [
	preload("res://Resources/Items/AtomicCore.tres"),
	preload("res://Resources/Items/Electron.tres"),
	preload("res://Resources/Items/Glass_shard.tres"),
	preload("res://Resources/Items/HP_Potion.tres"),
	preload("res://Resources/Items/Iron_ore.tres"),
	preload("res://Resources/Items/Letter.tres"),
	preload("res://Resources/Items/Neutron.tres"),
	preload("res://Resources/Items/Proton.tres")
]


func _ready():
	load_items()

	print("[ItemDatabase] Total items loaded: ", items.size())

	if items.has("item_004"):
		print("[ItemDatabase] item_004 FOUND")
	else:
		print("[ItemDatabase] item_004 NOT FOUND")


func load_items():
	items.clear()

	for item in item_resources:
		if item != null:
			items[item.item_id] = item
			print(
				"[ItemDatabase] Loaded: ",
				item.item_id,
				" -> ",
				item.item_name
			)


func get_item(item_id: String) -> ItemData:
	return items.get(item_id, null)


func has_item(item_id: String) -> bool:
	return items.has(item_id)

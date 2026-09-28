extends Node

var items: Dictionary = {}

# Explicitly load all ItemData resources
var item_resources: Array[ItemData] = [
	preload("res://Resources/Items/Crafting/ATOMON_REQ/AtomicCore.tres"),
	preload("res://Resources/Items/Crafting/ATOMON_REQ/Electron.tres"),
	preload("res://Resources/Items/Crafting/CRAFT_ITEM_REQ/Glass_shard.tres"),
	preload("res://Resources/Items/Consumables/HP_Potion.tres"),
	preload("res://Resources/Items/Crafting/CRAFT_ITEM_REQ/Iron_ore.tres"),
	preload("res://Resources/Items/QuestItems/Letter.tres"),
	preload("res://Resources/Items/Crafting/ATOMON_REQ/Neutron.tres"),
	preload("res://Resources/Items/Crafting/ATOMON_REQ/Proton.tres"),
	preload("res://Resources/Items/Consumables/apple.tres"),
	preload("res://Resources/Items/Consumables/coffee.tres"),
	preload("res://Resources/Items/Consumables/grapes.tres"),
	preload("res://Resources/Items/Consumables/watermelon.tres"),
]


func _ready():
	load_items()

	print("[ItemDatabase] Total items loaded: ", items.size())

	if items.has("item_004"):
		print("[ItemDatabase] item_004 FOUND")
	else:
		print("[ItemDatabase] item_004 NOT FOUND")


func load_items() -> void:
	items.clear()

	for item in item_resources:

		if item == null:
			continue

		if item.item_id.is_empty():
			push_error(
				"[ItemDatabase] Item has empty ID: " +
				item.resource_path
			)
			continue

		if items.has(item.item_id):
			push_error(
				"[ItemDatabase] Duplicate item ID: " +
				item.item_id
			)
			continue

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

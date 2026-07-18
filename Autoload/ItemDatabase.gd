extends Node

var items: Dictionary = {}

func _ready():
	load_items()

func load_items():
	items.clear()

	var dir = DirAccess.open("res://Resources/Items")

	if dir == null:
		push_error("ItemDatabase: Cannot open res://Resources/Items")
		return

	dir.list_dir_begin()

	var file_name = dir.get_next()

	while file_name != "":
		if !dir.current_is_dir():
			if file_name.ends_with(".tres"):
				var item = load("res://Resources/Items/" + file_name)

				if item is ItemData:
					items[item.item_id] = item

		file_name = dir.get_next()

	dir.list_dir_end()


func get_item(item_id: String) -> ItemData:
	return items.get(item_id, null)


func has_item(item_id: String) -> bool:
	return items.has(item_id)

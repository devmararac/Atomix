extends Node

var inventory: Array[ItemInstance] = []


func add_item(item: ItemInstance):

	# Try to stack
	if item.data.stackable:
		for existing in inventory:
			if existing.data.item_id == item.data.item_id:
				if existing.quantity < existing.data.max_stack:

					var space = existing.data.max_stack - existing.quantity
					var amount = min(space, item.quantity)

					existing.quantity += amount
					item.quantity -= amount

					if item.quantity <= 0:
						return

	# Anything left becomes a new stack
	inventory.append(item)


func remove_item(item: ItemInstance):
	inventory.erase(item)


func get_items() -> Array[ItemInstance]:
	return inventory

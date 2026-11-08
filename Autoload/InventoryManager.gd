extends Node

signal inventory_changed
var inventory: Array[ItemInstance] = []


func add_item(item: ItemInstance):

	if item.data.stackable:
		for existing in inventory:
			if existing.data.item_id == item.data.item_id:
				if existing.quantity < existing.data.max_stack:

					var space = existing.data.max_stack - existing.quantity
					var amount = min(space, item.quantity)

					existing.quantity += amount
					item.quantity -= amount

					inventory_changed.emit()

					if item.quantity <= 0:
						return

	inventory.append(item)
	inventory_changed.emit()


func remove_item(item: ItemInstance):
	inventory.erase(item)
	inventory_changed.emit()


func get_items() -> Array[ItemInstance]:
	return inventory



#for crafting

func get_item_count(item_id: String) -> int:
	var total := 0

	for item in inventory:
		if item.data.item_id == item_id:
			total += item.quantity

	return total


func has_item(item_id: String, amount: int) -> bool:
	return get_item_count(item_id) >= amount


func remove_item_by_id(item_id: String, amount: int) -> bool:

	if not has_item(item_id, amount):
		return false

	var remaining := amount

	for item in inventory.duplicate():

		if item.data.item_id != item_id:
			continue

		if item.quantity > remaining:
			item.quantity -= remaining
			inventory_changed.emit()
			return true

		remaining -= item.quantity
		inventory.erase(item)

		if remaining <= 0:
			inventory_changed.emit()
			return true

	return true

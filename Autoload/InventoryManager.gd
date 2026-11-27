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


# =========================================================
# USE HEALING ITEM
# =========================================================

func use_healing_item(
	item: ItemInstance,
	atomon: AtomonInstance
) -> bool:

	if item == null or item.data == null:
		return false

	if atomon == null or atomon.data == null:
		return false

	# Must be a consumable.
	if not item.data.consumable:
		return false

	# Must have a healing effect.
	if item.data.heal_amount <= 0:
		return false

	# Must have at least one remaining.
	if item.quantity <= 0:
		return false

	# Cannot heal a full-HP Atomon.
	var max_hp := StatCalculator.get_hp(atomon.data)

	if atomon.current_hp >= max_hp:
		print("[InventoryManager] Atomon already has full HP.")
		return false

	# Apply healing.
	var healed_amount := atomon.heal(item.data.heal_amount)

	if healed_amount <= 0:
		return false

	# Consume exactly one item.
	item.quantity -= 1

	# Remove the stack if empty.
	if item.quantity <= 0:
		inventory.erase(item)

	# Notify inventory UI to refresh.
	inventory_changed.emit()

	print(
		"[InventoryManager] Used ",
		item.data.item_name,
		". Restored ",
		healed_amount,
		" HP."
	)

	return true

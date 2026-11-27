extends RefCounted
class_name ConsumableHandler


# ============================================================
# USE HEALING ITEM
# ============================================================

static func use_healing_item(
	item: ItemInstance,
	target: AtomonInstance
) -> Dictionary:

	# --------------------------------------------------------
	# VALIDATE ITEM
	# --------------------------------------------------------

	if item == null or item.data == null:
		return {
			"success": false,
			"message": "Invalid item."
		}

	if not item.data.consumable \
	and item.data.category != ItemData.Category.CONSUMABLE:
		return {
			"success": false,
			"message": "This item cannot be consumed."
		}

	if item.data.heal_amount <= 0:
		return {
			"success": false,
			"message": "This item has no healing effect."
		}

	if InventoryManager.get_item_count(item.data.item_id) <= 0:
		return {
			"success": false,
			"message": "You don't have this item."
		}


	# --------------------------------------------------------
	# VALIDATE TARGET
	# --------------------------------------------------------

	if target == null or target.data == null:
		return {
			"success": false,
			"message": "Invalid Atomon target."
		}


	# --------------------------------------------------------
	# HEAL
	# --------------------------------------------------------

	var healed_amount: int = target.heal(
		item.data.heal_amount
	)

	if healed_amount <= 0:
		return {
			"success": false,
			"healed_amount": 0,
			"message": target.data.atomon_name + " is already at full HP."
		}


	# --------------------------------------------------------
	# CONSUME ITEM
	# --------------------------------------------------------

	var item_id: String = item.data.item_id

	var removed: bool = InventoryManager.remove_item_by_id(
		item_id,
		1
	)

	if not removed:
		push_error("[ConsumableHandler] Failed to consume item: " + item_id)

		return {
		"success": false,
		"healed_amount": healed_amount,
		"message": "Healing succeeded, but item consumption failed."
		}


	# --------------------------------------------------------
	# SUCCESS
	# --------------------------------------------------------

	return {
		"success": true,
		"healed_amount": healed_amount,
		"message": target.data.atomon_name + " recovered " + str(healed_amount) + " HP!"
	}

class_name ItemInstance
extends Resource


# ============================================================
# ITEM DATA
# ============================================================

@export var data: ItemData
@export var quantity: int = 1


# ============================================================
# FACTORY
# ============================================================

static func create(item_id: String, amount: int = 1) -> ItemInstance:
	var instance := ItemInstance.new()

	instance.data = ItemDatabase.get_item(item_id)
	instance.quantity = amount

	if instance.data == null:
		push_error(
			"[ItemInstance] Item not found in database: " + item_id
		)

	return instance


# ============================================================
# FIREBASE SERIALIZATION
# ============================================================

func to_save_dict() -> Dictionary:

	if data == null:
		push_error("[ItemInstance] Cannot save item without data.")
		return {}

	return {
		"item_id": data.item_id,
		"quantity": quantity
	}


# ============================================================
# FIREBASE DESERIALIZATION
# ============================================================

func apply_save_dict(save_dict: Dictionary) -> void:

	if save_dict.is_empty():
		return

	var item_id: String = str(
		save_dict.get("item_id", "")
	)

	if item_id.is_empty():
		push_error("[ItemInstance] Save data has no item_id.")
		return

	data = ItemDatabase.get_item(item_id)

	if data == null:
		push_error(
			"[ItemInstance] Item ID not found: " + item_id
		)
		return

	quantity = max(
		1,
		int(save_dict.get("quantity", 1))
	)

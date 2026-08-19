class_name ItemInstance
extends Resource


# ============================================================
# ITEM DATA
# ============================================================

@export var data: ItemData
@export var quantity: int = 1


# ============================================================
# FIREBASE SERIALIZATION
# ============================================================

func to_save_dict() -> Dictionary:

	if data == null:
		print("[ItemInstance] Cannot save item without data.")
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

	quantity = int(
		save_dict.get("quantity", 1)
	)

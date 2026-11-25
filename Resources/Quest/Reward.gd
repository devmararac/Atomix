@tool
extends Resource
class_name Reward

enum Type {
	COINS,
	ITEM
}

@export var reward_type: Type = Type.COINS:
	set(value):
		reward_type = value
		notify_property_list_changed()

@export var reward_amount: int = 1


var item_data: ItemData


func _get_property_list() -> Array:
	var properties: Array = []

	if reward_type == Type.ITEM:
		properties.append({
			"name": "item_data",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "ItemData",
			"usage": PROPERTY_USAGE_DEFAULT
		})

	return properties

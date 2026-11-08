extends Resource
class_name Reward

@export var reward_type: String = "coins" # "coins" or "item"
@export var reward_amount: int = 1

# This is the magic part: If you set reward_type to "item", drag your ItemData here!
@export var item_data: ItemData 

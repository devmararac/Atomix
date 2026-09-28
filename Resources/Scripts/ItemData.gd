class_name ItemData
extends Resource

enum Category {
	MATERIAL,
	CONSUMABLE,
	KEY_ITEM,
	QUEST_ITEM,
	CRAFTING,
	SPECIAL
}

@export_category("Basic Information")
@export var item_id: String
@export var item_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_category("Stacking")
@export var stackable := true
@export var max_stack := 99

@export_category("Economy")
@export var buy_price := 0
@export var sell_price := 0

@export_category("Classification")
@export var category: Category

@export_category("Properties")
@export var crafting_recipe := false
@export var consumable := false
@export var quest_item := false

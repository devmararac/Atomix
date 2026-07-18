class_name ItemData
extends Resource

@export var item_id: String
@export var item_name: String
@export_multiline var description: String

@export var icon: Texture2D

@export var stackable := true
@export var max_stack := 99
@export var buy_price := 0
@export var sell_price := 0

@export var category: String
@export var usable := false
@export var consumable := false
@export var quest_item := false

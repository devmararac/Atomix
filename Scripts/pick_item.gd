class_name ItemPickup
extends Area2D

@export var data: ItemData
@export var quantity := 1

@onready var sprite: Sprite2D = $Icon
@onready var indicator: AnimatedSprite2D = $Indicator



func _ready():
	if data:
		sprite.texture = data.icon

	indicator.visible = false
	indicator.play("bounce")
	$Highlight.visible = false


func _process(_delta):
	indicator.visible = should_show_indicator()


func should_show_indicator() -> bool:
	var quest = QuestManager.tracked_quest

	if quest == null or data == null:
		return false

	for objective in quest.objectives:

		if objective.type == ObjectiveType.Type.COLLECTION \
		and objective.target_id == data.item_id \
		and !objective.is_completed:

			return true

	return false


func collect():

	var instance = ItemInstance.new()
	instance.data = data
	instance.quantity = quantity

	InventoryManager.add_item(instance)

	QuestManager.notify(
		ObjectiveType.Type.COLLECTION,
		data.item_id,
		quantity
	)

	queue_free()

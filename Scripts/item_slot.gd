extends TextureButton

@onready var icon: TextureRect = $item_texture
@onready var quantity_label: Label = $Label

signal item_selected(item: ItemInstance)

var item_instance: ItemInstance

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	if item_instance != null:
		item_selected.emit(item_instance)

func set_item(item: ItemInstance):
	item_instance = item

	icon.texture = item.data.icon

	if item.quantity > 1:
		quantity_label.visible = true
		quantity_label.text = ("x") + str(item.quantity)
	else:
		quantity_label.visible = false
		quantity_label.text = ""


func clear_slot():
	item_instance = null
	icon.texture = null
	quantity_label.visible = false
	quantity_label.text = ""

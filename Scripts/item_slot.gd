extends TextureButton

@onready var icon: TextureRect = $item_texture
@onready var quantity_label: Label = $Label

signal item_selected(item: ItemInstance)

var item_instance: ItemInstance

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	print("SLOT PRESSED")

	if item_instance != null:
		print("ITEM IN SLOT: ", item_instance.data.item_id)
		print("ITEM NAME: ", item_instance.data.item_name)

		SfxManager.play_slot_click()
		item_selected.emit(item_instance)
	else:
		print("SLOT IS EMPTY")

func set_item(item: ItemInstance):
	item_instance = item

	print("ITEM SLOT:")
	print("Item ID: ", item.data.item_id)
	print("Item Name: ", item.data.item_name)
	print("Icon: ", item.data.icon)

	icon.texture = item.data.icon

	if item.quantity > 1:
		quantity_label.visible = true
		quantity_label.text = "x" + str(item.quantity)
	else:
		quantity_label.visible = false
		quantity_label.text = ""


func clear_slot():
	item_instance = null
	icon.texture = null
	quantity_label.visible = false
	quantity_label.text = ""

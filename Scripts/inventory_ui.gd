extends CanvasLayer

enum Category {
	ALL,
	ITEM,
	CONSUMABLE,
	QUEST
}

var current_category := Category.ALL

# Buttons
@onready var all_button = $TextureRect/Slots/All
@onready var item_button = $TextureRect/Slots/Item
@onready var consumable_button = $TextureRect/Slots/Consumables
@onready var quest_button = $TextureRect/Slots/QuestItems
@onready var slot_label = $TextureRect/Slots/Label
@onready var item_panel = $TextureRect/Description/ItemWindow
@onready var item_icon = $TextureRect/Description/ItemWindow/ItemIcon
@onready var item_description = $TextureRect/Description/ItemWindow/ItemDescription
@onready var item_name = $TextureRect/Description/ItemWindow/ItemName


# Inventory
@onready var grid = $TextureRect/Slots/ItemContainer/GridContainer
@onready var coins = $TextureRect/Slots/Coins/Amount

# Description Panel Later

func _ready():
	CurrencyManager.coins_changed.connect(_on_coins_changed)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)

	_on_coins_changed(CurrencyManager.coins)

	all_button.pressed.connect(_on_all_pressed)
	item_button.pressed.connect(_on_item_pressed)
	consumable_button.pressed.connect(_on_consumable_pressed)
	quest_button.pressed.connect(_on_quest_pressed)

	clear_description()
	load_category(Category.ALL)

func clear_description():
	item_panel.visible = false
	item_icon.visible = false
	item_name.visible = false
	item_description.visible = false

	item_icon.texture = null
	item_name.text = ""
	item_description.text = ""

func _on_coins_changed(amount: int):
	coins.text = str(amount)

func load_category(category):
	current_category = category

	update_buttons()
	refresh_inventory()


func update_buttons():
	all_button.button_pressed = current_category == Category.ALL
	item_button.button_pressed = current_category == Category.ITEM
	consumable_button.button_pressed = current_category == Category.CONSUMABLE
	quest_button.button_pressed = current_category == Category.QUEST

	match current_category:
		Category.ALL:
			slot_label.text = "All Items"
		Category.ITEM:
			slot_label.text = "Items"
		Category.CONSUMABLE:
			slot_label.text = "Consumables"
		Category.QUEST:
			slot_label.text = "Quest Items"


func refresh_inventory():
	# Remove old slots
	for child in grid.get_children():
		child.queue_free()

	var items = InventoryManager.get_items()
	var slot_scene = preload("res://Scenes/UI/item_slot.tscn")

	const SLOT_COUNT := 30

	for i in range(SLOT_COUNT):
		var slot = slot_scene.instantiate()
		grid.add_child(slot)
		slot.item_selected.connect(show_item)

		if i < items.size():
			slot.set_item(items[i])


func show_item(item: ItemInstance):
	print("SHOWING ITEM: ", item.data.item_id)
	print("NAME: ", item.data.item_name)
	print("DESCRIPTION: ", item.data.description)

	item_panel.visible = true
	item_icon.visible = true
	item_name.visible = true
	item_description.visible = true

	item_icon.texture = item.data.icon
	item_name.text = item.data.item_name
	item_description.text = item.data.description

func _on_all_pressed():
	load_category(Category.ALL)


func _on_item_pressed():
	load_category(Category.ITEM)


func _on_consumable_pressed():
	load_category(Category.CONSUMABLE)


func _on_quest_pressed():
	load_category(Category.QUEST)

func close():
	queue_free()

func _on_close_pressed() -> void:
	SfxManager.play_click()
	queue_free()


func _on_inventory_changed() -> void:
	refresh_inventory()

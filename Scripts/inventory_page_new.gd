extends Control

const TOTAL_SLOTS := 40

@onready var slot_container: GridContainer = $"Left Panel/ScrollContainer/SlotContainer"

@onready var right_panel: Panel = $"Right Panel"

@onready var coins: Label = $CoinText
@onready var item_icon: TextureRect = $"Right Panel/ITEMBG/ItemIcon"
@onready var item_name: Label = $"Right Panel/ITEMBG/ItemName"
@onready var description: RichTextLabel = $"Right Panel/Description"


@onready var use_button: Button = $"Right Panel/USE"
@onready var discard_button: Button = $"Right Panel/DISCARD"


var selected_item: ItemInstance


func _ready():
	CurrencyManager.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(CurrencyManager.coins)
	populate_inventory()
	clear_selection()

func _on_coins_changed(amount: int):
	coins.text = str(amount)

func populate_inventory():
	var items = InventoryManager.inventory

	for i in range(TOTAL_SLOTS):
		var slot = slot_container.get_child(i)

		if i < items.size():
			slot.set_item(items[i])

			if !slot.item_selected.is_connected(select_item):
				slot.item_selected.connect(select_item)
		else:
			slot.clear_slot()


func refresh():
	populate_inventory()

	if selected_item == null:
		clear_selection()


func select_item(item: ItemInstance):
	selected_item = item

	item_icon.texture = item.data.icon
	item_name.text = item.data.item_name
	description.text = item.data.description

	use_button.disabled = !item.data.usable
	discard_button.disabled = item.data.quest_item
	animate_item_icon()

func clear_selection():
	selected_item = null

	item_icon.texture = null
	item_name.text = "No Item Selected"
	description.text = "Select an item to view its description."

	use_button.disabled = true
	discard_button.disabled = true

func animate_item_icon():
	item_icon.scale = Vector2(0.7, 0.7)
	item_icon.rotation = deg_to_rad(-8)

	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		item_icon,
		"scale",
		Vector2.ONE,
		0.18
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		item_icon,
		"rotation",
		0.0,
		0.18
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

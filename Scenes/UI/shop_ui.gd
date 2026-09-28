extends CanvasLayer


# ============================================================
# CONFIGURATION
# ============================================================

const MAX_PURCHASE_QUANTITY := 99

const ITEM_CARD_WIDTH := 170
const ITEM_CARD_HEIGHT := 175

const SHOP_ITEM_IDS := [
	"proton",
	"neutron",
	"electron",
	"atomic_core",
	"apple",
	"coffee",
	"watermelon",
	"grapes"
]

# ============================================================
# CATEGORY
# ============================================================

enum ShopCategory {
	ALL,
	MATERIAL,
	CONSUMABLE,
	CRAFTING,
	SPECIAL
}


var current_category: ShopCategory = ShopCategory.ALL


# ============================================================
# CURRENT ITEM
# ============================================================

var selected_item_id: String = ""
var selected_item: ItemData = null
var purchase_quantity: int = 1


# ============================================================
# UI
# ============================================================

@onready var coins_label: Label = $ShopPanel/Header/CoinBox/Coins
@onready var message_label: Label = $ShopPanel/MessageLabel

@onready var item_grid: GridContainer = \
	$ShopPanel/Content/ProductsPanel/ScrollContainer/ItemGrid

@onready var item_count_label: Label = \
	$ShopPanel/Content/ProductsPanel/ItemCount

@onready var item_icon: TextureRect = \
	$ShopPanel/Content/DetailPanel/DisplayBox/ItemIcon

@onready var item_name_label: Label = \
	$ShopPanel/Content/DetailPanel/DisplayBox/ItemName

@onready var price_label: Label = \
	$ShopPanel/Content/DetailPanel/DisplayBox/Price

@onready var description_label: Label = \
	$ShopPanel/Content/DetailPanel/Description

@onready var owned_label: Label = \
	$ShopPanel/Content/DetailPanel/Owned

@onready var quantity_label: Label = \
	$ShopPanel/Content/DetailPanel/QuantityControls/QuantityBox/Quantity

@onready var total_price_label: Label = \
	$ShopPanel/Content/DetailPanel/TotalPrice

@onready var buy_button: Button = \
	$ShopPanel/Content/DetailPanel/Buy

@onready var minus_button: Button = \
	$ShopPanel/Content/DetailPanel/QuantityControls/Minus

@onready var plus_button: Button = \
	$ShopPanel/Content/DetailPanel/QuantityControls/Plus

@onready var max_button: Button = \
	$ShopPanel/Content/DetailPanel/QuantityControls/Max

@onready var close_button: TextureButton = \
	$ShopPanel/CloseButton


# ============================================================
# CATEGORY BUTTONS
# ============================================================

@onready var all_button: Button = \
	$ShopPanel/CategoryTabs/All

@onready var materials_button: Button = \
	$ShopPanel/CategoryTabs/Materials

@onready var consumables_button: Button = \
	$ShopPanel/CategoryTabs/Consumables

@onready var crafting_button: Button = \
	$ShopPanel/CategoryTabs/Crafting

@onready var special_button: Button = \
	$ShopPanel/CategoryTabs/Special


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	layer = 200

	# --------------------------------------------------------
	# Stop player movement
	# --------------------------------------------------------

	if global.player:
		global.player.can_move = false


	# --------------------------------------------------------
	# Currency signal
	# --------------------------------------------------------

	if not CurrencyManager.coins_changed.is_connected(
		_on_coins_changed
	):
		CurrencyManager.coins_changed.connect(
			_on_coins_changed
	)


	# --------------------------------------------------------
	# Category buttons
	# --------------------------------------------------------

	all_button.pressed.connect(
		func():
			_set_category(ShopCategory.ALL)
	)

	materials_button.pressed.connect(
		func():
			_set_category(ShopCategory.MATERIAL)
	)

	consumables_button.pressed.connect(
		func():
			_set_category(ShopCategory.CONSUMABLE)
	)

	crafting_button.pressed.connect(
		func():
			_set_category(ShopCategory.CRAFTING)
	)

	special_button.pressed.connect(
		func():
			_set_category(ShopCategory.SPECIAL)
	)


	# --------------------------------------------------------
	# Quantity controls
	# --------------------------------------------------------

	minus_button.pressed.connect(
		_decrease_quantity
	)

	plus_button.pressed.connect(
		_increase_quantity
	)

	max_button.pressed.connect(
		_set_max_quantity
	)


	# --------------------------------------------------------
	# Buy
	# --------------------------------------------------------

	buy_button.pressed.connect(
		_on_buy_pressed
	)


	# --------------------------------------------------------
	# Close
	# --------------------------------------------------------

	close_button.pressed.connect(
		_on_close_pressed
	)


	message_label.text = ""

	_set_category(ShopCategory.ALL)

	_update_coins()

	print("[ShopUI] Shop opened.")


# ============================================================
# CATEGORY
# ============================================================

func _set_category(category: ShopCategory) -> void:

	current_category = category

	_rebuild_item_grid()

	_update_category_visuals()


# ============================================================
# CATEGORY VISUALS
# ============================================================

func _update_category_visuals() -> void:

	# The pressed state is handled visually by the theme.
	# Keeping this function allows future selected-tab styling.


	all_button.button_pressed = current_category == ShopCategory.ALL
	materials_button.button_pressed = current_category == ShopCategory.MATERIAL
	consumables_button.button_pressed = current_category == ShopCategory.CONSUMABLE
	crafting_button.button_pressed = current_category == ShopCategory.CRAFTING
	special_button.button_pressed = current_category == ShopCategory.SPECIAL


# ============================================================
# BUILD ITEM GRID
# ============================================================

func _rebuild_item_grid() -> void:

	for child in item_grid.get_children():
		child.queue_free()


	var items: Array[ItemData] = []


	for item_id in SHOP_ITEM_IDS:

		var item: ItemData = ItemDatabase.get_item(item_id)

		if item == null:
			push_error(
				"[ShopUI] Shop item not found in ItemDatabase: "
				+ item_id
			)
			continue

		if item.buy_price <= 0:
			continue

		if _item_matches_category(item):
			items.append(item)


	items.sort_custom(_sort_items)


	item_count_label.text = str(items.size()) + " ITEMS"


	for item in items:

		var card := _create_item_card(item)

		item_grid.add_child(card)


	# Select first item if current selection disappeared.

	if selected_item == null \
	or not _item_matches_category(selected_item):

		if not items.is_empty():
			_select_item(items[0].item_id)
		else:
			_clear_selection()


# ============================================================
# CATEGORY FILTER
# ============================================================

func _item_matches_category(item: ItemData) -> bool:

	if current_category == ShopCategory.ALL:
		return true


	match current_category:

		ShopCategory.MATERIAL:
			return item.category == ItemData.Category.MATERIAL

		ShopCategory.CONSUMABLE:
			return item.category == ItemData.Category.CONSUMABLE

		ShopCategory.CRAFTING:
			return item.category == ItemData.Category.CRAFTING

		ShopCategory.SPECIAL:
			return item.category == ItemData.Category.SPECIAL


	return false


# ============================================================
# SORT
# ============================================================

func _sort_items(a: ItemData, b: ItemData) -> bool:

	return a.item_name.to_lower() < b.item_name.to_lower()


# ============================================================
# CREATE ITEM CARD
# ============================================================

func _create_item_card(item: ItemData) -> Button:

	var button := Button.new()

	button.custom_minimum_size = Vector2(
		ITEM_CARD_WIDTH,
		ITEM_CARD_HEIGHT
	)

	button.tooltip_text = item.description

	button.text = ""


	# --------------------------------------------------------
	# Card appearance
	# --------------------------------------------------------

	var normal := StyleBoxFlat.new()

	normal.bg_color = Color(
		0.93,
		0.76,
		0.58,
		1
	)

	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3

	normal.border_color = Color(
		0.38,
		0.2,
		0.1,
		1
	)

	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8


	var hover := normal.duplicate()

	hover.bg_color = Color(
		0.99,
		0.85,
		0.67,
		1
	)


	var pressed := normal.duplicate()

	pressed.bg_color = Color(
		0.65,
		0.72,
		0.48,
		1
	)


	button.add_theme_stylebox_override(
		"normal",
		normal
	)

	button.add_theme_stylebox_override(
		"hover",
		hover
	)

	button.add_theme_stylebox_override(
		"pressed",
		pressed
	)


	# --------------------------------------------------------
	# Item icon
	# --------------------------------------------------------

	var icon := TextureRect.new()

	icon.position = Vector2(40, 8)
	icon.size = Vector2(90, 90)

	icon.texture = item.icon

	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	button.add_child(icon)


	# --------------------------------------------------------
	# Item name
	# --------------------------------------------------------

	var name_label := Label.new()

	name_label.position = Vector2(8, 98)
	name_label.size = Vector2(154, 28)

	name_label.text = item.item_name.to_upper()

	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	name_label.add_theme_font_size_override(
		"font_size",
		16
	)

	name_label.add_theme_color_override(
		"font_color",
		Color(
			0.38,
			0.2,
			0.1,
			1
		)
	)

	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	button.add_child(name_label)


	# --------------------------------------------------------
	# Owned
	# --------------------------------------------------------

	var owned := Label.new()

	owned.position = Vector2(8, 130)
	owned.size = Vector2(154, 25)

	owned.text = (
		"Owned: "
		+ str(
			InventoryManager.get_item_count(
				item.item_id
			)
		)
	)

	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	owned.add_theme_font_size_override(
		"font_size",
		13
	)

	owned.add_theme_color_override(
		"font_color",
		Color(
			0.55,
			0.31,
			0.16,
			1
		)
	)

	owned.mouse_filter = Control.MOUSE_FILTER_IGNORE

	button.add_child(owned)


	# --------------------------------------------------------
	# Price
	# --------------------------------------------------------

	var price := Label.new()

	price.position = Vector2(8, 151)
	price.size = Vector2(154, 20)

	price.text = str(item.buy_price) + " COINS"

	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	price.add_theme_font_size_override(
		"font_size",
		12
	)

	price.add_theme_color_override(
		"font_color",
		Color(
			0.38,
			0.2,
			0.1,
			1
		)
	)

	price.mouse_filter = Control.MOUSE_FILTER_IGNORE

	button.add_child(price)


	# --------------------------------------------------------
	# Select
	# --------------------------------------------------------

	button.pressed.connect(
		func():
			_select_item(item.item_id)
	)

	return button


# ============================================================
# SELECT ITEM
# ============================================================

func _select_item(item_id: String) -> void:

	var item: ItemData = ItemDatabase.get_item(item_id)

	if item == null:
		push_error(
			"[ShopUI] Item not found: "
			+ item_id
		)
		return


	selected_item_id = item_id
	selected_item = item

	purchase_quantity = 1

	message_label.text = ""

	_update_detail_panel()


# ============================================================
# UPDATE DETAIL PANEL
# ============================================================

func _update_detail_panel() -> void:

	if selected_item == null:
		_clear_selection()
		return


	item_icon.texture = selected_item.icon

	item_name_label.text = \
		selected_item.item_name.to_upper()

	price_label.text = \
		str(selected_item.buy_price) + " COINS EACH"

	description_label.text = \
		selected_item.description


	_update_owned()

	_update_quantity_ui()


# ============================================================
# OWNED
# ============================================================

func _update_owned() -> void:

	if selected_item == null:
		owned_label.text = "Owned: 0"
		return


	var amount: int = InventoryManager.get_item_count(
		selected_item.item_id
	)


	owned_label.text = \
		"Owned: " + str(amount)


# ============================================================
# QUANTITY
# ============================================================

func _increase_quantity() -> void:

	if selected_item == null:
		return


	if purchase_quantity >= MAX_PURCHASE_QUANTITY:
		return


	purchase_quantity += 1

	_update_quantity_ui()


# ============================================================

func _decrease_quantity() -> void:

	if purchase_quantity <= 1:
		return


	purchase_quantity -= 1

	_update_quantity_ui()


# ============================================================

func _set_max_quantity() -> void:

	if selected_item == null:
		return


	var maximum := _get_max_affordable_quantity()

	if maximum <= 0:

		purchase_quantity = 1

	else:

		purchase_quantity = maximum


	_update_quantity_ui()


# ============================================================
# MAX AFFORDABLE
# ============================================================

func _get_max_affordable_quantity() -> int:

	if selected_item == null:
		return 0


	if selected_item.buy_price <= 0:
		return MAX_PURCHASE_QUANTITY


	var affordable := int(
		CurrencyManager.coins
		/ selected_item.buy_price
	)


	return clamp(
		affordable,
		0,
		MAX_PURCHASE_QUANTITY
	)


# ============================================================
# UPDATE QUANTITY UI
# ============================================================

func _update_quantity_ui() -> void:

	if selected_item == null:

		quantity_label.text = "0"
		total_price_label.text = "TOTAL: 0 COINS"
		buy_button.text = "BUY"
		buy_button.disabled = true

		return


	quantity_label.text = \
		str(purchase_quantity)


	var total := \
		selected_item.buy_price * purchase_quantity


	total_price_label.text = \
		"TOTAL: " + str(total) + " COINS"


	buy_button.text = \
		"BUY " + str(purchase_quantity)


	buy_button.disabled = \
		not CurrencyManager.has_coins(total)


	_update_quantity_buttons()


# ============================================================
# QUANTITY BUTTON STATES
# ============================================================

func _update_quantity_buttons() -> void:

	if selected_item == null:
		return


	minus_button.disabled = \
		purchase_quantity <= 1


	plus_button.disabled = \
		purchase_quantity >= MAX_PURCHASE_QUANTITY


	max_button.disabled = \
		_get_max_affordable_quantity() <= 0


# ============================================================
# BUY
# ============================================================

func _on_buy_pressed() -> void:

	if selected_item == null:
		return


	if purchase_quantity <= 0:
		return


	var total_price := \
		selected_item.buy_price * purchase_quantity


	# --------------------------------------------------------
	# Currency check
	# --------------------------------------------------------

	if not CurrencyManager.has_coins(total_price):

		message_label.text = \
			"NOT ENOUGH COINS."

		return


	# --------------------------------------------------------
	# Remove currency
	# --------------------------------------------------------

	CurrencyManager.remove_coins(
		total_price
	)


	# --------------------------------------------------------
	# Create item instance
	# --------------------------------------------------------

	var instance := ItemInstance.new()

	instance.data = selected_item
	instance.quantity = purchase_quantity


	# --------------------------------------------------------
	# Add inventory
	# --------------------------------------------------------

	InventoryManager.add_item(
		instance
	)


	# --------------------------------------------------------
	# Success message
	# --------------------------------------------------------

	message_label.text = (
		"PURCHASED "
		+ str(purchase_quantity)
		+ " × "
		+ selected_item.item_name.to_upper()
	)


	print(
		"[ShopUI] Purchase successful: ",
		selected_item.item_id,
		" x",
		purchase_quantity,
		" | Total: ",
		total_price
	)


	# --------------------------------------------------------
	# Reset quantity
	# --------------------------------------------------------

	purchase_quantity = 1


	_update_shop()


	# --------------------------------------------------------
	# Save
	# --------------------------------------------------------

	print(
		"[ShopUI] Requesting automatic save..."
	)


	await SaveManager.auto_save(
		"Shop purchase: "
		+ selected_item.item_id
		+ " x"
		+ str(instance.quantity)
	)


	print(
		"[ShopUI] Purchase save completed."
	)


# ============================================================
# SHOP UPDATE
# ============================================================

func _update_shop() -> void:

	_update_coins()

	_update_owned()

	_update_quantity_ui()

	_rebuild_item_grid()


# ============================================================
# COINS
# ============================================================

func _update_coins() -> void:

	coins_label.text = \
		"Coins: " + str(CurrencyManager.coins)


func _on_coins_changed(new_amount: int) -> void:

	coins_label.text = \
		"Coins: " + str(new_amount)

	_update_quantity_ui()


# ============================================================
# CLEAR SELECTION
# ============================================================

func _clear_selection() -> void:

	selected_item_id = ""
	selected_item = null
	purchase_quantity = 1

	item_icon.texture = null
	item_name_label.text = "NO ITEM SELECTED"
	price_label.text = ""
	description_label.text = "No items are available in this category."
	owned_label.text = "Owned: 0"
	quantity_label.text = "0"
	total_price_label.text = "TOTAL: 0 COINS"
	buy_button.text = "BUY"
	buy_button.disabled = true


# ============================================================
# CLOSE
# ============================================================

func _on_close_pressed() -> void:

	print("[ShopUI] Closing shop.")


	if global.player:
		global.player.can_move = true


	if CurrencyManager.coins_changed.is_connected(
		_on_coins_changed
	):
		CurrencyManager.coins_changed.disconnect(
			_on_coins_changed
		)


	queue_free()

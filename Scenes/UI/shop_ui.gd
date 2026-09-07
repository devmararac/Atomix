extends CanvasLayer


# ============================================================
# SHOP ITEMS
# ============================================================

const SHOP_ITEMS := {

	"proton": {
		"name": "PROTON",
		"price": 5,
		"description": "A proton is a positively charged\nparticle found inside the atomic nucleus.",
		"button": "proton"
	},

	"neutron": {
		"name": "NEUTRON",
		"price": 5,
		"description": "A neutron is a neutral particle\nfound inside the atomic nucleus.",
		"button": "neutron"
	},

	"electron": {
		"name": "ELECTRON",
		"price": 5,
		"description": "An electron is a negatively charged\nparticle found around the atomic nucleus.",
		"button": "electron"
	},

	"atomic_core": {
		"name": "ATOMIC CORE",
		"price": 10,
		"description": "An Atomic Core is a special crafting\nmaterial used to create Atomons.",
		"button": "atomic_core"
	}
}


# ============================================================
# CURRENTLY SELECTED ITEM
# ============================================================

var selected_item_id: String = "proton"


# ============================================================
# UI REFERENCES
# ============================================================

@onready var coins_label: Label = $ShopPanel/CoinBox/Coins

@onready var message_label: Label = $ShopPanel/MessageLabel

@onready var item_name_label: Label = $ShopPanel/Content/DetailPanel/ItemName

@onready var display_text: Label = $ShopPanel/Content/DetailPanel/DisplayBox/DisplayText

@onready var description_label: Label = $ShopPanel/Content/DetailPanel/Description

@onready var owned_label: Label = $ShopPanel/Content/DetailPanel/Owned

@onready var price_label: Label = $ShopPanel/Content/DetailPanel/PriceBox/Price

@onready var buy_button: Button = $ShopPanel/Content/DetailPanel/Buy


# Product buttons

@onready var proton_button: TextureButton = $ShopPanel/Content/ProductsPanel/Proton

@onready var neutron_button: TextureButton = $ShopPanel/Content/ProductsPanel/Neutron

@onready var electron_button: TextureButton = $ShopPanel/Content/ProductsPanel/Electron

@onready var atomic_core_button: TextureButton = $ShopPanel/Content/ProductsPanel/AtomicCore


# Close button

@onready var close_button: TextureButton = $ShopPanel/CloseButton


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	layer = 200


	# --------------------------------------------------------
	# Stop player movement while the shop is open.
	# --------------------------------------------------------

	if global.player:
		global.player.can_move = false


	# --------------------------------------------------------
	# Connect currency signal.
	# --------------------------------------------------------

	if not CurrencyManager.coins_changed.is_connected(
		_on_coins_changed
	):
		CurrencyManager.coins_changed.connect(
			_on_coins_changed
	)


	# --------------------------------------------------------
	# Connect product buttons.
	# --------------------------------------------------------

	proton_button.pressed.connect(
		func():
			_select_item("proton")
	)

	neutron_button.pressed.connect(
		func():
			_select_item("neutron")
	)

	electron_button.pressed.connect(
		func():
			_select_item("electron")
	)

	atomic_core_button.pressed.connect(
		func():
			_select_item("atomic_core")
	)


	# --------------------------------------------------------
	# Connect Buy button.
	# --------------------------------------------------------

	buy_button.pressed.connect(
		_on_buy_pressed
	)


	# --------------------------------------------------------
	# Connect Close button.
	# --------------------------------------------------------

	close_button.pressed.connect(
		_on_close_pressed
	)


	message_label.text = ""


	# --------------------------------------------------------
	# Show Proton by default.
	# --------------------------------------------------------

	_select_item("proton")


	print("[ShopUI] Shop opened.")


# ============================================================
# SELECT ITEM
# ============================================================

func _select_item(item_id: String) -> void:

	if not SHOP_ITEMS.has(item_id):

		push_error(
			"[ShopUI] Unknown shop item: "
			+ item_id
		)

		return


	selected_item_id = item_id

	var item_info: Dictionary = SHOP_ITEMS[item_id]


	# --------------------------------------------------------
	# Update item information on the RIGHT side.
	# --------------------------------------------------------

	item_name_label.text = item_info["name"]

	display_text.text = item_info["name"]

	description_label.text = item_info["description"]

	price_label.text = (
		str(item_info["price"])
		+ " COINS"
	)


	# Remove previous purchase message.

	message_label.text = ""


	# Update inventory and currency information.

	_update_owned_count()

	_update_coins()

	_update_buy_button()


	print(
		"[ShopUI] Selected: ",
		item_info["name"]
	)


# ============================================================
# UPDATE OWNED COUNT
# ============================================================

func _update_owned_count() -> void:

	var amount := InventoryManager.get_item_count(
		selected_item_id
	)

	owned_label.text = (
		"Owned: "
		+ str(amount)
	)


# ============================================================
# UPDATE COINS
# ============================================================

func _update_coins() -> void:

	coins_label.text = (
		"Coins: "
		+ str(CurrencyManager.coins)
	)


# ============================================================
# UPDATE BUY BUTTON
# ============================================================

func _update_buy_button() -> void:

	if not SHOP_ITEMS.has(selected_item_id):

		buy_button.disabled = true

		return


	var price: int = SHOP_ITEMS[selected_item_id]["price"]


	if CurrencyManager.has_coins(price):

		buy_button.disabled = false

	else:

		buy_button.disabled = true


# ============================================================
# REFRESH SHOP
# ============================================================

func _update_shop() -> void:

	_update_coins()

	_update_owned_count()

	_update_buy_button()


# ============================================================
# BUY ITEM
# ============================================================

func _on_buy_pressed() -> void:

	if not SHOP_ITEMS.has(selected_item_id):
		return


	var item_info: Dictionary = SHOP_ITEMS[selected_item_id]

	var item_name: String = item_info["name"]

	var price: int = item_info["price"]


	# --------------------------------------------------------
	# CHECK COINS
	# --------------------------------------------------------

	if not CurrencyManager.has_coins(price):

		message_label.text = "NOT ENOUGH COINS."

		print(
			"[ShopUI] Purchase failed."
		)

		print(
			"[ShopUI] Required: ",
			price
		)

		print(
			"[ShopUI] Current: ",
			CurrencyManager.coins
		)

		_update_buy_button()

		return


	# --------------------------------------------------------
	# GET ITEM DATA
	# --------------------------------------------------------

	var item_data: ItemData = ItemDatabase.get_item(
		selected_item_id
	)


	if item_data == null:

		message_label.text = "ITEM UNAVAILABLE."

		push_error(
			"[ShopUI] Item not found in ItemDatabase: "
			+ selected_item_id
		)

		return


	# --------------------------------------------------------
	# REMOVE COINS
	# --------------------------------------------------------

	CurrencyManager.remove_coins(
		price
	)


	# --------------------------------------------------------
	# CREATE ITEM INSTANCE
	# --------------------------------------------------------

	var item_instance := ItemInstance.new()

	item_instance.data = item_data

	item_instance.quantity = 1


	# --------------------------------------------------------
	# ADD ITEM TO INVENTORY
	# --------------------------------------------------------

	InventoryManager.add_item(
		item_instance
	)


	# --------------------------------------------------------
	# SHOW SUCCESS MESSAGE
	# --------------------------------------------------------

	message_label.text = (
		"PURCHASED "
		+ item_name
		+ "!"
	)


	print(
		"[ShopUI] Purchase successful."
	)

	print(
		"[ShopUI] Item: ",
		selected_item_id
	)

	print(
		"[ShopUI] Price: ",
		price
	)

	print(
		"[ShopUI] Remaining coins: ",
		CurrencyManager.coins
	)

	print(
		"[ShopUI] Inventory count: ",
		InventoryManager.get_item_count(
			selected_item_id
		)
	)


	# --------------------------------------------------------
	# REFRESH SHOP
	# --------------------------------------------------------

	_update_shop()


	# --------------------------------------------------------
	# AUTOMATIC SAVE
	# --------------------------------------------------------

	print(
		"[ShopUI] Requesting automatic save after purchase..."
	)


	await SaveManager.auto_save(
		"Shop purchase: " + selected_item_id
	)


	print(
		"[ShopUI] Shop purchase automatic save completed."
	)


# ============================================================
# CURRENCY CHANGED
# ============================================================

func _on_coins_changed(new_amount: int) -> void:

	coins_label.text = (
		"Coins: "
		+ str(new_amount)
	)

	_update_buy_button()


# ============================================================
# CLOSE SHOP
# ============================================================

func _on_close_pressed() -> void:

	print(
		"[ShopUI] Closing shop."
	)


	# --------------------------------------------------------
	# Restore player movement.
	# --------------------------------------------------------

	if global.player:

		global.player.can_move = true


	# --------------------------------------------------------
	# Disconnect signal.
	# --------------------------------------------------------

	if CurrencyManager.coins_changed.is_connected(
		_on_coins_changed
	):

		CurrencyManager.coins_changed.disconnect(
			_on_coins_changed
		)


	queue_free()

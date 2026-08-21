extends Panel

const HOTBAR_SIZE := 8

@onready var hbox: HBoxContainer = $HotBarSlotContainer

var hotbar_items: Array[ItemInstance] = []


func _ready() -> void:
	if not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.connect(_on_inventory_changed)

	_refresh_from_inventory()


# ============================================================
# INVENTORY CHANGED
# ============================================================

func _on_inventory_changed() -> void:
	_refresh_from_inventory()


# ============================================================
# REFRESH FROM INVENTORY
# ============================================================

func _refresh_from_inventory() -> void:

	hotbar_items.clear()

	var items: Array[ItemInstance] = InventoryManager.get_items()

	for item in items:

		if item == null:
			continue

		if item.data == null:
			continue

		if hotbar_items.size() >= HOTBAR_SIZE:
			break

		hotbar_items.append(item)

	_refresh_hotbar()


# ============================================================
# REFRESH HOTBAR UI
# ============================================================

func _refresh_hotbar() -> void:

	for i in range(HOTBAR_SIZE):

		if i >= hbox.get_child_count():
			break

		var slot = hbox.get_child(i)

		if i < hotbar_items.size():
			slot.set_item(hotbar_items[i])
		else:
			slot.clear_slot()


# ============================================================
# CLEAR HOTBAR
# ============================================================

func clear_hotbar() -> void:

	hotbar_items.clear()

	for i in range(HOTBAR_SIZE):

		if i >= hbox.get_child_count():
			break

		var slot = hbox.get_child(i)

		slot.clear_slot()

class_name ItemPickup
extends Area2D

@export var data: ItemData
@export var quantity := 1

# Unique identifier for this pickup instance in the world.
@export var spawn_id: String = ""

@onready var sprite: Sprite2D = $Icon
@onready var indicator: AnimatedSprite2D = $Indicator

var collected := false

# =========================================================
# RARITY RESPawn TIMES (SECONDS)
# =========================================================

const RARITY_RESPAWN_TIMES := {
	ItemData.Rarity.COMMON: 30.0,
	ItemData.Rarity.UNCOMMON: 60.0,
	ItemData.Rarity.RARE: 120.0,
	ItemData.Rarity.EPIC: 300.0,
	ItemData.Rarity.LEGENDARY: 600.0,
}


func _ready() -> void:

	if data:
		sprite.texture = data.icon

	indicator.visible = false
	indicator.play("bounce")
	$Highlight.visible = false

	var unique_id := _get_effective_spawn_id()

	if not RespawnManager.can_spawn(unique_id):
		collected = true
		_hide_pickup()

		print("[ItemPickup] Pickup is waiting to respawn: ", unique_id)
	else:
		collected = false


# =========================================================
# SPAWN ID
# =========================================================

func _get_effective_spawn_id() -> String:

	if not spawn_id.is_empty():
		return spawn_id

	var current_scene := get_tree().current_scene

	if current_scene:
		return current_scene.scene_file_path + "::" + str(get_path())

	return str(get_path())


# =========================================================
# HIDE PICKUP
# =========================================================

func _hide_pickup() -> void:

	hide()

	monitoring = false
	monitorable = false

	if has_node("Highlight"):
		$Highlight.visible = false

	if indicator:
		indicator.visible = false


# =========================================================
# SHOW PICKUP AGAIN
# =========================================================

func _show_pickup() -> void:

	show()

	monitoring = true
	monitorable = true

	collected = false

	print("[ItemPickup] Respawned: ", _get_effective_spawn_id())





# =========================================================
# QUEST INDICATOR
# =========================================================

func _process(_delta: float) -> void:

	# If collected, continuously check whether cooldown has expired.
	if collected:

		var unique_id := _get_effective_spawn_id()

		if RespawnManager.can_spawn(unique_id):
			_show_pickup()

		return

	indicator.visible = should_show_indicator()


func should_show_indicator() -> bool:

	var quest = QuestManager.tracked_quest

	if quest == null or data == null:
		return false

	for objective in quest.objectives:

		if objective == null:
			continue

		if objective.type == ObjectiveType.Type.COLLECTION \
		and objective.target_id == data.item_id \
		and not objective.is_completed:

			return true

	return false


# =========================================================
# COLLECT ITEM
# =========================================================

func collect() -> void:

	if collected:
		return

	if data == null:
		return

	collected = true

	var unique_id := _get_effective_spawn_id()

	# =====================================================
	# REGISTER COOLDOWN
	# =====================================================

	var cooldown: float = RARITY_RESPAWN_TIMES.get(
		data.rarity,
		30.0
	)

	RespawnManager.register_respawn(unique_id, cooldown)

	print(
		"[ItemPickup] Respawn registered: ",
		unique_id,
		" | Rarity: ",
		data.rarity,
		" | Cooldown: ",
		cooldown,
		" seconds"
	)

	# Hide instead of deleting so it can respawn automatically.
	_hide_pickup()



	# =====================================================
	# ADD ITEM TO INVENTORY
	# =====================================================

	var instance := ItemInstance.new()
	instance.data = data
	instance.quantity = quantity

	InventoryManager.add_item(instance)

	# =====================================================
	# QUEST NOTIFICATION
	# =====================================================

	QuestManager.notify(
		ObjectiveType.Type.COLLECTION,
		data.item_id,
		quantity
	)

	print(
		"[ItemPickup] Collected item: ",
		data.item_id,
		" × ",
		quantity
	)

	# =====================================================
	# AUTOMATIC SAVE
	# =====================================================

	print("[ItemPickup] Requesting automatic save after item collection...")

	await SaveManager.auto_save(
		"Collected item: " + data.item_id
	)

	print("[ItemPickup] Item collection automatic save completed.")

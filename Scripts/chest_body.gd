extends StaticBody2D

@export var chest_id: String = "chest_01"

@export_category("Contents")
@export var item_resources: Array[ItemData] = []
@export var item_amounts: Array[int] = []

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var highlight: AnimatedSprite2D = $Highlight

var is_opened: bool = false

func _ready() -> void:
	add_to_group("QuestObjects")
	highlight.visible = false
	
	if SaveManager.is_chest_opened(chest_id):
		queue_free()
		return
	
	sprite.frame = 0
	sprite.stop()

func interact() -> void:
	if is_opened:
		return

	is_opened = true
	highlight.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	
	if SfxManager: SfxManager.chest()

	# --- SMOOTH CHEST OPEN ---
	sprite.play("default")
	var original_scale := sprite.scale
	sprite.scale = original_scale * 1.15
	var bounce := create_tween()
	bounce.tween_property(sprite, "scale", original_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(0.15).timeout

	# --- GATHER ITEMS ---
	var items_to_show = []
	
	for i in item_resources.size():
		var item_data: ItemData = item_resources[i]
		if item_data == null:
			continue
		
		var amount := 1
		if i < item_amounts.size():
			amount = item_amounts[i]

		var new_item := ItemInstance.new()
		new_item.data = item_data
		new_item.quantity = amount
		InventoryManager.add_item(new_item)
		
		items_to_show.append({"data": item_data, "amount": amount})

	# --- SAVE THAT THIS CHEST IS OPENED ---
	SaveManager.mark_chest_opened(chest_id)
	SaveManager.auto_save("Chest opened: " + chest_id)

	# --- SHOW POPUP ---
	if not items_to_show.is_empty():
		_show_loot_popup(items_to_show)

	# --- FREE THE CHEST AFTER THE POPUP FINISHES ---
	# Total popup time: (stagger) + (read) + (icon flights) + (final cleanup)
	# For safety, just wait a fixed generous duration.
	await get_tree().create_timer(4.5).timeout
	queue_free()

func _show_loot_popup(items: Array) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	get_tree().current_scene.add_child(layer)
	
	var container := VBoxContainer.new()
	container.anchor_left = 1.0
	container.anchor_right = 1.0
	container.anchor_top = 0.0
	container.anchor_bottom = 0.0
	container.offset_left = -300.0
	container.offset_right = -40.0
	container.offset_top = 200.0
	container.offset_bottom = 500.0
	container.alignment = BoxContainer.ALIGNMENT_BEGIN
	container.add_theme_constant_override("separation", 12)
	layer.add_child(container)

	var font = load("res://Assets/Font/NicoPaint-Regular.woff")
	var rows: Array = []
	var icons: Array = []
	
	for i in items.size():
		var entry = items[i]
		var data = entry["data"]
		var amount = entry["amount"]
		
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_END
		
		var label := Label.new()
		label.text = str(amount) + "x " + data.item_name
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		
		var icon := TextureRect.new()
		icon.texture = data.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		
		container.add_child(row)
		
		row.modulate.a = 0.0
		row.scale = Vector2(0.7, 0.7)
		row.pivot_offset = Vector2(60, 16)
		row.position.x += 30
		
		rows.append(row)
		icons.append(icon)
		
		var delay := i * 0.15
		var appear := create_tween()
		appear.tween_interval(delay)
		appear.tween_property(row, "modulate:a", 1.0, 0.25)
		appear.parallel().tween_property(row, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		appear.parallel().tween_property(row, "position:x", row.position.x - 30, 0.3).set_trans(Tween.TRANS_SINE)
		
		await get_tree().create_timer(delay + 0.05).timeout

	await get_tree().create_timer(1.5).timeout

	var viewport_size := layer.get_viewport().get_visible_rect().size
	var target_pos := Vector2(viewport_size.x * 0.5, viewport_size.y - 90)

	for i in icons.size():
		var icon: TextureRect = icons[i]
		var row: HBoxContainer = rows[i]
		
		icon.reparent(layer)
		
		var start_pos := row.global_position + Vector2(row.size.x - 42, 4)
		icon.global_position = start_pos
		icon.modulate.a = 1.0
		icon.z_index = 100
		
		var text_fade := create_tween()
		text_fade.tween_property(row, "modulate:a", 0.0, 0.15)
		
		var fly := create_tween().set_parallel(true)
		var travel_time := 0.6 + i * 0.05
		
		fly.tween_property(icon, "global_position", target_pos, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fly.tween_property(icon, "scale", Vector2(0.3, 0.3), travel_time)
		fly.tween_property(icon, "modulate:a", 0.0, travel_time * 0.5).set_delay(travel_time * 0.5)
		
		await get_tree().create_timer(0.1).timeout

	await get_tree().create_timer(0.8).timeout
	layer.queue_free()

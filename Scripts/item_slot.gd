extends TextureButton

@onready var icon: TextureRect = $item_texture
@onready var quantity_label: Label = $Label
@onready var rarity_bg: Panel = $RarityBG

@export var show_rarity_color: bool = true

signal item_selected(item: ItemInstance)

var item_instance: ItemInstance

const RARITY_STYLES := {
	ItemData.Rarity.COMMON:    { "bg": Color(0.774, 0.735, 0.644, 1.0) },
	ItemData.Rarity.UNCOMMON:  { "bg": Color(0.514, 0.916, 0.566, 1.0) },
	ItemData.Rarity.RARE:      { "bg": Color(0.582, 0.833, 0.966, 1.0) },
	ItemData.Rarity.EPIC:      { "bg": Color(0.838, 0.743, 0.984, 1.0) },
	ItemData.Rarity.LEGENDARY: { "bg": Color(0.952, 0.896, 0.43, 1.0) },
}

func _ready():
	pressed.connect(_on_pressed)
	_apply_empty_style()

func _on_pressed():
	if item_instance != null:
		SfxManager.play_slot_click()
		item_selected.emit(item_instance)

func set_item(item: ItemInstance):
	item_instance = item
	icon.texture = item.data.icon

	if item.quantity > 1:
		quantity_label.visible = true
		quantity_label.text = "x" + str(item.quantity)
	else:
		quantity_label.visible = false
		quantity_label.text = ""

	if show_rarity_color:
		_apply_rarity_style(item.data.rarity)
	else:
		_apply_plain_style()

func clear_slot():
	item_instance = null
	icon.texture = null
	quantity_label.visible = false
	quantity_label.text = ""
	_apply_empty_style()

func _apply_rarity_style(rarity: int) -> void:
	if not show_rarity_color:
		_apply_plain_style()
		return
	var style: Dictionary = RARITY_STYLES.get(rarity, RARITY_STYLES[ItemData.Rarity.COMMON])
	var sb := StyleBoxFlat.new()
	sb.bg_color = style.bg
	sb.set_corner_radius_all(6)
	rarity_bg.add_theme_stylebox_override("panel", sb)

func _apply_empty_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.89, 0.77, 0.25)
	sb.set_corner_radius_all(6)
	rarity_bg.add_theme_stylebox_override("panel", sb)

func _apply_plain_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(6)
	rarity_bg.add_theme_stylebox_override("panel", sb)

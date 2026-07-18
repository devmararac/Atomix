extends CanvasLayer

@onready var party_grid = $Party/TextureRect/PartySlot
@onready var preview: AnimatedSprite2D = $Details/Sprite/AtomonAnimatedSprite
@onready var atomon_panel = $Details/Sprite
@onready var atomon_name = $Details/AtomonDetails/AtomonName
@onready var atomon_nickname = $Details/Sprite/AtomonNickname
@onready var atomon_symbol = $Details/Sprite/Symbol
@onready var atomon_description = $Details/Description
@onready var atomon_details = $Details/AtomonDetails


var slots := []

func _ready() -> void:
	atomon_details.visible = false
	atomon_nickname.visible = false
	atomon_panel.visible = false
	atomon_description.visible = false
	atomon_symbol.visible = false
	atomon_name.visible = false
	for child in party_grid.get_children():
		slots.append(child)
		child.slot_clicked.connect(_on_slot_clicked)

	refresh_party()


func refresh_party():
	var party = PartyManager.get_party()

	for i in range(slots.size()):
		if i < party.size():
			slots[i].set_atomon(party[i])
		else:
			slots[i].clear_slot()


func _on_slot_clicked(atomon: AtomonInstance):
	var data = atomon.data
	if atomon == null:
		return
	
	atomon_details.visible = true
	atomon_nickname.visible = true
	atomon_panel.visible = true
	atomon_name.visible = true
	atomon_nickname.text = atomon.data.alias
	atomon_name.text = atomon.data.atom_name
	
	if atomon.data.symbol: 
		atomon_symbol.visible = true
		atomon_symbol.texture = atomon.data.symbol
	else:
		atomon_symbol.visible = false
	
	atomon_description.visible = true
	atomon_description.text = atomon.data.description
	
	
	preview.sprite_frames = atomon.data.sprite_frames
	preview.play("idle")

func close():
	queue_free()


func _on_button_pressed() -> void:
	queue_free()

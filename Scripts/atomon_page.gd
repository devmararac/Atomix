extends Control

@onready var party_grid = $"Left Panel/ScrollContainer/SlotContainer"
@onready var book_anim: AnimatedSprite2D = $"Right Panel/Book BG"
@onready var preview: AnimatedSprite2D = $"Right Panel/Atomon Sprite/AnimatedSprite2D"
@onready var animation_timer: Timer = $"Right Panel/Atomon Sprite/Timer"
@onready var atomon_allias: Label = $"Right Panel/AtomonAllias"
@onready var atomon_panel: Panel = $"Right Panel/Atomon Sprite"
@onready var atomon_description: RichTextLabel = $"Right Panel/AtomonDescription"
@onready var atomon_symbol: TextureRect = $"Right Panel/AtomicSymbol"
@onready var atomon_name: Label = $"Right Panel/AtomonName"

var slots := []
var book_opened := false

func _ready() -> void:
	atomon_allias.visible = false
	atomon_panel.visible = false
	atomon_description.visible = false
	atomon_symbol.visible = false
	atomon_name.visible = false
	
	#Preview Animations
	#==================
	randomize()
	animation_timer.timeout.connect(_on_animation_timer_timeout)
	#==================
	
	book_anim.frame = 0
	
	# Connect slots
	#=================
	for child in party_grid.get_children():
		slots.append(child)
		child.slot_clicked.connect(_on_slot_clicked)
	#=================
	refresh_party()

func refresh_party():
	var party = PartyManager.get_party()

	for i in range(slots.size()):
		if i < party.size():
			slots[i].set_atomon(party[i])
		else:
			slots[i].clear_slot()


func _on_slot_clicked(atomon: AtomonInstance):
	if atomon == null:
		return
	if !book_opened:
		book_opened = true

		book_anim.play("idle")
		await book_anim.animation_finished

		atomon_allias.visible = true
		atomon_panel.visible = true
		atomon_description.visible = true
		atomon_symbol.visible = true
		atomon_name.visible = true
	
	animation_timer.stop()
	
	var data = atomon.data

	preview.sprite_frames = data.sprite_frames
	preview.scale = Vector2(5, 5)
	play_random_animation()

	await get_tree().process_frame

	# Center inside the panel
	preview.position = $"Right Panel/Atomon Sprite".size / 2
	
	atomon_allias.text = data.alias
	atomon_description.text = data.description
	atomon_symbol.texture = data.symbol
	atomon_name.text = data.atom_name
	
func play_random_animation():
	if preview.sprite_frames == null:
		return

	var animations: Array[String] = ["idle"]

	if preview.sprite_frames.has_animation("walk"):
		animations.append("walk")

	preview.play(animations.pick_random())

	animation_timer.wait_time = randf_range(2.0, 3.0)
	animation_timer.start()

func _on_animation_timer_timeout():
	play_random_animation()

func close():
	queue_free()


func _on_button_pressed():
	SfxManager.play_click()
	queue_free()

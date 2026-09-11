extends CanvasLayer




signal atomon_selected(index:int)
signal closed

var selected_index := -1
var selected_atomon = null

var current_battle_atomon: AtomonInstance

var waiting_for_switch := false
var force_switch := false

@onready var book_area: Control = $NinePatchRect/BG/Details/Control
@onready var book: Sprite2D = $NinePatchRect/BG/Details/Control/Book
@onready var book_animation: AnimationPlayer = $NinePatchRect/BG/Details/BookAnimation

var book_opened := false

const BOOK_FRAME_SIZE := Vector2(592.0, 522.0)

@onready var details_container = $NinePatchRect/BG/Details/Container
@onready var confirm_dialog = $NinePatchRect/BG/Details/Container/ConfirmationDialog
@onready var sprite = $NinePatchRect/BG/Details/Container/bg/TextureRect

@onready var name_type = $NinePatchRect/BG/Details/NameType
@onready var name_label = $NinePatchRect/BG/Details/NameType/Name
@onready var type_label = $NinePatchRect/BG/Details/NameType/Type

@onready var stats = $NinePatchRect/BG/Details/Stats
@onready var hp = $NinePatchRect/BG/Details/Stats/HP
@onready var atk = $NinePatchRect/BG/Details/Stats/Attack
@onready var defense = $NinePatchRect/BG/Details/Stats/Defense

@onready var sp_atk = $NinePatchRect/BG/Details/Stats/SpAttack
@onready var sp_def = $NinePatchRect/BG/Details/Stats/SpDefense
@onready var speed = $NinePatchRect/BG/Details/Stats/Speed

@onready var move1 = $NinePatchRect/BG/Details/Container/VBoxContainer/GridContainer/Label
@onready var pp1 = $NinePatchRect/BG/Details/Container/VBoxContainer/GridContainer/Label3

@onready var move2 = $NinePatchRect/BG/Details/Container/VBoxContainer/GridContainer/Label2
@onready var pp2 = $NinePatchRect/BG/Details/Container/VBoxContainer/GridContainer/Label4

@onready var move3 = $NinePatchRect/BG/Details/Container/VBoxContainer2/GridContainer/Label3
@onready var pp3 = $NinePatchRect/BG/Details/Container/VBoxContainer2/GridContainer/Label5

@onready var move4 = $NinePatchRect/BG/Details/Container/VBoxContainer2/GridContainer/Label4
@onready var pp4 = $NinePatchRect/BG/Details/Container/VBoxContainer2/GridContainer/Label6

@onready var switch_button = $NinePatchRect/BG/Details/Container/Switch
@onready var cancel_button = $NinePatchRect/BG/Details/Container/Cancel

@onready var slots = [
	$"NinePatchRect/BG/Slots Panel/ScrollContainer/GridContainer/slot_1",
	$"NinePatchRect/BG/Slots Panel/ScrollContainer/GridContainer/slot_2",
	$"NinePatchRect/BG/Slots Panel/ScrollContainer/GridContainer/slot_3",
	$"NinePatchRect/BG/Slots Panel/ScrollContainer/GridContainer/slot_4",
	$"NinePatchRect/BG/Slots Panel/ScrollContainer/GridContainer/slot_5",
]



	
func _ready():

	name_type.visible = false
	stats.visible = false
	details_container.hide()

	book_area.resized.connect(update_book_transform)
	update_book_transform()

	if not BattleControllerGlobal.hp_changed.is_connected(_on_hp_changed):
		BattleControllerGlobal.hp_changed.connect(_on_hp_changed)

	if not BattleControllerGlobal.stats_changed.is_connected(_on_stats_changed):
		BattleControllerGlobal.stats_changed.connect(_on_stats_changed)

	var party = PartyManager.get_party()

	for i in range(slots.size()):
		if i < party.size():
			slots[i].show()
			slots[i].set_atomon(party[i])

			slots[i].slot_clicked.connect(
				func(_instance):
					_on_slot_clicked(i)
			)
		else:
			slots[i].hide()
			slots[i].clear_slot()

func _on_hp_changed():
	if selected_atomon == null:
		return
		
	update_details(selected_atomon)
	# Also refresh the party slots
	refresh_slots()

func refresh_slots() -> void:
	var party = PartyManager.get_party()

	for i in range(slots.size()):
		if i < party.size():
			slots[i].show()
			slots[i].set_atomon(party[i])
		else:
			slots[i].hide()
			slots[i].clear_slot()

func _on_stats_changed() -> void:
	if selected_atomon == null:
		return
	update_details(selected_atomon)
	

func _on_slot_clicked(index: int):

	selected_atomon = PartyManager.get_party()[index]
	
	if selected_atomon.current_hp <= 0:
		waiting_for_switch = false
		confirm_dialog.dialog_text = "%s has fainted!" % selected_atomon.data.atom_name
		confirm_dialog.popup_centered()
		return

	selected_index = index

	# First click: open the book first
	if not book_opened:

		book_opened = true

		# Start from the closed book
		book.frame = 0

		# Play opening animation
		book_animation.play("open")

		# Wait until the book reaches frame 3
		await book_animation.animation_finished

	# Only show details after the book has opened
	details_container.show()
	name_type.show()
	stats.show()

	update_details(selected_atomon)
	
func update_details(instance: AtomonInstance) -> void:

	var data = instance.data

	# Make sure PP is initialized
	if instance.current_pp.size() != data.moves.size():
		instance.current_pp.clear()
		for move in data.moves:
			instance.current_pp.append(move.max_uses)

	# Sprite
	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
		sprite.play("idle")

	# Basic Info
	name_label.text = "Element: " + data.atom_name
	type_label.text = data.element_type

	var max_hp = StatCalculator.get_hp(data)
	hp.text = "%d / %d" % [instance.current_hp, max_hp]

	# Battle stats (shows buffs/debuffs if this is the active Atomon)
	atk.text = str(BattleControllerGlobal.get_display_attack(instance))
	defense.text = str(BattleControllerGlobal.get_display_defense(instance))
	sp_atk.text = str(BattleControllerGlobal.get_display_special_attack(instance))
	sp_def.text = str(BattleControllerGlobal.get_display_special_defense(instance))
	speed.text = str(BattleControllerGlobal.get_display_speed(instance))

	# Clear move labels
	move1.text = "-----"
	move2.text = "-----"
	move3.text = "-----"
	move4.text = "-----"

	pp1.text = "--"
	pp2.text = "--"
	pp3.text = "--"
	pp4.text = "--"

	# Move 1
	if data.moves.size() > 0:
		move1.text = data.moves[0].move_name
		pp1.text = "%d/%d" % [
			instance.current_pp[0],
			data.moves[0].max_uses
		]

	# Move 2
	if data.moves.size() > 1:
		move2.text = data.moves[1].move_name
		pp2.text = "%d/%d" % [
			instance.current_pp[1],
			data.moves[1].max_uses
		]

	# Move 3
	if data.moves.size() > 2:
		move3.text = data.moves[2].move_name
		pp3.text = "%d/%d" % [
			instance.current_pp[2],
			data.moves[2].max_uses
		]

	# Move 4
	if data.moves.size() > 3:
		move4.text = data.moves[3].move_name
		pp4.text = "%d/%d" % [
			instance.current_pp[3],
			data.moves[3].max_uses
		]

func update_book_transform() -> void:

	var container_size := book_area.size

	if container_size.x <= 0.0 or container_size.y <= 0.0:
		return

	# Center the book inside the Control
	book.position = container_size / 2.0

	# Stretch independently to exactly match the Control
	book.scale = Vector2(
		container_size.x / BOOK_FRAME_SIZE.x,
		container_size.y / BOOK_FRAME_SIZE.y
	)

func _on_switch_pressed():

	if selected_index == -1:
		return
	
	if selected_atomon == current_battle_atomon:
		confirm_dialog.dialog_text = "%s is already in battle!" % selected_atomon.data.atom_name
		confirm_dialog.popup_centered()
		return
	
	waiting_for_switch = true
	confirm_dialog.dialog_text = "Switch to %s?" % selected_atomon.data.atom_name
	confirm_dialog.popup_centered()


func _on_confirmation_dialog_confirmed():

	if !waiting_for_switch:
		return

	waiting_for_switch = false

	atomon_selected.emit(selected_index)
	queue_free()


func _on_cancel_pressed():

	if force_switch:
		return

	selected_index = -1
	selected_atomon = null
	details_container.hide()


func _on_close_button_pressed():

	if force_switch:
		return

	closed.emit()
	queue_free()

extends StaticBody2D

const CRAFTING_TABLE_MENU = preload("res://Scenes/UI/CraftingTableMenu.tscn")
const CRAFTING_UI = preload("res://Scenes/UI/crafting_ui.tscn")

var current_menu: CanvasLayer = null
var current_crafting_ui: CanvasLayer = null


func _ready() -> void:
	$Highlight.visible = false


func interact() -> void:
	# Don't open another menu if one is already open
	if current_menu != null:
		return

	print("CRAFTING TABLE INTERACTED")

	# Stop player movement
	if global.player:
		global.player.can_move = false

	# Create the Heal / Craft menu
	current_menu = CRAFTING_TABLE_MENU.instantiate()
	get_tree().current_scene.add_child(current_menu)

	# Connect menu buttons
	current_menu.heal_selected.connect(_on_heal_selected)
	current_menu.craft_selected.connect(_on_craft_selected)
	current_menu.menu_closed.connect(_on_menu_closed)


func _on_heal_selected() -> void:
	print("HEAL PARTY")

	heal_party()
	close_menu()


func _on_craft_selected() -> void:
	print("OPENING CRAFTING UI")

	close_menu()

	# Open your existing periodic-table crafting UI
	current_crafting_ui = CRAFTING_UI.instantiate()
	get_tree().current_scene.add_child(current_crafting_ui)

	# Player stays disabled while crafting UI is open


func _on_menu_closed() -> void:
	close_menu()


func heal_party() -> void:
	var party = PartyManager.get_party()

	for atomon in party:
		if atomon != null:
			atomon.current_hp = StatCalculator.get_hp(atomon.data)

	print("PARTY FULLY HEALED")


func close_menu() -> void:
	if current_menu != null:
		current_menu.queue_free()
		current_menu = null

	if global.player:
		global.player.can_move = true

extends CanvasLayer

var atomon_menu_scene = preload("res://Scenes/UI/atomons_menu.tscn")
var item_menu_scene = preload("res://Scenes/UI/inventory_ui.tscn")
var atomon_menu_instance: CanvasLayer
var item_menu_instance: CanvasLayer
var game_menu_instance: CanvasLayer
const GAME_MENU = preload("res://Scenes/UI/game_menu.tscn")

@onready var quest_log_panel: Control = $QuestLogPanel

func _ready() -> void:
	quest_log_panel.hide()
	
	Dialogic.timeline_started.connect(_on_dialogue_started)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)

func _on_dialogue_started() -> void:
	visible = false

func _on_dialogue_ended() -> void:
	visible = true

func show_hide_log() -> void:
	SfxManager.play_click()
	quest_log_panel.show_hide_log()

func _on_close_button_pressed() -> void:
	SfxManager.play_click()
	quest_log_panel.hide()

func _on_save_pressed() -> void:
	SfxManager.play_click()
	SaveManager.save_game()

func _on_load_pressed() -> void:
	SfxManager.play_click()
	SaveManager.load_game()
	PartyManager.load_saved_party()
	var tracker = get_tree().get_first_node_in_group("QuestTracker")

	if tracker:
		tracker.refresh_from_quest_manager()
	

func _on_menu_pressed() -> void:

	# Do not open the Game Menu while another UI is active
	if get_tree().get_first_node_in_group("CraftingUI") != null:
		print("[HUD] Game Menu blocked because Crafting UI is open.")
		return

	var menu = GAME_MENU.instantiate()
	menu.hud = self
	get_tree().current_scene.add_child(menu)

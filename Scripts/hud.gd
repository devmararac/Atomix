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

func _on_menu_pressed() -> void:
	var menu = GAME_MENU.instantiate()
	menu.hud = self
	get_tree().current_scene.add_child(menu)

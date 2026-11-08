extends CanvasLayer

var atomon_menu_scene = preload("res://Scenes/UI/atomons_menu.tscn")
var item_menu_scene = preload("res://Scenes/UI/inventory_ui.tscn")
var atomon_menu_instance: CanvasLayer
var item_menu_instance: CanvasLayer
var game_menu_instance: CanvasLayer
const GAME_MENU = preload("res://Scenes/UI/game_menu.tscn")

@onready var skip_button: Button = $SkipLayer/SkipButton

func _ready() -> void:
	skip_button.hide()
	
	Dialogic.timeline_started.connect(_on_dialogue_started)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)

# ==========================================
# SKIP BUTTON LOGIC
# ==========================================

func _on_skip_pressed() -> void:
	if SfxManager: SfxManager.play_click()
	Dialogic.Inputs.auto_skip.enabled = true
	skip_button.disabled = true
	skip_button.text = "SKIPPING..."

func _on_dialogue_started() -> void:
	visible = false
	skip_button.show()
	skip_button.disabled = false
	skip_button.text = "SKIP >>"
	Dialogic.Inputs.auto_skip.enabled = false

func _on_dialogue_ended() -> void:
	visible = true
	skip_button.hide()
	Dialogic.Inputs.auto_skip.enabled = false

# ==========================================
# EXISTING FUNCTIONS
# ==========================================

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
	if get_tree().get_first_node_in_group("CraftingUI") != null:
		print("[HUD] Game Menu blocked because Crafting UI is open.")
		return

	var menu = GAME_MENU.instantiate()
	menu.hud = self
	get_tree().current_scene.add_child(menu)

func _on_restart_pressed() -> void:
	SfxManager.play_click()
	print("[hud] reset pressed.")
	print("[hud] Resetting game/story progress...")

	var reset_success := await SaveManager.start_new_game()

	if not reset_success:
		print("[hud] ERROR: Could not start a new game.")
		return

	print("[hud] New game reset completed.")
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://Scenes/UI/CharacterSetup.tscn")

extends CanvasLayer


# ============================================================
# HUD
# ============================================================

@export var hud: CanvasLayer


# ============================================================
# PAGES
# ============================================================

const INVENTORY_PAGE = preload(
	"res://Scenes/UI/inventory_page_new.tscn"
)

const QUESTLOG_PAGE = preload(
	"res://Scenes/UI/quest_log_panel.tscn"
)

const ATOMON_PAGE = preload(
	"res://Scenes/UI/atomon_page.tscn"
)

const LESSONS_PAGE = preload(
	"res://Scenes/UI/lesson_page.tscn"
	
)

const QUIZZ_PAGE = preload(
	"res://Scenes/UI/quiz_page.tscn"
	
	
)

const SETTING_PAGE = preload(
	"res://Scenes/UI/setting_page.tscn"
)


# ============================================================
# CONTENT PANEL
# ============================================================

@onready var information_panel = (
	$Root/MainMargin/HBoxContainer/
	ContentPanel/InformationPanel
)


# ============================================================
# MENU BUTTONS
# ============================================================

@onready var inventory_button = (
	$Root/MainMargin/HBoxContainer/
	NavigationPanel/NavigationMargin/
	MenuVBox/InventoryButton
)

@onready var questlog_button = ($Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/QuestLogButton)

@onready var atomon_button = ($Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/AtomonButton)

@onready var player_button = ($Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/PlayerButton)

@onready var lessons_button = ($Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/LessonsButton)

@onready var quiz_button = ($Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/QuizButton)

@onready var settings_button = ($Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/SettingsButton)

@onready var close_button = ($Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/CloseButton)


# ============================================================
# CURRENT PAGE
# ============================================================

var current_page: Control


# ============================================================
# READY
# ============================================================

func _ready():

	print("[GameMenu] Game menu opened.")

	if hud:
		hud.hide()
	
	if global.player:
		global.player.can_move = false

	inventory_button.pressed.connect(
		_on_inventory_pressed
	)

	# Open Inventory by default.
	_on_inventory_pressed()


# ============================================================
# CHANGE PAGE
# ============================================================

func change_page(scene: PackedScene):

	if current_page:

		current_page.queue_free()


	current_page = scene.instantiate()

	information_panel.add_child(
		current_page
	)


# ============================================================
# INVENTORY
# ============================================================

func _on_inventory_pressed():

	print("[GameMenu] Inventory selected.")

	change_page(
		INVENTORY_PAGE
	)


# ============================================================
# QUEST LOG
# ============================================================

func _on_quest_log_button_pressed() -> void:

	print("[GameMenu] Quest Log selected.")

	change_page(
		QUESTLOG_PAGE
	)


# ============================================================
# ATOMON
# ============================================================

func _on_atomon_button_pressed() -> void:

	print("[GameMenu] Atomon selected.")

	change_page(
		ATOMON_PAGE
	)


# ============================================================
# PLAYER
# ============================================================

func _on_player_button_pressed() -> void:

	print("[GameMenu] Player selected.")

	# Player page is not implemented yet.


# ============================================================
# LESSONS
# ============================================================

func _on_lessons_button_pressed() -> void:

	print("[GameMenu] Lessons selected.")

	change_page(
		LESSONS_PAGE
	)

# ============================================================
# QUIZZ
# ============================================================
func _on_quiz_button_pressed() -> void:
	print("[GameMenu] Lessons selected.")
	change_page(QUIZZ_PAGE)

# ============================================================
# SETTINGS
# ============================================================

func _on_settings_button_pressed() -> void:
	change_page(
		SETTING_PAGE
	)

# ============================================================
# CLOSE
# ============================================================
func _on_close_button_pressed() -> void:
	print("[GameMenu] Closing menu.")

	if hud:
		hud.show()
	
	if global.player:
		global.player.can_move = true
		
	queue_free()

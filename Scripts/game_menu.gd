extends CanvasLayer

@export var hud: CanvasLayer
const INVENTORY_PAGE = preload("res://Scenes/UI/inventory_page_new.tscn")
const QUESTLOG_PAGE = preload("res://Scenes/UI/quest_log_panel.tscn")
const ATOMON_PAGE = preload("res://Scenes/UI/atomon_page.tscn")

@onready var information_panel = $Root/MainMargin/HBoxContainer/ContentPanel/InformationPanel

@onready var inventory_button = $Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/InventoryButton
@onready var questlog_button = $Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/QuestLogButton
@onready var atomon_button = $Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/AtomonButton
@onready var player_button = $Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/PlayerButton
@onready var settings_button = $Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/SettingsButton
@onready var close_button = $Root/MainMargin/HBoxContainer/NavigationPanel/NavigationMargin/MenuVBox/CloseButton

var current_page: Control

func _ready():
	if hud:
		hud.hide()
	inventory_button.pressed.connect(_on_inventory_pressed)
	questlog_button.pressed.connect(_on_questlog_pressed)
	atomon_button.pressed.connect(_on_atomon_pressed)
	player_button.pressed.connect(_on_player_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	close_button.pressed.connect(close)

	_on_inventory_pressed()

func change_page(scene: PackedScene):
	if current_page:
		current_page.queue_free()

	current_page = scene.instantiate()
	information_panel.add_child(current_page)


func _on_inventory_pressed():
	change_page(INVENTORY_PAGE)


func _on_questlog_pressed():
	change_page(QUESTLOG_PAGE)


func _on_atomon_pressed():
	change_page(ATOMON_PAGE)


func _on_player_pressed():
	pass


func _on_settings_pressed():
	pass

func close():
	hud.show()
	queue_free()

extends CanvasLayer

signal heal_selected
signal craft_selected
signal menu_closed


@onready var heal_button: TextureButton = $NinePatchRect/Heal
@onready var craft_button: TextureButton = $NinePatchRect/Craft
@onready var close_button: TextureButton = $NinePatchRect/Close


func _ready() -> void:
	heal_button.pressed.connect(_on_heal_pressed)
	craft_button.pressed.connect(_on_craft_pressed)
	close_button.pressed.connect(_on_close_pressed)


func _on_heal_pressed() -> void:
	heal_selected.emit()


func _on_craft_pressed() -> void:
	craft_selected.emit()


func _on_close_pressed() -> void:
	menu_closed.emit()

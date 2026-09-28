extends CanvasLayer


@onready var electron_rush_button: Button = $VBoxContainer2/VBoxContainer/Button
@onready var octet_builder_button: Button = $VBoxContainer2/VBoxContainer/Button2
@onready var bond_builder_button: Button = $VBoxContainer2/VBoxContainer/Button3


func _ready() -> void:
	electron_rush_button.pressed.connect(_on_electron_rush_pressed)
	octet_builder_button.pressed.connect(_on_octet_builder_pressed)
	bond_builder_button.pressed.connect(_on_bond_builder_pressed)


func _on_electron_rush_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Minigames/ElectronRush.tscn")


func _on_octet_builder_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Minigames/OctetBuilder.tscn")


func _on_bond_builder_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Minigames/BondBuilder.tscn")


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

extends Control

var atomon_menu_scene = preload("res://Scenes/UI/atomons_menu.tscn")
var item_menu_scene = preload("res://Scenes/UI/inventory_ui.tscn")
var atomon_menu_instance: CanvasLayer
var item_menu_instance: CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_atomons_pressed() -> void:
	if is_instance_valid(atomon_menu_instance):
		return

	atomon_menu_instance = atomon_menu_scene.instantiate()
	add_child(atomon_menu_instance)


func _on_save_pressed() -> void:
	SaveManager.save_game()


func _on_load_pressed() -> void:
	SaveManager.load_game()


func _on_item_pressed() -> void:
	if is_instance_valid(item_menu_instance):
		return

	item_menu_instance = item_menu_scene.instantiate()
	add_child(item_menu_instance)

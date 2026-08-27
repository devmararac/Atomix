extends Control

@onready var logout_button: TextureButton = $TextureRect/Logout

func _on_logout_pressed() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file(
		"res://Scenes/UI/MainMenu.tscn"
		
		
	)

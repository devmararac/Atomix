extends Control


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


# ============================================================
# LOG OUT
# ============================================================

func _on_logout_button_pressed() -> void:
	AuthManager.logout()

	await get_tree().create_timer(0.2).timeout

	get_tree().change_scene_to_file(
		"res://Scenes/UI/MainMenu.tscn"
	)

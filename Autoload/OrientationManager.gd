extends Node


func set_portrait() -> void:
	DisplayServer.screen_set_orientation(
		DisplayServer.SCREEN_PORTRAIT
	)


func set_landscape() -> void:
	DisplayServer.screen_set_orientation(
		DisplayServer.SCREEN_LANDSCAPE
	)

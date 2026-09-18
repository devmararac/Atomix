extends Node

var display_name: String = ""
var selected_character: CharacterData


func set_player_data(data: Dictionary) -> void:
	display_name = data.get("display_name", "")


func set_character(character: CharacterData) -> void:
	selected_character = character


func get_player_data() -> Dictionary:
	return {
		"display_name": display_name,
		"character_id": selected_character.character_id if selected_character else ""
	}

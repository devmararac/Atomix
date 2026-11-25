extends Node

var display_name: String = ""
var selected_character: CharacterData


func set_player_data(data: Dictionary) -> void:
	display_name = data.get("display_name", "")

	var character_id: String = data.get("character_id", "")

	if not character_id.is_empty():
		set_character_by_id(character_id)
	else:
		print("[PlayerManager] No character_id found in loaded player profile.")


func set_character(character: CharacterData) -> void:
	selected_character = character


func set_character_by_id(character_id: String) -> void:
	var characters: Array[CharacterData] = [
		preload("res://Resources/Characters/Default.tres"),
		preload("res://Resources/Characters/Alfred.tres"),
		preload("res://Resources/Characters/Deejhay.tres"),
		preload("res://Resources/Characters/Dianne.tres")
	]

	for character in characters:
		if character.character_id == character_id:
			selected_character = character
			print("[PlayerManager] Character restored: ", character.character_name)
			return

	push_warning("[PlayerManager] Character ID not found: " + character_id)


func get_player_data() -> Dictionary:
	return {
		"display_name": display_name,
		"character_id": selected_character.character_id if selected_character else ""
	}

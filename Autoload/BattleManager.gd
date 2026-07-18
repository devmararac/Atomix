extends Node

const ATOMON_SCENE = preload("res://Atomons/Atomon.tscn")

# Current battle data
var player_instance: AtomonInstance
var enemy_data: AtomonData

# Optional (we'll use these later)
var battle_result := ""
var previous_scene := ""
var previous_position := Vector2.ZERO


func start_battle(enemy: AtomonData) -> void:
	# Get the player's currently active Atomon
	player_instance = PartyManager.get_active_atomon()

	# Store the enemy
	enemy_data = enemy

	# Save where we came from
	previous_scene = get_tree().current_scene.scene_file_path
	previous_position = global.player.global_position

	# Go to battle
	get_tree().change_scene_to_file("res://Battle/BattleUI.tscn")


func end_battle() -> void:
	global.return_position = previous_position

	player_instance = null
	enemy_data = null

	get_tree().change_scene_to_file(previous_scene)

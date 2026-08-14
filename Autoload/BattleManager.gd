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

	var battle_party: Array[AtomonInstance] = PartyManager.get_battle_party()

	if battle_party.is_empty():
		push_error("No Atomons available for battle.")
		return

	# The first Atomon in the current party order is sent into battle
	player_instance = PartyManager.get_battle_party()[0]
	PartyManager.active_index = 0

	print(
		"BATTLE STARTING WITH: ",
		player_instance.data.atom_name
	)

	if player_instance == null:
		push_warning("Cannot start battle: player has no Atomon.")
		return

	if enemy == null:
		push_warning("Cannot start battle: enemy data is missing.")
		return

	enemy_data = enemy

	previous_scene = get_tree().current_scene.scene_file_path
	previous_position = global.player.global_position

	get_tree().change_scene_to_file(
		"res://Battle/BattleUI.tscn"
	)
	

func end_battle() -> void:

	global.return_position = previous_position
	get_tree().change_scene_to_file(previous_scene)

extends Node

const ATOMON_SCENE = preload("res://Atomons/Atomon.tscn")

# Current battle data
var player_instance: AtomonInstance
var enemy_data: AtomonData

# Optional (we'll use these later)
var battle_result := ""
var previous_scene := ""
var previous_position := Vector2.ZERO


func start_battle(
	enemy: AtomonData,
	scene_path: String,
	player_position: Vector2
) -> void:

	var battle_party: Array[AtomonInstance] = PartyManager.get_battle_party()

	if battle_party.is_empty():
		push_error("No Atomons available for battle.")
		return

	# Find the first Atomon that is not fainted
	player_instance = null

	for i in range(battle_party.size()):
		var atmon: AtomonInstance = battle_party[i]

		if atmon != null and atmon.current_hp > 0:
			player_instance = atmon
			PartyManager.active_index = i
			break

	if player_instance == null:
		push_error("No healthy Atomons available for battle.")
		return

	print(
		"BATTLE STARTING WITH: ",
		player_instance.data.atom_name
	)

	if enemy == null:
		push_warning("Cannot start battle: enemy data is missing.")
		return

	enemy_data = enemy

	# Save the scene and position BEFORE changing scenes
	previous_scene = scene_path
	previous_position = player_position

	print("RETURN SCENE: ", previous_scene)
	print("RETURN POSITION: ", previous_position)

	get_tree().change_scene_to_file(
        "res://Battle/BattleUI.tscn"
	)
	

func end_battle() -> void:

	global.return_position = previous_position
	get_tree().change_scene_to_file(previous_scene)

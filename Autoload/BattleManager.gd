
extends Node

const ATOMON_SCENE = preload("res://Atomons/Atomon.tscn")

# ============================================================
# CURRENT BATTLE DATA
# ============================================================

var player_instance: AtomonInstance
var enemy_data: AtomonData


# ============================================================
# FUSION TRAINING
# ============================================================

var is_fusion_training_battle: bool = false
var training_party: Array[AtomonInstance] = []


# ============================================================
# OPTIONAL BATTLE DATA
# ============================================================

var battle_result := ""
var previous_scene := ""
var previous_position := Vector2.ZERO


# ============================================================
# NORMAL BATTLE
# ============================================================

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

		push_warning(
			"Cannot start battle: enemy data is missing."
		)

		return

	enemy_data = enemy

	# Save the scene and position BEFORE changing scenes
	previous_scene = scene_path
	previous_position = player_position

	print(
		"RETURN SCENE: ",
		previous_scene
	)

	print(
		"RETURN POSITION: ",
		previous_position
	)

	get_tree().change_scene_to_file(
		"res://Battle/BattleUI.tscn"
	)


# ============================================================
# FUSION TRAINING BATTLE
# ============================================================

func start_fusion_training_battle() -> void:

	print("========================================")
	print("[BattleManager] STARTING FUSION TRAINING")
	print("========================================")

	var current_scene := get_tree().current_scene

	if current_scene == null:

		push_error(
			"[BattleManager] Cannot start Fusion training: "
			+ "current scene is null."
		)

		return

	# --------------------------------------------------------
	# Save return location
	# --------------------------------------------------------

	previous_scene = current_scene.scene_file_path

	if global.player != null:

		previous_position = global.player.global_position

	else:

		previous_position = Vector2.ZERO


	# --------------------------------------------------------
	# Enable training mode
	# --------------------------------------------------------

	is_fusion_training_battle = true


	# --------------------------------------------------------
	# Create temporary training Atomons
	#
	# These are NOT added to PartyManager.party.
	# They will NOT be saved as collected Atomons.
	# --------------------------------------------------------

	training_party.clear()

	var hydrogen_data: AtomonData = preload(
		"res://Resources/Atomons/Hydrogen.tres"
	)

	var oxygen_data: AtomonData = preload(
		"res://Resources/Atomons/Oxygen.tres"
	)


	# --------------------------------------------------------
	# Create TWO Hydrogen Atomons
	# --------------------------------------------------------

	for i in range(2):

		var hydrogen := AtomonInstance.new()

		hydrogen.initialize(hydrogen_data)

		training_party.append(hydrogen)


	# --------------------------------------------------------
	# Create ONE Oxygen Atomon
	# --------------------------------------------------------

	var oxygen := AtomonInstance.new()

	oxygen.initialize(oxygen_data)

	training_party.append(oxygen)


	# --------------------------------------------------------
	# Set first Hydrogen as the active Atomon
	# --------------------------------------------------------

	player_instance = training_party[0]


	# --------------------------------------------------------
	# Use Hydrogen as the training opponent
	# --------------------------------------------------------

	enemy_data = hydrogen_data


	# --------------------------------------------------------
	# Debug information
	# --------------------------------------------------------

	print(
		"[BattleManager] Training party created: ",
		training_party.size(),
		" Atomons"
	)

	for atomon in training_party:

		print(
			"[BattleManager] Training Atomon: ",
			atomon.data.atom_name,
			" (",
			atomon.data.chemical_symbol,
			")"
		)

	print(
		"[BattleManager] Return scene: ",
		previous_scene
	)

	print(
		"[BattleManager] Return position: ",
		previous_position
	)


	# --------------------------------------------------------
	# Open Battle UI
	# --------------------------------------------------------

	get_tree().change_scene_to_file(
		"res://Battle/BattleUI.tscn"
	)


# ============================================================
# END BATTLE
# ============================================================

func end_battle() -> void:

	global.return_position = previous_position


	# --------------------------------------------------------
	# Clear Fusion training data
	# --------------------------------------------------------

	is_fusion_training_battle = false

	training_party.clear()

	player_instance = null
	enemy_data = null


	# --------------------------------------------------------
	# Return to previous scene
	# --------------------------------------------------------

	get_tree().change_scene_to_file(
		previous_scene
	)

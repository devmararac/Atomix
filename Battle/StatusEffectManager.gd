extends Node
class_name StatusEffectManager


# =========================================================
# STATUS EFFECT DATA
# =========================================================

class ActiveEffect:
	var effect: MoveEffect
	var remaining_turns: int

	func _init(new_effect: MoveEffect):
		effect = new_effect
		remaining_turns = new_effect.duration


# =========================================================
# ACTIVE EFFECTS
# =========================================================

var player_effects: Array[ActiveEffect] = []
var enemy_effects: Array[ActiveEffect] = []


# =========================================================
# BASE STATS
# =========================================================

var player_base_stats := {
	"attack": 0,
	"defense": 0,
	"special_attack": 0,
	"special_defense": 0,
	"speed": 0
}

var enemy_base_stats := {
	"attack": 0,
	"defense": 0,
	"special_attack": 0,
	"special_defense": 0,
	"speed": 0
}


# =========================================================
# CURRENT STATS
# =========================================================

var player_stats := {}
var enemy_stats := {}


# =========================================================
# SETUP
# =========================================================

func setup_player_stats(
	attack: int,
	defense: int,
	special_attack: int,
	special_defense: int,
	speed: int
) -> void:

	player_base_stats = {
		"attack": attack,
		"defense": defense,
		"special_attack": special_attack,
		"special_defense": special_defense,
		"speed": speed
	}

	recalculate_player_stats()


func setup_enemy_stats(
	attack: int,
	defense: int,
	special_attack: int,
	special_defense: int,
	speed: int
) -> void:

	enemy_base_stats = {
		"attack": attack,
		"defense": defense,
		"special_attack": special_attack,
		"special_defense": special_defense,
		"speed": speed
	}

	recalculate_enemy_stats()


# =========================================================
# APPLY EFFECT
# =========================================================

func apply_effect_to_player(effect: MoveEffect) -> void:

	if effect == null:
		return

	if randf() * 100.0 > effect.chance:
		return

	var active_effect := ActiveEffect.new(effect)
	player_effects.append(active_effect)

	recalculate_player_stats()


func apply_effect_to_enemy(effect: MoveEffect) -> void:

	if effect == null:
		return

	if randf() * 100.0 > effect.chance:
		return

	var active_effect := ActiveEffect.new(effect)
	enemy_effects.append(active_effect)

	recalculate_enemy_stats()


# =========================================================
# RECALCULATE PLAYER STATS
# =========================================================

func recalculate_player_stats() -> void:

	player_stats = player_base_stats.duplicate()

	for active_effect in player_effects:

		var effect: MoveEffect = active_effect.effect

		match effect.effect_name:

			"Corrode":
				player_stats["defense"] -= effect.value

			"Oxidize":
				player_stats["attack"] -= effect.value

			"Catalyze":
				player_stats["speed"] += effect.value

			"Passivate":
				player_stats["defense"] += effect.value

			"Ionize":
				player_stats["special_attack"] += effect.value

			"Polarize":
				player_stats["special_defense"] -= effect.value

			"Excite":
				player_stats["special_attack"] += effect.value
				player_stats["speed"] += effect.value

			"Stabilize":
				player_stats["defense"] += effect.value
				player_stats["special_defense"] += effect.value

			"Inhibit":
				player_stats["speed"] -= effect.value

			"Neutralize":
				pass


# =========================================================
# RECALCULATE ENEMY STATS
# =========================================================

func recalculate_enemy_stats() -> void:

	enemy_stats = enemy_base_stats.duplicate()

	for active_effect in enemy_effects:

		var effect: MoveEffect = active_effect.effect

		match effect.effect_name:

			"Corrode":
				enemy_stats["defense"] -= effect.value

			"Oxidize":
				enemy_stats["attack"] -= effect.value

			"Catalyze":
				enemy_stats["speed"] += effect.value

			"Passivate":
				enemy_stats["defense"] += effect.value

			"Ionize":
				enemy_stats["special_attack"] += effect.value

			"Polarize":
				enemy_stats["special_defense"] -= effect.value

			"Excite":
				enemy_stats["special_attack"] += effect.value
				enemy_stats["speed"] += effect.value

			"Stabilize":
				enemy_stats["defense"] += effect.value
				enemy_stats["special_defense"] += effect.value

			"Inhibit":
				enemy_stats["speed"] -= effect.value

			"Neutralize":
				pass


# =========================================================
# TURN UPDATE
# =========================================================

func end_player_turn() -> void:

	update_effect_durations(player_effects)
	recalculate_player_stats()


func end_enemy_turn() -> void:

	update_effect_durations(enemy_effects)
	recalculate_enemy_stats()


func update_effect_durations(effect_list: Array[ActiveEffect]) -> void:

	for i in range(effect_list.size() - 1, -1, -1):

		var active_effect: ActiveEffect = effect_list[i]

		# Permanent effect
		if active_effect.remaining_turns <= 0:
			continue

		active_effect.remaining_turns -= 1

		if active_effect.remaining_turns <= 0:
			effect_list.remove_at(i)


# =========================================================
# NEUTRALIZE
# =========================================================

func neutralize_player() -> void:

	player_effects.clear()
	recalculate_player_stats()


func neutralize_enemy() -> void:

	enemy_effects.clear()
	recalculate_enemy_stats()


# =========================================================
# GET PLAYER STATS
# =========================================================

func get_player_attack() -> int:
	return player_stats.get("attack", 0)


func get_player_defense() -> int:
	return player_stats.get("defense", 0)


func get_player_special_attack() -> int:
	return player_stats.get("special_attack", 0)


func get_player_special_defense() -> int:
	return player_stats.get("special_defense", 0)


func get_player_speed() -> int:
	return player_stats.get("speed", 0)


# =========================================================
# GET ENEMY STATS
# =========================================================

func get_enemy_attack() -> int:
	return enemy_stats.get("attack", 0)


func get_enemy_defense() -> int:
	return enemy_stats.get("defense", 0)


func get_enemy_special_attack() -> int:
	return enemy_stats.get("special_attack", 0)


func get_enemy_special_defense() -> int:
	return enemy_stats.get("special_defense", 0)


func get_enemy_speed() -> int:
	return enemy_stats.get("speed", 0)

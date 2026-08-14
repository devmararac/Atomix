extends Node
class_name BattleController

# ============================================================
# BATTLE REFERENCES
# ============================================================
var player_instance: AtomonInstance
var enemy_data: AtomonData

var status_effect_manager: StatusEffectManager

# ============================================================
# BATTLE HP
# ============================================================
var player_hp: int = 0
var player_max_hp: int = 0

var enemy_hp: int = 0
var enemy_max_hp: int = 0

# ============================================================
# BATTLE STATS
# ============================================================
var player_attack_stat: int = 0
var player_defense_stat: int = 0
var player_special_attack_stat: int = 0
var player_special_defense_stat: int = 0
var player_speed_stat: int = 0

var enemy_attack_stat: int = 0
var enemy_defense_stat: int = 0
var enemy_special_attack_stat: int = 0
var enemy_special_defense_stat: int = 0
var enemy_speed_stat: int = 0

# ============================================================
# SIGNALS
# ============================================================
signal hp_changed
signal stats_changed

signal player_damaged(amount: int)
signal enemy_damaged(amount: int)

signal player_healed(amount: int)
signal enemy_healed(amount: int)

signal player_fainted
signal enemy_fainted

signal status_effect_applied(target: String, effect: MoveEffect)

signal move_started(move: MoveData, user_is_player: bool)
signal move_finished(move: MoveData, user_is_player: bool)


# ============================================================
# SETUP BATTLE
# ============================================================
func setup_battle(player: AtomonInstance, enemy: AtomonData) -> void:

	player_instance = player
	
	enemy_data = enemy
	
	if player_instance.current_pp.size() != player_instance.data.moves.size():
		player_instance.current_pp.clear()

		for move in player_instance.data.moves:
			player_instance.current_pp.append(move.max_uses)
	
	if player_instance == null:
		push_error("BattleController: Player Atomon is null.")
		return

	if enemy_data == null:
		push_error("BattleController: Enemy AtomonData is null.")
		return

	# ========================================================
	# PLAYER HP
	# ========================================================
	player_max_hp = StatCalculator.get_battle_hp(player_instance)
	player_hp = player_instance.current_hp

	# Restore HP only if the Atomon has never been initialized
	if player_hp <= 0:
		player_hp = player_max_hp
		player_instance.current_hp = player_hp

	# ========================================================
	# PLAYER STATS
	# ========================================================
# PLAYER STATS
	player_attack_stat = StatCalculator.get_battle_attack(player_instance)
	player_defense_stat = StatCalculator.get_battle_defense(player_instance)
	player_special_attack_stat = StatCalculator.get_battle_special_attack(player_instance)
	player_special_defense_stat = StatCalculator.get_battle_special_defense(player_instance)
	player_speed_stat = StatCalculator.get_battle_speed(player_instance)
	# ========================================================
	# ENEMY HP
	# ========================================================
	enemy_max_hp = StatCalculator.get_hp(enemy_data)
	enemy_hp = enemy_max_hp

	# ========================================================
	# ENEMY STATS
	# ========================================================
	enemy_attack_stat = StatCalculator.get_attack(enemy_data)
	enemy_defense_stat = StatCalculator.get_defense(enemy_data)
	enemy_special_attack_stat = StatCalculator.get_special_attack(enemy_data)
	enemy_special_defense_stat = StatCalculator.get_special_defense(enemy_data)
	enemy_speed_stat = StatCalculator.get_speed(enemy_data)

	# ========================================================
	# CREATE STATUS EFFECT MANAGER
	# ========================================================
	status_effect_manager = StatusEffectManager.new()

	status_effect_manager.setup_player_stats(
		player_attack_stat,
		player_defense_stat,
		player_special_attack_stat,
		player_special_defense_stat,
		player_speed_stat
	)
	status_effect_manager.setup_enemy_stats(
		enemy_attack_stat,
		enemy_defense_stat,
		enemy_special_attack_stat,
		enemy_special_defense_stat,
		enemy_speed_stat
	)

	hp_changed.emit()

# ============================================================
# PLAYER HP
# ============================================================
func get_player_hp() -> int:
	return player_hp

func get_player_max_hp() -> int:
	return player_max_hp

# ============================================================
# ENEMY HP
# ============================================================
func get_enemy_hp() -> int:
	return enemy_hp

func get_enemy_max_hp() -> int:
	return enemy_max_hp

# ============================================================
# PLAYER STATS
# ============================================================
func get_player_attack() -> int:
	if status_effect_manager:
		return status_effect_manager.get_player_attack()

	return player_attack_stat

func get_player_defense() -> int:
	if status_effect_manager:
		return status_effect_manager.get_player_defense()

	return player_defense_stat

func get_player_special_attack() -> int:
	if status_effect_manager:
		return status_effect_manager.get_player_special_attack()

	return player_special_attack_stat

func get_player_special_defense() -> int:
	if status_effect_manager:
		return status_effect_manager.get_player_special_defense()

	return player_special_defense_stat

func get_player_speed() -> int:
	if status_effect_manager:
		return status_effect_manager.get_player_speed()

	return player_speed_stat

# ============================================================
# ENEMY STATS
# ============================================================
func get_enemy_attack() -> int:
	if status_effect_manager:
		return status_effect_manager.get_enemy_attack()

	return enemy_attack_stat

func get_enemy_defense() -> int:
	if status_effect_manager:
		return status_effect_manager.get_enemy_defense()

	return enemy_defense_stat

func get_enemy_special_attack() -> int:
	if status_effect_manager:
		return status_effect_manager.get_enemy_special_attack()

	return enemy_special_attack_stat

func get_enemy_special_defense() -> int:
	if status_effect_manager:
		return status_effect_manager.get_enemy_special_defense()
		
	return enemy_special_defense_stat

func get_enemy_speed() -> int:
	if status_effect_manager:
		return status_effect_manager.get_enemy_speed()
		
	return enemy_speed_stat


# ============================================================
# DAMAGE CALCULATION
# ============================================================
func calculate_damage(action: DamageAction, attack: int, defense: int)  -> int:

	if action == null:
		return 0

	# New damage formula
	var damage: float = action.power * (1.0 + (attack - defense) / 200.0)

	# Random variation
	damage *= randf_range(0.90, 1.10)

	# Critical hit
	if randf() <= 0.10:
		damage *= 1.5

	# Prevent damage from becoming too low or too high
	damage = clamp(damage, 5.0, action.power * 2.0)
	return roundi(damage)

# ============================================================
# EXECUTE MOVE
# ============================================================
func execute_move(move: MoveData, user_is_player: bool) -> void:
	
	if move == null:
		return
		
	if user_is_player:
		consume_player_pp(move)
		gain_electron_energy(5)
		
	move_started.emit(move, user_is_player)
	for action in move.actions:
		if action == null:
			continue
			
		# ====================================================
		# DAMAGE ACTION
		# ====================================================
		if action is DamageAction:
			var damage_action := action as DamageAction
			var attack: int = 0
			var defense: int = 0
			if damage_action.damage_type == "Physical":
				if user_is_player:
					attack = get_player_attack()
					defense = get_enemy_defense()
				else:
					attack = get_enemy_attack()
					defense = get_player_defense()
					
			else:
				if user_is_player:
					attack = get_player_special_attack()
					defense = get_enemy_special_defense()
				else:
					attack = get_enemy_special_attack()
					defense = get_player_special_defense()
					
			var damage: int = calculate_damage(damage_action, attack,defense)
			if user_is_player:
				damage_enemy(damage)
			else:
				damage_player(damage)
			# Stop move actions if target faints
			if user_is_player and enemy_hp <= 0:
				break
			if not user_is_player and player_hp <= 0:
				break

		# ====================================================
		# HEAL ACTION
		# ====================================================
		elif action is HealAction:
			var heal_action := action as HealAction
			if user_is_player:
				heal_player(heal_action.heal_amount)
			else:
				heal_enemy(heal_action.heal_amount)

		# ====================================================
		# STATUS ACTION
		# ====================================================
		elif action is StatusAction:
			var status_action := action as StatusAction
			for effect in status_action.effects:
				if effect == null:
					continue
				if effect.self_target:
			# Self-buff
					if user_is_player:
						apply_effect_to_player(effect)
					else:
						apply_effect_to_enemy(effect)
				else:
			# Opponent debuff
					if user_is_player:
						apply_effect_to_enemy(effect)
					else:
						apply_effect_to_player(effect)
	move_finished.emit(move, user_is_player)
	
	# Consume Excited State after the player's attack
	if user_is_player and player_instance.active_excited_state > 0:
		player_instance.active_excited_state = 0
		player_instance.electron_energy = 0
		player_instance.excited_state = 0

		refresh_player_stats()
		stats_changed.emit()


func get_player_pp(move_index: int) -> int:
	if player_instance == null:
		return 0

	if move_index < 0 or move_index >= player_instance.current_pp.size():
		return 0

	return player_instance.current_pp[move_index]


func consume_player_pp(move: MoveData) -> void:
	if player_instance == null:
		return

	var index := player_instance.data.moves.find(move)

	if index == -1:
		return

	if player_instance.current_pp[index] > 0:
		player_instance.current_pp[index] -= 1

	stats_changed.emit()

# ============================================================
# DAMAGE PLAYER
# ============================================================
func damage_player(amount: int) -> void:
	if player_hp <= 0:
		return

	player_hp = max(0, player_hp - amount)

	# Keep the AtomonInstance synchronized
	if player_instance != null:
		player_instance.current_hp = player_hp

	player_damaged.emit(amount)
	hp_changed.emit()

	if player_hp <= 0:
		player_fainted.emit()

# ============================================================
# DAMAGE ENEMY
# ============================================================
func damage_enemy(amount: int) -> void:
	if enemy_hp <= 0:
		return

	enemy_hp = max(0, enemy_hp - amount)
	enemy_damaged.emit(amount)
	hp_changed.emit()

	if enemy_hp <= 0:
		enemy_hp = 0
		enemy_fainted.emit()


# ============================================================
# HEAL PLAYER
# ============================================================
func heal_player(amount: int) -> void:
	if player_hp <= 0:
		return

	var old_hp: int = player_hp
	player_hp = min(player_hp + amount, player_max_hp)

	# Keep the AtomonInstance synchronized
	if player_instance != null:
		player_instance.current_hp = player_hp

	var actual_heal: int = player_hp - old_hp

	if actual_heal > 0:
		player_healed.emit(actual_heal)
		hp_changed.emit()

# ============================================================
# HEAL ENEMY
# ============================================================
func heal_enemy(amount: int) -> void:
	if enemy_hp <= 0:
		return

	var old_hp: int = enemy_hp
	enemy_hp = min(enemy_hp + amount, enemy_max_hp)
	
	var actual_heal: int = enemy_hp - old_hp
	if actual_heal > 0:
		enemy_healed.emit(actual_heal)
		hp_changed.emit()


# ============================================================
# GAIN ELECTRON ENERGY
# ============================================================
func gain_electron_energy(amount: int) -> void:

	if player_instance == null:
		return

	player_instance.electron_energy += amount

	var thresholds := StatCalculator.get_energy_thresholds(player_instance.data)

	# Unlock Excited States only.
	# Do NOT consume energy.
	# Do NOT automatically activate.

	if player_instance.excited_state < 1 and player_instance.electron_energy >= thresholds[0]:
		player_instance.excited_state = 1
		print(player_instance.data.atom_name + " unlocked EX-I!")

	elif player_instance.excited_state < 2 and player_instance.electron_energy >= thresholds[1]:
		player_instance.excited_state = 2
		print(player_instance.data.atom_name + " unlocked EX-II!")

	elif player_instance.excited_state < 3 and player_instance.electron_energy >= thresholds[2]:
		player_instance.excited_state = 3
		print(player_instance.data.atom_name + " unlocked EX-III!")

	stats_changed.emit()

func activate_excited_state() -> bool:

	print("-----------------------------")
	print("Trying to activate EX")
	print("player_instance: ", player_instance)
	print("Unlocked EX: ", player_instance.excited_state)
	print("Active EX: ", player_instance.active_excited_state)
	print("Electron Energy: ", player_instance.electron_energy)

	if player_instance == null:
		print("FAILED -> player_instance is null")
		return false

	if player_instance.excited_state == 0:
		print("FAILED -> No EX unlocked")
		return false

	if player_instance.active_excited_state != 0:
		print("FAILED -> Already active")
		return false

	player_instance.active_excited_state = player_instance.excited_state

	print("SUCCESS -> Activated EX ", player_instance.active_excited_state)

	refresh_player_stats()
	stats_changed.emit()

	return true
# ============================================================
# APPLY EFFECT TO PLAYER
# ============================================================
func apply_effect_to_player(effect: MoveEffect) -> void:
	if status_effect_manager == null:
		return

	var attack_before: int = status_effect_manager.get_player_attack()
	var defense_before: int = status_effect_manager.get_player_defense()
	var special_attack_before: int = status_effect_manager.get_player_special_attack()
	var special_defense_before: int = status_effect_manager.get_player_special_defense()
	var speed_before: int = status_effect_manager.get_player_speed()

	status_effect_manager.apply_effect_to_player(effect)
	

	var attack_after: int = status_effect_manager.get_player_attack()
	var defense_after: int = status_effect_manager.get_player_defense()
	var special_attack_after: int = status_effect_manager.get_player_special_attack()
	var special_defense_after: int = status_effect_manager.get_player_special_defense()
	var speed_after: int = status_effect_manager.get_player_speed()

	print("========== PLAYER STATUS EFFECT ==========")
	print("Effect: ", effect.effect_name)
	print("Duration: ", effect.duration)
	print("Value: ", effect.value)

	print("Attack: ", attack_before, " -> ", attack_after)
	print("Defense: ", defense_before, " -> ", defense_after)
	print("Special Attack: ", special_attack_before, " -> ", special_attack_after)
	print("Special Defense: ", special_defense_before, " -> ", special_defense_after)
	print("Speed: ", speed_before, " -> ", speed_after)

	print("==========================================")

	status_effect_applied.emit("player", effect)
	stats_changed.emit()
	
# ============================================================
# APPLY EFFECT TO ENEMY
# ============================================================
func apply_effect_to_enemy(effect: MoveEffect) -> void:
	if status_effect_manager == null:
		return

	var attack_before: int = status_effect_manager.get_enemy_attack()
	var defense_before: int = status_effect_manager.get_enemy_defense()
	var special_attack_before: int = status_effect_manager.get_enemy_special_attack()
	var special_defense_before: int = status_effect_manager.get_enemy_special_defense()
	var speed_before: int = status_effect_manager.get_enemy_speed()

	status_effect_manager.apply_effect_to_enemy(effect)

	var attack_after: int = status_effect_manager.get_enemy_attack()
	var defense_after: int = status_effect_manager.get_enemy_defense()
	var special_attack_after: int = status_effect_manager.get_enemy_special_attack()
	var special_defense_after: int = status_effect_manager.get_enemy_special_defense()
	var speed_after: int = status_effect_manager.get_enemy_speed()

	print("========== ENEMY STATUS EFFECT ==========")
	print("Effect: ", effect.effect_name)
	print("Duration: ", effect.duration)
	print("Value: ", effect.value)

	print("Attack: ", attack_before, " -> ", attack_after)
	print("Defense: ", defense_before, " -> ", defense_after)
	print("Special Attack: ", special_attack_before, " -> ", special_attack_after)
	print("Special Defense: ", special_defense_before, " -> ", special_defense_after)
	print("Speed: ", speed_before, " -> ", speed_after)

	print("==========================================")

	status_effect_applied.emit("enemy", effect)
	stats_changed.emit()
# ============================================================
# END PLAYER TURN
# ============================================================
func end_player_turn() -> void:
	if status_effect_manager == null:
		return

	status_effect_manager.end_player_turn()
	stats_changed.emit()
	
# ============================================================
# END ENEMY TURN
# ============================================================
func end_enemy_turn() -> void:
	if status_effect_manager == null:
		return

	status_effect_manager.end_enemy_turn()
	stats_changed.emit()
	
# ============================================================
# NEUTRALIZE PLAYER EFFECTS
# ============================================================
func neutralize_player_effects() -> void:
	if status_effect_manager == null:
		return

	status_effect_manager.neutralize_player()
	stats_changed.emit()
	
# ============================================================
# NEUTRALIZE ENEMY EFFECTS
# ============================================================
func neutralize_enemy_effects() -> void:
	if status_effect_manager == null:
		return

	status_effect_manager.neutralize_enemy()
	stats_changed.emit()
	
# ============================================================
# SAVE PLAYER HP
# ============================================================
func save_player_hp() -> void:
	if player_instance != null:
		player_instance.current_hp = player_hp

# ============================================================
# SWITCH PLAYER ATOMON
# ============================================================
func switch_player_atomon(new_player: AtomonInstance) -> void:

	if new_player == null:
		push_error("BattleController: Cannot switch to null Atomon.")
		return

	# Save current Atomon HP
	save_player_hp()

	# Replace active Atomon
	player_instance = new_player

	# Load new Atomon HP
	player_max_hp = StatCalculator.get_hp(player_instance.data)
	player_hp = player_instance.current_hp
	if player_hp <= 0:
		player_hp = player_max_hp
		player_instance.current_hp = player_hp

	# Recalculate base stats
	player_attack_stat = StatCalculator.get_battle_attack(player_instance)
	player_defense_stat = StatCalculator.get_battle_defense(player_instance)
	player_special_attack_stat = StatCalculator.get_battle_special_attack(player_instance)
	player_special_defense_stat = StatCalculator.get_battle_special_defense(player_instance)
	player_speed_stat = StatCalculator.get_battle_speed(player_instance)

	# Rebuild player stats
	if status_effect_manager:
		status_effect_manager.setup_player_stats(
			player_attack_stat,
			player_defense_stat,
			player_special_attack_stat,
			player_special_defense_stat,
			player_speed_stat
		)

	# Remove status effects from the switched Atomon
	if status_effect_manager:
		status_effect_manager.neutralize_player()

	hp_changed.emit()

# ============================================================
# REFRESH PLAYER STATS
# ============================================================
func refresh_player_stats() -> void:

	player_max_hp = StatCalculator.get_battle_hp(player_instance)

	player_attack_stat = StatCalculator.get_battle_attack(player_instance)
	player_defense_stat = StatCalculator.get_battle_defense(player_instance)
	player_special_attack_stat = StatCalculator.get_battle_special_attack(player_instance)
	player_special_defense_stat = StatCalculator.get_battle_special_defense(player_instance)
	player_speed_stat = StatCalculator.get_battle_speed(player_instance)

	if status_effect_manager:
		status_effect_manager.setup_player_stats(
			player_attack_stat,
			player_defense_stat,
			player_special_attack_stat,
			player_special_defense_stat,
			player_speed_stat
		)

	stats_changed.emit()

func is_current_player_atomon(instance: AtomonInstance) -> bool:
	return instance == player_instance

func get_display_attack(instance: AtomonInstance) -> int:
	if is_current_player_atomon(instance):
		return get_player_attack()

	return StatCalculator.get_battle_attack(instance)

func get_display_defense(instance: AtomonInstance) -> int:
	if is_current_player_atomon(instance):
		return get_player_defense()

	return StatCalculator.get_battle_defense(instance)

func get_display_special_attack(instance: AtomonInstance) -> int:
	if is_current_player_atomon(instance):
		return get_player_special_attack()

	return StatCalculator.get_battle_special_attack(instance)

func get_display_special_defense(instance: AtomonInstance) -> int:
	if is_current_player_atomon(instance):
		return get_player_special_defense()

	return StatCalculator.get_battle_special_defense(instance)

func get_display_speed(instance: AtomonInstance) -> int:
	if is_current_player_atomon(instance):
		return get_player_speed()

	return StatCalculator.get_battle_speed(instance)


# ============================================================
# RESET BATTLE
# ============================================================
func reset_battle() -> void:
	save_player_hp()

	if status_effect_manager:
		status_effect_manager.neutralize_player()
		status_effect_manager.neutralize_enemy()

	status_effect_manager = null

	player_instance = null
	enemy_data = null

	player_hp = 0
	player_max_hp = 0

	enemy_hp = 0
	enemy_max_hp = 0

	player_attack_stat = 0
	player_defense_stat = 0
	player_special_attack_stat = 0
	player_special_defense_stat = 0
	player_speed_stat = 0

	enemy_attack_stat = 0
	enemy_defense_stat = 0
	enemy_special_attack_stat = 0
	enemy_special_defense_stat = 0
	enemy_speed_stat = 0


func on_excitement_button_pressed() -> void:

	print("Button reached BattleController")

	if player_instance == null:
		print("player_instance is NULL")
		return

	print("Unlocked State =", player_instance.excited_state)
	print("Active State =", player_instance.active_excited_state)
	print("Electron Energy =", player_instance.electron_energy)

	if activate_excited_state():
		print("Activated!")
	else:
		print("Activation Failed!")

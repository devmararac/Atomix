extends Control


# ============================================================
# CONSTANTS
# ============================================================

const BATTLE_SCALE := Vector2(10, 10)
const ATOMON_SCENE = preload("res://Atomons/Atomon.tscn")
const SWITCH_MENU = preload("res://Scenes/UI/switch_atomon.tscn")
const BATTLE_SUMMARY_SCENE = preload("res://Battle/BattleSummary.tscn")

# ============================================================
# BATTLE DATA
# ============================================================

var player_instance: AtomonInstance
var enemy_data: AtomonData

# ============================================================
# BATTLE ATOMONS
# ============================================================

var player_atomon: Node2D
var enemy_atomon: Node2D

var player_start_position: Vector2
var enemy_start_position: Vector2

# ============================================================
# SWITCH MENU
# ============================================================

var switch_menu: CanvasLayer

# ============================================================
# BATTLE SUMMARY
# ============================================================
var battle_summary: BattleSummary = null
var battle_ending: bool = false

# ============================================================
# BATTLE SUMMARY DATA
# ============================================================

var summary_result: String = "Victory"
var summary_enemy_name: String = ""
var summary_enemy_defeated: bool = false
var summary_atomons_remaining: int = 0

var summary_coins_reward: int = 0
var summary_item_rewards: Array[String] = []

# ============================================================
# FUSION SUMMARY DATA
# ============================================================
var fusion_used_this_battle: bool = false

var summary_fusion_skill_name: String = ""
var summary_fusion_formula: String = ""
var summary_fusion_atoms: Array[String] = []
var summary_fusion_bond_type: String = ""

var summary_octet_rule_completed: bool = false
var summary_octet_rule_explanation: String = ""
var summary_key_takeaway: String = ""

# ============================================================
# BATTLEFIELD
# ============================================================
@onready var enemy_container: Panel = $BattleField/EnemyContainer
@onready var enemy_spawn_point: Marker2D = $BattleField/EnemyContainer/SpawnPoint
@onready var friendly_container: Panel = $BattleField/FriendlyAtomonContainer
@onready var friendly_spawn_point: Marker2D = $BattleField/FriendlyAtomonContainer/SpawnPoint

# ============================================================
# ENEMY UI
# ============================================================

@onready var enemy_name_label: Label = $CanvasLayer/HUD/EnemyAtomonInfo/EnemyAtomonName
@onready var enemy_level_label: Label = $CanvasLayer/HUD/EnemyAtomonInfo/EnemyAtomonLevel/EALevel
@onready var enemy_hp_bar: TextureProgressBar = $CanvasLayer/HUD/EnemyAtomonInfo/EnemyAtomonHP
@onready var enemy_hp_text: Label = $CanvasLayer/HUD/EnemyAtomonInfo/EnemyAtomonHPText

# ============================================================
# PLAYER UI
# ============================================================

@onready var player_name_label: Label = $CanvasLayer/HUD/FriendlyAtomonInfo/FriendlyAtomonName
@onready var player_level_label: Label = $CanvasLayer/HUD/FriendlyAtomonInfo/FriendlyAtomonLevel/FALevel
@onready var player_hp_bar: TextureProgressBar = $CanvasLayer/HUD/FriendlyAtomonInfo/FriendlyAtomonHP
@onready var player_hp_text: Label = $CanvasLayer/HUD/FriendlyAtomonInfo/FriendlyAtomonHPText
@onready var exp_bar: TextureProgressBar = $CanvasLayer/HUD/FriendlyAtomonInfo/EXPBar

# ============================================================
# BATTLE LOG
# ============================================================
@onready var battle_log: RichTextLabel = $CanvasLayer/BattleLog
@onready var battle_announcer: NPCBase = $BattleAnnouncer
@onready var battle_controller: BattleController = $BattleController
@onready var fusion_enemy_target: Marker2D = $BattleField/EnemyContainer/SpawnPoint

# ============================================================
# MENUS
# ============================================================
@onready var command_ui: Control = $CommandUI
@onready var move_menu: PanelContainer = $CanvasLayer/MoveMenu
@onready var fusion_button: TextureButton = $CommandUI/GridContainer/Fusion

# ============================================================
# MOVE BUTTONS
# ============================================================
@onready var move_button_1: Button = $CanvasLayer/MoveMenu/VBoxContainer/Move1
@onready var move_button_2: Button = $CanvasLayer/MoveMenu/VBoxContainer/Move2
@onready var move_button_3: Button = $CanvasLayer/MoveMenu/VBoxContainer/Move3
@onready var move_button_4: Button = $CanvasLayer/MoveMenu/VBoxContainer/Move4

# ============================================================
# CURRENT MOVES
# ============================================================
var player_moves: Array[MoveData] = []

# ============================================================
# FUSION TRAINING TUTORIAL
# ============================================================
var fusion_training_tutorial_active: bool = false
var fusion_training_tutorial_step: int = 0

var tutorial_bubble: PanelContainer = null
var tutorial_name_label: Label = null
var tutorial_message_label: Label = null
var tutorial_continue_label: Label = null

var tutorial_font: Font = preload("res://Assets/Font/NicoPaint-Regular.woff")
# ============================================================
# READY
# ============================================================
func _ready() -> void:
	player_instance = BattleManager.player_instance
	enemy_data = BattleManager.enemy_data
	if player_instance == null:
		push_error("BattleUI: Player Atomon is null.")
		battle_log.text = "No Atomon is available for battle."
		return
	if enemy_data == null:
		push_error("BattleUI: Enemy Atomon is null.")
		battle_log.text = "No enemy Atomon is available."
		return
	BattleControllerGlobal.setup_battle(
		player_instance,
		enemy_data
	)
	if BattleManager.is_fusion_training_battle:
		BattleControllerGlobal.set_training_enemy_hp(85)
	connect_battle_controller_signals()

	setup_player_atomon()
	setup_enemy_atomon()

	setup_player_ui()
	setup_enemy_ui()
	setup_move_buttons()
	update_hp_ui()

	command_ui.visible = true
	move_menu.visible = false

	battle_log.text = (
		"A wild " + enemy_data.atom_name + " appeared!"
	)

	fusion_used_this_battle = false
	fusion_button.disabled = false

	reset_battle_summary_data()

	# ========================================================
	# START FUSION TRAINING TUTORIAL
	# ========================================================

	if BattleManager.is_fusion_training_battle:

		show_fusion_training_tutorial()

	else:

		announce(
			"A wild " + enemy_data.atom_name + " appeared!"
		)


# ============================================================
# RESET BATTLE SUMMARY DATA
# ============================================================

func reset_battle_summary_data() -> void:

	battle_ending = false

	summary_result = "Victory"
	summary_enemy_name = enemy_data.atom_name if enemy_data != null else ""
	summary_enemy_defeated = false
	summary_atomons_remaining = 0

	summary_coins_reward = 0
	summary_item_rewards.clear()

	summary_fusion_skill_name = ""
	summary_fusion_formula = ""
	summary_fusion_atoms.clear()
	summary_fusion_bond_type = ""

	summary_octet_rule_completed = false
	summary_octet_rule_explanation = ""
	summary_key_takeaway = ""


# ============================================================
# CONNECT BATTLE CONTROLLER SIGNALS
# ============================================================

func connect_battle_controller_signals() -> void:

	if not BattleControllerGlobal.hp_changed.is_connected(_on_hp_changed):
		BattleControllerGlobal.hp_changed.connect(_on_hp_changed)

	if not BattleControllerGlobal.player_damaged.is_connected(_on_player_damaged):
		BattleControllerGlobal.player_damaged.connect(_on_player_damaged)

	if not BattleControllerGlobal.enemy_damaged.is_connected(_on_enemy_damaged):
		BattleControllerGlobal.enemy_damaged.connect(_on_enemy_damaged)

	if not BattleControllerGlobal.player_healed.is_connected(_on_player_healed):
		BattleControllerGlobal.player_healed.connect(_on_player_healed)

	if not BattleControllerGlobal.enemy_healed.is_connected(_on_enemy_healed):
		BattleControllerGlobal.enemy_healed.connect(_on_enemy_healed)

	if not BattleControllerGlobal.player_fainted.is_connected(_on_player_fainted):
		BattleControllerGlobal.player_fainted.connect(_on_player_fainted)

	if not BattleControllerGlobal.enemy_fainted.is_connected(_on_enemy_fainted):
		BattleControllerGlobal.enemy_fainted.connect(_on_enemy_fainted)

	if not BattleControllerGlobal.stats_changed.is_connected(_on_stats_changed):
		BattleControllerGlobal.stats_changed.connect(_on_stats_changed)


# ============================================================
# SETUP PLAYER ATOMON
# ============================================================

func setup_player_atomon() -> void:

	player_atomon = ATOMON_SCENE.instantiate()

	friendly_container.add_child(player_atomon)

	player_atomon.position = friendly_spawn_point.position
	player_atomon.battle_mode = true
	player_atomon.setup(player_instance.data)
	player_atomon.scale = BATTLE_SCALE

	var player_sprite: AnimatedSprite2D = (
		player_atomon.get_node("AnimatedSprite2D")
	)

	player_sprite.flip_h = false

	player_start_position = player_atomon.position


# ============================================================
# SETUP ENEMY ATOMON
# ============================================================

func setup_enemy_atomon() -> void:

	enemy_atomon = ATOMON_SCENE.instantiate()

	enemy_container.add_child(enemy_atomon)

	enemy_atomon.position = enemy_spawn_point.position
	enemy_atomon.battle_mode = true
	enemy_atomon.setup(enemy_data)
	enemy_atomon.scale = BATTLE_SCALE

	var enemy_sprite: AnimatedSprite2D = (
		enemy_atomon.get_node("AnimatedSprite2D")
	)

	enemy_sprite.flip_h = true

	enemy_start_position = enemy_atomon.position


# ============================================================
# SETUP PLAYER UI
# ============================================================

func setup_player_ui() -> void:

	player_name_label.text = player_instance.data.atom_name

	update_excited_ui()


# ============================================================
# SETUP ENEMY UI
# ============================================================

func setup_enemy_ui() -> void:

	enemy_name_label.text = enemy_data.atom_name
	enemy_level_label.text = "1"


# ============================================================
# SETUP MOVE BUTTONS
# ============================================================

func setup_move_buttons() -> void:

	player_moves = player_instance.data.moves

	if player_moves.size() > 0:

		move_button_1.visible = true

		var label_1: Label = (
			move_button_1.get_node("Move1")
		)

		label_1.text = player_moves[0].move_name

	else:

		move_button_1.visible = false

	if player_moves.size() > 1:

		move_button_2.visible = true

		var label_2: Label = (
			move_button_2.get_node("Move2")
		)

		label_2.text = player_moves[1].move_name

	else:

		move_button_2.visible = false

	if player_moves.size() > 2:

		move_button_3.visible = true

		var label_3: Label = (
			move_button_3.get_node("Move3")
		)

		label_3.text = player_moves[2].move_name

	else:

		move_button_3.visible = false

	if player_moves.size() > 3:

		move_button_4.visible = true

		var label_4: Label = (
			move_button_4.get_node("Move4")
		)

		label_4.text = player_moves[3].move_name

	else:

		move_button_4.visible = false


# ============================================================
# UPDATE HP UI
# ============================================================

func update_hp_ui() -> void:

	var player_hp: int = (
		BattleControllerGlobal.get_player_hp()
	)

	var player_max_hp: int = (
		BattleControllerGlobal.get_player_max_hp()
	)

	var enemy_hp: int = (
		BattleControllerGlobal.get_enemy_hp()
	)

	var enemy_max_hp: int = (
		BattleControllerGlobal.get_enemy_max_hp()
	)

	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp

	player_hp_text.text = (
		str(player_hp) + "/" + str(player_max_hp)
	)

	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp

	enemy_hp_text.text = (
		str(enemy_hp) + "/" + str(enemy_max_hp)
	)


# ============================================================
# ATTACK BUTTON
# ============================================================

func _on_attack_pressed() -> void:

	if fusion_training_tutorial_active:
		return

	command_ui.visible = false
	move_menu.visible = true


# ============================================================
# MOVE BUTTONS
# ============================================================

func _on_move_1_pressed() -> void:
	use_move(0)


func _on_move_2_pressed() -> void:
	use_move(1)


func _on_move_3_pressed() -> void:
	use_move(2)


func _on_move_4_pressed() -> void:
	use_move(3)


# ============================================================
# USE MOVE
# ============================================================

func use_move(move_index: int) -> void:

	if move_index < 0:
		return

	if move_index >= player_moves.size():
		return

	var current_pp = (
		BattleControllerGlobal.get_player_pp(move_index)
	)

	if current_pp <= 0:

		battle_log.text = "No PP left for this move!"
		announce("No PP left for this move!")

		return

	var move: MoveData = player_moves[move_index]

	move_menu.visible = false
	command_ui.visible = false

	await animate_player_attack()

	battle_log.text = (
		player_instance.data.atom_name
		+ " used "
		+ move.move_name
		+ "!"
	)

	announce(
		player_instance.data.atom_name
		+ " used "
		+ move.move_name
		+ "!"
	)

	BattleControllerGlobal.execute_move(move, true)
	BattleControllerGlobal.end_player_turn()

	await get_tree().create_timer(0.5).timeout

	update_hp_ui()

	if BattleControllerGlobal.get_enemy_hp() <= 0:
		return

	await get_tree().create_timer(0.8).timeout

	await enemy_turn()


# ============================================================
# PLAYER ATTACK ANIMATION
# ============================================================

func animate_player_attack() -> void:

	if player_atomon == null:
		return

	var tween := create_tween()

	tween.tween_property(
		player_atomon,
		"position",
		player_start_position + Vector2(150, 0),
		0.15
	)

	tween.tween_property(
		player_atomon,
		"position",
		player_start_position,
		0.15
	)

	await tween.finished


# ============================================================
# ENEMY TURN
# ============================================================

func enemy_turn() -> void:

	if enemy_data == null:
		return

	if enemy_data.moves.is_empty():

		command_ui.visible = true

		return

	var enemy_move: MoveData = (
		enemy_data.moves[
			randi() % enemy_data.moves.size()
		]
	)

	await animate_enemy_attack()

	battle_log.text = (
		enemy_data.atom_name
		+ " used "
		+ enemy_move.move_name
		+ "!"
	)

	announce(
		enemy_data.atom_name
		+ " used "
		+ enemy_move.move_name
		+ "!"
	)

	BattleControllerGlobal.execute_move(enemy_move, false)
	BattleControllerGlobal.end_enemy_turn()

	await get_tree().create_timer(0.5).timeout

	update_hp_ui()

	if BattleControllerGlobal.get_player_hp() > 0:
		command_ui.visible = true


# ============================================================
# ENEMY ATTACK ANIMATION
# ============================================================

func animate_enemy_attack() -> void:

	if enemy_atomon == null:
		return

	var tween := create_tween()

	tween.tween_property(
		enemy_atomon,
		"position",
		enemy_start_position + Vector2(-150, 0),
		0.15
	)

	tween.tween_property(
		enemy_atomon,
		"position",
		enemy_start_position,
		0.15
	)

	await tween.finished


# ============================================================
# HP CHANGED
# ============================================================

func _on_hp_changed() -> void:

	update_hp_ui()
	update_excited_ui()


# ============================================================
# PLAYER DAMAGED
# ============================================================

func _on_player_damaged(amount: int) -> void:

	battle_log.text = (
		player_instance.data.atom_name
		+ " took "
		+ str(amount)
		+ " damage!"
	)

	announce(
		player_instance.data.atom_name
		+ " took "
		+ str(amount)
		+ " damage!"
	)


# ============================================================
# ENEMY DAMAGED
# ============================================================

func _on_enemy_damaged(amount: int) -> void:

	battle_log.text = (
		enemy_data.atom_name
		+ " took "
		+ str(amount)
		+ " damage!"
	)

	announce(
		enemy_data.atom_name
		+ " took "
		+ str(amount)
		+ " damage!"
	)


# ============================================================
# PLAYER HEALED
# ============================================================

func _on_player_healed(amount: int) -> void:

	battle_log.text = (
		player_instance.data.atom_name
		+ " recovered "
		+ str(amount)
		+ " HP!"
	)

	announce(
		player_instance.data.atom_name
		+ " recovered "
		+ str(amount)
		+ " HP!"
	)


# ============================================================
# ENEMY HEALED
# ============================================================

func _on_enemy_healed(amount: int) -> void:

	battle_log.text = (
		enemy_data.atom_name
		+ " recovered "
		+ str(amount)
		+ " HP!"
	)

	announce(
		enemy_data.atom_name
		+ " recovered "
		+ str(amount)
		+ " HP!"
	)


# ============================================================
# PLAYER FAINTED
# ============================================================

func _on_player_fainted() -> void:

	if battle_ending:
		return

	battle_log.text = player_instance.data.atom_name + " fainted!"

	announce(
		player_instance.data.atom_name + " fainted!"
	)

	command_ui.visible = false
	move_menu.visible = false

	await get_tree().create_timer(1.5).timeout

	# ========================================================
	# FUSION TRAINING DEFEAT
	# ========================================================

	if BattleManager.is_fusion_training_battle:

		battle_ending = true

		battle_log.text = "Training battle failed."

		announce("Training battle failed.")

		print(
			"[BattleUI] Fusion training battle ended in defeat."
		)

		await get_tree().create_timer(1.0).timeout

		BattleManager.end_battle()

		return

	# ========================================================
	# NORMAL BATTLE
	# ========================================================

	if PartyManager.has_available_atomon():

		open_party_menu()

		return

	battle_ending = true

	battle_log.text = "No Atomons left!"
	announce("No Atomons left!")

	BattleControllerGlobal.save_player_hp()

	var battle_save_success: bool = await SaveManager.auto_save_battle_state(
		"Battle defeat: all Atomons fainted",
		"defeat"
	)

	if battle_save_success:

		print("[BattleUI] Battle state saved after defeat.")

	else:

		push_error(
			"[BattleUI] Battle state save after defeat FAILED."
		)

	await get_tree().create_timer(1.0).timeout

	show_battle_summary(
		"Defeat",
		false,
		0,
		0,
		[]
	)


# ============================================================
# CALCULATE BATTLE COIN REWARD
# ============================================================

func calculate_battle_coin_reward() -> int:

	if enemy_data == null:
		return 0

	var atomic_number := enemy_data.atomic_number

	if atomic_number <= 20:
		return 5

	if atomic_number <= 40:
		return 6

	if atomic_number <= 60:
		return 7

	if atomic_number <= 80:
		return 8

	if atomic_number <= 100:
		return 9

	return 10


# ============================================================
# ADD MATERIAL REWARD
# ============================================================

func add_battle_material_reward(
	item_id: String,
	item_name: String
) -> bool:

	var item_data: ItemData = (
		ItemDatabase.get_item(item_id)
	)

	if item_data == null:

		push_error(
			"[BattleUI] Could not find reward item: "
			+ item_id
		)

		return false

	var item_instance := ItemInstance.new()

	item_instance.data = item_data
	item_instance.quantity = 1

	InventoryManager.add_item(item_instance)

	return true


# ============================================================
# GIVE BATTLE MATERIAL REWARDS
# ============================================================

func give_battle_material_rewards() -> Array[String]:

	var rewards: Array[String] = []

	if add_battle_material_reward(
		"proton",
		"Proton"
	):

		rewards.append("+1 Proton")

	if add_battle_material_reward(
		"electron",
		"Electron"
	):

		rewards.append("+1 Electron")

	if add_battle_material_reward(
		"neutron",
		"Neutron"
	):

		rewards.append("+1 Neutron")

	return rewards


# ============================================================
# ENEMY FAINTED
# ============================================================

func _on_enemy_fainted() -> void:

	if battle_ending:
		return

	# ========================================================
	# FUSION TRAINING VICTORY
	# ========================================================

	if BattleManager.is_fusion_training_battle:

		battle_ending = true

		command_ui.visible = false
		move_menu.visible = false

		battle_log.text = (
			enemy_data.atom_name
			+ " fainted!"
		)

		announce(
			enemy_data.atom_name
			+ " fainted!"
		)

		print("[BattleUI] Fusion training complete. Enemy defeated: ", enemy_data.atom_name)

		await get_tree().create_timer(1.5).timeout

		BattleManager.end_battle()

		return

	# ========================================================
	# NORMAL BATTLE
	# ========================================================

	battle_ending = true

	battle_log.text = enemy_data.atom_name + " fainted!"

	announce(
		enemy_data.atom_name
		+ " fainted!"
	)

	command_ui.visible = false
	move_menu.visible = false

	BattleControllerGlobal.save_player_hp()

	var battle_reward := calculate_battle_coin_reward()

	CurrencyManager.add_coins(
		battle_reward
	)

	var material_rewards := (
		give_battle_material_rewards()
	)

	summary_coins_reward = battle_reward
	summary_item_rewards = material_rewards.duplicate()

	print(
		"[BattleUI] Requesting battle auto-save..."
	)

	var battle_save_success: bool = await SaveManager.auto_save_battle_state(
		"Battle victory: +"
		+ str(battle_reward) + " coins and material rewards",
		"victory"
	)

	if battle_save_success:

		print(
			"[BattleUI] Battle state automatically saved successfully."
		)

	else:

		push_error(
			"[BattleUI] Battle state automatic save FAILED."
		)

	await get_tree().create_timer(1.0).timeout

	var remaining: int = count_remaining_atomons()

	show_battle_summary(
		"Victory",
		true,
		remaining,
		battle_reward,
		material_rewards
	)


# ============================================================
# COUNT REMAINING ATOMONS
# ============================================================

func count_remaining_atomons() -> int:

	var count := 0

	# ========================================================
	# FUSION TRAINING PARTY
	# ========================================================

	if BattleManager.is_fusion_training_battle:

		for atmon in BattleManager.training_party:

			if atmon == null:
				continue

			if atmon.current_hp > 0:
				count += 1

		return count

	# ========================================================
	# NORMAL PARTY
	# ========================================================

	var battle_party: Array[AtomonInstance] = (
		PartyManager.get_battle_party()
	)

	for atmon in battle_party:

		if atmon == null:
			continue

		if atmon.current_hp > 0:
			count += 1

	return count


# ============================================================
# ATOMONS BUTTON
# ============================================================

func _on_atomons_pressed() -> void:

	# Fusion training uses a temporary fixed training party.
	if BattleManager.is_fusion_training_battle:

		battle_log.text = (
			"Atomon switching is disabled during training."
		)

		announce(
			"Follow the Fusion training first!"
		)

		return

	open_party_menu()


# ============================================================
# OPEN PARTY MENU
# ============================================================

func open_party_menu() -> void:

	if BattleManager.is_fusion_training_battle:
		return

	if switch_menu != null:
		return

	switch_menu = SWITCH_MENU.instantiate()

	add_child(switch_menu)

	switch_menu.current_battle_atomon = player_instance

	switch_menu.force_switch = (
		BattleControllerGlobal.get_player_hp() <= 0
	)

	switch_menu.atomon_selected.connect(
		_on_atomon_selected
	)

	switch_menu.closed.connect(
		_on_switch_menu_closed
	)


# ============================================================
# ATOMON SELECTED
# ============================================================

func _on_atomon_selected(index: int) -> void:

	if BattleManager.is_fusion_training_battle:
		return

	var force_switch: bool = (
		BattleControllerGlobal.get_player_hp() <= 0
	)

	await switch_atomon(
		index,
		force_switch
	)

	switch_menu = null

	command_ui.visible = true
	move_menu.visible = false


# ============================================================
# SWITCH ATOMON
# ============================================================

func switch_atomon(
	index: int,
	free_switch: bool = false
) -> void:

	if BattleManager.is_fusion_training_battle:
		return

	if not PartyManager.set_active_atomon(index):
		return

	player_instance = PartyManager.get_active_atomon()

	if player_instance == null:
		return

	BattleControllerGlobal.switch_player_atomon(
		player_instance
	)

	refresh_player()

	if not free_switch:

		await enemy_turn()


# ============================================================
# REFRESH PLAYER ATOMON
# ============================================================

func refresh_player() -> void:

	var new_player: AtomonInstance = player_instance

	if new_player == null:
		return

	battle_log.text = "Go! " + new_player.data.atom_name

	announce(
		"Go! " + new_player.data.atom_name + "!"
	)

	if player_atomon != null:

		player_atomon.queue_free()

	player_atomon = ATOMON_SCENE.instantiate()

	friendly_container.add_child(
		player_atomon
	)

	player_atomon.setup(
		new_player.data
	)

	player_atomon.battle_mode = true
	player_atomon.position = friendly_spawn_point.position
	player_atomon.scale = BATTLE_SCALE

	var player_sprite: AnimatedSprite2D = (
		player_atomon.get_node("AnimatedSprite2D")
	)

	player_sprite.flip_h = false

	player_start_position = player_atomon.position

	player_name_label.text = new_player.data.atom_name

	StatCalculator.get_energy_thresholds(
		new_player.data
	)

	update_excited_ui()

	player_moves = new_player.data.moves

	setup_move_buttons()
	update_hp_ui()


# ============================================================
# SWITCH MENU CLOSED
# ============================================================

func _on_switch_menu_closed() -> void:

	if switch_menu != null:

		switch_menu.queue_free()
		switch_menu = null


# ============================================================
# RUN BUTTON
# ============================================================

func _on_run_pressed() -> void:

	if fusion_training_tutorial_active:
		return

	if battle_ending:
		return

	# ========================================================
	# TRAINING BATTLE
	# ========================================================

	if BattleManager.is_fusion_training_battle:

		battle_log.text = (
			"You cannot run from Fusion training."
		)

		announce(
			"Complete the Fusion training first!"
		)

		return

	# ========================================================
	# NORMAL BATTLE
	# ========================================================

	battle_ending = true

	battle_log.text = "You ran away!"

	announce("You ran away!")

	BattleControllerGlobal.save_player_hp()

	print(
		"[BattleUI] Saving battle state after escape..."
	)

	var battle_save_success: bool = await SaveManager.auto_save_battle_state(
		"Battle escaped: saving Atomon state",
		"escape"
	)

	if battle_save_success:

		print(
			"[BattleUI] Battle state saved successfully after escape."
		)

	else:

		push_error(
			"[BattleUI] Battle state save after escape FAILED."
		)

	await get_tree().create_timer(1.0).timeout

	var remaining: int = count_remaining_atomons()

	show_battle_summary(
		"Escaped",
		false,
		remaining,
		0,
		[]
	)


# ============================================================
# CLOSE MOVE MENU
# ============================================================

func _on_close_button_pressed() -> void:

	move_menu.visible = false
	command_ui.visible = true


# ============================================================
# EXCITED STATE UI
# ============================================================

func update_excited_ui() -> void:

	if player_instance == null:
		return

	if player_instance.data == null:
		return

	var thresholds = (
		StatCalculator.get_energy_thresholds(
			player_instance.data
		)
	)

	player_level_label.text = (
		"EX-" + str(player_instance.excited_state)
	)

	match player_instance.excited_state:

		0:
			exp_bar.max_value = thresholds[0]

		1:
			exp_bar.max_value = thresholds[1]

		2:
			exp_bar.max_value = thresholds[2]

		3:
			exp_bar.max_value = thresholds[2]

	exp_bar.value = player_instance.electron_energy


# ============================================================
# STATS CHANGED
# ============================================================

func _on_stats_changed() -> void:

	update_excited_ui()


# ============================================================
# EXCITE BUTTON
# ============================================================

func _on_excite_button_pressed() -> void:

	BattleControllerGlobal.on_excitement_button_pressed()


# ============================================================
# BATTLE ANNOUNCER
# ============================================================

func announce(message: String) -> void:

	if battle_announcer == null:
		return

	Dialogic.VAR.battle_message = message

	NpcManager.play_battle_announcement(
		battle_announcer,
		&"battle_announce"
	)


# ============================================================
# FUSION BUTTON
# ============================================================

func _on_fusion_pressed() -> void:

	# ========================================================
	# FUSION TRAINING TUTORIAL
	# ========================================================

	if fusion_training_tutorial_active:

		if fusion_training_tutorial_step < 5:
			return

		fusion_training_tutorial_active = false

		hide_fusion_training_tutorial()

	if battle_ending:
		return

	if fusion_used_this_battle:
		return

	var available_fusions: Array[FusionRecipe] = (
		FusionManager.get_available_fusion_recipes()
	)

	if available_fusions.is_empty():

		var active_atomon: AtomonInstance = null

		if BattleManager.is_fusion_training_battle:

			active_atomon = BattleManager.player_instance

		else:

			active_atomon = PartyManager.get_active_atomon()

		if active_atomon != null and active_atomon.data != null:

			var active_symbol: String = (
				active_atomon.data.chemical_symbol
			)

			battle_log.text = (
				active_atomon.data.atom_name
				+ " cannot perform any available Fusion."
			)

			announce(
				active_atomon.data.atom_name
				+ " cannot perform Fusion right now!"
			)

			print(
				"[BattleUI] No Fusion available for active Atomon: ",
				active_symbol
			)

		else:

			battle_log.text = (
				"No active Atomon can perform Fusion."
			)

		return

	hide_battle_ui()

	var fusion_menu_scene := preload(
		"res://Battle/FusionMenu.tscn"
	)

	var fusion_menu := fusion_menu_scene.instantiate()

	if fusion_menu.has_signal(
		"fusion_components_selected"
	):

		fusion_menu.fusion_components_selected.connect(
			_on_fusion_components_selected
		)

	if fusion_menu.has_signal(
		"fusion_menu_cancelled"
	):

		fusion_menu.fusion_menu_cancelled.connect(
			_on_fusion_menu_cancelled
		)

	get_tree().current_scene.add_child(
		fusion_menu
	)


# ============================================================
# FUSION MENU CANCELLED
# ============================================================

func _on_fusion_menu_cancelled() -> void:

	show_battle_ui()


# ============================================================
# FUSION COMPONENTS SELECTED
# ============================================================

func _on_fusion_components_selected(
	recipe: FusionRecipe,
	selected_atomons: Array[AtomonInstance]
) -> void:

	if recipe == null:
		return

	if selected_atomons.is_empty():
		return

	open_fusion_learning(
		recipe,
		selected_atomons
	)


# ============================================================
# OPEN FUSION LEARNING / OCTET RULE CHALLENGE
# ============================================================

func open_fusion_learning(
	recipe: FusionRecipe,
	selected_atomons: Array[AtomonInstance]
) -> void:

	if recipe == null:
		return

	hide_battle_ui()

	var learning_scene := preload(
		"res://Battle/BattleLearning.tscn"
	)

	var learning_layer := CanvasLayer.new()

	learning_layer.name = "BattleLearningLayer"
	learning_layer.layer = 100

	get_tree().current_scene.add_child(
		learning_layer
	)

	var learning_screen := (
		learning_scene.instantiate()
	)

	learning_layer.add_child(
		learning_screen
	)

	if learning_screen is Control:

		learning_screen.set_anchors_preset(
			Control.PRESET_FULL_RECT
		)

		learning_screen.position = Vector2.ZERO

		learning_screen.size = (
			get_viewport().get_visible_rect().size
		)

	if learning_screen.has_signal(
		"fusion_challenge_finished"
	):

		learning_screen.fusion_challenge_finished.connect(
			_on_fusion_challenge_finished.bind(
				learning_layer
			)
		)

	if learning_screen.has_method(
		"setup_fusion_challenge"
	):

		learning_screen.setup_fusion_challenge(
			recipe,
			selected_atomons
		)


# ============================================================
# FUSION CHALLENGE FINISHED
# ============================================================

func _on_fusion_challenge_finished(
	success: bool,
	recipe: FusionRecipe,
	selected_atomons: Array[AtomonInstance],
	learning_layer: CanvasLayer
) -> void:

	if success:

		record_fusion_summary(
			recipe,
			selected_atomons
		)

		fusion_button.disabled = true

		battle_log.text = "Fusion successful!"

	if learning_layer != null:

		learning_layer.queue_free()

	show_battle_ui()

	if recipe == null:
		return

	# ========================================================
	# FAILED CHALLENGE
	# ========================================================

	if not success:

		battle_log.text = (
			"Fusion failed! Review the Octet Rule."
		)

		announce(
			"Fusion failed!"
		)

		fusion_used_this_battle = false

		fusion_button.disabled = true

		command_ui.visible = false
		move_menu.visible = false

		BattleControllerGlobal.end_player_turn()

		await get_tree().create_timer(0.8).timeout

		await enemy_turn()

		if not battle_ending:

			command_ui.visible = true
			move_menu.visible = false

			fusion_button.disabled = false

		return

	# ========================================================
	# SUCCESSFUL CHALLENGE
	# ========================================================

	battle_log.text = (
		"Octet Rule challenge passed!\n"
		+ recipe.fusion_skill_name
	)

	announce(
		"Fusion successful!"
	)

	fusion_used_this_battle = true

	command_ui.visible = false
	move_menu.visible = false

	# ========================================================
	# QUEST: SUCCESSFUL FUSION
	# ========================================================

	if BattleManager.is_fusion_training_battle:

		print(
			"[BattleUI] Notifying QuestManager: Fusion used."
		)

		await QuestManager.notify(
			ObjectiveType.Type.INTERACT,
			"fusion"
		)

	execute_fusion_skill(
		recipe,
		selected_atomons
	)


# ============================================================
# RECORD FUSION SUMMARY
# ============================================================

func record_fusion_summary(
	recipe: FusionRecipe,
	selected_atomons: Array[AtomonInstance]
) -> void:

	if recipe == null:
		return

	fusion_used_this_battle = true

	summary_fusion_skill_name = (
		recipe.fusion_skill_name
	)

	summary_fusion_formula = (
		recipe.chemical_formula
	)

	summary_fusion_bond_type = (
		recipe.bond_type
	)

	summary_octet_rule_completed = true

	summary_octet_rule_explanation = (
		recipe.octet_rule_explanation
	)

	summary_key_takeaway = (
		recipe.fusion_description
	)

	summary_fusion_atoms.clear()

	var atomon_counts: Dictionary = {}

	for atomon in selected_atomons:

		if atomon == null:
			continue

		if atomon.data == null:
			continue

		var atom_name: String = (
			atomon.data.atom_name
		)

		if atomon_counts.has(atom_name):

			atomon_counts[atom_name] += 1

		else:

			atomon_counts[atom_name] = 1

	for atom_name in atomon_counts.keys():

		var count: int = atomon_counts[atom_name]

		var atom_text := (
			str(count)
			+ " × "
			+ str(atom_name)
		)

		summary_fusion_atoms.append(
			atom_text
		)


# ============================================================
# EXECUTE FUSION SKILL
# ============================================================

func execute_fusion_skill(
	recipe: FusionRecipe,
	selected_atomons: Array[AtomonInstance]
) -> void:

	if recipe == null:
		return

	if selected_atomons.is_empty():
		return

	if recipe.projectile_scene == null:

		push_error(
			"[BattleUI] Fusion recipe has no projectile scene: "
			+ recipe.chemical_formula
		)

		return

	var fusion_damage := recipe.get_fusion_damage(
		selected_atomons.size()
	)

	var projectile := (
		recipe.projectile_scene.instantiate()
	)

	if projectile == null:

		push_error(
			"[BattleUI] Failed to instantiate Fusion projectile."
		)

		return

	$BattleField/BattleEffects.add_child(
		projectile
	)

	projectile.scale = Vector2(15, 15)

	if projectile.has_signal(
		"projectile_finished"
	):

		projectile.projectile_finished.connect(
			_on_fusion_projectile_finished.bind(
				projectile,
				fusion_damage,
				recipe
			)
		)

	else:

		push_error(
			"[BattleUI] Fusion projectile has no "
			+ "projectile_finished signal."
		)

		projectile.queue_free()

		return

	if projectile.has_method("launch"):

		var start_position := (
			friendly_spawn_point.global_position
		)

		var target_position := (
			fusion_enemy_target.global_position
		)

		projectile.launch(
			start_position,
			target_position
		)

	else:

		push_error(
			"[BattleUI] Fusion projectile does not "
			+ "have launch()."
		)

		projectile.queue_free()


# ============================================================
# FUSION PROJECTILE FINISHED
# ============================================================

func _on_fusion_projectile_finished(
	projectile: Node,
	fusion_damage: int,
	recipe: FusionRecipe
) -> void:

	BattleControllerGlobal.damage_enemy(
		fusion_damage
	)

	if is_instance_valid(projectile):

		projectile.queue_free()

	battle_log.text = (
		recipe.fusion_skill_name
		+ " dealt "
		+ str(fusion_damage)
		+ " damage!"
	)

	announce(
		recipe.fusion_skill_name
		+ "!"
	)

	if BattleControllerGlobal.get_enemy_hp() <= 0:

		return

	BattleControllerGlobal.end_player_turn()

	await get_tree().create_timer(0.8).timeout

	await enemy_turn()

	if not battle_ending:

		command_ui.visible = true
		move_menu.visible = false


# ============================================================
# SHOW BATTLE SUMMARY
# ============================================================

func show_battle_summary(
	result: String,
	enemy_defeated: bool,
	remaining_atomons: int,
	coins_reward: int = 0,
	item_rewards: Array[String] = []
) -> void:

	if battle_summary != null:
		return

	summary_result = result

	summary_enemy_name = (
		enemy_data.atom_name
		if enemy_data != null
		else ""
	)

	summary_enemy_defeated = enemy_defeated
	summary_atomons_remaining = remaining_atomons

	summary_coins_reward = coins_reward
	summary_item_rewards = item_rewards.duplicate()

	command_ui.visible = false
	move_menu.visible = false

	if switch_menu != null:

		switch_menu.queue_free()
		switch_menu = null

	battle_summary = BATTLE_SUMMARY_SCENE.instantiate()

	get_tree().current_scene.add_child(
		battle_summary
	)

	if battle_summary is Control:

		battle_summary.set_anchors_preset(
			Control.PRESET_FULL_RECT
		)

		battle_summary.position = Vector2.ZERO

		battle_summary.size = (
			get_viewport().get_visible_rect().size
		)

	battle_summary.set_battle_result(
		summary_result,
		summary_enemy_name,
		summary_enemy_defeated,
		summary_atomons_remaining
	)

	if fusion_used_this_battle:

		battle_summary.set_fusion_lesson(
			summary_fusion_skill_name,
			summary_fusion_formula,
			summary_fusion_atoms,
			summary_fusion_bond_type,
			summary_octet_rule_completed,
			summary_octet_rule_explanation,
			summary_key_takeaway
		)

	else:

		battle_summary.set_octet_lesson(
			false,
			"",
			""
		)

	battle_summary.set_rewards(
		summary_coins_reward,
		summary_item_rewards
	)

	if battle_summary.has_signal(
		"continue_pressed"
	):

		battle_summary.continue_pressed.connect(
			_on_battle_summary_continue
		)

# ============================================================
# BATTLE SUMMARY CONTINUE
# ============================================================

func _on_battle_summary_continue() -> void:

	if battle_summary != null:

		battle_summary.queue_free()
		battle_summary = null

	BattleManager.end_battle()


# ============================================================
# BATTLE UI VISIBILITY
# ============================================================

func hide_battle_ui() -> void:

	visible = false


func show_battle_ui() -> void:

	visible = true


# ============================================================
# FUSION TRAINING TUTORIAL
# ============================================================

func show_fusion_training_tutorial() -> void:

	fusion_training_tutorial_active = true
	fusion_training_tutorial_step = 0

	create_fusion_training_tutorial_ui()

	command_ui.visible = true
	move_menu.visible = false

	var attack_button: TextureButton = ($CommandUI/GridContainer/Attack)
	var atomons_button: TextureButton = ($CommandUI/GridContainer/Atomons)
	var run_button: TextureButton = ($CommandUI/GridContainer/Run)

	attack_button.disabled = true
	fusion_button.disabled = true
	atomons_button.disabled = true
	run_button.disabled = true

	tutorial_bubble.visible = true

	update_fusion_training_tutorial()


func create_fusion_training_tutorial_ui() -> void:

	if tutorial_bubble != null and is_instance_valid(tutorial_bubble):
		return

	tutorial_bubble = PanelContainer.new()
	tutorial_bubble.name = "FusionTrainingTutorial"

	tutorial_bubble.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	var panel_style := StyleBoxFlat.new()

	panel_style.bg_color = Color("fae3c4")
	panel_style.border_color = Color("785a3d")

	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(10)

	panel_style.content_margin_left = 18.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_bottom = 14.0

	tutorial_bubble.add_theme_stylebox_override(
		"panel",
		panel_style
	)

	tutorial_bubble.set_anchors_preset(
		Control.PRESET_TOP_LEFT
	)

	tutorial_bubble.position = (
		command_ui.position + Vector2(-390, -15)
	)

	tutorial_bubble.size = Vector2(370, 150)

	var container := VBoxContainer.new()

	container.add_theme_constant_override(
		"separation",
		3
	)

	tutorial_bubble.add_child(container)

	tutorial_name_label = Label.new()

	tutorial_name_label.text = "Andrew"

	tutorial_name_label.add_theme_font_override(
		"font",
		tutorial_font
	)

	tutorial_name_label.add_theme_font_size_override(
		"font_size",
		25
	)

	tutorial_name_label.add_theme_color_override(
		"font_color",
		Color("785a3d")
	)

	container.add_child(tutorial_name_label)

	tutorial_message_label = Label.new()

	tutorial_message_label.custom_minimum_size = (
		Vector2(0, 75)
	)

	tutorial_message_label.add_theme_font_override(
		"font",
		tutorial_font
	)

	tutorial_message_label.add_theme_font_size_override(
		"font_size",
		21
	)

	tutorial_message_label.add_theme_color_override(
		"font_color",
		Color("2e281f")
	)

	tutorial_message_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	tutorial_message_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	container.add_child(tutorial_message_label)

	tutorial_continue_label = Label.new()

	tutorial_continue_label.text = "Click to continue..."

	tutorial_continue_label.add_theme_font_override(
		"font",
		tutorial_font
	)

	tutorial_continue_label.add_theme_font_size_override(
		"font_size",
		16
	)

	tutorial_continue_label.add_theme_color_override(
		"font_color",
		Color("785a3d")
	)

	tutorial_continue_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	container.add_child(tutorial_continue_label)

	add_child(tutorial_bubble)


func update_fusion_training_tutorial() -> void:

	if tutorial_bubble == null:
		return

	match fusion_training_tutorial_step:

		0:
			tutorial_name_label.text = "Andrew"

			tutorial_message_label.text = (
				"These are your battle commands. "
				+ "I'll explain what each one does."
			)

			tutorial_continue_label.text = (
				"Click to continue..."
			)

		1:
			tutorial_name_label.text = "Andrew"

			tutorial_message_label.text = (
				"Attack lets you choose a move "
				+ "for your Atomon."
			)

			tutorial_continue_label.text = (
				"Click to continue..."
			)

		2:
			tutorial_name_label.text = "Andrew"

			tutorial_message_label.text = (
				"Fusion allows compatible Atomons "
				+ "to combine into a new substance."
			)

			tutorial_continue_label.text = (
				"Click to continue..."
			)

		3:
			tutorial_name_label.text = "Andrew"

			tutorial_message_label.text = (
				"Atomons lets you view and switch "
				+ "between the Atomons you have."
			)

			tutorial_continue_label.text = (
				"Click to continue..."
			)

		4:
			tutorial_name_label.text = "Andrew"

			tutorial_message_label.text = (
				"Run allows you to escape "
				+ "from a normal battle."
			)

			tutorial_continue_label.text = (
				"Click to continue..."
			)

		5:
			tutorial_name_label.text = "Andrew"

			tutorial_message_label.text = (
				"For this training, we'll focus on "
				+ "Fusion. Select Fusion when you're ready."
			)

			tutorial_continue_label.text = (
				"Select FUSION to continue."
			)


func advance_fusion_training_tutorial() -> void:

	if not fusion_training_tutorial_active:
		return

	if fusion_training_tutorial_step >= 5:
		return

	fusion_training_tutorial_step += 1

	update_fusion_training_tutorial()

	if fusion_training_tutorial_step == 5:

		var attack_button: TextureButton = ($CommandUI/GridContainer/Attack)
		var atomons_button: TextureButton = ($CommandUI/GridContainer/Atomons)
		var run_button: TextureButton = ($CommandUI/GridContainer/Run)

		attack_button.disabled = true
		atomons_button.disabled = true
		run_button.disabled = true

		fusion_button.disabled = false


func hide_fusion_training_tutorial() -> void:
	if tutorial_bubble != null:
		tutorial_bubble.visible = false

func _input(event: InputEvent):

	if not fusion_training_tutorial_active:
		return

	# ========================================================
	# STEPS 0-4
	# TAPS/CLICKS ADVANCE THE TUTORIAL
	# ========================================================

	if fusion_training_tutorial_step < 5:

		if event is InputEventScreenTouch:

			if event.pressed:

				advance_fusion_training_tutorial()
				get_viewport().set_input_as_handled()

		elif event is InputEventMouseButton:

			if (
				event.button_index == MOUSE_BUTTON_LEFT
				and event.pressed
			):

				advance_fusion_training_tutorial()
				get_viewport().set_input_as_handled()

		elif event is InputEventKey:

			if event.pressed and not event.echo:

				if (
					event.keycode == KEY_SPACE
					or event.keycode == KEY_ENTER
				):

					advance_fusion_training_tutorial()
					get_viewport().set_input_as_handled()

	# ========================================================
	# STEP 5
	# DO NOT CONSUME THE TOUCH/CLICK
	# FUSION BUTTON MUST RECEIVE IT
	# ========================================================

	else:

		return

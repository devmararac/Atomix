extends Control

# ============================================================
# CONSTANTS
# ============================================================
const BATTLE_SCALE := Vector2(10, 10)
const ATOMON_SCENE = preload("res://Atomons/Atomon.tscn")
const SWITCH_MENU = preload("res://Scenes/UI/switch_atomon.tscn")

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
# BATTLEFIELD
# ============================================================
@onready var enemy_container: Panel = ($BattleField/EnemyContainer)
@onready var enemy_spawn_point: Marker2D = ($BattleField/EnemyContainer/SpawnPoint)
@onready var friendly_container: Panel = ($BattleField/FriendlyAtomonContainer)
@onready var friendly_spawn_point: Marker2D = ($BattleField/FriendlyAtomonContainer/SpawnPoint)

# ============================================================
# ENEMY UI
# ============================================================
@onready var enemy_name_label: Label = ($CanvasLayer/HUD/EnemyAtomonInfo/EnemyAtomonName)
@onready var enemy_level_label: Label = ($CanvasLayer/HUD/EnemyAtomonInfo/EnemyAtomonLevel/EALevel)
@onready var enemy_hp_bar: TextureProgressBar = ($CanvasLayer/HUD/EnemyAtomonInfo/EnemyAtomonHP)
@onready var enemy_hp_text: Label = ($CanvasLayer/HUD/EnemyAtomonInfo/EnemyAtomonHPText)

# ============================================================
# PLAYER UI
# ============================================================
@onready var player_name_label: Label = ($CanvasLayer/HUD/FriendlyAtomonInfo/FriendlyAtomonName)
@onready var player_level_label: Label = (	$CanvasLayer/HUD/FriendlyAtomonInfo/FriendlyAtomonLevel/FALevel)
@onready var player_hp_bar: TextureProgressBar = ($CanvasLayer/HUD/FriendlyAtomonInfo/FriendlyAtomonHP)
@onready var player_hp_text: Label = ($CanvasLayer/HUD/FriendlyAtomonInfo/FriendlyAtomonHPText)
@onready var exp_bar: TextureProgressBar = ($CanvasLayer/HUD/FriendlyAtomonInfo/EXPBar)

# ============================================================
# BATTLE LOG
# ============================================================
@onready var battle_log: RichTextLabel = ($CanvasLayer/BattleLog)

# ============================================================
# MENUS
# ============================================================
@onready var command_ui: Control = ($CommandUI)
@onready var move_menu: PanelContainer = ($CanvasLayer/MoveMenu)

# ============================================================
# MOVE BUTTONS
# ============================================================
@onready var move_button_1: Button = ($CanvasLayer/MoveMenu/VBoxContainer/Move1)
@onready var move_button_2: Button = ($CanvasLayer/MoveMenu/VBoxContainer/Move2)
@onready var move_button_3: Button = ($CanvasLayer/MoveMenu/VBoxContainer/Move3)
@onready var move_button_4: Button = ($CanvasLayer/MoveMenu/VBoxContainer/Move4)

# ============================================================
# CURRENT MOVES
# ============================================================
var player_moves: Array[MoveData] = []

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	# --------------------------------------------------------
	# Get battle data
	# --------------------------------------------------------
	player_instance = (BattleManager.player_instance)
	enemy_data = (BattleManager.enemy_data)

	# --------------------------------------------------------
	# Validate player
	# --------------------------------------------------------
	if player_instance == null:
		push_error("BattleUI: Player Atomon is null.")
		battle_log.text = ("No Atomon is available for battle.")
		return

	# --------------------------------------------------------
	# Validate enemy
	# --------------------------------------------------------
	if enemy_data == null:
		push_error("BattleUI: Enemy Atomon is null.")
		battle_log.text = ("No enemy Atomon is available.")
		return

	# --------------------------------------------------------
	# Setup battle controller
	# --------------------------------------------------------
	BattleControllerGlobal.setup_battle(player_instance, enemy_data)

	# --------------------------------------------------------
	# Connect signals
	# --------------------------------------------------------
	connect_battle_controller_signals()

	# --------------------------------------------------------
	# Spawn Atomons
	# --------------------------------------------------------
	setup_player_atomon()
	setup_enemy_atomon()

	# --------------------------------------------------------
	# Setup UI
	# --------------------------------------------------------
	setup_player_ui()
	setup_enemy_ui()
	setup_move_buttons()
	update_hp_ui()
	
	# --------------------------------------------------------
	# Initial menu state
	# --------------------------------------------------------
	command_ui.visible = true
	move_menu.visible = false

	# --------------------------------------------------------
	# Initial message
	# --------------------------------------------------------
	battle_log.text = ("A wild " + enemy_data.atom_name + " appeared!")

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
	player_atomon = (ATOMON_SCENE.instantiate())
	friendly_container.add_child(player_atomon)
	player_atomon.position = (friendly_spawn_point.position)
	player_atomon.battle_mode = true
	player_atomon.setup(player_instance.data)
	player_atomon.scale = (BATTLE_SCALE)
	var player_sprite: AnimatedSprite2D = (player_atomon.get_node("AnimatedSprite2D"))
	# Player faces right
	player_sprite.flip_h = false
	player_start_position = (player_atomon.position)

# ============================================================
# SETUP ENEMY ATOMON
# ============================================================
func setup_enemy_atomon() -> void:
	enemy_atomon = (ATOMON_SCENE.instantiate())
	enemy_container.add_child(enemy_atomon)
	enemy_atomon.position = (enemy_spawn_point.position)
	enemy_atomon.battle_mode = true
	enemy_atomon.setup(enemy_data)
	enemy_atomon.scale = (BATTLE_SCALE)
	var enemy_sprite: AnimatedSprite2D = (enemy_atomon.get_node("AnimatedSprite2D"))

	# Enemy faces left
	enemy_sprite.flip_h = true
	enemy_start_position = (enemy_atomon.position)
	
# ============================================================
# SETUP PLAYER UI
# ============================================================
func setup_player_ui() -> void:
	player_name_label.text = (player_instance.data.atom_name)

	update_excited_ui()

# ============================================================
# SETUP ENEMY UI
# ============================================================

func setup_enemy_ui() -> void:
	enemy_name_label.text = (enemy_data.atom_name)
	enemy_level_label.text = "1"

# ============================================================
# SETUP MOVE BUTTONS
# ============================================================

func setup_move_buttons() -> void:
	player_moves = (player_instance.data.moves)

	# --------------------------------------------------------
	# Move 1
	# --------------------------------------------------------
	if player_moves.size() > 0:
		move_button_1.visible = true
		var label_1: Label = (
			move_button_1.get_node("Move1"))
		label_1.text = (player_moves[0].move_name)
	else:
		move_button_1.visible = false
		
	# --------------------------------------------------------
	# Move 2
	# --------------------------------------------------------
	if player_moves.size() > 1:
		move_button_2.visible = true
		var label_2: Label = (move_button_2.get_node("Move2"))
		label_2.text = (player_moves[1].move_name)
	else:
		move_button_2.visible = false
		
	# --------------------------------------------------------
	# Move 3
	# --------------------------------------------------------
	if player_moves.size() > 2:
		move_button_3.visible = true
		var label_3: Label = (move_button_3.get_node("Move3"))
		label_3.text = (player_moves[2].move_name)
	else:
		move_button_3.visible = false

	# --------------------------------------------------------
	# Move 4
	# --------------------------------------------------------
	if player_moves.size() > 3:
		move_button_4.visible = true
		var label_4: Label = (move_button_4.get_node("Move4"))
		label_4.text = (player_moves[3].move_name)
	else:
		move_button_4.visible = false

# ============================================================
# UPDATE HP UI
# ============================================================
func update_hp_ui() -> void:  
	var player_hp: int = (BattleControllerGlobal.get_player_hp())
	var player_max_hp: int = (BattleControllerGlobal.get_player_max_hp())
	
	var enemy_hp: int = (BattleControllerGlobal.get_enemy_hp())
	var enemy_max_hp: int = (BattleControllerGlobal.get_enemy_max_hp())

	# Player HP
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp
	player_hp_text.text = (str(player_hp) + "/" + str(player_max_hp))

	# Enemy HP
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp
	enemy_hp_text.text = (str(enemy_hp) + "/" + str(enemy_max_hp))

# ============================================================
# ATTACK BUTTON
# ============================================================
func _on_attack_pressed() -> void:
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

	if BattleControllerGlobal.get_player_pp(move_index) <= 0:
		battle_log.text = "No PP left for this move!"
		return

	var move: MoveData = (player_moves[move_index])
	move_menu.visible = false
	command_ui.visible = false

	# --------------------------------------------------------
	# Player attack animation
	# --------------------------------------------------------
	await animate_player_attack()
	battle_log.text = (player_instance.data.atom_name + " used " + move.move_name + "!")

	# --------------------------------------------------------
	# Execute move
	# --------------------------------------------------------
	BattleControllerGlobal.execute_move(move, true)
	BattleControllerGlobal.end_player_turn()
	await get_tree().create_timer(0.5).timeout
	update_hp_ui()

	# --------------------------------------------------------
	# Check enemy faint
	# --------------------------------------------------------
	if (BattleControllerGlobal.get_enemy_hp() <= 0):
		return

	# --------------------------------------------------------
	# Enemy turn
	# --------------------------------------------------------
	await get_tree().create_timer(0.8).timeout
	await enemy_turn()

# ============================================================
# PLAYER ATTACK ANIMATION
# ============================================================
func animate_player_attack() -> void:
	if player_atomon == null:
		return

	var tween := create_tween()
	tween.tween_property(player_atomon, "position", player_start_position + Vector2(150, 0), 0.15)
	tween.tween_property(player_atomon, "position", player_start_position, 0.15)
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

	var enemy_move: MoveData = (enemy_data.moves[randi() % enemy_data.moves.size()])
	await animate_enemy_attack()
	battle_log.text = (enemy_data.atom_name + " used " + enemy_move.move_name + "!")
	BattleControllerGlobal.execute_move(enemy_move, false)
	BattleControllerGlobal.end_enemy_turn()
	await get_tree().create_timer(0.5).timeout
	update_hp_ui()

	if (BattleControllerGlobal.get_player_hp() > 0):
		command_ui.visible = true

# ============================================================
# ENEMY ATTACK ANIMATION
# ============================================================
func animate_enemy_attack() -> void:
	if enemy_atomon == null:
		return

	var tween := create_tween()
	tween.tween_property(enemy_atomon, "position", enemy_start_position + Vector2(-150, 0), 0.15)
	tween.tween_property(enemy_atomon, "position", enemy_start_position, 0.15)
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
	battle_log.text = (player_instance.data.atom_name + " took " + str(amount) + " damage!")

# ============================================================
# ENEMY DAMAGED
# ============================================================
func _on_enemy_damaged(amount: int) -> void:
	battle_log.text = (enemy_data.atom_name + " took " + str(amount) + " damage!")

# ============================================================
# PLAYER HEALED
# ============================================================
func _on_player_healed(amount: int) -> void:

	battle_log.text = (player_instance.data.atom_name + " recovered " + str(amount) + " HP!")

# ============================================================
# ENEMY HEALED
# ============================================================
func _on_enemy_healed(amount: int) -> void:
	battle_log.text = (enemy_data.atom_name + " recovered " + str(amount) + " HP!")

# ============================================================
# PLAYER FAINTED
# ============================================================
func _on_player_fainted() -> void:
	battle_log.text = (player_instance.data.atom_name + " fainted!")
	command_ui.visible = false
	move_menu.visible = false
	await get_tree().create_timer(1.5).timeout

	if PartyManager.has_available_atomon():
		open_party_menu()
	else:
		battle_log.text = ("No Atomons left!")

		await get_tree().create_timer(1.0).timeout
		BattleManager.end_battle()
		command_ui.visible = false
		move_menu.visible = false

# ============================================================
# ENEMY FAINTED
# ============================================================
func _on_enemy_fainted() -> void:
	battle_log.text = (enemy_data.atom_name + " fainted!")
	command_ui.visible = false
	move_menu.visible = false

	# Save the player's current HP before ending the battle
	BattleControllerGlobal.save_player_hp()
	await get_tree().create_timer(1.5).timeout
	BattleManager.end_battle()

# ============================================================
# ATOMONS BUTTON
# ============================================================
func _on_atomons_pressed() -> void:
	open_party_menu()

# ============================================================
# OPEN PARTY MENU
# ============================================================
func open_party_menu() -> void:
	
	if switch_menu != null:
		return

	switch_menu = (SWITCH_MENU.instantiate())
	add_child(switch_menu)

	switch_menu.current_battle_atomon = player_instance
	switch_menu.force_switch = (BattleControllerGlobal.get_player_hp() <= 0)
	switch_menu.atomon_selected.connect(_on_atomon_selected)
	switch_menu.closed.connect(_on_switch_menu_closed )
	

# ============================================================
# ATOMON SELECTED
# ============================================================
func _on_atomon_selected(index: int) -> void:
	var force_switch: bool = (BattleControllerGlobal.get_player_hp() <= 0)
	await switch_atomon(index, force_switch)
	switch_menu = null
	
	# Show commands after switching
	command_ui.visible = true
	move_menu.visible = false
	
	
# ============================================================
# SWITCH ATOMON
# ============================================================
func switch_atomon(index: int, free_switch: bool = false) -> void:

	# Set the selected party slot as the active battle Atomon
	if !PartyManager.set_active_atomon(index):
		return

	# Get the new active Atomon
	player_instance = PartyManager.get_active_atomon()

	if player_instance == null:
		return

	# Update BattleController
	BattleControllerGlobal.switch_player_atomon(player_instance)

	# Refresh battle sprite and UI
	refresh_player()

	# Enemy attacks after a manual switch
	if !free_switch:
		await enemy_turn()

# ============================================================
# REFRESH PLAYER ATOMON
# ============================================================
func refresh_player() -> void:
	var new_player: AtomonInstance = player_instance

	if new_player == null:
		return
		
	battle_log.text = ( "Go! " + new_player.data.atom_name + "!")

	if player_atomon != null:
		player_atomon.queue_free()
		
	player_atomon = ATOMON_SCENE.instantiate()
	friendly_container.add_child(player_atomon)
	player_atomon.setup(new_player.data)
	player_atomon.battle_mode = true
	player_atomon.position = (friendly_spawn_point.position)
	player_atomon.scale = BATTLE_SCALE
	
	var player_sprite: AnimatedSprite2D = (player_atomon.get_node("AnimatedSprite2D"))
	player_sprite.flip_h = false
	player_start_position = (player_atomon.position)

	# Update UI
	player_name_label.text = (new_player.data.atom_name)
	
	var thresholds = StatCalculator.get_energy_thresholds(new_player.data)

	update_excited_ui()

	# Update moves
	player_moves = (new_player.data.moves)
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
	battle_log.text = ("You ran away!")
	# Save the HP the Atomon currently has
	BattleControllerGlobal.save_player_hp()
	await get_tree().create_timer(1.0).timeout
	BattleManager.end_battle()


func _on_close_button_pressed() -> void:
	move_menu.visible = false
	command_ui.visible = true

func update_excited_ui() -> void:

	var thresholds = StatCalculator.get_energy_thresholds(player_instance.data)

	player_level_label.text = "EX-" + str(player_instance.excited_state)

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

func _on_stats_changed() -> void:
	update_excited_ui()

func _on_excite_button_pressed() -> void:
	print("Excitement button pressed!")
	print("battle_controller = ", BattleControllerGlobal)

	BattleControllerGlobal.on_excitement_button_pressed()

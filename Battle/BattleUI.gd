extends Control

const BATTLE_SCALE := Vector2(10, 10)



@onready var enemy_container = $BattleField/EnemyContainer
@onready var player_container = $BattleField/FriendlyAtomonContainer

# ==========================
# HUD
# ==========================

@onready var enemy_hp_bar = $CanvasLayer/HUD/EnemyAtomonInfo/EnemyAtomonHP
@onready var player_hp_bar = $CanvasLayer/HUD/FriendlyAtomonInfo/FriendlyAtomonHP

@onready var enemy_hp_text = $CanvasLayer/HUD/EnemyAtomonInfo/EnemyAtomonHPText
@onready var player_hp_text = $CanvasLayer/HUD/FriendlyAtomonInfo/FriendlyAtomonHPText

#get name to display
@onready var enemy_name = $CanvasLayer/HUD/EnemyAtomonInfo/EnemyAtomonName
@onready var player_name = $CanvasLayer/HUD/FriendlyAtomonInfo/FriendlyAtomonName

@onready var enemy_level = $CanvasLayer/HUD/EnemyAtomonInfo/EnemyAtomonLevel/EALevel
@onready var player_level = $CanvasLayer/HUD/FriendlyAtomonInfo/FriendlyAtomonLevel/FALevel

@onready var exp_bar = $CanvasLayer/HUD/FriendlyAtomonInfo/EXPBar

@onready var player_spawn = $BattleField/FriendlyAtomonContainer/SpawnPoint
@onready var enemy_spawn = $BattleField/EnemyContainer/SpawnPoint

#for moves
@onready var move_menu = $CanvasLayer/MoveMenu

#for swtiching atomons
const SWITCH_MENU = preload("res://Scenes/UI/switch_atomon.tscn")

var switch_menu: CanvasLayer
# ==========================
# HP
# ==========================

var player_hp := 0
var player_max_hp := 0

var enemy_hp := 0
var enemy_max_hp := 0


# ==========================
# Cached Stats
# ==========================

var player_attack_stat := 0
var player_defense_stat := 0
var player_special_attack_stat := 0
var player_special_defense_stat := 0
var player_speed_stat := 0

var enemy_attack_stat := 0
var enemy_defense_stat := 0
var enemy_special_attack_stat := 0
var enemy_special_defense_stat := 0
var enemy_speed_stat := 0


# ==========================
# Battle Objects
# ==========================

var player_atomon: Node2D
var enemy_atomon: Node2D

var player_start_pos: Vector2
var enemy_start_pos: Vector2


func _ready() -> void:

	randomize()

	spawn_battle()

	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp

	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp

	update_hp_text()


func update_hp_text():

	player_hp_text.text = "%d/%d" % [player_hp, player_max_hp]
	enemy_hp_text.text = "%d/%d" % [enemy_hp, enemy_max_hp]


func spawn_battle():

	# ==========================
	# PLAYER
	# ==========================

	player_atomon = BattleManager.ATOMON_SCENE.instantiate()

	player_container.add_child(player_atomon)

	player_atomon.setup(BattleManager.player_instance.data)
	player_atomon.battle_mode = true

	player_atomon.position = player_spawn.position
	player_atomon.scale = BATTLE_SCALE

	var player_sprite = player_atomon.get_node("AnimatedSprite2D")
	player_sprite.flip_h = false

	player_start_pos = player_atomon.position


	# ==========================
	# ENEMY
	# ==========================

	enemy_atomon = BattleManager.ATOMON_SCENE.instantiate()

	enemy_container.add_child(enemy_atomon)

	enemy_atomon.setup(BattleManager.enemy_data)
	enemy_atomon.battle_mode = true

	enemy_atomon.position = enemy_spawn.position
	enemy_atomon.scale = BATTLE_SCALE

	var enemy_sprite = enemy_atomon.get_node("AnimatedSprite2D")
	enemy_sprite.flip_h = true

	enemy_start_pos = enemy_atomon.position


	# ==========================
	# Names / Levels
	# ==========================

	player_name.text = BattleManager.player_instance.data.atom_name
	enemy_name.text = BattleManager.enemy_data.atom_name

	player_level.text = str(BattleManager.player_instance.level)
	enemy_level.text = "1"


	# ==========================
	# EXP
	# ==========================

	exp_bar.max_value = 100
	exp_bar.value = BattleManager.player_instance.experience


	# ==========================
	# PLAYER STATS
	# ==========================

	player_max_hp = StatCalculator.get_hp(BattleManager.player_instance.data)

	player_hp = BattleManager.player_instance.current_hp

	if player_hp <= 0:
		player_hp = player_max_hp
		BattleManager.player_instance.current_hp = player_hp

	player_attack_stat = StatCalculator.get_attack(BattleManager.player_instance.data)
	player_defense_stat = StatCalculator.get_defense(BattleManager.player_instance.data)
	player_special_attack_stat = StatCalculator.get_special_attack(BattleManager.player_instance.data)
	player_special_defense_stat = StatCalculator.get_special_defense(BattleManager.player_instance.data)
	player_speed_stat = StatCalculator.get_speed(BattleManager.player_instance.data)


	# ==========================
	# ENEMY STATS
	# ==========================

	enemy_max_hp = StatCalculator.get_hp(BattleManager.enemy_data)
	enemy_hp = enemy_max_hp

	enemy_attack_stat = StatCalculator.get_attack(BattleManager.enemy_data)
	enemy_defense_stat = StatCalculator.get_defense(BattleManager.enemy_data)
	enemy_special_attack_stat = StatCalculator.get_special_attack(BattleManager.enemy_data)
	enemy_special_defense_stat = StatCalculator.get_special_defense(BattleManager.enemy_data)
	enemy_speed_stat = StatCalculator.get_speed(BattleManager.enemy_data)


func _on_attack_pressed() -> void:
	
	move_menu.visible = true

	if player_speed_stat >= enemy_speed_stat:

		await perform_player_attack()

		if enemy_hp > 0:
			await perform_enemy_attack()

	else:

		await perform_enemy_attack()

		if player_hp > 0:
			await perform_player_attack()


func perform_player_attack():

	var tween = create_tween()

	tween.tween_property(
		player_atomon,
		"position",
		player_start_pos + Vector2(150, 0),
		0.15
	)

	tween.tween_property(
		player_atomon,
		"position",
		player_start_pos,
		0.15
	)

	await tween.finished

	var move = BattleManager.player_instance.data.moves[0]

	var damage = calculate_damage(
	move,
	player_attack_stat,
	enemy_defense_stat
)

	damage_enemy(damage)



func perform_enemy_attack():

	var tween = create_tween()

	tween.tween_property(
		enemy_atomon,
		"position",
		enemy_start_pos + Vector2(-150, 0),
		0.15
	)

	tween.tween_property(
		enemy_atomon,
		"position",
		enemy_start_pos,
		0.15
	)

	await tween.finished

	var move = BattleManager.enemy_data.moves[0]
	var damage = calculate_damage(
	move,
	enemy_attack_stat,
	player_defense_stat
)

	damage_player(damage)

func damage_player(amount:int):

	player_hp = max(0, player_hp - amount)

	var tween = create_tween()
	tween.tween_property(player_hp_bar, "value", player_hp, 0.25)

	update_hp_text()

	if player_hp == 0:

		BattleManager.player_instance.current_hp = 0

		await get_tree().create_timer(1.0).timeout

		BattleManager.end_battle()


func damage_enemy(amount: int):

	enemy_hp = max(0, enemy_hp - amount)

	var tween = create_tween()
	tween.tween_property(enemy_hp_bar, "value", enemy_hp, 0.25)

	update_hp_text()

	if enemy_hp == 0:

		BattleManager.player_instance.current_hp = player_hp

		await get_tree().create_timer(1.0).timeout

		BattleManager.end_battle()


func _on_run_pressed() -> void:

	BattleManager.player_instance.current_hp = player_hp

	await get_tree().create_timer(1.0).timeout

	BattleManager.end_battle()

#for atomons switching
func _on_atomons_pressed():
		open_party_menu()
		

func open_party_menu():

	if switch_menu:
		return

	switch_menu = SWITCH_MENU.instantiate()
	add_child(switch_menu)

	switch_menu.atomon_selected.connect(_on_atomon_selected)
	switch_menu.closed.connect(_on_switch_menu_closed)
		
func switch_atomon(index:int) -> void:

	PartyManager.set_active_atomon(index)
	BattleManager.player_instance = PartyManager.get_active_atomon()

	refresh_player()

	# Switching costs your turn
	await perform_enemy_attack()
	
	
func refresh_player():

	player_atomon.queue_free()

	player_atomon = BattleManager.ATOMON_SCENE.instantiate()
	player_container.add_child(player_atomon)

	player_atomon.setup(BattleManager.player_instance.data)
	player_atomon.battle_mode = true
	player_atomon.position = player_spawn.position
	player_atomon.scale = BATTLE_SCALE
	player_atomon.get_node("AnimatedSprite2D").flip_h = false

	player_start_pos = player_atomon.position


	# HUD
	player_name.text = BattleManager.player_instance.data.atom_name
	player_level.text = str(BattleManager.player_instance.level)
	exp_bar.value = BattleManager.player_instance.experience

	# Stats
	player_max_hp = StatCalculator.get_hp(BattleManager.player_instance.data)
	player_hp = BattleManager.player_instance.current_hp

	player_attack_stat = StatCalculator.get_attack(BattleManager.player_instance.data)
	player_defense_stat = StatCalculator.get_defense(BattleManager.player_instance.data)
	player_special_attack_stat = StatCalculator.get_special_attack(BattleManager.player_instance.data)
	player_special_defense_stat = StatCalculator.get_special_defense(BattleManager.player_instance.data)
	player_speed_stat = StatCalculator.get_speed(BattleManager.player_instance.data)

	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp

	update_hp_text()


func _on_atomon_selected(index:int):

	switch_menu.queue_free()
	switch_menu = null

	switch_atomon(index)


func _on_switch_menu_closed():

	if switch_menu:
		switch_menu.queue_free()
		switch_menu = null


# For dmg Calculation
func calculate_damage(move: MoveData, attack:int, defense:int) -> int:

	var damage = move.power * ((attack + 50.0) / (defense + 50.0))

	damage *= randf_range(0.90, 1.10)

	if randf() <= 0.10:
		damage *= 1.5

	damage = clamp(damage, 5.0, move.power * 2.0)

	return roundi(damage)


func _on_move_1_pressed() -> void:
	pass # Replace with function body.


func _on_move_2_pressed() -> void:
	pass # Replace with function body.


func _on_move_3_pressed() -> void:
	pass # Replace with function body.


func _on_move_4_pressed() -> void:
	pass # Replace with function body.



func use_move(index:int):

	move_menu.visible = false

	var move = BattleManager.player_instance.data.moves[index]

	if move == null:
		return

	if player_speed_stat >= enemy_speed_stat:

		await perform_player_attack(move)

		if enemy_hp > 0:
			await perform_enemy_attack()

	else:

		await perform_enemy_attack()

		if player_hp > 0:
			await perform_player_attack(move)

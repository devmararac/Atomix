extends Node2D

@onready var player = $Player
@onready var player_camera := $Player/Camera2D
@onready var beryll = $Beryll
@onready var animation_player := $AnimationPlayer
@onready var cutscene_camera := $Camera2D
@onready var hud = $HUD
@onready var tutorial_ui = $Tutorial

@onready var eyelid = $CanvasLayer
@onready var player_cutscene_path = $PlayerCutscene
@onready var player_path = $PlayerCutscene/PathFollow2D
@onready var cutscene_start = $CutsceneStartPoint

const MOVEMENT_TUTORIAL := preload("res://Resources/Tutorials/movement.tres")


func _ready():
	$Player/Alert.visible = false
	$Beryll/Alert.visible = false
	eyelid.visible = true
	player.face_left()
	player.can_move = false
	
	hud.visible = false
	$"WALLS, PROPS/HOLE".visible = false
	
	await get_tree().process_frame

	var layout = NpcManager.interact(beryll)

	if layout == null:
		push_error("NpcManager returned a null layout.")
		return

	player.register_dialogic(layout)

	Dialogic.signal_event.connect(_on_dialogic_signal)
	QuestManager.quest_completed.connect(_on_quest_completed)


func _on_quest_completed(quest_id: String):
	if quest_id == "story_quest_explore_dungeon":
		move_player_to_location()


func move_player_to_location():
	hud.visible = false
	player.can_move = false

	# Follow player during cutscene movement
	player_camera.enabled = true
	cutscene_camera.enabled = false

	await walk_to_cutscene_start()

	await follow_cutscene_path()

	Dialogic.start("beryll_introduction")
	print("Camera final position:", player_camera.global_position)


# First: player walks normally to the path starting point
func walk_to_cutscene_start():
	player.is_cutscene_moving = true
	player.anim.play("walk")

	var tween = create_tween()

	tween.tween_property(
		player,
		"global_position",
		cutscene_start.global_position,
		1.5
	)

	await tween.finished
	
	player.is_cutscene_moving = false
	player.anim.play("idle")


# Second: player follows Path2D
func follow_cutscene_path():
	hud.visible = false
	player.is_cutscene_moving = true
	player.anim.play("walk")

	player_path.progress = 0

	var tween = create_tween()

	tween.tween_method(
		move_player_along_path,
		0.0,
		player_cutscene_path.curve.get_baked_length(),
		3.0
	)

	await tween.finished

	player.is_cutscene_moving = false
	player.anim.play("idle")


func move_player_along_path(distance):

	var previous_position = player.global_position

	player_path.progress = distance
	player.global_position = player_path.global_position

	if player.global_position.x < previous_position.x:
		player.face_left()

	elif player.global_position.x > previous_position.x:
		player.face_right()
	

# Use Cutscene Camera
func use_cutscene_camera():
	player_camera.enabled = false
	cutscene_camera.enabled = true

func walk_player_to_beryll():
	player.is_cutscene_moving = true
	player.anim.play("walk")

	var tween = create_tween()
	tween.tween_property(
		player,
		"global_position",
		$FrontGate.global_position, # Marker2D where you want the player to stop
		2.0
	)

	await tween.finished

	player.is_cutscene_moving = false
	player.anim.play("idle")

# Return To MAIN Camera
func return_to_player_camera():
	cutscene_camera.enabled = false
	player_camera.enabled = true
	print("Camera final position:", cutscene_camera.global_position)

func walk_beryll():
	beryll.sprite.play("walk")

	var tween = create_tween()
	tween.tween_property(
		beryll,
		"global_position",
		$BeryllPath.global_position,
		2.0
	)

	await tween.finished

	beryll.sprite.play("idle")

func _on_dialogic_signal(arg: String):
	match arg:

		"open_eyes":
			animation_player.play("open_eyes")


		"open_eyes_complete":
			animation_player.play("open_eyes_complete")

		"pan_camera":
			use_cutscene_camera()

			animation_player.play("pan_camera")

			await animation_player.animation_finished

			return_to_player_camera()


		"look_around":
			use_cutscene_camera()

			animation_player.play("look_around")

			await animation_player.animation_finished

			return_to_player_camera()


		"show_hud":
			hud.visible = true
			tutorial_ui.show_tutorial(MOVEMENT_TUTORIAL)


		"explore_the_area":
			QuestManager.start_story_quest("story_quest_explore_dungeon")
		
		"beryll_entrance_atomonia":
			hud.visible = false
			use_cutscene_camera()
			
			animation_player.play("camera_001")
			await animation_player.animation_finished
			
			await walk_player_to_beryll()
			Dialogic.start("beryll_introduction2")
			
		"player_reaction":
			player.is_playing_cutscene_animation = true
			$Player/Alert.visible = true
			SfxManager.alert()
			player.anim.play("jump")
			await get_tree().create_timer(1.0).timeout
			$Player/Alert.visible = false
			player.is_playing_cutscene_animation = false
		
		"beryll_reaction":
			$Beryll/Alert.visible = true
			SfxManager.alert()
			
			await get_tree().create_timer(1.0).timeout
			$Beryll/Alert.visible = false
		
		"beryll_walk":
			await walk_beryll()
		
		"debug":
			get_tree().change_scene_to_file("res://Scenes/Areas/start_map.tscn")

func _on_touch_screen_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Areas/start_map.tscn")

func _on_touch_screen_button_2_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Admin/teacher_dashboard.tscn")

extends Node2D

@onready var professor := $"WALL, PROPS/Prof_Andrew"
@onready var hydrogen_icon = $"WALL, PROPS/Garry/HydrogenIcon"
@onready var animation_player := $AnimationPlayer
@onready var emote = $"WALL, PROPS/Player/Emote"
@onready var blur_material: ShaderMaterial = $CanvasLayer/BlurOverlay.material
@onready var world_bus := AudioServer.get_bus_index("World")
@onready var voice_player: AudioStreamPlayer = $VoicePlayer

var prof_footstep_timer := 0.0
const PROF_FOOTSTEP_INTERVAL := 0.35

var follow_professor := false
var voices: Dictionary = {}
var voice_playing := false

func _ready():
	_load_voices("res://Assets/Music/VoiceOvers/ProfAndrew/ClassroomCutscene/")
	hydrogen_icon.visible = false
	emote.visible = false
	await get_tree().process_frame
	var layout = NpcManager.interact(professor)
	$"WALL, PROPS/Felix".register_dialogic(layout)
	$"WALL, PROPS/Anne".register_dialogic(layout)
	$"WALL, PROPS/Garry".register_dialogic(layout)
	$"WALL, PROPS/Player".register_dialogic(layout)
	
	Dialogic.signal_event.connect(_on_dialogic_signal)

func _load_voices(folder_path: String):
	var dir := DirAccess.open(folder_path)

	if dir == null:
		push_error("Couldn't open %s" % folder_path)
		return
	
	dir.list_dir_begin()

	while true:
		var file := dir.get_next()

		if file == "":
			break

		if dir.current_is_dir():
			continue

		if file.ends_with(".ogg") or file.ends_with(".wav") or file.ends_with(".mp3"):
			var id := file.get_basename()
			voices[id] = load(folder_path.path_join(file))

	dir.list_dir_end()

func _play_voice(id: String):
	var stream: AudioStream = voices.get(id)
	if stream == null:
		push_warning("Voice '%s' not found." % id)
		return

	voice_playing = true

	voice_player.stream = stream
	voice_player.play()

	await voice_player.finished

	voice_playing = false

func _process(delta):

	if follow_professor:
		$Camera2D.global_position = $Camera2D.global_position.lerp(
			professor.global_position,
			6.0 * delta
		)
	
	play_professor_footsteps(delta)

func play_professor_footsteps(delta):
	var sfx: AudioStreamPlayer = professor.get_node("Walk SFX")

	if !follow_professor:
		prof_footstep_timer = 0.0
		return

	prof_footstep_timer += delta

	if prof_footstep_timer >= PROF_FOOTSTEP_INTERVAL:
		prof_footstep_timer = 0.0
		sfx.play()

func _on_dialogic_signal(arg: String):
	if arg.begins_with("voice:"):
		_play_voice(arg.trim_prefix("voice:"))
		return
	
	match arg:
		
		"camera_professor":
			animation_player.play("camera_professor")
		
		"camera_felix":
			animation_player.play("camera_felix")
		
		"camera_anne":
			animation_player.play("camera_anne")
		
		"camera_garry":
			animation_player.play("camera_garry")

		"camera_return":
			animation_player.play("camera_return")

		"prof_write_hydrogen":
			var sprite := professor.get_node("NpcSprite")
			var sfx := professor.get_node("SFX")
			
			sprite.speed_scale = 5.0
			sprite.play("doing")
			
			sfx.play()
			await get_tree().create_timer(1.3).timeout
			sfx.stop()
			
			hydrogen_icon.visible = true
			sprite.speed_scale = 1.0
			sprite.play("idle")
		
		"player_sleepy":
			world_sleepy()
			emote.position = Vector2(18.0, -22.0)
			emote.visible = true
			emote.play("sleepy")
		
		"Audio":
			animation_player.play("audio")
		
		"vision_start":

			animation_player.play("vision_start")
			
			var tween = create_tween()

			tween.tween_property(
				blur_material,
				"shader_parameter/blur_strength",
				2.0,
				0.25
			)

			tween.tween_property(
				blur_material,
				"shader_parameter/blur_strength",
				0.5,
				0.20
			)

			tween.tween_property(
				blur_material,
				"shader_parameter/blur_strength",
				2.5,
				0.25
			)

			tween.tween_property(
				blur_material,
				"shader_parameter/blur_strength",
				1.0,
				0.20
			)

		"blur_more":
			var tween = create_tween()

			tween.tween_property(
				blur_material,
				"shader_parameter/blur_strength",
				5.0,
				1.25
			)

			tween.tween_property(
				blur_material,
				"shader_parameter/blur_strength",
				1.5,
				1.20
			)

			tween.tween_property(
				blur_material,
				"shader_parameter/blur_strength",
				3.0,
				0.75
			)

			tween.tween_property(
				blur_material,
				"shader_parameter/blur_strength",
				2.0,
				1.20
			)
		
		"dim_more":
			animation_player.play("dim_more")
		
		"black_screen":
			animation_player.play("black_screen")
			
		"teleport_atomonia":
			get_tree().change_scene_to_file("res://Scenes/Cutscenes/atomonia_entrance.tscn")
			
		"prof_walk_to_player":
			Dialogic.paused = true

			follow_professor = true

			var cam_tween := create_tween()
			cam_tween.set_parallel(true)

			# Zoom in while following the professor
			cam_tween.tween_property($Camera2D, "zoom", Vector2(10, 10), 0.5)

			professor.walk_to($"WALL, PROPS/Player".global_position)

			await professor.destination_reached

			follow_professor = false

			Dialogic.paused = false

func world_normal():
	AudioServer.set_bus_volume_db(world_bus, 0.0)

func world_sleepy():
	var tween := create_tween()

	tween.tween_method(
		func(v):
			AudioServer.set_bus_volume_db(world_bus, v),
		0.0,
		-10.0,
		1.5
	)

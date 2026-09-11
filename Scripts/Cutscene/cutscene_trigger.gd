extends Area2D

@export_file("*.dtl") var cutscene_timeline: String
@export var trigger_once: bool = true

@export_category("Cutscene")
@export var npc: NPCBase
@export var cutscene_camera: Camera2D
@export var camera_pan_duration := 1.0

@export_category("Cutscene Atomon")
@export var cutscene_atomon: CharacterBody2D
@export var cutscene_atomon_target: Marker2D

@export_category("Cutscene Targets")
@export var player_target: Marker2D
@export var npc_target: Marker2D

@export_category("HUD")
@export var hud: CanvasLayer

var triggered := false
var dialogic_layout


func _ready():
	body_entered.connect(_on_body_entered)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_on_cutscene_finished)

func _on_body_entered(body):
	
	print("CUTSCENE TRIGGER ENTERED BY: ", body.name)
	print("Player groups: ", body.get_groups())
	
	if triggered and trigger_once:
		return
	
	if not body.is_in_group("Player"):
		return
	
	triggered = true
	
	if cutscene_timeline == "":
		push_warning("CutsceneTrigger has no timeline assigned.")
		return
	
	if global.player != null:
		global.player.can_move = false
	
	if hud != null:
		hud.visible = false
	
	if cutscene_camera != null:
		await pan_to_cutscene_camera()
	
	dialogic_layout = Dialogic.start(cutscene_timeline)
	
	if npc != null:
		var bubble_marker = npc.get_node_or_null("BubbleMarker")

		if bubble_marker != null:
			dialogic_layout.register_character(
				npc.data.dialogic_character,
				bubble_marker
			)
		
	if global.player and global.player.has_method("register_dialogic"):
		global.player.register_dialogic(dialogic_layout)
	
	await get_tree().process_frame

func pan_to_cutscene_camera():
	var player_camera: Camera2D = global.player.get_node("Camera2D")

	if npc == null:
		push_warning("CutsceneTrigger has no NPC assigned.")
		return

	var target_position := npc.global_position

	cutscene_camera.global_position = player_camera.global_position
	cutscene_camera.zoom = player_camera.zoom

	cutscene_camera.enabled = true
	player_camera.enabled = false

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		cutscene_camera,
		"global_position",
		target_position,
		camera_pan_duration
	)

	await tween.finished


func _on_dialogic_signal(arg: String) -> void:
	print("=== DIALOGIC SIGNAL ===")
	print("Received signal: ", arg)

	# NPC EMOTE
	if arg.begins_with("emote:"):
		print("Emote signal detected!")

		var parts := arg.split(":")

		if parts.size() >= 3:
			var npc_name := parts[1]
			var emote_name := parts[2]

			print("NPC name: ", npc_name)
			print("Emote name: ", emote_name)

			# Use the NPC assigned to this CutsceneTrigger
			if npc == null:
				print("ERROR: No NPC assigned to CutsceneTrigger.")
				return

			print("NPC assigned: ", npc.name)
			print("Playing emote: ", emote_name)

			npc.play_emote(emote_name)

		return

	match arg:
		"player_move_to_target":
			if global.player != null and player_target != null:
				await global.player.move_to_cutscene_target(player_target)

		"player_face_npc":
			if global.player != null and npc != null:
				global.player.face_npc(npc)

		"npc_move_to_target":
			if npc != null and npc_target != null:
				await move_npc_to_target()

		"atomon_walk":
			if cutscene_atomon != null and cutscene_atomon_target != null:
				cutscene_atomon.move_to_cutscene_target(cutscene_atomon_target)

func _on_cutscene_finished():
	if not triggered:
		return

	# Return camera control to player
	if global.player != null:
		var player_camera: Camera2D = global.player.get_node("Camera2D")

		if cutscene_camera != null:
			cutscene_camera.enabled = false

		player_camera.enabled = true

	# Show HUD again
	if hud != null:
		hud.visible = true

	# Restore player control
	if global.player != null:
		global.player.can_move = true
		global.player.is_cutscene_moving = false
		global.player.velocity = Vector2.ZERO

	print("Cutscene finished.")

func move_npc_to_target():
	if npc == null or npc_target == null:
		return

	npc.walk_to(npc_target.global_position)

	await npc.destination_reached

extends Area2D
class_name SceneTrigger

@export var target_scene: String
@export var target_spawn: String
@export var area_target_id: String = ""

func _on_body_entered(body: Node2D) -> void:
	print("[SceneTrigger] Body entered: ", body.name)

	if body is Player:
		print("[SceneTrigger] Player entered trigger: ", name)
		print("[SceneTrigger] Area Target ID: ", area_target_id)

		if not body.can_use_doors:
			print("[SceneTrigger] Player cannot use doors.")
			return

		# Notify an AREA quest objective if this trigger has one.
		if area_target_id != "":
			print("[SceneTrigger] Notifying AREA objective: ", area_target_id)

			QuestManager.notify(
				ObjectiveType.Type.AREA,
				area_target_id
			)

		global.spawn_point_name = target_spawn
		run_transition(target_scene)

func run_transition(scene_path: String) -> void:
	await FadeLayer.fade_out()
	await get_tree().process_frame
	get_tree().call_deferred("change_scene_to_file", target_scene)
	await FadeLayer.fade_in()

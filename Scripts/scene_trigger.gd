extends Area2D
class_name SceneTrigger

@export var target_scene: String
@export var target_spawn: String

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if not body.can_use_doors:
			return

		global.spawn_point_name = target_spawn
		run_transition(target_scene)

func run_transition(scene_path: String) -> void:
	await FadeLayer.fade_out()
	await get_tree().process_frame
	get_tree().call_deferred("change_scene_to_file", target_scene)
	await FadeLayer.fade_in()

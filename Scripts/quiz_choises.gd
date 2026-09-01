extends CanvasLayer


const MULTIPLE_CHOICE_CREATOR = preload("res://Scenes/Admin/Teacher/quiz_creator.tscn")

const IDENTIFICATION_CREATOR = preload("res://Scenes/Admin/Teacher/identification_creator.tscn")

const ENUMERATION_CREATOR = preload("res://Scenes/Admin/Teacher/enumeration_creator.tscn")

const TRUE_FALSE_CREATOR = preload("res://Scenes/Admin/Teacher/true_false_creator.tscn")


func _on_multiple_choices_pressed() -> void:
	_open_creator(MULTIPLE_CHOICE_CREATOR)


func _on_identification_pressed() -> void:
	_open_creator(IDENTIFICATION_CREATOR)


func _on_enumeration_pressed() -> void:
	_open_creator(ENUMERATION_CREATOR)


func _on_true_false_pressed() -> void:
	_open_creator(TRUE_FALSE_CREATOR)


func _open_creator(creator_scene: PackedScene) -> void:
	var creator := creator_scene.instantiate()

	get_tree().current_scene.add_child(creator)

	queue_free()

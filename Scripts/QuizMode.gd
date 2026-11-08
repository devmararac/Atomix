extends Node

const QUIZ_CHOICES = preload(
	"res://Scenes/Admin/Teacher/quiz_choises.tscn"
)


func _ready() -> void:
	pass


func _on_create_quiz_pressed() -> void:
	var choices := QUIZ_CHOICES.instantiate()

	get_tree().current_scene.add_child(choices)

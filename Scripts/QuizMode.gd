extends Node
const QUIZ_CREATOR = preload("res://Scenes/Admin/quiz_creator.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_create_quiz_pressed() -> void:
	var creator := QUIZ_CREATOR.instantiate()
	get_tree().current_scene.add_child(creator)

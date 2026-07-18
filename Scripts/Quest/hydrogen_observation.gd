extends CharacterBody2D

@export var target_id := "hydrogen"
@export var dialogue_timeline := "observe_hydrogen"

var observed := false

func _ready() -> void:
	$Highlight.visible = false

func interact():

	if observed:
		return

	observed = true

	Dialogic.start(dialogue_timeline)
	global.player.can_move = false

func is_objective_complete() -> bool:
	return observed

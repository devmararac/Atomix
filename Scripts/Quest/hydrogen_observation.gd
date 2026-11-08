extends CharacterBody2D

@export var target_id := "hydrogen"
@export var dialogue_timeline := "observe_hydrogen"
@export var dialogic_character: DialogicCharacter
@onready var bubble_marker := $BubbleMarker

var observed := false

func _ready() -> void:
	$Highlight.visible = false

func interact():

	if observed:
		return

	observed = true

	var layout = Dialogic.start(dialogue_timeline)

	register_dialogic(layout)

	if global.player:
		global.player.register_dialogic(layout)

	QuestManager.notify(
		ObjectiveType.Type.OBSERVE,
		target_id
	)
	global.player.can_move = false

func register_dialogic(layout):
	layout.register_character(dialogic_character, bubble_marker)

func is_objective_complete() -> bool:
	return observed

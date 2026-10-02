extends StaticBody2D


func _ready() -> void:
	$Highlight.visible = false


func interact() -> void:
	print("EXPERIMENT STATION INTERACTED")

	# Complete the Conduct Experiment objective
	QuestManager.notify(
		ObjectiveType.Type.INTERACT,
		"experiment_station"
	)

extends Area2D

@export var target_id: String


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):

	print("AREA ENTERED BY:", body.name)
	print("AREA TARGET:", target_id)

	if not body.is_in_group("Player"):
		print("NOT PLAYER")
		return

	print("CALLING QUEST MANAGER")

	QuestManager.notify(
		ObjectiveType.Type.AREA,
		target_id
	)

	print("NOTIFY FINISHED")

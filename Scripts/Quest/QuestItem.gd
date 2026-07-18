@tool
extends Area2D

@onready var sprite_2d = $Sprite2D
@onready var indicator: AnimatedSprite2D = $Indicator

@export var item_id: String = ""
@export var item_quan: int = 1
@export var item_icon: Texture2D
@export var target_id: String

func _ready() -> void:
	if not Engine.is_editor_hint():
		sprite_2d.texture = item_icon
		indicator.visible = false
		indicator.play("bounce")
		$Highlight.visible = false


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		sprite_2d.texture = item_icon
		return

	sprite_2d.texture = item_icon

	indicator.visible = should_show_indicator()


func should_show_indicator() -> bool:
	var quest = QuestManager.selected_quest

	if quest == null:
		return false

	for objective in quest.objectives:
		if objective.target_type == "collection" \
		and objective.target_id == item_id \
		and !objective.is_completed:
			return true

	return false

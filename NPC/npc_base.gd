extends CharacterBody2D
class_name NPCBase

@export var data: NPCData

@onready var sprite = $NpcSprite
@onready var indicator = $NpcSprite/Indicator
@onready var BubbleMarker = $BubbleMarker
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@export var show_navigation_path := false

signal destination_reached

var is_moving := false
var debug_path: PackedVector2Array = []

func _ready():
	setup_npc()
	$Highlight.visible = false

func setup_npc():

	if data == null:
		push_warning("NPCData missing.")
		return

	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
		sprite.play("idle")

	sprite.flip_h = data.facing_direction == NPCData.FacingDirection.LEFT

func interact():
	NpcManager.interact(self)

func show_indicator():
	indicator.visible = true

func hide_indicator():
	indicator.visible = false

func _physics_process(_delta):

	if !is_moving:
		return

	if navigation_agent.is_navigation_finished():
		is_moving = false
		velocity = Vector2.ZERO
		sprite.play("idle")
		destination_reached.emit()
		return

	var next_position = navigation_agent.get_next_path_position()
	debug_path = navigation_agent.get_current_navigation_path()
	if show_navigation_path:
		queue_redraw()
	
	var direction = (next_position - global_position).normalized()

	velocity = direction * data.move_speed
	move_and_slide()

	sprite.play("walking")
	sprite.flip_h = velocity.x < 0

func walk_to(target: Vector2):
	navigation_agent.target_position = target
	is_moving = true


func _draw():

	if !show_navigation_path:
		return

	if debug_path.size() < 2:
		return

	for i in range(debug_path.size() - 1):
		draw_line(
			to_local(debug_path[i]),
			to_local(debug_path[i + 1]),
			Color.RED,
			2.0
		)

	for point in debug_path:
		draw_circle(to_local(point), 4, Color.YELLOW)

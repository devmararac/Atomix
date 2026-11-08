extends CharacterBody2D

@export var npc_name: String
@export var target_id: String


const speed = 30
var current_state = IDLE

var dir = Vector2.RIGHT
var start_pos

var is_roaming = true
var is_chatting = false

var player
var player_in_chat_zone = false

enum {
	IDLE,
	NEW_DIR,
	MOVE
}

func _ready() -> void:
	randomize()
	start_pos = position

func _process(delta: float) -> void:
	if current_state == 0 or current_state == 1:
		$AnimatedSprite2D.play("idle")
	elif current_state == 2 and !is_chatting:
		$AnimatedSprite2D.play("walk")
		if dir.x < 0:
			$AnimatedSprite2D.flip_h = true
		elif dir.x > 0:
			$AnimatedSprite2D.flip_h = false
			
	if is_roaming:
		match current_state:
			IDLE:
				velocity = velocity.move_toward(Vector2.ZERO, 20)
			NEW_DIR:
				dir = choose ([Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN])
			MOVE:
				move(delta)

func choose(array):
	array.shuffle()
	return array.front()

func move(delta):
	if !is_chatting:
		velocity = dir * speed

func _physics_process(delta: float) -> void:
	move_and_collide(velocity * delta)

	
func _on_chat_detection_area_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player = body
		player_in_chat_zone = true


func _on_chat_detection_area_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_in_chat_zone = false


func _on_timer_timeout() -> void:
	$Timer.wait_time = choose([0.5, 1, 1.5])
	current_state = choose([IDLE, NEW_DIR, MOVE])

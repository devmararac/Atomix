extends RigidBody3D
class_name ElementObject

@export var spawn_position: Vector3 = Vector3(0, 15, 0)
@export var despawn_height: float = -30.0
@export var despawn_distance_x: float = 40.0

var is_held: bool = false
var _respawning: bool = false


func _ready() -> void:
	gravity_scale = 1.0
	global_position = spawn_position


func _physics_process(_delta: float) -> void:
	if is_held or _respawning:
		return

	if global_position.y < despawn_height \
	or absf(global_position.x) > despawn_distance_x:
		_respawn()


func _respawn() -> void:
	_respawning = true
	freeze = true

	global_position = spawn_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	freeze = false
	_respawning = false

extends Node3D

@onready var hand_gesture_controller = $HandGestureController

func _ready() -> void:
	CameraSource.start()
	
	if hand_gesture_controller:
		hand_gesture_controller.right_hand_double_pinch.connect(_on_right_hand_double_pinch)

func _on_right_hand_double_pinch() -> void:
	print("[GDMP] Right hand double pinch - Exiting and loading save.")
	
	# 1. Stop the camera
	CameraSource.stop()
	
	# 2. Load the save file (which will change the scene to the game world)
	await SaveManager.load_game()

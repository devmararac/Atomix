extends Resource
class_name AtomonInstance

# Species
@export var data: AtomonData

# Progress
@export var level: int = 1
@export var experience: int = 0

# Battle
@export var current_hp: int = 0
@export var electron_energy: int = 0

# Status
@export var is_active := false
@export var nickname := ""

# Future
@export var individual_values := {}
@export var effort_values := {}
@export var learned_moves: Array[MoveData] = []

# Unique ID
@export var instance_id := ""

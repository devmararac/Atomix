extends Resource
class_name AtomonInstance

# Species
@export var data: AtomonData



# Battle
@export var current_hp: int = 0
@export var electron_energy: int = 0 #xp
@export var excited_state := 0 # level
@export var active_excited_state := 0

# Status
@export var is_active := false
@export var nickname := ""

# Future
@export var individual_values := {}
@export var effort_values := {}
@export var learned_moves: Array[MoveData] = []

# Unique ID
@export var instance_id := ""

#moves (PP)
@export var current_pp: Array[int] = []


#moves (PP)
func initialize(atomon_data: AtomonData) -> void:
	data = atomon_data

	current_hp = StatCalculator.get_hp(data)

	# Only initialize PP if this is a brand new Atomon
	if current_pp.is_empty():
		for move in data.moves:
			current_pp.append(move.max_uses)

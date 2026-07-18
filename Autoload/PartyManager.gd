extends Node

# All Atomons the player currently owns
var party: Array[AtomonInstance] = []

# Which Atomon is currently active
var active_index: int = 0


func _ready() -> void:
	pass

func remove_atomon(index: int) -> void:
	if index >= 0 and index < party.size():
		party.remove_at(index)

func add_species(species: AtomonData) -> AtomonInstance:
	var instance := AtomonInstance.new()

	instance.data = species
	instance.level = 1
	instance.current_hp = StatCalculator.get_hp(species)
	party.append(instance)

	return instance

func get_active_atomon() -> AtomonInstance:
	if party.is_empty():
		return null

	return party[active_index]


func set_active_atomon(index: int) -> void:
	if index >= 0 and index < party.size():
		active_index = index


func get_party() -> Array[AtomonInstance]:
	return party

extends Node


# ============================================================
# PARTY LIMITS
# ============================================================

const MAX_PARTY_SIZE: int = 15
const MAX_BATTLE_PARTY_SIZE: int = 5


# ============================================================
# PARTY DATA
# ============================================================

var party: Array[AtomonInstance] = []

# The Atomon currently active in battle
var active_index: int = 0


# ============================================================
# ADD ATOMON
# ============================================================

func add_species(species: AtomonData) -> AtomonInstance:

	if species == null:
		push_error("PartyManager: Cannot add a null species.")
		return null

	if party.size() >= MAX_PARTY_SIZE:
		push_warning("Party is full.")
		return null

	var instance: AtomonInstance = AtomonInstance.new()
	instance.initialize(species)
	party.append(instance)
	return instance

# ============================================================
# LOAD SAVED PARTY FROM STUDENT DATA
# ============================================================

func load_saved_party() -> void:

	party.clear()
	active_index = 0

	var symbols: Array[String] = StudentDataManager.get_collected_elements()

	print("[PartyManager] Loading saved Atomons...")
	print("[PartyManager] Saved elements: ", symbols)

	for symbol in symbols:

		if not AtomonDatabase.ELEMENTS.has(symbol):
			print("[PartyManager] No element data for: ", symbol)
			continue

		var species: AtomonData = AtomonDatabase.ELEMENTS[symbol]

		if species == null:
			print("[PartyManager] Null species data for: ", symbol)
			continue

		var atomon := add_species(species)

		if atomon != null:
			print(
				"[PartyManager] Restored: ",
				symbol,
				" -> ",
				species.atom_name
			)

	print(
		"[PartyManager] Party restored: ",
		party.size(),
		"/",
		MAX_PARTY_SIZE
	)


# ============================================================
# REMOVE ATOMON
# ============================================================

func remove_atomon(index: int) -> void:

	if index < 0 or index >= party.size():
		return

	party.remove_at(index)

	if party.is_empty():
		active_index = 0

	elif active_index >= party.size():
		active_index = party.size() - 1


# ============================================================
# GET ACTIVE ATOMON
# ============================================================

func get_active_atomon() -> AtomonInstance:

	if party.is_empty():
		return null

	if active_index < 0 or active_index >= party.size():
		active_index = 0
	
	print("Current active index:", active_index)
	print("Returning:", party[active_index].data.atom_name)
	
	return party[active_index]


# ============================================================
# SET ACTIVE ATOMON
# ============================================================

func set_active_atomon(index: int) -> bool:

	print("Setting active index to:", index)

	if index < 0 or index >= party.size():
		return false

	if index >= MAX_BATTLE_PARTY_SIZE:
		return false

	var selected_atomon: AtomonInstance = party[index]

	if selected_atomon == null:
		return false

	if selected_atomon.current_hp <= 0:
		return false

	active_index = index

	print("Now active is:", party[active_index].data.atom_name)

	return true


# ============================================================
# GET FULL PARTY
# ============================================================

func get_party() -> Array[AtomonInstance]:

	return party


# ============================================================
# GET BATTLE PARTY
# ============================================================

func get_battle_party() -> Array[AtomonInstance]:

	var battle_party: Array[AtomonInstance] = []

	var battle_party_count: int = mini(
		MAX_BATTLE_PARTY_SIZE,
		party.size()
	)

	for i: int in range(battle_party_count):

		if party[i] != null:
			battle_party.append(party[i])

	return battle_party


# ============================================================
# GET RESERVE PARTY
# ============================================================

func get_reserve_party() -> Array[AtomonInstance]:

	var reserve_party: Array[AtomonInstance] = []

	for i: int in range(
		MAX_BATTLE_PARTY_SIZE,
		party.size()
	):

		reserve_party.append(party[i])

	return reserve_party


# ============================================================
# CHECK IF ATOMON IS IN BATTLE PARTY
# ============================================================

func is_in_battle_party(index: int) -> bool:

	if index < 0 or index >= party.size():
		return false

	return index < MAX_BATTLE_PARTY_SIZE


# ============================================================
# SWAP TWO ATOMON POSITIONS
# ============================================================

func swap_atomon_positions(index_a: int, index_b: int) -> bool:

	if index_a < 0 or index_a >= party.size():
		return false

	if index_b < 0 or index_b >= party.size():
		return false

	if index_a == index_b:
		return false

	var temp: AtomonInstance = party[index_a]
	party[index_a] = party[index_b]
	party[index_b] = temp

	# The first slot is always the lead outside battle.
	active_index = 0

	return true


# ============================================================
# CHECK AVAILABLE ATOMON IN BATTLE PARTY
# ============================================================

func has_available_atomon() -> bool:

	var battle_party_count: int = mini(
		MAX_BATTLE_PARTY_SIZE,
		party.size()
	)

	for i: int in range(battle_party_count):

		if party[i] != null and party[i].current_hp > 0:
			return true

	return false


# ============================================================
# CHECK AVAILABLE ATOMON EXCEPT ACTIVE
# ============================================================

func has_available_battle_atomon_except_active() -> bool:

	var battle_party_count: int = mini(
		MAX_BATTLE_PARTY_SIZE,
		party.size()
	)

	for i: int in range(battle_party_count):

		if i == active_index:
			continue

		if party[i] != null and party[i].current_hp > 0:
			return true

	return false


func has_species(species: AtomonData) -> bool:
	if species == null:
		return false

	for atomon in party:
		if atomon == null:
			continue

		if atomon.data == species:
			return true

	return false

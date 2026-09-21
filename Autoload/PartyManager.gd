extends Node


# ============================================================
# PARTY / COLLECTION LIMITS
# ============================================================

# Maximum number of INDIVIDUAL ATOMON INSTANCES the player
# can own.
#
# Duplicate elements are allowed.
#
# Example:
# Hydrogen #1
# Hydrogen #2
# Hydrogen #3
#
# These are 3 separate Atomons and count as 3 collection
# entries.
const MAX_COLLECTION_SIZE: int = 118

# Maximum number of Atomons currently carried.
const MAX_CARRIED_ATOMONS: int = 8

# First 5 carried Atomons are the Battle Party.
const MAX_BATTLE_PARTY_SIZE: int = 5

# Remaining 3 carried Atomons are Reserve.
const MAX_RESERVE_SIZE: int = 3


# ============================================================
# COLLECTION
# ============================================================
#
# ALL Atomons owned by the player.
#
# Duplicate Atomons are allowed.
#
# Example:
#
# Hydrogen #1
# Hydrogen #2
# Oxygen #1
# Hydrogen #3
#
# party.size() = 4
# ============================================================

var party: Array[AtomonInstance] = []


# ============================================================
# CARRIED PARTY
# ============================================================
#
# Current Atomons carried by the player.
#
# Maximum 8:
#
# 1-5 = Battle Party
# 6-8 = Reserve
#
# The objects here are references to objects inside party.
# ============================================================

var carried_party: Array[AtomonInstance] = []


# ============================================================
# ACTIVE BATTLE ATOMON
# ============================================================

var active_index: int = 0


# ============================================================
# ADD NEW ATOMON
# ============================================================

func add_species(species: AtomonData) -> AtomonInstance:

	if species == null:
		push_error("[PartyManager] Cannot add null species.")
		return null

	# --------------------------------------------------------
	# COLLECTION FULL
	# --------------------------------------------------------

	if party.size() >= MAX_COLLECTION_SIZE:
		push_warning(
			"[PartyManager] Collection is full: ",
			MAX_COLLECTION_SIZE,
			"/",
			MAX_COLLECTION_SIZE
		)

		return null

	# --------------------------------------------------------
	# CREATE NEW INDIVIDUAL INSTANCE
	# --------------------------------------------------------

	var instance: AtomonInstance = AtomonInstance.new()

	instance.initialize(species)

	# --------------------------------------------------------
	# ADD TO COLLECTION
	# --------------------------------------------------------

	party.append(instance)

	print(
		"[PartyManager] Added Atomon: ",
		species.chemical_symbol,
		" - ",
		species.atom_name
	)

	print(
		"[PartyManager] Total owned Atomons: ",
		party.size(),
		"/",
		MAX_COLLECTION_SIZE
	)

	# --------------------------------------------------------
	# AUTOMATICALLY CARRY IF THERE IS SPACE
	# --------------------------------------------------------

	if carried_party.size() < MAX_CARRIED_ATOMONS:

		carried_party.append(instance)

		print(
			"[PartyManager] New Atomon automatically carried."
		)

		print(
			"[PartyManager] Carried: ",
			carried_party.size(),
			"/",
			MAX_CARRIED_ATOMONS
		)

	return instance


# ============================================================
# LEGACY / FALLBACK LOADER
# ============================================================

func load_saved_party() -> void:

	var symbols: Array[String] = (
		StudentDataManager.get_collected_elements()
	)

	print("[PartyManager] Loading collected Atomons...")
	print("[PartyManager] Saved elements: ", symbols)

	if symbols.is_empty():

		print(
			"[PartyManager] No collected-element fallback data."
		)

		print(
			"[PartyManager] Keeping current Atomon collection."
		)

		return

	party.clear()
	carried_party.clear()
	active_index = 0

	for symbol in symbols:

		if not AtomonDatabase.ELEMENTS.has(symbol):

			print(
				"[PartyManager] No element data for: ",
				symbol
			)

			continue

		var species: AtomonData = (
			AtomonDatabase.ELEMENTS[symbol]
		)

		if species == null:
			continue

		add_species(species)

	print(
		"[PartyManager] Collection restored: ",
		party.size()
	)


# ============================================================
# LOAD COMPLETE COLLECTION FROM FIREBASE
# ============================================================

func load_saved_collection(saved_collection: Array) -> void:

	party.clear()
	carried_party.clear()
	active_index = 0

	print(
		"[PartyManager] ========================================"
	)

	print(
		"[PartyManager] LOADING FIREBASE ATOMON COLLECTION"
	)

	print(
		"[PartyManager] Saved entries: ",
		saved_collection.size()
	)

	print(
		"[PartyManager] ========================================"
	)

	# --------------------------------------------------------
	# RESTORE EVERY INDIVIDUAL ATOMON
	# --------------------------------------------------------

	for saved_atom in saved_collection:

		if not saved_atom is Dictionary:
			continue

		var chemical_symbol := str(
			saved_atom.get(
				"chemical_symbol",
				""
			)
		).strip_edges()

		if chemical_symbol.is_empty():
			continue

		if not AtomonDatabase.ELEMENTS.has(
			chemical_symbol
		):

			print(
				"[PartyManager] Cannot find element data: ",
				chemical_symbol
			)

			continue

		var species: AtomonData = (
			AtomonDatabase.ELEMENTS[
				chemical_symbol
			]
		)

		if species == null:
			continue

		# Create individual Atomon instance.
		var atomon: AtomonInstance = (
			AtomonInstance.new()
		)

		atomon.initialize(species)

		# Restore saved instance state.
		atomon.apply_save_dict(
			saved_atom
		)

		# Add to complete collection.
		party.append(atomon)

		print(
			"[PartyManager] RESTORED: ",
			chemical_symbol,
			" | ID: ",
			atomon.instance_id
		)

	# --------------------------------------------------------
	# FALLBACK CARRIED PARTY
	# --------------------------------------------------------
	#
	# SaveManager can later replace this with the exact saved
	# carried-party arrangement.
	# --------------------------------------------------------

	var carried_count := mini(
		MAX_CARRIED_ATOMONS,
		party.size()
	)

	for i in range(carried_count):
		carried_party.append(
			party[i]
		)

	active_index = 0

	print(
		"[PartyManager] Collection: ",
		party.size()
	)

	print(
		"[PartyManager] Carried: ",
		carried_party.size(),
		"/",
		MAX_CARRIED_ATOMONS
	)


# ============================================================
# REMOVE ATOMON FROM COLLECTION
# ============================================================

func remove_atomon(index: int) -> void:

	if index < 0 or index >= party.size():
		return

	var atomon: AtomonInstance = party[index]

	if atomon != null:
		carried_party.erase(atomon)

	party.remove_at(index)

	if active_index >= get_battle_party_count():
		active_index = 0

	print(
		"[PartyManager] Atomon removed."
	)


# ============================================================
# GET COMPLETE COLLECTION
# ============================================================

func get_party() -> Array[AtomonInstance]:
	return party


func get_collection() -> Array[AtomonInstance]:
	return party


# ============================================================
# GET CARRIED PARTY
# ============================================================

func get_carried_party() -> Array[AtomonInstance]:
	return carried_party


# ============================================================
# GET CARRIED SLOT
# ============================================================
#
# Returns the Atomon occupying a specific carried position.
#
# Index:
#
# 0-4 = Battle
# 5-7 = Reserve
#
# Returns null if that position is empty.
# ============================================================

func get_carried_atomon(slot_index: int) -> AtomonInstance:

	if slot_index < 0:
		return null

	if slot_index >= MAX_CARRIED_ATOMONS:
		return null

	if slot_index >= carried_party.size():
		return null

	return carried_party[slot_index]


# ============================================================
# SET ATOMON IN CARRIED SLOT
# ============================================================
#
# This is the main function used by PlayerPage.
#
# If the selected Atomon is already carried somewhere else,
# the two Atomons are SWAPPED.
#
# Example:
#
# Slot 1 = H
# Slot 2 = O
#
# Select O for Slot 1:
#
# Slot 1 = O
# Slot 2 = H
# ============================================================

func set_atomon_in_carried_slot(
	slot_index: int,
	selected_atomon: AtomonInstance
) -> bool:

	if selected_atomon == null:
		return false

	if slot_index < 0:
		return false

	if slot_index >= MAX_CARRIED_ATOMONS:
		return false

	if not party.has(selected_atomon):
		push_warning(
			"[PartyManager] Selected Atomon is not owned."
		)

		return false

	# --------------------------------------------------------
	# MAKE SURE ARRAY HAS ENOUGH POSITIONS
	# --------------------------------------------------------

	while carried_party.size() <= slot_index:

		carried_party.append(null)

	# --------------------------------------------------------
	# CURRENT ATOMON IN TARGET SLOT
	# --------------------------------------------------------

	var old_atomon: AtomonInstance = (
		carried_party[slot_index]
	)

	# --------------------------------------------------------
	# FIND SELECTED ATOMON
	# --------------------------------------------------------

	var existing_index := carried_party.find(
		selected_atomon
	)

	# --------------------------------------------------------
	# SELECTED ATOMON IS ALREADY CARRIED
	# --------------------------------------------------------

	if existing_index != -1:

		if existing_index == slot_index:
			return true

		# Swap.
		carried_party[existing_index] = old_atomon

	# --------------------------------------------------------
	# PUT SELECTED ATOMON INTO TARGET SLOT
	# --------------------------------------------------------

	carried_party[slot_index] = selected_atomon

	# --------------------------------------------------------
	# REMOVE TRAILING EMPTY POSITIONS
	# --------------------------------------------------------

	while (
		not carried_party.is_empty()
		and carried_party[carried_party.size() - 1] == null
	):

		carried_party.pop_back()

	# --------------------------------------------------------
	# KEEP ACTIVE INDEX VALID
	# --------------------------------------------------------

	if active_index >= get_battle_party_count():
		active_index = 0

	print(
		"[PartyManager] Carried slot ",
		slot_index + 1,
		" changed to ",
		selected_atomon.data.chemical_symbol
	)

	return true


# ============================================================
# GET BATTLE PARTY
# ============================================================

func get_battle_party() -> Array[AtomonInstance]:

	var battle_party: Array[AtomonInstance] = []

	var battle_count := mini(
		MAX_BATTLE_PARTY_SIZE,
		carried_party.size()
	)

	for i in range(battle_count):

		var atomon := carried_party[i]

		if atomon != null:
			battle_party.append(atomon)

	return battle_party


# ============================================================
# GET RESERVE PARTY
# ============================================================

func get_reserve_party() -> Array[AtomonInstance]:

	var reserve_party: Array[AtomonInstance] = []

	if carried_party.size() <= MAX_BATTLE_PARTY_SIZE:
		return reserve_party

	for i in range(
		MAX_BATTLE_PARTY_SIZE,
		carried_party.size()
	):

		var atomon := carried_party[i]

		if atomon != null:
			reserve_party.append(atomon)

		if reserve_party.size() >= MAX_RESERVE_SIZE:
			break

	return reserve_party


# ============================================================
# ADD TO CARRIED PARTY
# ============================================================

func add_to_carried_party(
	atomon: AtomonInstance
) -> bool:

	if atomon == null:
		return false

	if not party.has(atomon):
		return false

	if carried_party.has(atomon):
		return false

	if carried_party.size() >= MAX_CARRIED_ATOMONS:
		push_warning(
			"[PartyManager] Carried party is full."
		)

		return false

	carried_party.append(atomon)

	return true


# ============================================================
# REMOVE FROM CARRIED PARTY
# ============================================================

func remove_from_carried_party(
	atomon: AtomonInstance
) -> bool:

	if atomon == null:
		return false

	if not carried_party.has(atomon):
		return false

	if carried_party.size() <= 1:

		push_warning(
			"[PartyManager] At least one Atomon must remain carried."
		)

		return false

	carried_party.erase(atomon)

	if active_index >= get_battle_party_count():
		active_index = 0

	return true


# ============================================================
# SET ENTIRE CARRIED PARTY
# ============================================================

func set_carried_party(
	selected_atomons: Array[AtomonInstance]
) -> bool:

	if selected_atomons.is_empty():
		return false

	if selected_atomons.size() > MAX_CARRIED_ATOMONS:
		return false

	for atomon in selected_atomons:

		if atomon == null:
			return false

		if not party.has(atomon):
			return false

	# Prevent duplicate references.
	for i in range(selected_atomons.size()):

		for j in range(i + 1, selected_atomons.size()):

			if selected_atomons[i] == selected_atomons[j]:
				return false

	carried_party.clear()

	for atomon in selected_atomons:
		carried_party.append(atomon)

	active_index = 0

	return true


# ============================================================
# ACTIVE ATOMON
# ============================================================

func get_active_atomon() -> AtomonInstance:

	var battle_party := get_battle_party()

	if battle_party.is_empty():
		return null

	if active_index < 0:
		active_index = 0

	if active_index >= battle_party.size():
		active_index = 0

	return battle_party[active_index]


func set_active_atomon(index: int) -> bool:

	var battle_party := get_battle_party()

	if index < 0 or index >= battle_party.size():
		return false

	var selected := battle_party[index]

	if selected == null:
		return false

	if selected.current_hp <= 0:
		return false

	active_index = index

	return true


# ============================================================
# MEMBERSHIP CHECKS
# ============================================================

func is_atomon_carried(
	atomon: AtomonInstance
) -> bool:

	return atomon != null and carried_party.has(atomon)


func is_atomon_in_battle_party(
	atomon: AtomonInstance
) -> bool:

	return atomon != null and get_battle_party().has(atomon)


func is_atomon_in_reserve(
	atomon: AtomonInstance
) -> bool:

	return atomon != null and get_reserve_party().has(atomon)


func owns_atomon(
	atomon: AtomonInstance
) -> bool:

	return atomon != null and party.has(atomon)


# ============================================================
# SPECIES CHECK
# ============================================================

func has_species(
	species: AtomonData
) -> bool:

	if species == null:
		return false

	for atomon in party:

		if atomon == null:
			continue

		if atomon.data == species:
			return true

	return false


# ============================================================
# AVAILABLE ATOMON CHECKS
# ============================================================

func has_available_atomon() -> bool:

	for atomon in get_battle_party():

		if atomon != null and atomon.current_hp > 0:
			return true

	return false


func has_available_battle_atomon_except_active() -> bool:

	var battle_party := get_battle_party()

	for i in range(battle_party.size()):

		if i == active_index:
			continue

		var atomon := battle_party[i]

		if atomon != null and atomon.current_hp > 0:
			return true

	return false


# ============================================================
# COUNTS
# ============================================================

func get_carried_count() -> int:
	return carried_party.size()


func get_collection_count() -> int:
	return party.size()


func get_battle_party_count() -> int:
	return get_battle_party().size()


func get_reserve_count() -> int:
	return get_reserve_party().size()

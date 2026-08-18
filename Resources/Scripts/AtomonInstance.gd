extends Resource
class_name AtomonInstance


# ============================================================
# SPECIES
# ============================================================

@export var data: AtomonData


# ============================================================
# BATTLE
# ============================================================

@export var current_hp: int = 0
@export var electron_energy: int = 0 # XP
@export var excited_state: int = 0 # Level
@export var active_excited_state: int = 0


# ============================================================
# STATUS
# ============================================================

@export var is_active: bool = false
@export var nickname: String = ""


# ============================================================
# FUTURE
# ============================================================

@export var individual_values := {}
@export var effort_values := {}
@export var learned_moves: Array[MoveData] = []


# ============================================================
# UNIQUE ID
# ============================================================

@export var instance_id: String = ""


# ============================================================
# MOVES / PP
# ============================================================

@export var current_pp: Array[int] = []


# ============================================================
# INITIALIZE
# ============================================================

func initialize(atomon_data: AtomonData) -> void:

	data = atomon_data

	current_hp = StatCalculator.get_hp(data)

	# Give every captured Atomon its own unique ID.
	if instance_id.is_empty():
		instance_id = str(
			atomon_data.chemical_symbol,
			"_",
			Time.get_unix_time_from_system(),
			"_",
			randi()
		)

	# Only initialize PP for a brand-new Atomon.
	if current_pp.is_empty():

		for move in data.moves:
			current_pp.append(move.max_uses)


# ============================================================
# FIREBASE SERIALIZATION
# ============================================================

func to_save_dict() -> Dictionary:

	if data == null:
		print("[AtomonInstance] Cannot save Atomon without data.")
		return {}

	return {
		# Species identifier
		"chemical_symbol": data.chemical_symbol,
		"atomic_number": data.atomic_number,

		# Unique instance identifier
		"instance_id": instance_id,

		# Battle state
		"current_hp": current_hp,
		"electron_energy": electron_energy,
		"excited_state": excited_state,
		"active_excited_state": active_excited_state,

		# Status
		"is_active": is_active,
		"nickname": nickname,

		# Stats
		"individual_values": individual_values.duplicate(true),
		"effort_values": effort_values.duplicate(true),

		# PP
		"current_pp": current_pp.duplicate()
	}


# ============================================================
# FIREBASE DESERIALIZATION
# ============================================================

func apply_save_dict(save_dict: Dictionary) -> void:

	if save_dict.is_empty():
		return

	# --------------------------------------------------------
	# INSTANCE ID
	# --------------------------------------------------------

	instance_id = str(
		save_dict.get("instance_id", instance_id)
	)


	# --------------------------------------------------------
	# BATTLE
	# --------------------------------------------------------

	current_hp = int(
		save_dict.get("current_hp", current_hp)
	)

	electron_energy = int(
		save_dict.get("electron_energy", electron_energy)
	)

	excited_state = int(
		save_dict.get("excited_state", excited_state)
	)

	active_excited_state = int(
		save_dict.get(
			"active_excited_state",
			active_excited_state
		)
	)


	# --------------------------------------------------------
	# STATUS
	# --------------------------------------------------------

	is_active = bool(
		save_dict.get("is_active", is_active)
	)

	nickname = str(
		save_dict.get("nickname", nickname)
	)


	# --------------------------------------------------------
	# STATS
	# --------------------------------------------------------

	var saved_iv = save_dict.get(
		"individual_values",
		{}
	)

	if saved_iv is Dictionary:
		individual_values = saved_iv.duplicate(true)


	var saved_ev = save_dict.get(
		"effort_values",
		{}
	)

	if saved_ev is Dictionary:
		effort_values = saved_ev.duplicate(true)


	# --------------------------------------------------------
	# PP
	# --------------------------------------------------------

	var saved_pp = save_dict.get(
		"current_pp",
		[]
	)

	if saved_pp is Array:

		current_pp.clear()

		for pp in saved_pp:
			current_pp.append(int(pp))

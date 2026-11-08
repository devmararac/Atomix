extends Node
class_name StatCalculator

# Hp
const HP_MIN := 100
const HP_MAX := 500

# all stats
const STAT_MIN := 20
const STAT_MAX := 120

# ------------------------------------
# Scientific ranges for normalization
# ------------------------------------

# HP (Atomix Mass)
const MASS_MIN := 1.008
const MASS_MAX := 294.0

# Physical Attack (1st Ionization Energy)
const ION_MIN := 3.89
const ION_MAX := 24.59

# Physical Defense (Density)
const DENSITY_MIN := 0.0000899
const DENSITY_MAX := 22.59

# Special Attack (Allen Electronegativity)
const EN_MIN := 0.47
const EN_MAX := 4.79

# Special Defense (Electron Affinity)
const EA_MIN := -48.0
const EA_MAX := 349.0


static func normalize(value: float, minimum: float, maximum: float) -> int:
	value = clamp(value, minimum, maximum)

	return roundi(
		STAT_MIN +
		(value - minimum) / (maximum - minimum)
		* (STAT_MAX - STAT_MIN)
	)

static func battle_effectiveness(stat: int) -> float:
	var normalized := float(stat - STAT_MIN) / float(STAT_MAX - STAT_MIN)

	# Compress extreme differences
	return 0.75 + normalized * 0.5


static func normalize_hp(value: float, minimum: float, maximum: float) -> int:
	value = clamp(value, minimum, maximum)

	return round(
		HP_MIN +
		(value - minimum) / (maximum - minimum)
		* (HP_MAX - HP_MIN)
	)
	
	
# HP (Atomix Mass and period)
static func get_hp(data: AtomonData) -> int:

	var mass_hp = normalize_hp(
		data.atomic_mass,
		MASS_MIN,
		MASS_MAX
	)

	var period_hp = normalize_hp(
		data.period,
		1,
		7
	)

	return round(
		mass_hp * 0.7 +
		period_hp * 0.3
	)

# for level stats hp
static func get_battle_hp(atomon: AtomonInstance) -> int:
	var base := get_hp(atomon.data)
	var multiplier := get_state_multiplier(atomon.active_excited_state)
	return roundi(base * multiplier)
	
# Physical Attack (1st Ionization Energy)
static func get_attack(data: AtomonData) -> int:
	return normalize(
		data.ionization_energy,
		ION_MIN,
		ION_MAX
	)


# for level stats attack
static func get_battle_attack(atomon: AtomonInstance) -> int:

	var base := get_attack(atomon.data)

	var multiplier := get_state_multiplier(atomon.active_excited_state)

	return roundi(base * multiplier)


# Physical Defense (Density)
static func get_defense(data: AtomonData) -> int:
	return normalize(
		data.density,
		DENSITY_MIN,
		DENSITY_MAX
	)

# for level stats defense
static func get_battle_defense(atomon: AtomonInstance) -> int:

	var base := normalize(
		atomon.data.density,
		DENSITY_MIN,
		DENSITY_MAX
	)

	return roundi(base * get_state_multiplier(atomon.active_excited_state))

# Special Attack (Allen Electronegativity)
static func get_special_attack(data: AtomonData) -> int:
	return normalize(
		data.electronegativity,
		EN_MIN,
		EN_MAX
	)

# for level stats special attack
static func get_battle_special_attack(atomon: AtomonInstance) -> int:

	var base := normalize(
		atomon.data.electronegativity,
		EN_MIN,
		EN_MAX
	)

	return roundi(base * get_state_multiplier(atomon.active_excited_state))

# Special Defense (Electron Affinity)
static func get_special_defense(data: AtomonData) -> int:
	return normalize(
		data.electron_affinity,
		EA_MIN,
		EA_MAX
	)

# for level stats special defense
static func get_battle_special_defense(atomon: AtomonInstance) -> int:

	var base := normalize(
		atomon.data.electron_affinity,
		EA_MIN,
		EA_MAX
	)
	return roundi(base * get_state_multiplier(atomon.active_excited_state))

# Speed (Phase)
static func get_speed(data: AtomonData) -> int:

	var base := 0

	match data.state:
		"Gas":
			base = 90
		"Liquid":
			base = 65
		"Solid":
			base = 40

	# Lighter atoms move slightly faster
	var ratio = (MASS_MAX - data.atomic_mass) / (MASS_MAX - MASS_MIN)
	var bonus = round(ratio * 20)

	return clamp(base + int(bonus), STAT_MIN, STAT_MAX)

static func get_battle_speed(atomon: AtomonInstance) -> int:

	var base := 0

	match atomon.data.state:
		"Gas":
			base = 90
		"Liquid":
			base = 65
		"Solid":
			base = 40

	var ratio = (MASS_MAX - atomon.data.atomic_mass) / (MASS_MAX - MASS_MIN)
	var bonus = round(ratio * 20)

	base = clamp(base + int(bonus), STAT_MIN, STAT_MAX)

	return roundi(base * get_state_multiplier(atomon.active_excited_state))


# Fusion Gauge

static func get_fusion_gauge(data: AtomonData) -> int:
	return data.valence_electrons


# ============================================================
# Stat calculator when atomons "level up"
# ============================================================

static func get_energy_thresholds(atomon: AtomonData) -> Array[int]:

	var normalized: float = (
		atomon.ionization_energy - ION_MIN
	) / float(ION_MAX - ION_MIN)

	var excited_1: int = roundi(20.0 + normalized * 60.0)

	return [
		excited_1,
		excited_1 * 2,
		excited_1 * 3
	]
	

static func get_state_multiplier(state: int) -> float:

	match state:
		1:
			return 1.10    # Excited State I
		2:
			return 1.20    # Excited State II
		3:
			return 1.30    # Excited State III

	return 1.0          # Ground State

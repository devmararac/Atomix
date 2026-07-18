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


# Physical Attack (1st Ionization Energy)
static func get_attack(data: AtomonData) -> int:
	return normalize(
		data.ionization_energy,
		ION_MIN,
		ION_MAX
	)


# Physical Defense (Density)
static func get_defense(data: AtomonData) -> int:
	return normalize(
		data.density,
		DENSITY_MIN,
		DENSITY_MAX
	)


# Special Attack (Allen Electronegativity)
static func get_special_attack(data: AtomonData) -> int:
	return normalize(
		data.electronegativity,
		EN_MIN,
		EN_MAX
	)


# Special Defense (Electron Affinity)
static func get_special_defense(data: AtomonData) -> int:
	return normalize(
		data.electron_affinity,
		EA_MIN,
		EA_MAX
	)


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



# Fusion Gauge

static func get_fusion_gauge(data: AtomonData) -> int:
	return data.valence_electrons

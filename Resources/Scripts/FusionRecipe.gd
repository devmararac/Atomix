extends Resource
class_name FusionRecipe


# ============================================================
# FUSION RECIPE
# ============================================================
# Defines one complete Skill Fusion recipe.
#
# Examples:
#
# H₂O:
#   Hydrogen ×2
#   Oxygen ×1
#
# MgCl₂:
#   Magnesium ×1
#   Chlorine ×2
#
# CaCO₃:
#   Calcium ×1
#   Carbon ×1
#   Oxygen ×3
#
# The recipe contains both the chemical information and
# the Skill Fusion information.
#
# BattleLearning generates its challenge from this recipe.
# ============================================================


# ============================================================
# ELEMENT REQUIREMENTS
# ============================================================

@export_group("Element Requirements")

@export var requirements: Array[FusionElementRequirement] = []


# ============================================================
# CHEMICAL RESULT
# ============================================================

@export_group("Chemical Result")

@export var compound_name: String = ""

@export var chemical_formula: String = ""

@export_enum(
	"Covalent",
	"Ionic",
	"Metallic",
	"Other"
)
var bond_type: String = "Covalent"


# ============================================================
# SKILL FUSION RESULT
# ============================================================

@export_group("Skill Fusion")

# Name of the Fusion Skill.
@export var fusion_skill_name: String = ""

# Base damage of the Fusion Skill.
@export var fusion_damage: int = 0

# Additional damage for every Atomon used in the Fusion.
#
# Example:
#
# Base Damage = 20
# Damage Per Atomon = 10
# 3 Atomons used:
#
# 20 + (3 × 10) = 50 damage
@export var damage_per_atomon: int = 10

# Projectile/visual effect used by the Fusion Skill.
#
# Example:
# res://Battle/FusionProjectiles/WaterProjectile.tscn
@export var projectile_scene: PackedScene


# ============================================================
# OCTET RULE LESSON
# ============================================================

@export_group("Octet Rule")

# Explanation of the Octet Rule for this Fusion.
@export_multiline var octet_rule_explanation: String = ""

# Explanation of how/why the elements form the compound.
@export_multiline var fusion_description: String = ""


# ============================================================
# VALIDATION
# ============================================================

func is_valid() -> bool:

	# --------------------------------------------------------
	# ELEMENT REQUIREMENTS
	# --------------------------------------------------------

	# A recipe must have at least two different elements.
	if requirements.size() < 2:
		return false

	for requirement in requirements:
		if requirement == null:
			return false

		if not requirement.is_valid():
			return false


	# Make sure the same element isn't accidentally added
	# more than once.
	var used_elements: Array[AtomonData] = []

	for requirement in requirements:
		if requirement.element in used_elements:
			return false

		used_elements.append(requirement.element)


	# --------------------------------------------------------
	# CHEMICAL RESULT
	# --------------------------------------------------------

	if compound_name.is_empty():
		return false

	if chemical_formula.is_empty():
		return false


	# --------------------------------------------------------
	# SKILL FUSION
	# --------------------------------------------------------

	if fusion_skill_name.is_empty():
		return false

	if fusion_damage <= 0:
		return false

	if damage_per_atomon < 0:
		return false


	# --------------------------------------------------------
	# OCTET RULE LESSON
	# --------------------------------------------------------

	if octet_rule_explanation.is_empty():
		return false

	if fusion_description.is_empty():
		return false


	return true


# ============================================================
# GET FUSION DAMAGE
# ============================================================
# Calculates the final damage based on how many Atomons
# participated in the Fusion Skill.
#
# Example:
#
# Base Damage = 20
# Damage Per Atomon = 10
# Selected Atomons = 3
#
# Final Damage:
#
# 20 + (3 × 10)
# = 50
# ============================================================

func get_fusion_damage(atomon_count: int) -> int:

	if atomon_count <= 0:
		return 0

	return fusion_damage + (
		atomon_count * damage_per_atomon
	)


# ============================================================
# GET NUMBER OF DIFFERENT ELEMENTS
# ============================================================

func get_element_type_count() -> int:
	return requirements.size()


# ============================================================
# CHECK WHETHER AN ELEMENT IS PART OF THIS RECIPE
# ============================================================

func contains_element(element: AtomonData) -> bool:

	if element == null:
		return false

	for requirement in requirements:
		if requirement.element == element:
			return true

	return false


# ============================================================
# GET REQUIRED AMOUNT OF AN ELEMENT
# ============================================================

func get_required_amount(element: AtomonData) -> int:

	if element == null:
		return 0

	for requirement in requirements:
		if requirement.element == element:
			return requirement.amount

	return 0


# ============================================================
# GET REQUIREMENT FOR AN ELEMENT
# ============================================================

func get_requirement(
	element: AtomonData
) -> FusionElementRequirement:

	if element == null:
		return null

	for requirement in requirements:
		if requirement.element == element:
			return requirement

	return null


# ============================================================
# CHECK A COMPLETE SET OF ELEMENT COUNTS
# ============================================================
# This function checks whether a collection of available
# elements contains everything required by the recipe.
#
# Example H₂O:
#
# available:
# Hydrogen = 2
# Oxygen = 1
#
# result:
# true
#
# If:
# Hydrogen = 1
# Oxygen = 1
#
# result:
# false
# ============================================================

func has_required_elements(
	available_counts: Dictionary
) -> bool:

	if not is_valid():
		return false

	for requirement in requirements:

		var element_id := (
			requirement.element.chemical_symbol
		)

		var available_amount: int = int(
			available_counts.get(element_id, 0)
		)

		if available_amount < requirement.amount:
			return false

	return true


# ============================================================
# GET REQUIRED ELEMENT COUNTS
# ============================================================
# Returns a Dictionary using chemical symbols.
#
# H₂O returns:
#
# {
#     "H": 2,
#     "O": 1
# }
#
# CaCO₃ returns:
#
# {
#     "Ca": 1,
#     "C": 1,
#     "O": 3
# }
# ============================================================

func get_required_element_counts() -> Dictionary:

	var counts: Dictionary = {}

	for requirement in requirements:

		if requirement == null:
			continue

		if requirement.element == null:
			continue

		var symbol := (
			requirement.element.chemical_symbol
		)

		counts[symbol] = requirement.amount

	return counts


# ============================================================
# GET REQUIRED ELEMENTS
# ============================================================
# Returns the actual AtomonData resources used by the recipe.
# ============================================================

func get_required_elements() -> Array[AtomonData]:

	var elements: Array[AtomonData] = []

	for requirement in requirements:

		if requirement == null:
			continue

		if requirement.element == null:
			continue

		elements.append(requirement.element)

	return elements

extends Resource
class_name FusionRecipe


# ============================================================
# FUSION RECIPE
# ============================================================
# Defines one complete Skill Fusion recipe.
#
# The recipe supports ANY number of different elements.
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
# This allows the Fusion system to scale beyond two-element
# compounds.
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

@export var fusion_skill_name: String = ""

@export var fusion_damage: int = 0


# ============================================================
# OCTET RULE LESSON
# ============================================================

@export_group("Octet Rule")

@export_multiline var octet_rule_explanation: String = ""

@export_multiline var fusion_description: String = ""


# ============================================================
# VALIDATION
# ============================================================

func is_valid() -> bool:
	# A recipe must have at least two different element
	# requirements.
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

	if compound_name.is_empty():
		return false

	if chemical_formula.is_empty():
		return false

	if fusion_skill_name.is_empty():
		return false

	if fusion_damage <= 0:
		return false

	return true


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

func get_requirement(element: AtomonData) -> FusionElementRequirement:
	if element == null:
		return null

	for requirement in requirements:
		if requirement.element == element:
			return requirement

	return null


# ============================================================
# CHECK A COMPLETE SET OF ELEMENT COUNTS
# ============================================================
# This function is useful later when FusionManager checks
# whether the player's party contains everything needed.
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

func has_required_elements(available_counts: Dictionary) -> bool:
	if not is_valid():
		return false

	for requirement in requirements:
		var element_id := requirement.element.chemical_symbol

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

		var symbol := requirement.element.chemical_symbol

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

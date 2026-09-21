extends Resource
class_name FusionElementRequirement


# ============================================================
# FUSION ELEMENT REQUIREMENT
# ============================================================
# Defines how many Atomons of one element are required
# for a specific Skill Fusion recipe.
#
# Examples:
#
# H₂O:
# Hydrogen ×2
# Oxygen ×1
#
# MgCl₂:
# Magnesium ×1
# Chlorine ×2
#
# CaCO₃:
# Calcium ×1
# Carbon ×1
# Oxygen ×3
# ============================================================


# ============================================================
# ELEMENT
# ============================================================

@export var element: AtomonData


# ============================================================
# REQUIRED AMOUNT
# ============================================================

@export_range(1, 20, 1)
var amount: int = 1


# ============================================================
# VALIDATION
# ============================================================

func is_valid() -> bool:
	if element == null:
		return false

	if amount <= 0:
		return false

	return true

extends Node


# ========================================================
# FUSION RECIPE RESOURCES
# ========================================================

# IMPORTANT:
# These preload() references make sure Godot includes the
# Fusion Recipe resources when exporting to Android.
#
# Add future Fusion Recipe .tres files to this array.
const FUSION_RECIPE_RESOURCES: Array[Resource] = [
	preload("res://Resources/Fusion/H2O.tres"),
	preload("res://Resources/Fusion/CO2.tres"),
	#	preload("res://Resources/Fusion/NaCl.tres"),
	preload("res://Resources/Fusion/NH3.tres"),
	preload("res://Resources/Fusion/CH4.tres"),
	preload("res://Resources/Fusion/C2H4.tres"),
	preload("res://Resources/Fusion/C3H4.tres"),
	preload("res://Resources/Fusion/C2H6.tres"),
	preload("res://Resources/Fusion/H2.tres"),
	preload("res://Resources/Fusion/HCL.tres")
]


var fusion_recipes: Array[FusionRecipe] = []


func _ready() -> void:
	load_fusion_recipes()


# ========================================================
# LOAD FUSION RECIPES
# ========================================================

func load_fusion_recipes() -> void:
	fusion_recipes.clear()


	for resource in FUSION_RECIPE_RESOURCES:

		if resource == null:

			continue


		if not resource is FusionRecipe:

			push_warning(
				"[FusionManager] Resource is not a FusionRecipe: ",
				resource.resource_path
			)

			continue

		var recipe: FusionRecipe = resource as FusionRecipe

		if recipe.is_valid():

			fusion_recipes.append(recipe)


		else:

			push_warning(
				"[FusionManager] INVALID Fusion Recipe: "
				+ recipe.chemical_formula
			)




# ========================================================
# GET RECIPES
# ========================================================

func get_all_recipes() -> Array[FusionRecipe]:
	return fusion_recipes


func get_recipe_by_formula(formula: String) -> FusionRecipe:
	for recipe in fusion_recipes:
		if recipe.chemical_formula == formula:
			return recipe

	return null


# ========================================================
# PARTY ELEMENT COUNTS
# ========================================================

func get_party_element_counts() -> Dictionary:

	var counts: Dictionary = {}

	var carried_party: Array[AtomonInstance]

	if BattleManager.is_fusion_training_battle:

		carried_party = BattleManager.training_party

	else:

		carried_party = PartyManager.get_carried_party()

	for atomon in carried_party:

		if atomon == null:
			continue

		if atomon.data == null:
			continue

		var symbol: String = atomon.data.chemical_symbol

		counts[symbol] = int(
			counts.get(symbol, 0)
		) + 1

	return counts


func print_party_element_counts() -> void:
	var counts := get_party_element_counts()



# ========================================================
# CHECK RECIPE REQUIREMENTS
# ========================================================

func can_fuse_recipe(recipe: FusionRecipe) -> bool:
	if recipe == null:
		return false

	if not recipe.is_valid():
		return false

	var available_counts := get_party_element_counts()

	return recipe.has_required_elements(available_counts)


# ========================================================
# CHECK ACTIVE ATOMON FOR FUSION
# ========================================================

func active_atomon_can_use_recipe(
	recipe: FusionRecipe
) -> bool:

	if recipe == null:
		return false

	if not recipe.is_valid():
		return false

	var active_atomon: AtomonInstance

	if BattleManager.is_fusion_training_battle:

		active_atomon = BattleManager.player_instance

	else:

		active_atomon = PartyManager.get_active_atomon()

	if active_atomon == null:
		return false

	if active_atomon.data == null:
		return false

	var active_symbol: String = (
		active_atomon.data.chemical_symbol
	)

	for requirement in recipe.requirements:
		if requirement == null:
			continue

		if requirement.element == null:
			continue

		var required_symbol: String = (
			requirement.element.chemical_symbol
		)

		if required_symbol == active_symbol:
			return true

	return false


# ========================================================
# GET ATOMON INSTANCES FOR A FUSION
# ========================================================

func get_fusion_atomon_candidates(recipe: FusionRecipe) -> Dictionary:
	var result: Dictionary = {}

	if recipe == null:
		return result

	if not can_fuse_recipe(recipe):
		return result

	if not active_atomon_can_use_recipe(recipe):
		return result

	var carried_party: Array[AtomonInstance]

	if BattleManager.is_fusion_training_battle:

		carried_party = BattleManager.training_party

	else:

		carried_party = PartyManager.get_carried_party()

	for requirement in recipe.requirements:
		if requirement == null:
			continue

		if requirement.element == null:
			continue

		var symbol: String = requirement.element.chemical_symbol
		var required_amount: int = requirement.amount

		var matching_atomons: Array[AtomonInstance] = []

		for atomon in carried_party:
			if atomon == null:
				continue

			if atomon.data == null:
				continue

			if atomon.data.chemical_symbol == symbol:
				matching_atomons.append(atomon)

		if matching_atomons.size() < required_amount:
			return {}

		result[symbol] = matching_atomons.slice(0, required_amount)

	return result


# ========================================================
# GET ALL AVAILABLE FUSIONS
# ========================================================

func get_available_fusion_recipes() -> Array[FusionRecipe]:
	var available: Array[FusionRecipe] = []

	for recipe in fusion_recipes:
		if not can_fuse_recipe(recipe):
			continue

		if not active_atomon_can_use_recipe(recipe):
			continue

		available.append(recipe)

	return available

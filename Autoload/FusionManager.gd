extends Node

const FUSION_RECIPE_FOLDER := "res://Resources/Fusion/"

var fusion_recipes: Array[FusionRecipe] = []


func _ready() -> void:
	load_fusion_recipes()


# ========================================================
# LOAD FUSION RECIPES
# ========================================================

func load_fusion_recipes() -> void:
	fusion_recipes.clear()

	var directory := DirAccess.open(FUSION_RECIPE_FOLDER)

	if directory == null:
		push_error("[FusionManager] Could not open folder: " + FUSION_RECIPE_FOLDER)
		return

	directory.list_dir_begin()

	var file_name := directory.get_next()

	while file_name != "":
		if not directory.current_is_dir():
			if file_name.ends_with(".tres"):
				var recipe_path := FUSION_RECIPE_FOLDER + file_name
				var recipe = load(recipe_path)

				if recipe is FusionRecipe:
					if recipe.is_valid():
						fusion_recipes.append(recipe)

						print(
							"[FusionManager] Loaded Fusion Recipe: ",
							recipe.chemical_formula
						)
					else:
						push_warning(
							"[FusionManager] Invalid Fusion Recipe: ",
							recipe_path
						)

		file_name = directory.get_next()

	directory.list_dir_end()

	print(
		"[FusionManager] Total Fusion Recipes Loaded: ",
		fusion_recipes.size()
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

	var carried_party := PartyManager.get_carried_party()

	for atomon in carried_party:
		if atomon == null:
			continue

		if atomon.data == null:
			continue

		var symbol: String = atomon.data.chemical_symbol
		counts[symbol] = int(counts.get(symbol, 0)) + 1

	return counts


func print_party_element_counts() -> void:
	var counts := get_party_element_counts()

	print(
		"[FusionManager] Carried Atomon Element Counts: ",
		counts
	)


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
# GET ATOMON INSTANCES FOR A FUSION
# ========================================================

func get_fusion_atomon_candidates(recipe: FusionRecipe) -> Dictionary:
	var result: Dictionary = {}

	if recipe == null:
		return result

	if not can_fuse_recipe(recipe):
		return result

	var carried_party := PartyManager.get_carried_party()

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
		if can_fuse_recipe(recipe):
			available.append(recipe)

	return available


# ========================================================
# DEBUG
# ========================================================

func print_available_fusions() -> void:
	var available := get_available_fusion_recipes()

	print("[FusionManager] Available Fusion Recipes: ", available.size())

	for recipe in available:
		print(
			"[FusionManager] Available: ",
			recipe.chemical_formula
		)

func print_fusion_atomon_candidates(recipe: FusionRecipe) -> void:
	var candidates := get_fusion_atomon_candidates(recipe)

	print("[FusionManager] Fusion Atomon Candidates: ", candidates)

extends Node

func get_crafting_recipe(element: AtomonData) -> CraftingRecipe:
	var recipe := CraftingRecipe.new()

	recipe.result = element
	recipe.proton_cost = element.atomic_number
	recipe.electron_cost = element.atomic_number
	recipe.neutron_cost = element.mass_number - element.atomic_number

	# Every element requires one Atomic Core.
	recipe.atomic_core_cost = 1

	return recipe


func can_craft(recipe: CraftingRecipe) -> bool:
	if recipe == null or recipe.result == null:
		return false

	return (
		InventoryManager.has_item("proton", recipe.proton_cost)
		and InventoryManager.has_item("neutron", recipe.neutron_cost)
		and InventoryManager.has_item("electron", recipe.electron_cost)
		and InventoryManager.has_item("atomic_core", recipe.atomic_core_cost)
	)


func craft(recipe: CraftingRecipe) -> bool:
	if !can_craft(recipe):
		print("Cannot craft ", recipe.result.atom_name)
		return false

	# Remove crafting materials.
	InventoryManager.remove_item_by_id("proton", recipe.proton_cost)
	InventoryManager.remove_item_by_id("neutron", recipe.neutron_cost)
	InventoryManager.remove_item_by_id("electron", recipe.electron_cost)
	InventoryManager.remove_item_by_id("atomic_core", recipe.atomic_core_cost)

	# Let PartyManager create and initialize the AtomonInstance.
	var atomon := PartyManager.add_species(recipe.result)

	if atomon == null:
		print("Failed to add Atomon to party.")

		# IMPORTANT:
		# For now, materials have already been removed.
		# We'll improve this later so a full party doesn't consume materials.
		return false

	print("Successfully crafted: ", recipe.result.atom_name)

	return true

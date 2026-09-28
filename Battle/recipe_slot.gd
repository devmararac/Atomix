class_name RecipeSlot
extends TextureButton


# ============================================================
# DATA
# ============================================================

var recipe: FusionRecipe = null


# ============================================================
# SETUP
# ============================================================

func setup(new_recipe: FusionRecipe) -> void:
	if new_recipe == null:
		push_warning("[RecipeSlot] Cannot setup with a null recipe.")
		return

	recipe = new_recipe

	update_skill_button()
	update_recipe_text()


# ============================================================
# SKILL BUTTON
# ============================================================

func update_skill_button() -> void:
	if recipe == null:
		return

	var skill_id := recipe.fusion_skill_id

	if skill_id.is_empty():
		push_warning(
			"[RecipeSlot] Recipe has no Fusion Skill ID."
		)
		return

	if not FusionSkillDatabase.has_skill(skill_id):
		push_warning(
			"[RecipeSlot] Unknown Fusion Skill: " + skill_id
		)
		return

	var normal_texture := \
		FusionSkillDatabase.get_button_texture_normal(skill_id)

	var pressed_texture := \
		FusionSkillDatabase.get_button_texture_pressed(skill_id)

	if normal_texture != null:
		texture_normal = normal_texture

	if pressed_texture != null:
		texture_pressed = pressed_texture


# ============================================================
# RECIPE TEXT
# ============================================================

func update_recipe_text() -> void:
	if recipe == null:
		return

	var compound_name_label := \
		$CompoundReq as Label

	var requirements_label := \
		$CompoundName as Label

	if compound_name_label != null:
		compound_name_label.text = recipe.compound_name

	if requirements_label != null:
		requirements_label.text = build_requirement_text()


# ============================================================
# REQUIREMENT TEXT
# ============================================================

func build_requirement_text() -> String:
	if recipe == null:
		return ""

	var parts: Array[String] = []

	for requirement in recipe.requirements:
		if requirement == null:
			continue

		if requirement.element == null:
			continue

		var symbol := requirement.element.chemical_symbol
		var amount := requirement.amount

		if amount == 1:
			parts.append(symbol)
		else:
			parts.append(
				symbol + " ×" + str(amount)
			)

	return "Requires: " + " + ".join(parts)

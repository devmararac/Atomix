class_name FusionSkillDatabase
extends RefCounted


# ============================================================
# FUSION SKILL DATABASE
# ============================================================

const SKILLS := {
	"water_burst": {
		"display_name": "Water Burst",

		"button_texture_normal":
			preload(
				"res://Assets/UX/Buttons/SkillButtons/water_burst.png"
			),

		"button_texture_pressed":
			preload(
				"res://Assets/UX/Buttons/SkillButtons/water_burst_pressed.png"
			),

		"molecule_scene":
			preload(
				"res://Resources/Fusion/Molecules/water_molecule.tscn"
			),
	},

	"acid_splash": {
		"display_name": "Acid Splash",
		"button_texture_normal":
			preload(
				"res://Assets/UX/Buttons/SkillButtons/acid_splash.png"
			),
		"button_texture_pressed":
			preload(
				"res://Assets/UX/Buttons/SkillButtons/acid_splash_pressed.png"
			),
	},
}



# ============================================================
# LOOKUP
# ============================================================

static func has_skill(skill_id: String) -> bool:
	return SKILLS.has(skill_id)


static func get_skill(skill_id: String) -> Dictionary:
	if not SKILLS.has(skill_id):
		push_warning(
			"[FusionSkillDatabase] Unknown skill: " + skill_id
		)
		return {}

	return SKILLS[skill_id]


# ============================================================
# BUTTON TEXTURES
# ============================================================

static func get_button_texture_normal(
	skill_id: String
) -> Texture2D:

	var skill := get_skill(skill_id)

	if skill.is_empty():
		return null

	return skill.get("button_texture_normal") as Texture2D


static func get_button_texture_pressed(
	skill_id: String
) -> Texture2D:

	var skill := get_skill(skill_id)

	if skill.is_empty():
		return null

	return skill.get("button_texture_pressed") as Texture2D

# ============================================================
# MOLECULE SCENE
# ============================================================

static func get_molecule_scene(
	skill_id: String
) -> PackedScene:

	var skill := get_skill(skill_id)

	if skill.is_empty():
		return null

	return skill.get("molecule_scene") as PackedScene

# ============================================================
# DISPLAY
# ============================================================

static func get_display_name(
	skill_id: String
) -> String:

	var skill := get_skill(skill_id)

	if skill.is_empty():
		return ""

	return str(
		skill.get("display_name", "")
	)

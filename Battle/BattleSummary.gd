extends Control
class_name BattleSummary

signal continue_pressed

var battle_result: String = "Victory"
var enemy_name: String = ""
var enemy_defeated: bool = false
var atomons_remaining: int = 0

var fusion_used: bool = false
var fusion_skill_name: String = ""
var fusion_formula: String = ""
var fusion_atoms: Array[String] = []
var fusion_bond_type: String = ""

var octet_rule_completed: bool = false
var octet_rule_explanation: String = ""

var key_takeaway: String = ""

var coins_reward: int = 0
var item_rewards: Array[String] = []


@onready var review_page: Control = $CardBackground/FormBG/ReviewPage
@onready var result_page: Control = $CardBackground/FormBG/ResultPage

@onready var review_header: Label = $CardBackground/FormBG/ReviewPage/Title/Header
@onready var review_battle_name: Label = $CardBackground/FormBG/ReviewPage/Title/BattleName

@onready var learning_section_1_title: Label = $CardBackground/FormBG/ReviewPage/WhatYouLearnedPanel/Header
@onready var learning_section_1_content: Label = $CardBackground/FormBG/ReviewPage/WhatYouLearnedPanel/ScrollContainer/Content

@onready var learning_section_2_title: Label = $CardBackground/FormBG/ReviewPage/BattleLessonPanel/Header
@onready var learning_section_2_content: Label = $CardBackground/FormBG/ReviewPage/BattleLessonPanel/ScrollContainer/Content

@onready var takeaway_title: Label = $CardBackground/FormBG/ReviewPage/KeyIdeaPanel/Header
@onready var takeaway_content: Label = $CardBackground/FormBG/ReviewPage/KeyIdeaPanel/ScrollContainer/Content

@onready var result_header: Label = $CardBackground/FormBG/ResultPage/Title/Header
@onready var result_label: Label = $CardBackground/FormBG/ResultPage/Title/Result

@onready var battle_status_label: Label = $CardBackground/FormBG/ResultPage/ResultPanel/ResultContent/BattleStatus
@onready var enemy_result_label: Label = $CardBackground/FormBG/ResultPage/ResultPanel/ResultContent/EnemyResult
@onready var atomons_remaining_title: Label = $CardBackground/FormBG/ResultPage/ResultPanel/ResultContent/AtomonsRemainingTitle
@onready var atomons_remaining_label: Label = $CardBackground/FormBG/ResultPage/ResultPanel/ResultContent/AtomonsRemaining

@onready var rewards_title: Label = $CardBackground/FormBG/ResultPage/BattleRewards/VBoxContainer/Title
@onready var coins_label: Label = $CardBackground/FormBG/ResultPage/BattleRewards/VBoxContainer/Rewards/Coins
@onready var reward_label_1: Label = $CardBackground/FormBG/ResultPage/BattleRewards/VBoxContainer/Rewards/Reward1
@onready var reward_label_2: Label = $CardBackground/FormBG/ResultPage/BattleRewards/VBoxContainer/Rewards/Reward2

@onready var continue_button: TextureButton = $CardBackground/ContinueButton
@onready var continue_button_2: TextureButton = $CardBackground/ContinueButton2


func _ready() -> void:
	show_review_page()
	update_battle_review()
	update_battle_result()
	update_rewards()

	if not continue_button.pressed.is_connected(_on_review_continue_pressed):
		continue_button.pressed.connect(_on_review_continue_pressed)

	if not continue_button_2.pressed.is_connected(_on_result_continue_pressed):
		continue_button_2.pressed.connect(_on_result_continue_pressed)


# ============================================================
# PAGE CONTROL
# ============================================================

func show_review_page() -> void:
	review_page.visible = true
	result_page.visible = false

	continue_button.visible = true
	continue_button_2.visible = false


func show_result_page() -> void:
	review_page.visible = false
	result_page.visible = true

	continue_button.visible = false
	continue_button_2.visible = true


# ============================================================
# BATTLE REVIEW
# ============================================================

func update_battle_review() -> void:
	review_header.text = "BATTLE REVIEW"

	if enemy_name.is_empty():
		review_battle_name.text = "Battle Review"
	else:
		review_battle_name.text = "Battle with " + enemy_name

	learning_section_1_title.text = "WHAT YOU LEARNED"
	learning_section_2_title.text = "BATTLE SUMMARY"
	takeaway_title.text = "FUN FACT"

	learning_section_1_content.text = get_learning_summary()
	learning_section_2_content.text = get_battle_summary()
	takeaway_content.text = get_fun_fact()

	if not key_takeaway.is_empty():
		takeaway_content.text = key_takeaway

	reset_review_scrolls()


func reset_review_scrolls() -> void:
	var learning_scroll: ScrollContainer = $CardBackground/FormBG/ReviewPage/WhatYouLearnedPanel/ScrollContainer
	var lesson_scroll: ScrollContainer = $CardBackground/FormBG/ReviewPage/BattleLessonPanel/ScrollContainer
	var key_scroll: ScrollContainer = $CardBackground/FormBG/ReviewPage/KeyIdeaPanel/ScrollContainer

	learning_scroll.scroll_vertical = 0
	lesson_scroll.scroll_vertical = 0
	key_scroll.scroll_vertical = 0


# ============================================================
# WHAT YOU LEARNED
# ============================================================

func get_learning_summary() -> String:
	var learning_lines: Array[String] = []

	if fusion_used:
		if not fusion_skill_name.is_empty():
			learning_lines.append("Fusion: " + fusion_skill_name)

		if not fusion_formula.is_empty():
			learning_lines.append("Formula: " + fusion_formula)

		if not fusion_bond_type.is_empty():
			learning_lines.append("Bond type: " + fusion_bond_type)

		if not fusion_atoms.is_empty():
			learning_lines.append(
				"Components: " + str(fusion_atoms.size()) + " Atomons"
			)

		if octet_rule_completed:
			learning_lines.append("Octet Rule challenge completed")

			if not octet_rule_explanation.is_empty():
				learning_lines.append(octet_rule_explanation)

		if learning_lines.is_empty():
			return get_general_element_lesson()

		return "\n\n".join(learning_lines)

	if octet_rule_completed:
		learning_lines.append("Octet Rule")

		if not octet_rule_explanation.is_empty():
			learning_lines.append(octet_rule_explanation)
		else:
			learning_lines.append(get_octet_rule_lesson())

		return "\n\n".join(learning_lines)

	return get_general_element_lesson()


# ============================================================
# GENERAL ELEMENT LESSON
# ============================================================

func get_general_element_lesson() -> String:
	if enemy_name.is_empty():
		return "Every element has unique chemical properties that affect how it behaves and interacts with other elements."

	match enemy_name:
		"Hydrogen":
			return "Hydrogen follows the duet rule. Its first electron shell can hold a maximum of 2 electrons, so hydrogen needs 1 more electron to complete its outer shell."

		"Helium":
			return "Helium follows the duet rule. Its first electron shell is complete with 2 electrons, making helium a noble gas."

		"Oxygen":
			return "Oxygen has 6 valence electrons. It needs 2 more electrons to complete its outer shell and reach a stable octet."

		"Carbon":
			return "Carbon has 4 valence electrons. These electrons allow carbon to form many different chemical bonds."

		"Nitrogen":
			return "Nitrogen has 5 valence electrons. It needs 3 more electrons to complete its outer shell and reach an octet."

		"Sodium":
			return "Sodium has 1 valence electron. It can lose this electron to form a more stable electron configuration."

		"Chlorine":
			return "Chlorine has 7 valence electrons. It needs 1 more electron to complete its outer shell."

		"Fluorine":
			return "Fluorine has 7 valence electrons. It needs only 1 more electron to complete its outer shell."

		"Magnesium":
			return "Magnesium has 2 valence electrons. It can lose these electrons to form a more stable electron configuration."

		"Calcium":
			return "Calcium has 2 valence electrons. It can lose both electrons when forming many ionic compounds."

		"Neon":
			return "Neon has a complete outer electron shell. This makes neon a noble gas with very low chemical reactivity."

		"Argon":
			return "Argon has a complete outer electron shell. Because its valence shell is full, it is chemically very stable."

		_:
			return "Valence electrons are the electrons in an atom's outermost shell. They play an important role in how elements form chemical bonds."


# ============================================================
# OCTET RULE LESSON
# ============================================================

func get_octet_rule_lesson() -> String:
	if enemy_name == "Hydrogen" or enemy_name == "Helium":
		return "Hydrogen and helium follow the duet rule. Their first electron shell is stable when it contains 2 electrons."

	return "Many atoms tend to become more stable when their outermost electron shell contains 8 electrons. This is known as the Octet Rule."


# ============================================================
# BATTLE SUMMARY
# ============================================================

func get_battle_summary() -> String:
	var summary_lines: Array[String] = []

	match battle_result.to_lower():
		"victory":
			summary_lines.append("✓ Enemy defeated")

			if atomons_remaining > 0:
				summary_lines.append(
					"✓ " + str(atomons_remaining) + " Atomon(s) remaining"
				)

			if fusion_used:
				summary_lines.append("✓ Fusion successfully used")

				if not fusion_formula.is_empty():
					summary_lines.append("✓ Correct Fusion composition")

				if octet_rule_completed:
					summary_lines.append("✓ Octet Rule challenge completed")

			if summary_lines.size() == 1:
				summary_lines.append("• Battle completed successfully")

		"defeat":
			if atomons_remaining <= 0:
				summary_lines.append("✗ All Atomons were defeated")
			else:
				summary_lines.append("✗ Enemy was not defeated")

			if not enemy_defeated:
				summary_lines.append("✗ Enemy remained active")

			if fusion_used:
				summary_lines.append("✓ Fusion learning activity completed")

				if octet_rule_completed:
					summary_lines.append("✓ Octet Rule challenge completed")

		"escaped":
			summary_lines.append("• Battle ended by escape")

			if not enemy_defeated:
				summary_lines.append("• Enemy remained undefeated")

			if atomons_remaining > 0:
				summary_lines.append(
					"• " + str(atomons_remaining) + " Atomon(s) remained"
				)

			if fusion_used:
				summary_lines.append("✓ Fusion learning activity completed")

				if octet_rule_completed:
					summary_lines.append("✓ Octet Rule challenge completed")

		_:
			summary_lines.append("• Battle outcome recorded")

	if summary_lines.is_empty():
		return "No battle information was recorded."

	return "\n".join(summary_lines)


# ============================================================
# FUN FACT
# ============================================================

func get_fun_fact() -> String:
	if enemy_name.is_empty():
		return "Atomon stats are calculated using real scientific properties of the elements."

	match enemy_name:
		"Hydrogen":
			return "Atomon HP is partly calculated using atomic mass and period. Hydrogen has an atomic mass of only 1.008."

		"Helium":
			return "Atomon Speed is influenced by an element's physical state and atomic mass. Gaseous elements receive a higher base Speed in the game."

		"Oxygen":
			return "Atomon Attack is calculated using first ionization energy, the energy needed to remove an electron from an atom."

		"Carbon":
			return "Atomon Special Attack is calculated using electronegativity, which describes how strongly an atom attracts electrons."

		"Nitrogen":
			return "Atomon Special Defense is calculated using electron affinity, which describes the energy change when an atom gains an electron."

		"Sodium":
			return "Atomon Defense is calculated using density. Density describes how much mass is packed into a given volume."

		"Chlorine":
			return "An Atomon's Fusion Gauge is based on its number of valence electrons."

		"Fluorine":
			return "Atomon Special Attack is based on electronegativity. Fluorine has the highest electronegativity value."

		_:
			return "Atomon stats are calculated from scientific properties such as atomic mass, density, ionization energy, electronegativity, and electron affinity."


# ============================================================
# BATTLE RESULTS
# ============================================================

func update_battle_result() -> void:
	result_header.text = "BATTLE RESULTS"

	match battle_result.to_lower():
		"victory":
			result_label.text = "VICTORY!"
			battle_status_label.text = "Victory"

			if enemy_name.is_empty():
				enemy_result_label.text = "Enemy defeated"
			else:
				enemy_result_label.text = enemy_name + " defeated"

			atomons_remaining_title.text = "ATOMONS REMAINING"
			atomons_remaining_label.text = str(atomons_remaining)
			rewards_title.text = "REWARDS"

		"defeat":
			result_label.text = "DEFEAT"
			battle_status_label.text = "Defeat"
			enemy_result_label.text = "Your Atomons were defeated."

			atomons_remaining_title.text = "ATOMONS REMAINING"
			atomons_remaining_label.text = str(atomons_remaining)
			rewards_title.text = "REWARDS"

		"escaped":
			result_label.text = "ESCAPED"
			battle_status_label.text = "Escaped"

			if enemy_name.is_empty():
				enemy_result_label.text = "You escaped from the battle."
			else:
				enemy_result_label.text = "You escaped from " + enemy_name + "."

			atomons_remaining_title.text = "ATOMONS REMAINING"
			atomons_remaining_label.text = str(atomons_remaining)
			rewards_title.text = "REWARDS"

		_:
			result_label.text = battle_result
			battle_status_label.text = battle_result

			if enemy_name.is_empty():
				enemy_result_label.text = "Battle completed."
			else:
				enemy_result_label.text = enemy_name

			atomons_remaining_title.text = "ATOMONS REMAINING"
			atomons_remaining_label.text = str(atomons_remaining)


# ============================================================
# REWARDS
# ============================================================

func update_rewards() -> void:
	coins_label.text = "+%d Coins" % coins_reward

	reward_label_1.visible = false
	reward_label_2.visible = false

	if item_rewards.size() > 0:
		reward_label_1.visible = true
		reward_label_1.text = item_rewards[0]

	if item_rewards.size() > 1:
		reward_label_2.visible = true
		reward_label_2.text = item_rewards[1]


# ============================================================
# SET BATTLE RESULT
# ============================================================

func set_battle_result(
	result: String,
	enemy: String = "",
	defeated: bool = false,
	remaining: int = 0
) -> void:
	battle_result = result
	enemy_name = enemy
	enemy_defeated = defeated
	atomons_remaining = remaining

	update_battle_review()
	update_battle_result()


# ============================================================
# FUSION LESSON
# ============================================================

func set_fusion_lesson(
	skill_name: String,
	formula: String,
	atoms: Array[String],
	bond_type: String,
	octet_completed: bool,
	octet_explanation: String = "",
	takeaway: String = ""
) -> void:
	fusion_used = true
	fusion_skill_name = skill_name
	fusion_formula = formula
	fusion_atoms = atoms
	fusion_bond_type = bond_type

	octet_rule_completed = octet_completed
	octet_rule_explanation = octet_explanation

	key_takeaway = takeaway

	update_battle_review()


# ============================================================
# OCTET RULE LESSON
# ============================================================

func set_octet_lesson(
	completed: bool,
	explanation: String = "",
	takeaway: String = ""
) -> void:
	octet_rule_completed = completed
	octet_rule_explanation = explanation

	if not takeaway.is_empty():
		key_takeaway = takeaway

	update_battle_review()


# ============================================================
# SET REWARDS
# ============================================================

func set_rewards(
	coins: int,
	items: Array[String] = []
) -> void:
	coins_reward = coins
	item_rewards = items.duplicate()

	update_rewards()


# ============================================================
# REVIEW CONTINUE
# ============================================================

func _on_review_continue_pressed() -> void:
	show_result_page()


# ============================================================
# RESULT CONTINUE
# ============================================================

func _on_result_continue_pressed() -> void:
	continue_pressed.emit()
	queue_free()

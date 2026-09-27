extends Control
class_name BattleSummary


# ============================================================
# SIGNALS
# ============================================================

signal continue_pressed


# ============================================================
# BATTLE RESULT DATA
# ============================================================

var battle_result: String = "Victory"
var enemy_name: String = ""
var enemy_defeated: bool = false
var atomons_remaining: int = 0


# ============================================================
# FUSION / LEARNING DATA
# ============================================================

var fusion_used: bool = false
var fusion_skill_name: String = ""
var fusion_formula: String = ""
var fusion_atoms: Array[String] = []
var fusion_bond_type: String = ""

var octet_rule_completed: bool = false
var octet_rule_explanation: String = ""

var key_takeaway: String = ""


# ============================================================
# REWARD DATA
# ============================================================

var coins_reward: int = 0
var item_rewards: Array[String] = []


# ============================================================
# PAGE UI
# ============================================================

@onready var review_page: Control = $CardBackground/FormBG/ReviewPage
@onready var result_page: Control = $CardBackground/FormBG/ResultPage


# ============================================================
# REVIEW PAGE UI
# ============================================================

@onready var review_header: Label = $CardBackground/FormBG/ReviewPage/Title/Header
@onready var review_battle_name: Label = $CardBackground/FormBG/ReviewPage/Title/BattleName


# ------------------------------------------------------------
# WHAT YOU LEARNED
# ------------------------------------------------------------

@onready var learning_section_1_title: Label = $CardBackground/FormBG/ReviewPage/WhatYouLearnedPanel/Header
@onready var learning_section_1_content: Label = $CardBackground/FormBG/ReviewPage/WhatYouLearnedPanel/ScrollContainer/Content


# ------------------------------------------------------------
# BATTLE LESSON
# ------------------------------------------------------------

@onready var learning_section_2_title: Label = $CardBackground/FormBG/ReviewPage/BattleLessonPanel/Header
@onready var learning_section_2_content: Label = $CardBackground/FormBG/ReviewPage/BattleLessonPanel/ScrollContainer/Content


# ------------------------------------------------------------
# KEY IDEA
# ------------------------------------------------------------

@onready var takeaway_title: Label = $CardBackground/FormBG/ReviewPage/KeyIdeaPanel/Header
@onready var takeaway_content: Label = $CardBackground/FormBG/ReviewPage/KeyIdeaPanel/ScrollContainer/Content


# ============================================================
# RESULT PAGE UI
# ============================================================

@onready var result_header: Label = $CardBackground/FormBG/ResultPage/Title/Header
@onready var result_label: Label = $CardBackground/FormBG/ResultPage/Title/Result

@onready var battle_status_label: Label = $CardBackground/FormBG/ResultPage/ResultPanel/ResultContent/BattleStatus
@onready var enemy_result_label: Label = $CardBackground/FormBG/ResultPage/ResultPanel/ResultContent/EnemyResult
@onready var atomons_remaining_title: Label = $CardBackground/FormBG/ResultPage/ResultPanel/ResultContent/AtomonsRemainingTitle
@onready var atomons_remaining_label: Label = $CardBackground/FormBG/ResultPage/ResultPanel/ResultContent/AtomonsRemaining


# ============================================================
# REWARDS UI
# ============================================================

@onready var rewards_title: Label = $CardBackground/FormBG/ResultPage/BattleRewards/VBoxContainer/Title
@onready var coins_label: Label = $CardBackground/FormBG/ResultPage/BattleRewards/VBoxContainer/Rewards/Coins
@onready var reward_label_1: Label = $CardBackground/FormBG/ResultPage/BattleRewards/VBoxContainer/Rewards/Reward1
@onready var reward_label_2: Label = $CardBackground/FormBG/ResultPage/BattleRewards/VBoxContainer/Rewards/Reward2


# ============================================================
# CONTINUE BUTTONS
# ============================================================

@onready var continue_button: TextureButton = $CardBackground/ContinueButton
@onready var continue_button_2: TextureButton = $CardBackground/ContinueButton2


# ============================================================
# READY
# ============================================================

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
	learning_section_2_title.text = "BATTLE LESSON"
	takeaway_title.text = "KEY IDEA"

	# --------------------------------------------------------
	# CHEMISTRY INFORMATION
	# --------------------------------------------------------

	learning_section_1_content.text = get_learning_summary()

	# --------------------------------------------------------
	# BATTLE OUTCOME FACTORS
	# --------------------------------------------------------

	learning_section_2_content.text = get_battle_lesson()

	# --------------------------------------------------------
	# KEY IDEA
	# --------------------------------------------------------

	takeaway_content.text = get_default_key_idea()

	if not key_takeaway.is_empty():
		takeaway_content.text = key_takeaway

	# Reset scroll positions whenever the review is refreshed.
	reset_review_scrolls()


# ============================================================
# RESET REVIEW SCROLLS
# ============================================================

func reset_review_scrolls() -> void:

	var learning_scroll: ScrollContainer = $CardBackground/FormBG/ReviewPage/WhatYouLearnedPanel/ScrollContainer
	var lesson_scroll: ScrollContainer = $CardBackground/FormBG/ReviewPage/BattleLessonPanel/ScrollContainer
	var key_scroll: ScrollContainer = $CardBackground/FormBG/ReviewPage/KeyIdeaPanel/ScrollContainer

	learning_scroll.scroll_vertical = 0
	lesson_scroll.scroll_vertical = 0
	key_scroll.scroll_vertical = 0


# ============================================================
# CHEMISTRY LEARNING SUMMARY
# ============================================================

func get_learning_summary() -> String:

	var learning_lines: Array[String] = []

	# --------------------------------------------------------
	# FUSION
	# --------------------------------------------------------

	if fusion_used:

		if not fusion_skill_name.is_empty():
			learning_lines.append(
				"Fusion: " + fusion_skill_name
			)

		if not fusion_formula.is_empty():
			learning_lines.append(
				"Formula: " + fusion_formula
			)

		if not fusion_bond_type.is_empty():
			learning_lines.append(
				"Bond type: " + fusion_bond_type
			)

		if not fusion_atoms.is_empty():
			learning_lines.append(
				"Components: "
				+ str(fusion_atoms.size())
				+ " Atomons"
			)

		if octet_rule_completed:
			learning_lines.append(
				"Octet Rule challenge completed"
			)

			if not octet_rule_explanation.is_empty():
				learning_lines.append(
					octet_rule_explanation
				)

	# --------------------------------------------------------
	# OCTET RULE WITHOUT FUSION
	# --------------------------------------------------------

	elif octet_rule_completed:

		learning_lines.append(
			"Octet Rule challenge completed"
		)

		if not octet_rule_explanation.is_empty():
			learning_lines.append(
				octet_rule_explanation
			)

	# --------------------------------------------------------
	# NO CHEMISTRY ACTIVITY
	# --------------------------------------------------------

	if learning_lines.is_empty():
		return "No specific chemistry activity was recorded in this battle."

	return "\n\n".join(learning_lines)


# ============================================================
# BATTLE LESSON
# ============================================================
#
# This intentionally shows only important factors.
# It does NOT list every move performed during battle.
# ============================================================

func get_battle_lesson() -> String:

	var lesson_lines: Array[String] = []

	match battle_result.to_lower():

		# ====================================================
		# VICTORY
		# ====================================================

		"victory":

			lesson_lines.append(
				"✓ Enemy defeated"
			)

			if atomons_remaining > 0:
				lesson_lines.append(
					"✓ "
					+ str(atomons_remaining)
					+ " Atomon(s) remaining"
				)

			if fusion_used:

				lesson_lines.append(
					"✓ Fusion successfully used"
				)

				if not fusion_formula.is_empty():
					lesson_lines.append(
						"✓ Correct Fusion composition"
					)

				if octet_rule_completed:
					lesson_lines.append(
						"✓ Octet Rule challenge completed"
					)

			if lesson_lines.size() == 1:
				lesson_lines.append(
					"• Battle completed successfully"
				)


		# ====================================================
		# DEFEAT
		# ====================================================

		"defeat":

			if atomons_remaining <= 0:
				lesson_lines.append(
					"✗ All Atomons were defeated"
				)
			else:
				lesson_lines.append(
					"✗ Enemy was not defeated"
				)

			if not enemy_defeated:
				lesson_lines.append(
					"✗ Enemy remained active"
				)

			if fusion_used:

				lesson_lines.append(
					"✓ Fusion learning activity completed"
				)

				if octet_rule_completed:
					lesson_lines.append(
						"✓ Octet Rule challenge completed"
					)

			lesson_lines.append(
				"• Review Atomon selection and HP management"
			)


		# ====================================================
		# ESCAPED
		# ====================================================

		"escaped":

			lesson_lines.append(
				"• Battle ended by escape"
			)

			if not enemy_defeated:
				lesson_lines.append(
					"• Enemy remained undefeated"
				)

			if atomons_remaining > 0:
				lesson_lines.append(
					"• "
					+ str(atomons_remaining)
					+ " Atomon(s) remained"
				)

			if fusion_used:

				lesson_lines.append(
					"✓ Fusion learning activity completed"
				)

				if octet_rule_completed:
					lesson_lines.append(
						"✓ Octet Rule challenge completed"
					)


		# ====================================================
		# OTHER
		# ====================================================

		_:

			lesson_lines.append(
				"• Battle outcome recorded"
			)


	if lesson_lines.is_empty():
		return "No specific battle lesson was recorded."

	return "\n".join(lesson_lines)


# ============================================================
# DEFAULT KEY IDEA
# ============================================================

func get_default_key_idea() -> String:

	# --------------------------------------------------------
	# FUSION
	# --------------------------------------------------------

	if fusion_used:
		return "Chemical composition determines which Fusion reactions can be performed."

	# --------------------------------------------------------
	# OCTET RULE
	# --------------------------------------------------------

	if octet_rule_completed:
		return "Valence electrons help explain how atoms participate in chemical bonding."

	# --------------------------------------------------------
	# BATTLE OUTCOME
	# --------------------------------------------------------

	match battle_result.to_lower():

		"victory":
			return "Battle outcome is affected by Atomon selection, HP, and battle decisions."

		"defeat":
			return "Review Atomon selection, HP, and battle decisions before the next battle."

		"escaped":
			return "Retreating allows the player to prepare before another encounter."

		_:
			return "Battle results can be used to review both chemistry and battle decisions."


# ============================================================
# BATTLE RESULT
# ============================================================

func update_battle_result() -> void:

	result_header.text = "BATTLE RESULTS"

	match battle_result.to_lower():

		# ====================================================
		# VICTORY
		# ====================================================

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


		# ====================================================
		# DEFEAT
		# ====================================================

		"defeat":

			result_label.text = "DEFEAT"
			battle_status_label.text = "Defeat"

			enemy_result_label.text = "Your Atomons were defeated."

			atomons_remaining_title.text = "ATOMONS REMAINING"
			atomons_remaining_label.text = str(atomons_remaining)

			rewards_title.text = "REWARDS"


		# ====================================================
		# ESCAPED
		# ====================================================

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


		# ====================================================
		# OTHER
		# ====================================================

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
# UPDATE REWARDS
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
# SET FUSION LESSON
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
# SET OCTET RULE LESSON
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
# CONTINUE FROM REVIEW
# ============================================================

func _on_review_continue_pressed() -> void:

	show_result_page()


# ============================================================
# CONTINUE FROM RESULTS
# ============================================================

func _on_result_continue_pressed() -> void:

	continue_pressed.emit()

	queue_free()

extends Control

signal fusion_challenge_finished(
	success: bool,
	recipe: FusionRecipe,
	selected_atomons: Array[AtomonInstance]
)


@onready var title_label: Label = $Panel/VBoxContainer3/Title
@onready var lesson_label: Label = $Panel/VBoxContainer3/ScrollContainer/Lesson

@onready var question_label: Label = $Panel/VBoxContainer3/Question
@onready var feedback_label: Label = $Panel/VBoxContainer2/Feedback
@onready var continue_button: TextureButton = $Panel/VBoxContainer2/Continue

@onready var answer_1: TextureButton = $Panel/VBoxContainer2/Control/Answer
@onready var answer_2: TextureButton = $Panel/VBoxContainer2/Control/Answer2
@onready var answer_3: TextureButton = $Panel/VBoxContainer2/Control/Answer3
@onready var answer_4: TextureButton = $Panel/VBoxContainer2/Control/Answer4

@onready var answer_1_label: Label = $Panel/VBoxContainer2/Control/Answer/Label
@onready var answer_2_label: Label = $Panel/VBoxContainer2/Control/Answer2/Label
@onready var answer_3_label: Label = $Panel/VBoxContainer2/Control/Answer3/Label
@onready var answer_4_label: Label = $Panel/VBoxContainer2/Control/Answer4/Label


# ============================================================
# CHALLENGE DATA
# ============================================================

var fusion_recipe: FusionRecipe = null

var selected_atomons: Array[AtomonInstance] = []

var correct_answer_index: int = 0

var answered: bool = false

var challenge_success: bool = false

# Feedback generated together with the question.
var correct_feedback: String = ""
var wrong_feedback: String = ""


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_STOP


	# --------------------------------------------------------
	# Connect answer buttons.
	# --------------------------------------------------------

	if not answer_1.pressed.is_connected(_on_answer_1_pressed):
		answer_1.pressed.connect(_on_answer_1_pressed)

	if not answer_2.pressed.is_connected(_on_answer_2_pressed):
		answer_2.pressed.connect(_on_answer_2_pressed)

	if not answer_3.pressed.is_connected(_on_answer_3_pressed):
		answer_3.pressed.connect(_on_answer_3_pressed)

	if not answer_4.pressed.is_connected(_on_answer_4_pressed):
		answer_4.pressed.connect(_on_answer_4_pressed)


	# --------------------------------------------------------
	# Continue button.
	# --------------------------------------------------------

	if not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)


	# --------------------------------------------------------
	# Default state.
	# --------------------------------------------------------

	title_label.text = "BATTLE LEARNING"

	lesson_label.text = ""
	question_label.text = ""
	feedback_label.text = ""

	continue_button.disabled = true

	answer_1.disabled = false
	answer_2.disabled = false
	answer_3.disabled = false
	answer_4.disabled = false


# ============================================================
# FUSION CHALLENGE SETUP
# ============================================================

func setup_fusion_challenge(
	recipe: FusionRecipe,
	components: Array[AtomonInstance]
) -> void:

	fusion_recipe = recipe

	selected_atomons = components.duplicate()

	answered = false
	challenge_success = false

	prepare_fusion_challenge()


# ============================================================
# PREPARE FUSION CHALLENGE
# ============================================================

func prepare_fusion_challenge() -> void:

	if fusion_recipe == null:
		setup_default_challenge()
		return


	title_label.text = "OCTET RULE CHALLENGE"


	# --------------------------------------------------------
	# Get information directly from the FusionRecipe.
	# --------------------------------------------------------

	var formula := fusion_recipe.chemical_formula
	var compound_name := fusion_recipe.compound_name

	var explanation := fusion_recipe.octet_rule_explanation
	var fusion_description := fusion_recipe.fusion_description


	# --------------------------------------------------------
	# Build the lesson dynamically.
	# --------------------------------------------------------

	lesson_label.text = (
		"Fusion: " + formula + " (" + compound_name + ")\n\n"
		+ fusion_description
		+ "\n\n"
		+ explanation
	)


	# --------------------------------------------------------
	# Generate a challenge from the recipe.
	# --------------------------------------------------------

	generate_dynamic_challenge()


# ============================================================
# GENERATE DYNAMIC CHALLENGE
# ============================================================

func generate_dynamic_challenge() -> void:

	var challenge_pool: Array[Dictionary] = []

	# --------------------------------------------------------
	# Build all available question types.
	# --------------------------------------------------------

	var total_valence_question := build_total_valence_question()

	if not total_valence_question.is_empty():
		challenge_pool.append(total_valence_question)


	var element_valence_question := build_element_valence_question()

	if not element_valence_question.is_empty():
		challenge_pool.append(element_valence_question)


	var bond_type_question := build_bond_type_question()

	if not bond_type_question.is_empty():
		challenge_pool.append(bond_type_question)


	var octet_question := build_octet_rule_question()

	if not octet_question.is_empty():
		challenge_pool.append(octet_question)


	# --------------------------------------------------------
	# If no dynamic question could be created, use fallback.
	# --------------------------------------------------------

	if challenge_pool.is_empty():
		setup_default_challenge()
		return


	# --------------------------------------------------------
	# Pick one question randomly.
	# --------------------------------------------------------

	var selected_challenge: Dictionary = challenge_pool[
		randi() % challenge_pool.size()
	]


	apply_challenge(selected_challenge)


# ============================================================
# TOTAL VALENCE ELECTRON QUESTION
# ============================================================

func build_total_valence_question() -> Dictionary:

	if fusion_recipe == null:
		return {}


	var total_valence := 0

	var calculation_parts: Array[String] = []


	for requirement in fusion_recipe.requirements:

		if requirement == null:
			continue

		if requirement.element == null:
			continue


		var element: AtomonData = requirement.element

		var amount: int = requirement.amount

		var valence: int = element.valence_electrons

		total_valence += valence * amount


		calculation_parts.append(
			str(amount)
			+ " × "
			+ element.chemical_symbol
			+ " (" + str(valence) + ")"
		)


	if fusion_recipe.requirements.is_empty():
		return {}


	var options: Array[String] = build_number_options(
		total_valence
	)


	return {
		"question":
			"How many total valence electrons are contributed "
			+ "by the atoms used to form "
			+ fusion_recipe.chemical_formula
			+ "?",

		"correct_answer":
			str(total_valence),

		"options":
			options,

		"correct_feedback":
			"The selected elements contribute "
			+ str(total_valence)
			+ " valence electrons in total.\n\n"
			+ "Calculation: "
			+ ", ".join(calculation_parts)
			+ ".",

		"wrong_feedback":
			"The total must be calculated from the "
			+ "valence electrons of every element and "
			+ "the number of atoms of each element."
	}


# ============================================================
# ELEMENT VALENCE QUESTION
# ============================================================

func build_element_valence_question() -> Dictionary:

	if fusion_recipe == null:
		return {}


	var valid_requirements: Array = []


	for requirement in fusion_recipe.requirements:

		if requirement == null:
			continue

		if requirement.element == null:
			continue

		valid_requirements.append(requirement)


	if valid_requirements.is_empty():
		return {}


	# Pick one of the elements in the recipe.
	var requirement = valid_requirements[
		randi() % valid_requirements.size()
	]


	var element: AtomonData = requirement.element

	var symbol := element.chemical_symbol

	var correct_value: int = element.valence_electrons


	var options: Array[String] = build_number_options(
		correct_value
	)


	return {
		"question":
			"How many valence electrons does "
			+ symbol
			+ " contribute per atom?",

		"correct_answer":
			str(correct_value),

		"options":
			options,

		"correct_feedback":
			symbol
			+ " has "
			+ str(correct_value)
			+ " valence electrons.",

		"wrong_feedback":
			"Check the valence electron value of "
			+ symbol
			+ " in its AtomonData."
	}


# ============================================================
# BOND TYPE QUESTION
# ============================================================

func build_bond_type_question() -> Dictionary:

	if fusion_recipe == null:
		return {}


	var correct_type := fusion_recipe.bond_type

	if correct_type.is_empty():
		return {}


	var all_types := [
		"Covalent",
		"Ionic",
		"Metallic",
		"Other"
	]


	var options: Array[String] = []

	options.append(correct_type)


	for bond_type in all_types:

		if bond_type == correct_type:
			continue

		options.append(bond_type)


		if options.size() >= 4:
			break


	options.shuffle()


	return {
		"question":
			"What type of chemical bond is associated "
			+ "with the formation of "
			+ fusion_recipe.chemical_formula
			+ "?",

		"correct_answer":
			correct_type,

		"options":
			options,

		"correct_feedback":
			fusion_recipe.chemical_formula
			+ " uses a "
			+ correct_type
			+ " bond type in this Fusion recipe.",

		"wrong_feedback":
			"The bond type is defined by the "
			+ "FusionRecipe for "
			+ fusion_recipe.chemical_formula
			+ "."
	}


# ============================================================
# OCTET RULE QUESTION
# ============================================================

func build_octet_rule_question() -> Dictionary:

	var options: Array[String] = [
		"8 valence electrons",
		"8 protons",
		"8 neutrons",
		"8 electron shells"
	]


	return {
		"question":
			"According to the Octet Rule, what do many "
			+ "main-group atoms tend to achieve in their "
			+ "outermost electron shell?",

		"correct_answer":
			"8 valence electrons",

		"options":
			options,

		"correct_feedback":
			"Many main-group atoms tend to achieve "
			+ "eight valence electrons in their outermost "
			+ "electron shell.",

		"wrong_feedback":
			"The Octet Rule concerns valence electrons "
			+ "in the outermost electron shell."
	}


# ============================================================
# BUILD NUMBER OPTIONS
# ============================================================

func build_number_options(correct_value: int) -> Array[String]:

	var possible_values: Array[int] = []

	# --------------------------------------------------------
	# Generate nearby incorrect values.
	# --------------------------------------------------------

	var candidates := [
		correct_value - 2,
		correct_value - 1,
		correct_value + 1,
		correct_value + 2,
		correct_value + 3,
		correct_value - 3
	]


	for value in candidates:

		if value < 0:
			continue

		if value == correct_value:
			continue

		if value in possible_values:
			continue

		possible_values.append(value)

		if possible_values.size() >= 3:
			break


	# --------------------------------------------------------
	# Convert to strings.
	# --------------------------------------------------------

	var options: Array[String] = []

	options.append(str(correct_value))


	for value in possible_values:
		options.append(str(value))


	# --------------------------------------------------------
	# Make sure there are exactly 4 answers.
	# --------------------------------------------------------

	while options.size() < 4:

		var fallback_value := correct_value + options.size() + 2

		if fallback_value in options:
			continue

		options.append(str(fallback_value))


	options.shuffle()

	return options


# ============================================================
# APPLY GENERATED CHALLENGE
# ============================================================

func apply_challenge(challenge: Dictionary) -> void:

	var question: String = challenge.get(
		"question",
		""
	)

	var correct_answer: String = challenge.get(
		"correct_answer",
		""
	)

	var options: Array = challenge.get(
		"options",
		[]
	)


	correct_feedback = challenge.get(
		"correct_feedback",
		"Correct!"
	)

	wrong_feedback = challenge.get(
		"wrong_feedback",
		"Not quite."
	)


	question_label.text = question


	# --------------------------------------------------------
	# Apply the four generated answers.
	# --------------------------------------------------------

	answer_1_label.text = str(options[0])
	answer_2_label.text = str(options[1])
	answer_3_label.text = str(options[2])
	answer_4_label.text = str(options[3])


	# --------------------------------------------------------
	# Find the correct answer after shuffling.
	# --------------------------------------------------------

	correct_answer_index = -1


	for i in range(options.size()):

		if str(options[i]) == correct_answer:
			correct_answer_index = i
			break


	# Safety check.
	if correct_answer_index == -1:

		print(
			"[BattleLearning] ERROR: "
			+ "Could not find correct answer."
		)

		setup_default_challenge()
		return


	reset_question_state()


	print(
		"[BattleLearning] Generated challenge for: ",
		fusion_recipe.chemical_formula
	)

	print(
		"[BattleLearning] Question: ",
		question
	)

	print(
		"[BattleLearning] Correct answer: ",
		correct_answer
	)


# ============================================================
# DEFAULT CHALLENGE
# ============================================================

func setup_default_challenge() -> void:

	fusion_recipe = null

	selected_atomons.clear()

	answered = false

	challenge_success = false

	correct_feedback = (
		"Many main-group atoms tend to achieve "
		+ "eight valence electrons in their "
		+ "outermost electron shell."
	)

	wrong_feedback = (
		"The Octet Rule concerns valence electrons "
		+ "in the outermost electron shell."
	)


	title_label.text = "OCTET RULE CHALLENGE"


	lesson_label.text = (
		"Review the Octet Rule.\n\n"
		+ "Many main-group atoms tend to become more "
		+ "stable when their outermost electron shell "
		+ "contains eight valence electrons."
	)


	question_label.text = (
		"According to the Octet Rule, what do many "
		+ "main-group atoms tend to achieve in their "
		+ "outermost electron shell?"
	)


	answer_1_label.text = "8 valence electrons"
	answer_2_label.text = "8 protons"
	answer_3_label.text = "8 neutrons"
	answer_4_label.text = "8 electron shells"


	correct_answer_index = 0

	reset_question_state()


# ============================================================
# RESET QUESTION STATE
# ============================================================

func reset_question_state() -> void:

	answered = false

	challenge_success = false

	feedback_label.text = ""

	continue_button.disabled = true

	answer_1.disabled = false
	answer_2.disabled = false
	answer_3.disabled = false
	answer_4.disabled = false


# ============================================================
# ANSWER BUTTONS
# ============================================================

func _on_answer_1_pressed() -> void:
	_answer_pressed(0)


func _on_answer_2_pressed() -> void:
	_answer_pressed(1)


func _on_answer_3_pressed() -> void:
	_answer_pressed(2)


func _on_answer_4_pressed() -> void:
	_answer_pressed(3)


# ============================================================
# ANSWER PROCESSING
# ============================================================

func _answer_pressed(answer_index: int) -> void:

	if answered:
		return


	answered = true


	answer_1.disabled = true
	answer_2.disabled = true
	answer_3.disabled = true
	answer_4.disabled = true


	# --------------------------------------------------------
	# CORRECT
	# --------------------------------------------------------

	if answer_index == correct_answer_index:

		challenge_success = true

		feedback_label.text = (
			"Correct!\n\n"
			+ correct_feedback
		)

		print(
			"[BattleLearning] Octet Rule challenge passed."
		)


	# --------------------------------------------------------
	# WRONG
	# --------------------------------------------------------

	else:

		challenge_success = false

		feedback_label.text = (
			"Not quite.\n\n"
			+ wrong_feedback
		)

		print(
			"[BattleLearning] Octet Rule challenge failed."
		)


	continue_button.disabled = false


# ============================================================
# CONTINUE
# ============================================================

func _on_continue_pressed() -> void:

	if not answered:
		return


	print(
		"[BattleLearning] Continue pressed."
	)

	print(
		"[BattleLearning] Challenge result: ",
		challenge_success
	)


	fusion_challenge_finished.emit(
		challenge_success,
		fusion_recipe,
		selected_atomons
	)

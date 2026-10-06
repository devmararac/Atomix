extends Control


signal fusion_challenge_finished(
	success: bool,
	recipe: FusionRecipe,
	selected_atomons: Array[AtomonInstance]
)


# ============================================================
# UI
# ============================================================

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
# FUSION DATA
# ============================================================

var fusion_recipe: FusionRecipe = null
var selected_atomons: Array[AtomonInstance] = []


# ============================================================
# CHALLENGE STATE
# ============================================================

var current_element: AtomonData = null
var current_correct_answer: String = ""
var correct_answer_index: int = -1
var answered: bool = false
var challenge_success: bool = false
var current_correct_feedback: String = ""
var current_wrong_feedback: String = ""
var current_question_type: String = ""


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	randomize()

	mouse_filter = Control.MOUSE_FILTER_STOP

	# --------------------------------------------------------
	# Answer buttons
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
	# Continue button
	# --------------------------------------------------------

	if not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)

	# --------------------------------------------------------
	# Initial UI
	# --------------------------------------------------------

	title_label.text = "OCTET RULE CHALLENGE"
	lesson_label.text = ""
	question_label.text = ""
	feedback_label.text = ""

	continue_button.disabled = true

	answer_1.disabled = false
	answer_2.disabled = false
	answer_3.disabled = false
	answer_4.disabled = false

	answer_1.visible = true
	answer_2.visible = true
	answer_3.visible = true
	answer_4.visible = true


# ============================================================
# SETUP FUSION CHALLENGE
# ============================================================

func setup_fusion_challenge(
	recipe: FusionRecipe,
	components: Array[AtomonInstance]
) -> void:

	fusion_recipe = recipe
	selected_atomons = components.duplicate()

	current_element = null
	current_correct_answer = ""
	correct_answer_index = -1
	answered = false
	challenge_success = false
	current_question_type = ""

	# --------------------------------------------------------
	# Check recipe
	# --------------------------------------------------------

	if fusion_recipe == null:
		setup_default_challenge()
		return

	if fusion_recipe.requirements.is_empty():
		setup_default_challenge()
		return

	prepare_fusion_lesson()
	prepare_learning_challenge()


# ============================================================
# PREPARE FUSION LESSON
# ============================================================

func prepare_fusion_lesson() -> void:

	if fusion_recipe == null:
		return

	var formula: String = fusion_recipe.chemical_formula
	var compound_name: String = fusion_recipe.compound_name
	var explanation: String = fusion_recipe.octet_rule_explanation
	var fusion_description: String = fusion_recipe.fusion_description

	lesson_label.text = (
		"Fusion: "
		+ formula
		+ " ("
		+ compound_name
		+ ")\n\n"
		+ fusion_description
		+ "\n\n"
		+ explanation
		+ "\n\n"
		+ "Before Fusion can be performed, answer the "
		+ "Octet Rule challenge."
	)


# ============================================================
# PREPARE LEARNING CHALLENGE
# ============================================================

func prepare_learning_challenge() -> void:

	var valid_elements: Array[AtomonData] = (
		get_fusion_learning_elements()
	)

	if valid_elements.is_empty():
		setup_default_challenge()
		return

	# --------------------------------------------------------
	# Randomly choose one of the unique elements.
	# --------------------------------------------------------

	current_element = (
		valid_elements[
			randi() % valid_elements.size()
		]
	)

	# --------------------------------------------------------
	# Randomly choose a question type.
	# --------------------------------------------------------

	var question_type := choose_question_type(
		current_element
	)

	current_question_type = question_type

	# --------------------------------------------------------
	# Build the selected question.
	# --------------------------------------------------------

	build_learning_question(
		current_element,
		current_question_type
	)


# ============================================================
# GET UNIQUE FUSION LEARNING ELEMENTS
# ============================================================

func get_fusion_learning_elements() -> Array[AtomonData]:

	var elements: Array[AtomonData] = []

	if fusion_recipe == null:
		return elements

	for requirement in fusion_recipe.requirements:

		if requirement == null:
			continue

		if requirement.element == null:
			continue

		var element: AtomonData = requirement.element
		var already_added := false

		for existing_element in elements:

			if existing_element == element:
				already_added = true
				break

			if existing_element.chemical_symbol == (
				element.chemical_symbol
			):
				already_added = true
				break

		if already_added:
			continue

		elements.append(element)

	return elements


# ============================================================
# CHOOSE QUESTION TYPE
# ============================================================

func choose_question_type(
	element: AtomonData
) -> String:

	if element == null:
		return "valence"

	var question_types: Array[String] = []

	# --------------------------------------------------------
	# Every element can have a valence-electron question.
	# --------------------------------------------------------

	question_types.append("valence")

	# --------------------------------------------------------
	# Elements that are being taught with the Octet Rule
	# can receive an octet completion question.
	# --------------------------------------------------------

	if follows_octet_rule(element):

		question_types.append("octet_needed")
		question_types.append("true_false_octet")

	# --------------------------------------------------------
	# Hydrogen and Helium use the duet rule.
	# --------------------------------------------------------

	if follows_duet_rule(element):

		question_types.append("duet_needed")
		question_types.append("true_false_duet")

	# --------------------------------------------------------
	# Element identification can be used for any element.
	# --------------------------------------------------------

	question_types.append("identify_element")

	return question_types[
		randi() % question_types.size()
	]


# ============================================================
# RULE HELPERS
# ============================================================

func follows_duet_rule(
	element: AtomonData
) -> bool:

	if element == null:
		return false

	return (
		element.chemical_symbol == "H"
		or element.chemical_symbol == "He"
	)


func follows_octet_rule(
	element: AtomonData
) -> bool:

	if element == null:
		return false

	if follows_duet_rule(element):
		return false

	if element.valence_electrons <= 0:
		return false

	if element.valence_electrons >= 8:
		return false

	return true


# ============================================================
# BUILD LEARNING QUESTION
# ============================================================

func build_learning_question(
	element: AtomonData,
	question_type: String
) -> void:

	if element == null:
		setup_default_challenge()
		return

	match question_type:

		"valence":
			build_valence_question(element)

		"octet_needed":
			build_octet_needed_question(element)

		"duet_needed":
			build_duet_needed_question(element)

		"true_false_octet":
			build_true_false_octet_question(element)

		"true_false_duet":
			build_true_false_duet_question(element)

		"identify_element":
			build_identify_element_question(element)

		_:
			build_valence_question(element)


# ============================================================
# QUESTION TYPE 1
# VALENCE ELECTRONS
# ============================================================

func build_valence_question(
	element: AtomonData
) -> void:

	var symbol: String = element.chemical_symbol
	var valence: int = element.valence_electrons

	current_correct_answer = str(valence)

	current_correct_feedback = (
		symbol
		+ " has "
		+ str(valence)
		+ " valence electrons.\n\n"
		+ "Valence electrons are the electrons in the "
		+ "outermost electron shell. They are important "
		+ "in understanding how atoms form chemical bonds."
	)

	current_wrong_feedback = (
		"Remember to look at the number of valence "
		+ "electrons of "
		+ symbol
		+ "."
	)

	var options := build_number_options(valence)

	apply_challenge(
		"How many valence electrons does "
		+ symbol
		+ " have?",
		current_correct_answer,
		options,
		current_correct_feedback,
		current_wrong_feedback
	)


# ============================================================
# QUESTION TYPE 2
# OCTET ELECTRONS NEEDED
# ============================================================

func build_octet_needed_question(
	element: AtomonData
) -> void:

	var symbol: String = element.chemical_symbol
	var valence: int = element.valence_electrons
	var needed: int = 8 - valence

	if needed < 0:
		needed = 0

	current_correct_answer = str(needed)

	var needed_word := "electrons"

	if needed == 1:
		needed_word = "electron"

	current_correct_feedback = (
		symbol
		+ " has "
		+ str(valence)
		+ " valence electrons.\n\n"
		+ "An octet means 8 valence electrons, so "
		+ symbol
		+ " needs "
		+ str(needed)
		+ " more "
		+ needed_word
		+ "."
	)

	current_wrong_feedback = (
		"An octet means 8 valence electrons.\n\n"
		+ symbol
		+ " currently has "
		+ str(valence)
		+ " valence electrons."
	)

	var options := build_number_options(needed)

	apply_challenge(
		symbol
		+ " has "
		+ str(valence)
		+ " valence electrons.\n\n"
		+ "How many more electrons does "
		+ symbol
		+ " need to complete its octet?",
		current_correct_answer,
		options,
		current_correct_feedback,
		current_wrong_feedback
	)


# ============================================================
# QUESTION TYPE 3
# DUET ELECTRONS NEEDED
# ============================================================

func build_duet_needed_question(
	element: AtomonData
) -> void:

	var symbol: String = element.chemical_symbol
	var valence: int = element.valence_electrons
	var needed: int = 2 - valence

	if needed < 0:
		needed = 0

	current_correct_answer = str(needed)

	var needed_word := "electrons"

	if needed == 1:
		needed_word = "electron"

	current_correct_feedback = (
		symbol
		+ " follows the duet rule in this challenge.\n\n"
		+ "A duet is completed with 2 electrons in the "
		+ "outermost shell. "
		+ symbol
		+ " needs "
		+ str(needed)
		+ " more "
		+ needed_word
		+ "."
	)

	current_wrong_feedback = (
		symbol
		+ " is being considered using the duet rule.\n\n"
		+ "A duet means 2 electrons in the relevant "
		+ "outermost shell."
	)

	var options := build_number_options(needed)

	apply_challenge(
		symbol
		+ " has "
		+ str(valence)
		+ " valence electron.\n\n"
		+ "How many more electrons does "
		+ symbol
		+ " need to complete its duet?",
		current_correct_answer,
		options,
		current_correct_feedback,
		current_wrong_feedback
	)


# ============================================================
# QUESTION TYPE 4
# TRUE / FALSE OCTET
# ============================================================

func build_true_false_octet_question(
	element: AtomonData
) -> void:

	var symbol: String = element.chemical_symbol
	var valence: int = element.valence_electrons
	var correct_needed: int = 8 - valence

	if correct_needed < 0:
		correct_needed = 0

	# --------------------------------------------------------
	# Randomly decide whether the statement is TRUE or FALSE.
	# --------------------------------------------------------

	var statement_is_true: bool = (
		randi() % 2 == 0
	)

	var displayed_needed: int = correct_needed

	if not statement_is_true:

		var wrong_values: Array[int] = []

		for value in range(0, 9):

			if value == correct_needed:
				continue

			wrong_values.append(value)

		displayed_needed = wrong_values[
			randi() % wrong_values.size()
		]

	# --------------------------------------------------------
	# Build statement.
	# --------------------------------------------------------

	var displayed_word := "electrons"

	if displayed_needed == 1:
		displayed_word = "electron"

	var statement := (
		symbol
		+ " needs "
		+ str(displayed_needed)
		+ " more "
		+ displayed_word
		+ " to complete its octet."
	)

	# --------------------------------------------------------
	# TRUE / FALSE choices.
	# --------------------------------------------------------

	var options: Array[String] = [
		"TRUE",
		"FALSE"
	]

	options.shuffle()

	var correct_answer := (
		"TRUE"
		if statement_is_true
		else
		"FALSE"
	)

	# --------------------------------------------------------
	# Feedback.
	# --------------------------------------------------------

	var correct_word := "electrons"

	if correct_needed == 1:
		correct_word = "electron"

	current_correct_feedback = (
		symbol
		+ " has "
		+ str(valence)
		+ " valence electrons.\n\n"
		+ "An octet means 8 valence electrons, so "
		+ symbol
		+ " needs "
		+ str(correct_needed)
		+ " more "
		+ correct_word
		+ "."
	)

	current_wrong_feedback = (
		"Remember that an octet means 8 valence electrons.\n\n"
		+ symbol
		+ " has "
		+ str(valence)
		+ " valence electrons and needs "
		+ str(correct_needed)
		+ " more "
		+ correct_word
		+ "."
	)

	apply_challenge(
		statement
		+ "\n\nIs this statement TRUE or FALSE?",
		correct_answer,
		options,
		current_correct_feedback,
		current_wrong_feedback
	)


# ============================================================
# QUESTION TYPE 5
# TRUE / FALSE DUET
# ============================================================

func build_true_false_duet_question(
	element: AtomonData
) -> void:

	var symbol: String = element.chemical_symbol
	var valence: int = element.valence_electrons
	var correct_needed: int = 2 - valence

	if correct_needed < 0:
		correct_needed = 0

	# --------------------------------------------------------
	# Randomly decide whether the statement is TRUE or FALSE.
	# --------------------------------------------------------

	var statement_is_true: bool = (
		randi() % 2 == 0
	)

	var displayed_needed: int = correct_needed

	if not statement_is_true:

		var wrong_values: Array[int] = []

		for value in range(0, 3):

			if value == correct_needed:
				continue

			wrong_values.append(value)

		displayed_needed = wrong_values[
			randi() % wrong_values.size()
		]

	# --------------------------------------------------------
	# Build statement.
	# --------------------------------------------------------

	var displayed_word := "electrons"

	if displayed_needed == 1:
		displayed_word = "electron"

	var statement := (
		symbol
		+ " needs "
		+ str(displayed_needed)
		+ " more "
		+ displayed_word
		+ " to complete its duet."
	)

	# --------------------------------------------------------
	# TRUE / FALSE choices.
	# --------------------------------------------------------

	var options: Array[String] = [
		"TRUE",
		"FALSE"
	]

	options.shuffle()

	var correct_answer := (
		"TRUE"
		if statement_is_true
		else
		"FALSE"
	)

	# --------------------------------------------------------
	# Feedback.
	# --------------------------------------------------------

	var correct_word := "electrons"

	if correct_needed == 1:
		correct_word = "electron"

	current_correct_feedback = (
		symbol
		+ " follows the duet rule in this challenge.\n\n"
		+ "A duet is completed with 2 electrons. "
		+ symbol
		+ " has "
		+ str(valence)
		+ " valence electron"
		+ ("s" if valence != 1 else "")
		+ " and needs "
		+ str(correct_needed)
		+ " more "
		+ correct_word
		+ "."
	)

	current_wrong_feedback = (
		"Remember that the duet rule uses 2 electrons.\n\n"
		+ symbol
		+ " has "
		+ str(valence)
		+ " valence electron"
		+ ("s" if valence != 1 else "")
		+ " and needs "
		+ str(correct_needed)
		+ " more "
		+ correct_word
		+ "."
	)

	apply_challenge(
		statement
		+ "\n\nIs this statement TRUE or FALSE?",
		correct_answer,
		options,
		current_correct_feedback,
		current_wrong_feedback
	)


# ============================================================
# QUESTION TYPE 6
# IDENTIFY ELEMENT
# ============================================================

func build_identify_element_question(
	element: AtomonData
) -> void:

	if fusion_recipe == null:
		build_valence_question(element)
		return

	var learning_elements := (
		get_fusion_learning_elements()
	)

	if learning_elements.size() < 2:

		if follows_octet_rule(element):
			build_octet_needed_question(element)

		elif follows_duet_rule(element):
			build_duet_needed_question(element)

		else:
			build_valence_question(element)

		return

	var correct_symbol: String = element.chemical_symbol
	var options: Array[String] = []

	options.append(correct_symbol)

	# --------------------------------------------------------
	# Add other elements from this Fusion as distractors.
	# --------------------------------------------------------

	for other_element in learning_elements:

		if other_element == null:
			continue

		if other_element.chemical_symbol == correct_symbol:
			continue

		var other_symbol := other_element.chemical_symbol

		if other_symbol in options:
			continue

		options.append(other_symbol)

	# --------------------------------------------------------
	# Add generic distractors.
	# --------------------------------------------------------

	var generic_elements: Array[String] = [
		"H",
		"He",
		"C",
		"N",
		"O",
		"F",
		"Ne"
	]

	generic_elements.shuffle()

	for generic_symbol in generic_elements:

		if generic_symbol in options:
			continue

		options.append(generic_symbol)

		if options.size() >= 4:
			break

	current_correct_feedback = (
		"Correct.\n\n"
		+ correct_symbol
		+ " is one of the elements used in the "
		+ fusion_recipe.chemical_formula
		+ " Fusion."
	)

	current_wrong_feedback = (
		"Look at the elements involved in "
		+ fusion_recipe.chemical_formula
		+ "."
	)

	apply_challenge(
		"Which element is being reviewed in this question?\n\n"
		+ "It has "
		+ str(element.valence_electrons)
		+ " valence electrons.",
		correct_symbol,
		options,
		current_correct_feedback,
		current_wrong_feedback
	)


# ============================================================
# APPLY CHALLENGE
# ============================================================

func apply_challenge(
	question: String,
	correct_answer: String,
	options: Array[String],
	correct_feedback: String,
	wrong_feedback: String
) -> void:

	var is_true_false := (
		options.size() == 2
		and (
			(options[0] == "TRUE" and options[1] == "FALSE")
			or
			(options[0] == "FALSE" and options[1] == "TRUE")
		)
	)

	if options.size() < 2:

		push_error(
			"[BattleLearning] Challenge requires at least two options."
		)

		setup_default_challenge()
		return

	if not is_true_false and options.size() < 4:

		push_error(
			"[BattleLearning] Normal challenge requires four options."
		)

		setup_default_challenge()
		return

	current_correct_answer = correct_answer
	current_correct_feedback = correct_feedback
	current_wrong_feedback = wrong_feedback

	question_label.text = question

	answer_1_label.text = str(options[0])
	answer_2_label.text = str(options[1])

	if not is_true_false:
		answer_3_label.text = str(options[2])
		answer_4_label.text = str(options[3])

	correct_answer_index = -1

	for i in range(options.size()):

		if str(options[i]) == correct_answer:

			correct_answer_index = i
			break

	if correct_answer_index == -1:

		push_error(
			"[BattleLearning] Correct answer was not found."
		)

		setup_default_challenge()
		return

	# Reset button states first.
	reset_question_state()

	# Then apply the special TRUE/FALSE layout.
	if is_true_false:

		answer_3.visible = false
		answer_4.visible = false

	else:

		answer_3.visible = true
		answer_4.visible = true


# ============================================================
# NUMBER OPTIONS
# ============================================================

func build_number_options(
	correct_value: int
) -> Array[String]:

	var possible_values: Array[int] = []

	var candidates: Array[int] = [
		correct_value - 3,
		correct_value - 2,
		correct_value - 1,
		correct_value + 1,
		correct_value + 2,
		correct_value + 3,
		correct_value + 4,
		correct_value + 5
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

	var options: Array[String] = []

	options.append(str(correct_value))

	for value in possible_values:
		options.append(str(value))

	var fallback_value := 0

	while options.size() < 4:

		fallback_value += 1

		var fallback_text := str(fallback_value)

		if fallback_text in options:
			continue

		options.append(fallback_text)

	options.shuffle()

	return options


# ============================================================
# DEFAULT CHALLENGE
# ============================================================

func setup_default_challenge() -> void:

	current_element = null
	current_correct_answer = "8"
	current_question_type = "default"

	current_correct_feedback = (
		"The Octet Rule states that many main-group atoms "
		+ "tend to achieve eight valence electrons in their "
		+ "outermost electron shell."
	)

	current_wrong_feedback = (
		"An octet means having 8 valence electrons "
		+ "in the outermost electron shell."
	)

	title_label.text = "OCTET RULE CHALLENGE"

	lesson_label.text = (
		"Review the Octet Rule.\n\n"
		+ "Many main-group atoms tend to become more stable "
		+ "when their outermost electron shell contains "
		+ "eight valence electrons."
	)

	question_label.text = (
		"How many valence electrons are associated with "
		+ "a complete octet?"
	)

	var options: Array[String] = [
		"8",
		"2",
		"6",
		"10"
	]

	options.shuffle()

	answer_1_label.text = options[0]
	answer_2_label.text = options[1]
	answer_3_label.text = options[2]
	answer_4_label.text = options[3]

	answer_1.visible = true
	answer_2.visible = true
	answer_3.visible = true
	answer_4.visible = true

	correct_answer_index = -1

	for i in range(options.size()):

		if options[i] == current_correct_answer:
			correct_answer_index = i
			break

	reset_question_state()


# ============================================================
# RESET QUESTION
# ============================================================

func reset_question_state() -> void:

	answered = false
	challenge_success = false

	feedback_label.text = ""
	continue_button.disabled = true

	# --------------------------------------------------------
	# Restore all four buttons.
	#
	# True/False questions hide Answer 3 and Answer 4
	# after this function runs.
	# --------------------------------------------------------

	answer_1.visible = true
	answer_2.visible = true
	answer_3.visible = true
	answer_4.visible = true

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

func _answer_pressed(
	answer_index: int
) -> void:

	if answered:
		return

	answered = true

	answer_1.disabled = true
	answer_2.disabled = true
	answer_3.disabled = true
	answer_4.disabled = true

	if answer_index == correct_answer_index:

		challenge_success = true

		feedback_label.text = (
			"Correct!\n\n"
			+ current_correct_feedback
		)

		print(
			"[BattleLearning] Octet Rule challenge passed."
		)

	else:

		challenge_success = false

		feedback_label.text = (
			"Not quite.\n\n"
			+ current_wrong_feedback
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

	# --------------------------------------------------------
	# Only ONE question is asked per Fusion attempt.
	# --------------------------------------------------------

	if challenge_success:

		print(
			"[BattleLearning] Fusion challenge completed successfully."
		)

		emit_challenge_result(true)

	else:

		print(
			"[BattleLearning] Fusion challenge failed."
		)

		emit_challenge_result(false)


# ============================================================
# EMIT FINAL RESULT
# ============================================================

func emit_challenge_result(
	success: bool
) -> void:

	print(
		"[BattleLearning] Final challenge result: ",
		success
	)

	if fusion_recipe != null:

		print(
			"[BattleLearning] Recipe: ",
			fusion_recipe.chemical_formula
		)

	fusion_challenge_finished.emit(
		success,
		fusion_recipe,
		selected_atomons
	)

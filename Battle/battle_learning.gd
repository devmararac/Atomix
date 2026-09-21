extends Control

signal fusion_challenge_finished(
	success: bool,
	recipe: FusionRecipe,
	selected_atomons: Array[AtomonInstance]
)

@onready var title_label: Label = $Panel/VBoxContainer3/Title
@onready var lesson_label: Label = $Panel/VBoxContainer3/Lesson

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


var fusion_recipe: FusionRecipe = null
var selected_atomons: Array[AtomonInstance] = []

var correct_answer_index := 0
var answered := false
var challenge_success := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Connect answer buttons.
	answer_1.pressed.connect(_on_answer_1_pressed)
	answer_2.pressed.connect(_on_answer_2_pressed)
	answer_3.pressed.connect(_on_answer_3_pressed)
	answer_4.pressed.connect(_on_answer_4_pressed)

	# Connect Continue button.
	continue_button.pressed.connect(_on_continue_pressed)

	# Default state.
	title_label.text = "BATTLE LEARNING"

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


func prepare_fusion_challenge() -> void:

	if fusion_recipe == null:
		setup_default_challenge()
		return

	title_label.text = "OCTET RULE CHALLENGE"

	var formula := fusion_recipe.chemical_formula

	lesson_label.text = (
		"Fusion: " + formula + "\n\n"
		+ "Before your Atomons can perform this Fusion, "
		+ "review the Octet Rule.\n\n"
		+ "Many main-group atoms tend to become more stable "
		+ "when their outermost electron shell contains "
		+ "eight valence electrons."
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
# DEFAULT CHALLENGE
# ============================================================

func setup_default_challenge() -> void:

	fusion_recipe = null
	selected_atomons.clear()

	answered = false
	challenge_success = false

	title_label.text = "OCTET RULE CHALLENGE"

	lesson_label.text = (
		"Review the Octet Rule.\n\n"
		+ "Many main-group atoms tend to become more stable "
		+ "when their outermost electron shell contains "
		+ "eight valence electrons."
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

	if answer_index == correct_answer_index:

		challenge_success = true

		feedback_label.text = (
			"Correct!\n\n"
			+ "According to the Octet Rule, many "
			+ "main-group atoms tend to achieve "
			+ "eight valence electrons in their "
			+ "outermost shell."
		)

	else:

		challenge_success = false

		feedback_label.text = (
			"Not quite.\n\n"
			+ "The Octet Rule concerns the number "
			+ "of valence electrons in the outermost "
			+ "electron shell."
		)

	continue_button.disabled = false


# ============================================================
# CONTINUE
# ============================================================

func _on_continue_pressed() -> void:

	if not answered:
		return

	fusion_challenge_finished.emit(
		challenge_success,
		fusion_recipe,
		selected_atomons
	)

extends Control


# ============================================================
# ELEMENT DATA
# ============================================================

var elements: Array[Dictionary] = [
	{
		"name": "Hydrogen",
		"symbol": "H",
		"atomic_number": 1,
		"valence_electrons": 1
	},
	{
		"name": "Carbon",
		"symbol": "C",
		"atomic_number": 6,
		"valence_electrons": 4
	},
	{
		"name": "Nitrogen",
		"symbol": "N",
		"atomic_number": 7,
		"valence_electrons": 5
	},
	{
		"name": "Oxygen",
		"symbol": "O",
		"atomic_number": 8,
		"valence_electrons": 6
	},
	{
		"name": "Fluorine",
		"symbol": "F",
		"atomic_number": 9,
		"valence_electrons": 7
	},
	{
		"name": "Neon",
		"symbol": "Ne",
		"atomic_number": 10,
		"valence_electrons": 8
	},
	{
		"name": "Sodium",
		"symbol": "Na",
		"atomic_number": 11,
		"valence_electrons": 1
	},
	{
		"name": "Chlorine",
		"symbol": "Cl",
		"atomic_number": 17,
		"valence_electrons": 7
	}
]


# ============================================================
# GAME SETTINGS
# ============================================================

const MAX_ROUNDS: int = 8
const TIME_PER_ROUND: float = 7.0

const BASE_SCORE: int = 100
const STREAK_BONUS: int = 25


# ============================================================
# GAME STATE
# ============================================================

var score: int = 0
var streak: int = 0
var round: int = 0

var current_element: Dictionary = {}

var answered: bool = false
var time_remaining: float = 0.0

var game_active: bool = false


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var score_value: Label = $MarginContainer/MainVBox/Header/ScorePanel/ScoreValue
@onready var streak_value: Label = $MarginContainer/MainVBox/Header/StreakPanel/StreakValue
@onready var round_value: Label = $MarginContainer/MainVBox/Header/RoundPanel/RoundValue

@onready var progress_bar: ProgressBar = $MarginContainer/MainVBox/ProgressBar

@onready var symbol_label: Label = $MarginContainer/MainVBox/QuestionPanel/QuestionVBox/SymbolLabel
@onready var element_label: Label = $MarginContainer/MainVBox/QuestionPanel/QuestionVBox/ElementLabel
@onready var atomic_label: Label = $MarginContainer/MainVBox/QuestionPanel/QuestionVBox/AtomicLabel

@onready var electrons_container: HBoxContainer = $MarginContainer/MainVBox/QuestionPanel/QuestionVBox/ElectronsContainer

@onready var choices: HBoxContainer = $MarginContainer/MainVBox/QuestionPanel/QuestionVBox/Choices

@onready var feedback_label: Label = $MarginContainer/MainVBox/FeedbackLabel

@onready var question_label: Label = $MarginContainer/MainVBox/QuestionPanel/QuestionVBox/QuestionLabel

@onready var start_button: Button = $MarginContainer/MainVBox/StartButton


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)

	progress_bar.min_value = 0.0
	progress_bar.max_value = TIME_PER_ROUND
	progress_bar.value = TIME_PER_ROUND

	update_ui()


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	if not game_active:
		return

	if answered:
		return

	time_remaining -= delta

	if time_remaining < 0.0:
		time_remaining = 0.0

	progress_bar.value = time_remaining

	if time_remaining <= 0.0:
		answer_question(-1)


# ============================================================
# START GAME
# ============================================================

func _on_start_pressed() -> void:
	start_game()


func start_game() -> void:
	score = 0
	streak = 0
	round = 0

	game_active = true
	answered = false

	start_button.visible = false

	update_ui()

	next_round()


# ============================================================
# NEXT ROUND
# ============================================================

func next_round() -> void:
	if round >= MAX_ROUNDS:
		finish_game()
		return

	round += 1
	answered = false

	current_element = elements.pick_random()

	display_question()
	create_answer_buttons()

	time_remaining = TIME_PER_ROUND
	progress_bar.value = TIME_PER_ROUND

	update_ui()


# ============================================================
# DISPLAY QUESTION
# ============================================================

func display_question() -> void:
	var symbol: String = current_element["symbol"]
	var element_name: String = current_element["name"]
	var atomic_number: int = current_element["atomic_number"]
	var valence_electrons: int = current_element["valence_electrons"]

	symbol_label.text = symbol
	element_label.text = element_name

	atomic_label.text = "Atomic Number: %d" % atomic_number

	question_label.text = "How many valence electrons does this Atomon have?"

	create_electron_display(valence_electrons)

	feedback_label.text = ""


# ============================================================
# ELECTRON DISPLAY
# ============================================================

func create_electron_display(count: int) -> void:
	for child in electrons_container.get_children():
		child.queue_free()

	for i in range(count):
		var electron: Label = Label.new()

		electron.text = "●"
		electron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		electron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		electron.custom_minimum_size = Vector2(36, 36)

		electrons_container.add_child(electron)


# ============================================================
# ANSWER BUTTONS
# ============================================================

func create_answer_buttons() -> void:
	for child in choices.get_children():
		child.queue_free()

	var correct_answer: int = current_element["valence_electrons"]

	var answer_set: Array[int] = [
		correct_answer
	]

	while answer_set.size() < 3:
		var random_answer: int = randi_range(1, 8)

		if not answer_set.has(random_answer):
			answer_set.append(random_answer)

	answer_set.shuffle()

	for answer in answer_set:
		var button: Button = Button.new()

		button.text = str(answer)

		button.custom_minimum_size = Vector2(140, 60)

		button.add_theme_font_size_override("font_size", 24)

		button.pressed.connect(
			_on_answer_pressed.bind(answer)
		)

		choices.add_child(button)


# ============================================================
# ANSWER
# ============================================================

func _on_answer_pressed(answer: int) -> void:
	answer_question(answer)


func answer_question(answer: int) -> void:
	if answered:
		return

	answered = true

	var correct_answer: int = current_element["valence_electrons"]

	if answer == correct_answer:
		var earned_points: int = BASE_SCORE + (streak * STREAK_BONUS)

		score += earned_points
		streak += 1

		feedback_label.text = "✓ Correct! +%d points" % earned_points

	else:
		streak = 0

		if answer == -1:
			feedback_label.text = "Time's up! Correct answer: %d" % correct_answer
		else:
			feedback_label.text = "✗ Incorrect. Correct answer: %d" % correct_answer

	update_ui()

	await get_tree().create_timer(0.9).timeout

	if game_active:
		next_round()


# ============================================================
# FINISH
# ============================================================

func finish_game() -> void:
	game_active = false

	for child in choices.get_children():
		child.queue_free()

	symbol_label.text = "★"
	element_label.text = "Mini-game Complete!"

	atomic_label.text = "Final Score: %d" % score

	question_label.text = "You completed all %d rounds." % MAX_ROUNDS

	feedback_label.text = "Final Streak: %d" % streak

	for child in electrons_container.get_children():
		child.queue_free()

	start_button.text = "PLAY AGAIN"
	start_button.visible = true

	progress_bar.value = 0.0

	update_ui()


# ============================================================
# UI
# ============================================================

func update_ui() -> void:
	score_value.text = str(score)
	streak_value.text = str(streak)
	round_value.text = "%d/%d" % [round, MAX_ROUNDS]


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/minigames.tscn")

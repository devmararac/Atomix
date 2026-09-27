extends CanvasLayer


const MULTIPLE_CHOICE_CREATOR = preload(
	"res://Scenes/Admin/Teacher/quiz_creator.tscn"
)

const IDENTIFICATION_CREATOR = preload(
	"res://Scenes/Admin/Teacher/identification_creator.tscn"
)

const ENUMERATION_CREATOR = preload(
	"res://Scenes/Admin/Teacher/enumeration_creator.tscn"
)

const TRUE_FALSE_CREATOR = preload(
	"res://Scenes/Admin/Teacher/true_false_creator.tscn"
)


@onready var quiz_panel: Panel = $QuizPanel
@onready var dim_background: ColorRect = $DimBackground


const ANIMATION_TIME := 0.4

var panel_width: float


func _ready() -> void:
	# Wait one frame so the anchored panel gets its actual size.
	await get_tree().process_frame

	# Get the panel's actual width based on the current viewport.
	panel_width = quiz_panel.size.x

	# Start outside the left side of the screen.
	quiz_panel.position.x = -panel_width

	# Start the background transparent.
	var background_color := dim_background.color
	background_color.a = 0.0
	dim_background.color = background_color

	# Play the opening animation.
	_open_panel()


func _open_panel() -> void:
	var tween := create_tween()

	tween.set_parallel(true)

	# Slide the panel into view.
	tween.tween_property(
		quiz_panel,
		"position:x",
		0.0,
		ANIMATION_TIME
	).set_trans(
		Tween.TRANS_QUART
	).set_ease(
		Tween.EASE_OUT
	)

	# Fade in the dark background.
	tween.tween_property(
		dim_background,
		"color:a",
		0.28,
		ANIMATION_TIME
	).set_trans(
		Tween.TRANS_QUART
	).set_ease(
		Tween.EASE_OUT
	)


func _close_panel() -> void:
	var tween := create_tween()

	tween.set_parallel(true)

	# Slide the panel back outside the screen.
	tween.tween_property(
		quiz_panel,
		"position:x",
		-panel_width,
		0.3
	).set_trans(
		Tween.TRANS_QUART
	).set_ease(
		Tween.EASE_IN
	)

	# Fade out the background.
	tween.tween_property(
		dim_background,
		"color:a",
		0.0,
		0.3
	).set_trans(
		Tween.TRANS_QUART
	).set_ease(
		Tween.EASE_IN
	)

	tween.set_parallel(false)

	tween.tween_callback(queue_free)


func _on_multiple_choices_pressed() -> void:
	_open_creator(MULTIPLE_CHOICE_CREATOR)


func _on_identification_pressed() -> void:
	_open_creator(IDENTIFICATION_CREATOR)


func _on_enumeration_pressed() -> void:
	_open_creator(ENUMERATION_CREATOR)


func _on_true_false_pressed() -> void:
	_open_creator(TRUE_FALSE_CREATOR)


func _open_creator(creator_scene: PackedScene) -> void:
	var creator := creator_scene.instantiate()

	if creator == null:
		push_error(
			"[QuizChoices] Failed to instantiate creator scene."
		)
		return

	var tween := create_tween()

	tween.set_parallel(true)

	# Slide the quiz-choice panel out.
	tween.tween_property(
		quiz_panel,
		"position:x",
		-panel_width,
		0.3
	).set_trans(
		Tween.TRANS_QUART
	).set_ease(
		Tween.EASE_IN
	)

	# Fade out the background.
	tween.tween_property(
		dim_background,
		"color:a",
		0.0,
		0.3
	).set_trans(
		Tween.TRANS_QUART
	).set_ease(
		Tween.EASE_IN
	)

	tween.set_parallel(false)

	# Open the selected quiz creator after
	# the slide-out animation finishes.
	tween.tween_callback(func():
		get_tree().current_scene.add_child(creator)
		queue_free()
	)


func _on_back_button_pressed() -> void:
	print("[QuizChoices] Back button pressed.")

	_close_panel()

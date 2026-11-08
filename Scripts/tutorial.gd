extends CanvasLayer

@onready var title_label: Label = $TutorialPanel/TitleLabel
@onready var description_label: RichTextLabel = $TutorialPanel/DescriptionLabel
@onready var tutorial_video: VideoStreamPlayer = $TutorialPanel/Panel/TutorialVideo
@onready var continue_button: TextureButton = $TutorialPanel/ContinueButton
@onready var previous_button: TextureButton = $TutorialPanel/PreviousButton

func _ready() -> void:
	visible = false
	previous_button.visible = false
	continue_button.pressed.connect(_on_continue_pressed)

func show_tutorial(data: TutorialData) -> void:
	title_label.text = data.title
	description_label.text = data.description

	tutorial_video.stop()
	tutorial_video.stream = data.video

	if tutorial_video.stream:
		tutorial_video.play()
	else:
		push_warning("Tutorial has no video assigned: " + data.id)

	visible = true

func close_tutorial() -> void:
	tutorial_video.stop()
	visible = false

func _on_continue_pressed() -> void:
	close_tutorial()

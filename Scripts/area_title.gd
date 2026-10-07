extends CanvasLayer

@onready var center_container: CenterContainer = $CenterContainer
@onready var area_name: Label = $CenterContainer/VBoxContainer/AreaName
@onready var subtitle: Label = $CenterContainer/VBoxContainer/Subtitle


func _ready() -> void:
	center_container.visible = false
	center_container.modulate.a = 0.0


func show_area(area_name_text: String, duration: float = 3.0) -> void:
	area_name.text = area_name_text

	center_container.visible = true
	center_container.modulate.a = 0.0

	var tween: Tween = create_tween()

	# Fade in
	tween.tween_property(
		center_container,
		"modulate:a",
		1.0,
		0.4
	)

	# Stay visible
	tween.tween_interval(duration)

	# Fade out
	tween.tween_property(
		center_container,
		"modulate:a",
		0.0,
		0.6
	)

	# Hide after fade out
	tween.tween_callback(_hide)


func _hide() -> void:
	center_container.visible = false

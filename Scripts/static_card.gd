extends Panel
class_name StatisticCard

@onready var icon = $MarginContainer/HBoxContainer/Icon
@onready var title = $MarginContainer/HBoxContainer/VBoxContainer/Title
@onready var value = $MarginContainer/HBoxContainer/VBoxContainer/Value
@onready var subtitle = $MarginContainer/HBoxContainer/VBoxContainer/Subtitle

func set_data(texture: Texture2D, card_title: String, card_value: String, card_subtitle: String):
	icon.texture = texture
	title.text = card_title
	value.text = card_value
	subtitle.text = card_subtitle

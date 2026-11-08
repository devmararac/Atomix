extends CharacterBody2D

@export var dialogic_character: DialogicCharacter

@onready var bubble_marker := $BubbleMarker

func register_dialogic(layout):
	layout.register_character(dialogic_character, bubble_marker)

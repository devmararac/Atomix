extends Node2D

const AREA_TITLE_SCENE = preload("res://Scenes/AreaTitle.tscn")

var area_title: CanvasLayer


func _ready() -> void:
	area_title = AREA_TITLE_SCENE.instantiate()
	add_child(area_title)
	area_title.show_area("Ironia Town")

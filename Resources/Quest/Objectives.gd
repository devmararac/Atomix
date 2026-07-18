extends Resource


class_name Objectives
@export var id: String
@export var description: String

#Objective Type
@export var target_id: String
@export var target_type: String

#Talk To Objective
@export var objective_dialogue: String = ""

#Collection Objective
@export var required_quantity: int = 0
@export var collected_quantity: int = 0

#Objective State
@export var is_completed: bool = false 

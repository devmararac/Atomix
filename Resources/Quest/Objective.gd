#OBJECTIVE
extends Resource
class_name Objective

@export var id: String
@export_multiline var description: String

@export var type: ObjectiveType.Type

## The ID of the thing we're looking for.
## Examples:
## NPC -> "beryll"
## Item -> "hydrogen"
## Enemy -> "wild_oxygen"
## Area -> "forest_gate"
@export var target_id: String

## Number required to finish this objective.
@export var required_amount: int = 1

## Current progress.
@export var current_amount: int = 0

## Runtime state
@export var is_active: bool = false
@export var is_completed: bool = false

func is_finished() -> bool:
	return current_amount >= required_amount

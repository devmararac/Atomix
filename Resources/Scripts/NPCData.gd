class_name NPCData
extends Resource

enum FacingDirection {
	LEFT,
	RIGHT
}

@export var npc_id: String
@export var display_name: String

@export_multiline var dialogue: String

@export var portrait: Texture2D
@export var sprite_frames: SpriteFrames

# Later
# @export var shop: ShopData
@export var quest: Quest

# Behavior
@export var can_wander := false
@export var move_speed := 30.0

# Visuals
@export var interaction_icon: Texture2D

# Direction
@export var facing_direction := FacingDirection.RIGHT

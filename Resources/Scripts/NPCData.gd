class_name NPCData
extends Resource

enum NPCType {
	VILLAGER,
	QUEST_GIVER,
	MERCHANT,
	TEACHER,
	GUARD,
	TRAINER
}

enum FacingDirection {
	LEFT,
	RIGHT
}

# Identity
@export var npc_id: String
@export var display_name: String
@export var npc_type := NPCType.VILLAGER

# Appearance
@export var portrait: Texture2D
@export var sprite_frames: SpriteFrames
@export var interaction_icon: Texture2D
@export var dialogic_character: DialogicCharacter

# Dialogue
@export var dialogue_data: NPCDialogueData

# Quests
@export var quests: Array[Quest]

# Behaviour
@export var can_wander := false
@export var move_speed := 30.0
@export var facing_direction := FacingDirection.RIGHT

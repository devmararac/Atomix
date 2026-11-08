extends Resource
class_name NPCDialogueData

# Dialogue played when no special conversation matches.
@export var default_timeline: DialogicTimeline

# Conversations available for this NPC.
@export var conversations: Array[NPCConversation] = []

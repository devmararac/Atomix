extends Resource
class_name NPCConversation

enum ConversationType {
	DEFAULT,
	GREETING,
	QUEST_OFFER,
	QUEST_PROGRESS,
	QUEST_COMPLETE,
	QUEST_OBJECTIVE,
	SHOP,
	CUTSCENE
}

@export var objective_id: String = ""

# Name shown only in the Inspector.
@export var conversation_name: String = ""

#what Convo?
@export var conversation_type: ConversationType = ConversationType.DEFAULT

#Quest Related
@export var quest: Quest

@export var required_objective_id: String = ""

# Timeline played for this conversation.
@export var timeline: DialogicTimeline

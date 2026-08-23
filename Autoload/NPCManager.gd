extends Node


func interact(npc: NPCBase):

	if npc.data == null:
		return

	if npc.data.dialogue_data == null:
		push_warning("%s has no DialogueData." % npc.data.display_name)
		return

	var conversation := get_best_conversation(npc)

	if conversation == null:
		push_warning("%s has no playable conversation." % npc.data.display_name)
		return

	# Play the conversation first.
	var result = play_conversation(npc, conversation)

	# Then notify the quest system that the player talked to this NPC.
	QuestManager.notify(
		ObjectiveType.Type.TALK,
		npc.data.npc_id
	)

	return result
	
func play_conversation(npc: NPCBase, conversation: NPCConversation):

	if conversation == null:
		return
	
	if conversation.timeline == null:
		return
		
	if global.player != null:
		global.player.can_move = false
	
	var layout = Dialogic.start(conversation.timeline)
	
	if global.player and global.player.has_method("register_dialogic"):
		global.player.register_dialogic(layout)

	layout.register_character(npc.data.dialogic_character, npc.get_node("BubbleMarker")) 
	return layout

func get_best_conversation(npc: NPCBase) -> NPCConversation:
	if npc.data == null:
		return null
	if npc.data.dialogue_data == null:
		return null
	var dialogue: NPCDialogueData = npc.data.dialogue_data
	
	# Check quests first
	for quest in npc.data.quests:
		var player_quest = QuestManager.get_quest(quest.quest_id)
		
		# Quest not accepted
		if player_quest == null:
			var conversation = get_conversation(dialogue, NPCConversation.ConversationType.QUEST_OFFER, quest)
			if conversation:
				return conversation

		# Quest completed
		elif player_quest.state == QuestState.Type.COMPLETED:
			var conversation = get_conversation(dialogue, NPCConversation.ConversationType.QUEST_COMPLETE, quest)
			if conversation:
				return conversation

		# Quest in progress
		elif player_quest.state == QuestState.Type.ACTIVE:
			# Active objective conversations
			if player_quest != null and player_quest.state == QuestState.Type.ACTIVE:
				for objective in player_quest.objectives:
					if !objective.is_active:
						continue
					var conversation = get_objective_conversation(dialogue, player_quest, objective.id)
					if conversation:
						return conversation
						
			var conversation = get_conversation(dialogue, NPCConversation.ConversationType.QUEST_PROGRESS, quest)
			if conversation:
				return conversation

	# No quest conversation found
	return get_conversation(dialogue, NPCConversation.ConversationType.DEFAULT)


func get_conversation(dialogue_data: NPCDialogueData, conversation_type: NPCConversation.ConversationType, quest: Quest = null) -> NPCConversation:

	for conversation in dialogue_data.conversations:

		if conversation.conversation_type != conversation_type:
			continue

		# If we're looking for a specific quest conversation,
		# it must belong to that quest.
		if quest != null:
			if conversation.quest == null:
				continue
			if conversation.quest.quest_id != quest.quest_id:
				continue

		return conversation

	return null

func get_objective_conversation(
	dialogue_data: NPCDialogueData,
	quest: Quest,
	objective_id: String
) -> NPCConversation:

	for conversation in dialogue_data.conversations:

		if conversation.conversation_type != NPCConversation.ConversationType.QUEST_OBJECTIVE:
			continue

		if conversation.quest == null:
			continue

		if conversation.quest.quest_id != quest.quest_id:
			continue

		if conversation.objective_id != objective_id:
			continue

		return conversation

	return null

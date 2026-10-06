
extends Node


# ============================================================
# REGISTERED NPCs
# ============================================================

var registered_npcs: Array[NPCBase] = []


# ============================================================
# NPC REGISTRATION
# ============================================================

func register_npc(npc: NPCBase) -> void:

	if npc == null:
		return

	if registered_npcs.has(npc):
		return

	registered_npcs.append(npc)


func unregister_npc(npc: NPCBase) -> void:

	if npc == null:
		return

	registered_npcs.erase(npc)


# ============================================================
# QUEST INDICATORS
# ============================================================

func refresh_quest_indicators() -> void:

	for npc in registered_npcs:

		if npc == null:
			continue

		if not is_instance_valid(npc):
			continue

		if npc.data == null:
			npc.hide_quest_indicator()
			continue

		if has_active_quest_target(npc.data.npc_id):
			npc.show_quest_indicator()
		else:
			npc.hide_quest_indicator()


func has_active_quest_target(npc_id: String) -> bool:

	if npc_id.is_empty():
		return false

	for quest in QuestManager.get_active_quests():

		if quest == null:
			continue

		var objective = quest.get_active_objective()

		if objective == null:
			continue

		if objective.type != ObjectiveType.Type.TALK:
			continue

		if objective.target_id != npc_id:
			continue

		return true

	return false


# ============================================================
# INTERACTION
# ============================================================

func interact(npc: NPCBase):

	print("========== NPC MANAGER INTERACT ==========")
	print("[NPCManager] NPC: ", npc)

	if npc == null:
		print("[NPCManager] FAILED: NPC is null.")
		return null

	if npc.data == null:
		print("[NPCManager] FAILED: npc.data is null.")
		return null

	print("[NPCManager] NPC ID: ", npc.data.npc_id)
	print("[NPCManager] Dialogue data: ", npc.data.dialogue_data)

	if npc.data.dialogue_data == null:
		print("[NPCManager] FAILED: dialogue_data is null.")
		return null

	print("[NPCManager] Calling get_best_conversation()...")

	var conversation := get_best_conversation(npc)

	print("[NPCManager] Best conversation: ", conversation)

	if conversation == null:
		print(
			"[NPCManager] FAILED: "
			+ "get_best_conversation() returned NULL."
		)
		return null

	print(
		"[NPCManager] Conversation name: ",
		conversation.conversation_name
	)

	print(
		"[NPCManager] Conversation type: ",
		conversation.conversation_type
	)

	print(
		"[NPCManager] Conversation objective ID: ",
		conversation.objective_id
	)

	print(
		"[NPCManager] Conversation quest: ",
		conversation.quest
	)

	print(
		"[NPCManager] Conversation timeline: ",
		conversation.timeline
	)

	print("[NPCManager] Calling play_conversation()...")

	var result = await play_conversation(
		npc,
		conversation
	)

	print(
		"[NPCManager] play_conversation() returned: ",
		result
	)

	return result




# ============================================================
# FIND BEST CONVERSATION
# ============================================================

func get_best_conversation(npc: NPCBase) -> NPCConversation:

	print("========== GET BEST CONVERSATION ==========")

	if npc == null:
		print("[NPCManager] FAILED: npc is null.")
		return null

	if npc.data == null:
		print("[NPCManager] FAILED: npc.data is null.")
		return null

	if npc.data.dialogue_data == null:
		print("[NPCManager] FAILED: dialogue_data is null.")
		return null

	var dialogue: NPCDialogueData = npc.data.dialogue_data

	print("[NPCManager] NPC has quests: ", npc.data.quests.size())
	print("[NPCManager] Dialogue conversations: ", dialogue.conversations.size())

	# ------------------------------------------------------------
	# CHECK QUESTS ASSIGNED TO THIS NPC
	# ------------------------------------------------------------

	for quest in npc.data.quests:

		if quest == null:
			print("[NPCManager] NPC quest is NULL.")
			continue

		print("------------------------------------------")
		print("[NPCManager] NPC Quest ID: ", quest.quest_id)
		print("[NPCManager] NPC Quest Name: ", quest.quest_name)

		var player_quest = QuestManager.get_quest(quest.quest_id)

		print("[NPCManager] Player Quest: ", player_quest)

		# --------------------------------------------------------
		# QUEST NOT ACCEPTED
		# --------------------------------------------------------

		if player_quest == null:

			print("[NPCManager] Player does NOT have this quest.")

			var conversation = get_conversation(
				dialogue,
				NPCConversation.ConversationType.QUEST_OFFER,
				quest
			)

			print("[NPCManager] Quest offer conversation: ", conversation)

			if conversation:
				return conversation

		# --------------------------------------------------------
		# QUEST COMPLETED
		# --------------------------------------------------------

		elif player_quest.state == QuestState.Type.COMPLETED:

			print("[NPCManager] Player quest is COMPLETED.")

			var conversation = get_conversation(
				dialogue,
				NPCConversation.ConversationType.QUEST_COMPLETE,
				quest
			)

			print("[NPCManager] Quest complete conversation: ", conversation)

			if conversation:
				return conversation

		# --------------------------------------------------------
		# QUEST ACTIVE
		# --------------------------------------------------------

		elif player_quest.state == QuestState.Type.ACTIVE:

			print("[NPCManager] Player quest is ACTIVE.")
			print("[NPCManager] Checking objectives...")

			for objective in player_quest.objectives:

				if objective == null:
					print("[NPCManager] Objective is NULL.")
					continue

				print(
					"[NPCManager] Objective: ",
					objective.id,
					" | Active: ",
					objective.is_active,
					" | Completed: ",
					objective.is_completed,
					" | Type: ",
					objective.type,
					" | Target: ",
					objective.target_id
				)

				if !objective.is_active:
					continue

				print(
					"[NPCManager] Looking for conversation with objective ID: ",
					objective.id
				)

				var conversation = get_objective_conversation(
					dialogue,
					player_quest,
					objective.id
				)

				print(
					"[NPCManager] Matching objective conversation: ",
					conversation
				)

				if conversation:
					return conversation

			print("[NPCManager] No objective conversation found.")

			# ----------------------------------------------------
			# FALLBACK QUEST PROGRESS CONVERSATION
			# ----------------------------------------------------

			var progress_conversation = get_conversation(
				dialogue,
				NPCConversation.ConversationType.QUEST_PROGRESS,
				quest
			)

			print(
				"[NPCManager] Quest progress conversation: ",
				progress_conversation
			)

			if progress_conversation:
				return progress_conversation

	# ------------------------------------------------------------
	# DEFAULT CONVERSATION
	# ------------------------------------------------------------

	print("[NPCManager] No quest conversation found.")

	var default_conversation = get_conversation(
		dialogue,
		NPCConversation.ConversationType.DEFAULT
	)

	print("[NPCManager] Default conversation: ", default_conversation)

	return default_conversation


# ============================================================
# GET QUEST CONVERSATION
# ============================================================

func get_conversation(
	dialogue_data: NPCDialogueData,
	conversation_type: NPCConversation.ConversationType,
	quest: Quest = null
) -> NPCConversation:

	for conversation in dialogue_data.conversations:

		if conversation == null:
			continue

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


# ============================================================
# GET OBJECTIVE CONVERSATION
# ============================================================

func get_objective_conversation(
	dialogue_data: NPCDialogueData,
	quest: Quest,
	objective_id: String
) -> NPCConversation:

	print(
		"[NPCManager] Searching objective conversation:",
		" Quest=",
		quest.quest_id,
		" Objective=",
		objective_id
	)

	for conversation in dialogue_data.conversations:

		if conversation == null:
			continue

		print(
			"[NPCManager] Checking conversation:",
			conversation.conversation_name,
			" | Type=",
			conversation.conversation_type,
			" | Objective=",
			conversation.objective_id,
			" | Quest=",
			conversation.quest
		)

		if conversation.conversation_type != NPCConversation.ConversationType.QUEST_OBJECTIVE:
			continue

		if conversation.quest == null:
			continue

		if conversation.quest.quest_id != quest.quest_id:
			continue

		if conversation.objective_id != objective_id:
			continue

		print("[NPCManager] FOUND matching objective conversation!")

		return conversation

	return null


# ============================================================
# PLAY CONVERSATION
# ============================================================

func play_conversation(
	npc: NPCBase,
	conversation: NPCConversation
):

	print("========== PLAY CONVERSATION ==========")

	if conversation == null:
		print("[NPCManager] FAILED: conversation is null.")
		return null

	if conversation.timeline == null:
		print(
			"[NPCManager] FAILED: conversation timeline is null."
		)
		return null

	print(
		"[NPCManager] Starting timeline: ",
		conversation.timeline
	)

	npc.set_dialogue_active(true)

	if global.player != null:
		global.player.can_move = false

	var layout = Dialogic.start(
		conversation.timeline
	)

	print(
		"[NPCManager] Dialogic.start() returned: ",
		layout
	)

	if global.player and global.player.has_method(
		"register_dialogic"
	):
		global.player.register_dialogic(layout)

	if npc.data.dialogic_character != null:

		layout.register_character(
			npc.data.dialogic_character,
			npc.get_node("BubbleMarker")
		)

	# ------------------------------------------------------------
	# WAIT FOR DIALOGUE TO FINISH
	# ------------------------------------------------------------

	await Dialogic.timeline_ended

	print(
		"[NPCManager] Dialogue finished: ",
		conversation.conversation_name
	)

	# ------------------------------------------------------------
	# RESTORE PLAYER CONTROL
	# ------------------------------------------------------------

	npc.set_dialogue_active(false)

	if global.player != null:
		global.player.can_move = true

	# ------------------------------------------------------------
	# COMPLETE TALK OBJECTIVE
	# ------------------------------------------------------------

	if (
		conversation.quest != null
		and not conversation.objective_id.is_empty()
	):

		var objective_id := conversation.objective_id

		print(
			"[NPCManager] Conversation objective finished: ",
			objective_id
		)

		# Only TALK conversations should automatically
		# complete a TALK objective.
		if (
			conversation.conversation_type
			== NPCConversation.ConversationType.DEFAULT
			or conversation.conversation_type
			== NPCConversation.ConversationType.QUEST_OBJECTIVE
		):

			if objective_id.begins_with("talk_"):

				print(
					"[NPCManager] "
					+ "Notifying TALK objective: ",
					objective_id
				)

				await QuestManager.notify(
					ObjectiveType.Type.TALK,
					npc.data.npc_id
				)

	return layout




# ============================================================
# BATTLE ANNOUNCEMENT
# ============================================================

func play_battle_announcement(npc: NPCBase, timeline: StringName):

	if npc == null:
		return

	if npc.data == null:
		return

	if global.player != null:
		global.player.can_move = false

	var layout = Dialogic.start(timeline)

	# ------------------------------------------------------------
	# FIRST REGISTRATION
	# ------------------------------------------------------------

	if global.player and global.player.has_method("register_dialogic"):
		global.player.register_dialogic(layout)

	if npc.data.dialogic_character != null:

		layout.register_character(
			npc.data.dialogic_character,
			npc.get_node("BubbleMarker")
		)

	# ------------------------------------------------------------
	# WAIT FOR DIALOGIC INITIALIZATION
	# ------------------------------------------------------------

	await get_tree().process_frame

	if not is_instance_valid(layout):
		return

	# ------------------------------------------------------------
	# SECOND REGISTRATION
	# ------------------------------------------------------------

	if global.player and global.player.has_method("register_dialogic"):
		global.player.register_dialogic(layout)

	if npc.data.dialogic_character != null:

		layout.register_character(
			npc.data.dialogic_character,
			npc.get_node("BubbleMarker")
		)

	return layout

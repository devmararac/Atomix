extends Node2D

# -------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------

signal quest_updated(quest_id: String)
signal objective_updated(quest_id: String, objective_id: String)
signal quest_list_updated()
signal tracked_quest_changed(quest: Quest)
signal quest_completed(quest_id: String)


# -------------------------------------------------------------------
# Quest Database
# -------------------------------------------------------------------

var quest_database := {
	"quest_hydrogen_001": preload("res://Resources/Quest/quest_hydrogen_001.tres"),
	"quest_collect_iron": preload("res://Resources/Quest/quest_collect_iron.tres"),
	"story_quest_explore_dungeon": preload("res://Resources/Objectives/explore_dungeon.tres"),
	"quest_chain_001_01": preload("res://Resources/Quest/quest_chain.tres"),
	"quest_chain_001_02": preload("res://Resources/Quest/quest_chain2.tres"),
	"quest_chain_002_01": preload("res://Resources/Quest/quest_chain_002_01.tres")
}


# -------------------------------------------------------------------
# Runtime Quest Data
# -------------------------------------------------------------------

## Quests currently in progress.
var active_quests: Dictionary[String, Quest] = {}

## Finished quests.
var completed_quests: Dictionary[String, Quest] = {}

## Quest currently shown in the tracker.
var tracked_quest: Quest = null


# -------------------------------------------------------------------
# Dialogic Quest Notification Queue
# -------------------------------------------------------------------

var quest_notify_queue: Array[String] = []
var processing_quest_notify := false


# -------------------------------------------------------------------
# Ready
# -------------------------------------------------------------------

func _ready():
	Dialogic.signal_event.connect(_on_dialogic_signal)


# -------------------------------------------------------------------
# Quest Indicators
# -------------------------------------------------------------------

func refresh_npc_quest_indicators() -> void:
	NpcManager.refresh_quest_indicators()


# -------------------------------------------------------------------
# Dialogic Signals
# -------------------------------------------------------------------

func _on_dialogic_signal(argument: String):

	# ============================================================
	# QUEST ACCEPT
	# ============================================================

	if argument.begins_with("quest_accept:"):

		var quest_id := argument.get_slice(":", 1)
		accept_quest(quest_id)
		return


	# ============================================================
	# QUEST NOTIFY
	# ============================================================

	if argument.begins_with("quest_notify:"):

		quest_notify_queue.append(argument)

		if not processing_quest_notify:
			_process_quest_notify_queue()


# -------------------------------------------------------------------
# Process Dialogic Quest Notification Queue
# -------------------------------------------------------------------

func _process_quest_notify_queue() -> void:

	if processing_quest_notify:
		return

	processing_quest_notify = true

	while not quest_notify_queue.is_empty():

		var argument: String = quest_notify_queue.pop_front()
		var parts := argument.split(":")

		if parts.size() < 3:
			print("[QuestManager] Invalid quest notification: ", argument)
			continue

		var quest_id := parts[1]
		var objective_id := parts[2]

		var quest := get_quest(quest_id)

		if quest == null:
			print("[QuestManager] Quest not found: ", quest_id)
			continue

		var objective := quest.get_active_objective()

		if objective == null:
			print("[QuestManager] Quest has no active objective: ", quest_id)
			continue

		# Only process notifications for the current objective.
		if objective.id != objective_id:
			print(
				"[QuestManager] Ignoring notification. ",
				"Active objective: ",
				objective.id,
				" | Requested: ",
				objective_id
			)
			continue

		await get_tree().process_frame

		await notify(
			objective.type,
			objective.target_id
		)

		var next_objective := quest.get_active_objective()

		if next_objective != null:
			print(
				"[QuestManager] Next active objective: ",
				next_objective.id
			)

	processing_quest_notify = false


# -------------------------------------------------------------------
# Accept Quest
# -------------------------------------------------------------------

func accept_quest(quest_id: String) -> void:

	if active_quests.has(quest_id):
		print("[QuestManager] Quest is already ACTIVE: ", quest_id)
		return

	if completed_quests.has(quest_id):
		print("[QuestManager] Quest is already COMPLETED: ", quest_id)
		return

	if !quest_database.has(quest_id):
		push_error("Quest '%s' not found!" % quest_id)
		return

	var quest: Quest = quest_database[quest_id].duplicate(true)

	quest.start()

	active_quests[quest.quest_id] = quest

	# Automatically track the first accepted quest.
	if tracked_quest == null:
		set_tracked_quest(quest)

	quest_updated.emit(quest.quest_id)
	quest_list_updated.emit()
	refresh_npc_quest_indicators()

	print("[QuestManager] Quest accepted: ", quest.quest_id)

	await SaveManager.auto_save_quest_data(
		"Accepted quest: " + quest.quest_id
	)


# -------------------------------------------------------------------
# Start Story Quest
# -------------------------------------------------------------------

func start_story_quest(quest_id: String) -> void:

	if active_quests.has(quest_id):
		return

	if completed_quests.has(quest_id):
		return

	accept_quest(quest_id)


# -------------------------------------------------------------------
# Get Quest
# -------------------------------------------------------------------

func get_quest(quest_id: String) -> Quest:
	return active_quests.get(quest_id)


# -------------------------------------------------------------------
# Check Objective
# -------------------------------------------------------------------

func is_objective_completed(
	quest_id: String,
	objective_id: String
) -> bool:

	var quest = get_quest(quest_id)

	if quest == null:
		return false

	for objective in quest.objectives:

		if objective.id == objective_id:
			return objective.is_completed

	return false


# -------------------------------------------------------------------
# Update Quest
# -------------------------------------------------------------------

func update_quest(
	quest_id: String,
	state: QuestState.Type
) -> void:

	var quest := get_quest(quest_id)

	if quest == null:
		return

	quest.state = state
	quest_updated.emit(quest_id)


# -------------------------------------------------------------------
# Get Active Quests
# -------------------------------------------------------------------

func get_active_quests() -> Array[Quest]:
	return active_quests.values()


# -------------------------------------------------------------------
# Debug Quests
# -------------------------------------------------------------------

func debug_quests() -> void:

	print("=== Active Quests ===")

	if active_quests.is_empty():
		print("No active quests.")
		return

	for quest in active_quests.values():
		print(
			quest.quest_id,
			" State:",
			quest.state
		)


# ============================================================
# UNLOCK NEXT QUEST
# ============================================================

func unlock_next_quest(completed_quest: Quest) -> void:

	if completed_quest == null:
		return

	var next_quest_id := completed_quest.unlock_id

	# This quest does not unlock another quest.
	if next_quest_id.is_empty():
		print(
			"[QuestManager] Quest has no next quest: ",
			completed_quest.quest_id
		)
		return

	print(
		"[QuestManager] Unlocking next quest: ",
		next_quest_id
	)

	# Already active.
	if active_quests.has(next_quest_id):
		print(
			"[QuestManager] Next quest is already active: ",
			next_quest_id
		)
		return

	# Already completed.
	if completed_quests.has(next_quest_id):
		print(
			"[QuestManager] Next quest is already completed: ",
			next_quest_id
		)
		return

	# Quest does not exist in the database.
	if not quest_database.has(next_quest_id):
		push_error(
			"[QuestManager] Unlock quest '%s' was not found in quest_database!"
			% next_quest_id
		)
		return

	# Create a runtime copy.
	var next_quest: Quest = quest_database[next_quest_id].duplicate(true)

	# Start the quest.
	next_quest.start()

	# Add it to active quests.
	active_quests[next_quest.quest_id] = next_quest

	print(
		"[QuestManager] Next quest activated: ",
		next_quest.quest_id
	)

	quest_updated.emit(next_quest.quest_id)
	quest_list_updated.emit()
	refresh_npc_quest_indicators()


# ============================================================
# PLAYER REWARDS + QUEST COMPLETION
# ============================================================

func handle_quest_completion(quest: Quest) -> void:

	if quest == null:
		return

	# ========================================================
	# GIVE REWARDS
	# ========================================================

	for reward in quest.rewards:

		match reward.reward_type:

			"coins":
				CurrencyManager.add_coins(
					reward.reward_amount
				)


	# ========================================================
	# REMEMBER TRACKED QUEST
	# ========================================================

	var was_tracked := tracked_quest == quest


	# ========================================================
	# MARK AS COMPLETED
	# ========================================================

	update_quest(
		quest.quest_id,
		QuestState.Type.COMPLETED
	)


	# ========================================================
	# MOVE ACTIVE -> COMPLETED
	# ========================================================

	active_quests.erase(
		quest.quest_id
	)

	completed_quests[quest.quest_id] = quest


	# ========================================================
	# UNLOCK NEXT QUEST
	# ========================================================

	unlock_next_quest(quest)


	# ========================================================
	# CHANGE TRACKED QUEST
	# ========================================================

	if was_tracked:

		var next_tracked_quest: Quest = null

		# Prefer the newly unlocked quest.
		if not quest.unlock_id.is_empty():

			if active_quests.has(quest.unlock_id):
				next_tracked_quest = active_quests[quest.unlock_id]

		# Otherwise use another active quest.
		if next_tracked_quest == null and not active_quests.is_empty():
			next_tracked_quest = active_quests.values()[0]

		# Set the new tracked quest directly.
		# We intentionally do NOT set tracked_quest to null first.
		set_tracked_quest(next_tracked_quest)


	# ========================================================
	# SIGNALS
	# ========================================================

	quest_completed.emit(
		quest.quest_id
	)

	quest_list_updated.emit()

	refresh_npc_quest_indicators()


	# ========================================================
	# SAVE AFTER QUEST COMPLETION
	# ========================================================

	if quest.quest_id == "story_quest_explore_dungeon":

		print(
			"[QuestManager] Initial story quest completed."
		)

		await SaveManager.auto_save_quest_data(
			"Completed quest: " + quest.quest_id
		)

		print(
			"[QuestManager] Initial story quest completion saved."
		)

	else:

		print(
			"[QuestManager] Quest completed: ",
			quest.quest_id
		)

		await SaveManager.auto_save(
			"Completed quest: " + quest.quest_id
		)

		print(
			"[QuestManager] Quest completion automatic save completed."
		)


# -------------------------------------------------------------------
# Set Tracked Quest
# -------------------------------------------------------------------

func set_tracked_quest(quest: Quest) -> void:

	if tracked_quest == quest:
		return

	tracked_quest = quest

	if quest != null:
		print(
			"[QuestManager] Tracking quest: ",
			quest.quest_id
		)
	else:
		print(
			"[QuestManager] No quest is currently tracked."
		)

	tracked_quest_changed.emit(quest)


# -------------------------------------------------------------------
# Notify Quest
# -------------------------------------------------------------------

func notify(
	type: ObjectiveType.Type,
	target_id: String,
	amount: int = 1
) -> void:

	print("================================")
	print("[QuestManager] NOTIFY RECEIVED")
	print("[QuestManager] Type: ", type)
	print("[QuestManager] Target ID: ", target_id)

	var quest_to_complete: Quest = null

	for quest in active_quests.values():

		if quest == null:
			continue

		print("[QuestManager] Checking quest: ", quest.quest_id)

		var active_objective: Objective = quest.get_active_objective()

		if active_objective == null:
			print("[QuestManager] No active objective.")
			continue

		print(
			"[QuestManager] Active objective: ",
			active_objective.id
		)

		print(
			"[QuestManager] Objective type: ",
			active_objective.type
		)

		print(
			"[QuestManager] Objective target: ",
			active_objective.target_id
		)

		print(
			"[QuestManager] Type matches: ",
			active_objective.type == type
		)

		print(
			"[QuestManager] Target matches: ",
			active_objective.target_id == target_id
		)

		if quest.notify(type, target_id, amount):

			print(
				"[QuestManager] Quest.notify() SUCCESS: ",
				quest.quest_id
			)

			var next_objective: Objective = quest.get_active_objective()

			if next_objective != null:

				objective_updated.emit(
					quest.quest_id,
					next_objective.id
				)

				print(
					"[QuestManager] Next objective: ",
					next_objective.id
				)

				await SaveManager.auto_save(
					"Quest progress: " + quest.quest_id
				)

			else:

				print(
					"[QuestManager] No next objective."
				)

			if quest.is_completed():
				quest_to_complete = quest

			break

		else:

			print(
				"[QuestManager] Quest.notify() FAILED."
			)

	print("[QuestManager] NOTIFY FINISHED")
	print("================================")

	if quest_to_complete != null:
		await handle_quest_completion(quest_to_complete)

	refresh_npc_quest_indicators()




# ============================================================
# SAVE ALL QUESTS
# ============================================================

func get_save_data() -> Dictionary:

	var data := {
		"active_quests": {},
		"completed_quests": {},
		"tracked_quest_id": ""
	}

	for quest_id in active_quests:

		var quest: Quest = active_quests[quest_id]

		if quest != null:
			data["active_quests"][quest_id] = quest.to_save_dict()

	for quest_id in completed_quests:

		var quest: Quest = completed_quests[quest_id]

		if quest != null:
			data["completed_quests"][quest_id] = quest.to_save_dict()

	if tracked_quest != null:
		data["tracked_quest_id"] = tracked_quest.quest_id

	return data


# ============================================================
# LOAD ALL QUESTS
# ============================================================

func load_save_data(data: Dictionary) -> void:

	active_quests.clear()
	completed_quests.clear()
	tracked_quest = null


	# --------------------------------------------------------
	# ACTIVE QUESTS
	# --------------------------------------------------------

	var saved_active: Dictionary = data.get(
		"active_quests",
		{}
	)

	for quest_id in saved_active:

		if not quest_database.has(quest_id):

			print(
				"[QuestManager] Quest not found: ",
				quest_id
			)

			continue

		var quest: Quest = (
			quest_database[quest_id].duplicate(true)
		)

		quest.apply_save_dict(
			saved_active[quest_id]
		)

		active_quests[quest_id] = quest


	# --------------------------------------------------------
	# COMPLETED QUESTS
	# --------------------------------------------------------

	var saved_completed: Dictionary = data.get(
		"completed_quests",
		{}
	)

	for quest_id in saved_completed:

		if not quest_database.has(quest_id):

			print(
				"[QuestManager] Completed quest not found: ",
				quest_id
			)

			continue

		var quest: Quest = (
			quest_database[quest_id].duplicate(true)
		)

		quest.apply_save_dict(
			saved_completed[quest_id]
		)

		completed_quests[quest_id] = quest


	# --------------------------------------------------------
	# TRACKED QUEST
	# --------------------------------------------------------

	var tracked_id := str(
		data.get(
			"tracked_quest_id",
			""
		)
	)

	if not tracked_id.is_empty():

		if active_quests.has(tracked_id):

			tracked_quest = active_quests[tracked_id]


	# --------------------------------------------------------
	# LOAD COMPLETE
	# --------------------------------------------------------

	print(
		"[QuestManager] Loaded active quests: ",
		active_quests.size()
	)

	print(
		"[QuestManager] Loaded completed quests: ",
		completed_quests.size()
	)

	if tracked_quest != null:

		print(
			"[QuestManager] Tracked quest: ",
			tracked_quest.quest_id
		)

		tracked_quest_changed.emit(
			tracked_quest
		)

	quest_list_updated.emit()
	refresh_npc_quest_indicators()

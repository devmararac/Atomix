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
	"story_quest_explore_dungeon": preload("res://Resources/Quest/explore_dungeon.tres"),
	"quest_chain_001_01": preload("res://Resources/Quest/quest_chain.tres"),
	"quest_chain_001_02": preload("res://Resources/Quest/quest_chain2.tres")
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

		# Add the notification to the queue.
		quest_notify_queue.append(argument)

		print(
			"[QuestManager] Added quest notification to queue: ",
			argument
		)

		print(
			"[QuestManager] Queue size: ",
			quest_notify_queue.size()
		)

		# Start processing if nothing is currently processing.
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

		print(
			"[QuestManager] Processing queued quest notification: ",
			argument
		)

		var parts := argument.split(":")

		if parts.size() < 3:

			print(
				"[QuestManager] Invalid quest notification: ",
				argument
			)

			continue

		var quest_id := parts[1]
		var objective_id := parts[2]

		var quest := get_quest(quest_id)

		if quest == null:

			print(
				"[QuestManager] Quest not found for notification: ",
				quest_id
			)

			continue


		# --------------------------------------------------------
		# Get current active objective
		# --------------------------------------------------------

		var objective := quest.get_active_objective()

		if objective == null:

			print(
				"[QuestManager] Quest has no active objective: ",
				quest_id
			)

			continue


		print(
			"[QuestManager] Current active objective: ",
			objective.id
		)

		print(
			"[QuestManager] Requested objective: ",
			objective_id
		)


		# --------------------------------------------------------
		# Make sure this notification belongs to the
		# current active objective.
		# --------------------------------------------------------

		if objective.id != objective_id:

			print(
				"[QuestManager] Ignoring notification because ",
				"it does not match the active objective."
			)

			continue


		# --------------------------------------------------------
		# Wait one frame before processing.
		# --------------------------------------------------------

		await get_tree().process_frame


		print(
			"[QuestManager] Notifying objective: ",
			objective.id
		)


		# --------------------------------------------------------
		# IMPORTANT:
		# Wait for notify() to completely finish before processing
		# the next Dialogic notification.
		# --------------------------------------------------------

		await notify(
			objective.type,
			objective.target_id
		)


		print(
			"[QuestManager] Finished objective notification: ",
			objective.id
		)


		# --------------------------------------------------------
		# Show next active objective.
		# --------------------------------------------------------

		var next_objective := quest.get_active_objective()

		if next_objective != null:

			print(
				"[QuestManager] Next active objective: ",
				next_objective.id
			)

		else:

			print(
				"[QuestManager] No active objective remaining."
			)


	processing_quest_notify = false

	print(
		"[QuestManager] Quest notification queue finished."
	)

# -------------------------------------------------------------------
# Accept Quest
# -------------------------------------------------------------------

func accept_quest(quest_id: String) -> void:

	# Already active?
	if active_quests.has(quest_id):
		print("[QuestManager] Quest is already ACTIVE: ", quest_id)
		return

	if completed_quests.has(quest_id):
		print("[QuestManager] Quest is already COMPLETED: ", quest_id)
		return

	# Doesn't exist?
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

	# ========================================================
	# QUEST ACCEPTANCE SAVE
	# ========================================================

	print(
		"[QuestManager] Requesting quest-only automatic save after quest acceptance..."
	)

	await SaveManager.auto_save_quest_data(
		"Accepted quest: " + quest.quest_id
	)

	print(
		"[QuestManager] Quest acceptance quest-only automatic save completed."
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

func is_objective_completed(quest_id: String, objective_id: String) -> bool:

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

func update_quest(quest_id: String, state: QuestState.Type) -> void:

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
		print(quest.quest_id, " State:", quest.state)

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
		"[QuestManager] Quest completed. Unlocking next quest: ",
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

	# Create a runtime copy of the quest resource.
	var next_quest: Quest = quest_database[next_quest_id].duplicate(true)

	# Start the quest.
	next_quest.start()

	# Add it to active quests.
	active_quests[next_quest.quest_id] = next_quest

	print(
		"[QuestManager] Next quest activated: ",
		next_quest.quest_id
	)

	# If there is no tracked quest, automatically track this one.
	if tracked_quest == null:
		set_tracked_quest(next_quest)

	# Update UI.
	quest_updated.emit(next_quest.quest_id)
	quest_list_updated.emit()

	# Update NPC indicators.
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

	if tracked_quest == quest:

		tracked_quest = null

		# Prefer the newly unlocked quest if there is one.
		if not quest.unlock_id.is_empty():

			if active_quests.has(quest.unlock_id):

				set_tracked_quest(
					active_quests[quest.unlock_id]
				)

		# Otherwise track the first active quest.
		if tracked_quest == null and active_quests.size() > 0:

			set_tracked_quest(
				active_quests.values()[0]
			)

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

		# The first story quest happens during the intro.
		# Save only the quest data so we do NOT create
		# a full game checkpoint at the intro location.

		print(
			"[QuestManager] Initial story quest completed."
		)

		print(
			"[QuestManager] Requesting quest-only automatic save..."
		)

		await SaveManager.auto_save_quest_data(
			"Completed quest: " + quest.quest_id
		)

		print(
			"[QuestManager] Initial story quest completion saved."
		)

	else:

		# Normal quests create a full game checkpoint.

		print(
			"[QuestManager] Requesting automatic save after quest completion..."
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
	tracked_quest_changed.emit(quest)

# -------------------------------------------------------------------
# Notify Quest
# -------------------------------------------------------------------

func notify(
	type: ObjectiveType.Type,
	target_id: String,
	amount: int = 1
) -> void:

	print(">>> QUEST NOTIFY CALLED <<<")
	print("TYPE: ", type)
	print("TARGET: ", target_id)
	print("STACK: ", get_stack())

	print("====================")
	print("QUEST EVENT:")
	print("Type:", type)
	print("Target:", target_id)
	print("Amount:", amount)

	print("ACTIVE QUESTS:")

	for quest in active_quests.values():

		print(
			"-",
			quest.quest_id,
			"| State:",
			quest.state
		)

		for objective in quest.objectives:

			print(
				"   Objective:",
				objective.id,
				"| Type:",
				objective.type,
				"| Target:",
				objective.target_id,
				"| Active:",
				objective.is_active,
				"| Completed:",
				objective.is_completed
			)

	print("====================")


	var quest_to_complete: Quest = null

	for quest in active_quests.values():

		if quest.notify(type, target_id, amount):

			var objective: Objective = quest.get_active_objective()

			if objective != null:

				objective_updated.emit(
					quest.quest_id,
					objective.id
				)

				print(
					"[QuestManager] Quest progress updated: ",
					quest.quest_id,
					" | Objective: ",
					objective.id
				)

				print(
					"[QuestManager] Requesting automatic save after quest progress..."
				)

				await SaveManager.auto_save(
					"Quest progress: " + quest.quest_id
				)

				print(
					"[QuestManager] Quest progress automatic save completed."
				)

			if quest.is_completed():
				quest_to_complete = quest

			break

	# Complete the quest AFTER finishing the active quest loop.
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

		tracked_quest_changed.emit(tracked_quest)

	quest_list_updated.emit()
	refresh_npc_quest_indicators()


extends Node

var save_data: SaveData = null
var completed_cutscenes: Dictionary = {}
var saved_carried_party_ids: Array[String] = []
var opened_chests: Array[String] = []
# ============================================================
# AUTOMATIC SAVE STATE
# ============================================================

var auto_save_in_progress: bool = false
var auto_save_queued: bool = false


# ============================================================
# AUTOMATIC SAVE
# ============================================================

func auto_save(reason: String = "") -> void:

	if auto_save_in_progress:
		auto_save_queued = true
		print("[SaveManager] Auto-save already in progress. Queuing another save.")
		return

	auto_save_in_progress = true

	if not reason.is_empty():
		print("[SaveManager] Auto-save started. Reason: ", reason)
	else:
		print("[SaveManager] Auto-save started.")

	await save_game()

	auto_save_in_progress = false

	print("[SaveManager] Auto-save finished.")

	if auto_save_queued:
		auto_save_queued = false
		print("[SaveManager] Running queued auto-save.")
		await auto_save("Queued auto-save")


# ============================================================
# BATTLE AUTO-SAVE
# ============================================================

func auto_save_battle_state(
	reason: String = "",
	battle_outcome: String = ""
) -> bool:

	if not StudentDataManager.is_student_logged_in():
		return false

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		return false

	# SAVE PLAYER HP
	if has_node("/root/BattleControllerGlobal"):
		if BattleControllerGlobal.has_method("save_player_hp"):
			BattleControllerGlobal.save_player_hp()

	# VALIDATE RETURN LOCATION
	var saved_scene := BattleManager.previous_scene

	if saved_scene.is_empty():
		push_error("[SaveManager] Battle return scene is empty.")
		return false

	var saved_position := {
		"x": BattleManager.previous_position.x,
		"y": BattleManager.previous_position.y
	}

	# --------------------------------------------------------
	# PARTY
	# --------------------------------------------------------

	var firebase_party: Array = []

	for atomon in PartyManager.party:

		if atomon == null or atomon.data == null:
			continue

		var atomon_dict: Dictionary = atomon.to_save_dict()

		if not atomon_dict.is_empty():
			firebase_party.append(atomon_dict)

	# --------------------------------------------------------
	# CARRIED PARTY
	# --------------------------------------------------------

	var carried_party_ids: Array[String] = []

	for carried_atomon in PartyManager.get_carried_party():

		if carried_atomon == null:
			continue

		if carried_atomon.instance_id.is_empty():
			continue

		carried_party_ids.append(carried_atomon.instance_id)

	# --------------------------------------------------------
	# INVENTORY
	# --------------------------------------------------------

	var firebase_inventory: Array = []

	for item in InventoryManager.inventory:

		if item == null:
			continue

		var item_dict: Dictionary = item.to_save_dict()

		if not item_dict.is_empty():
			firebase_inventory.append(item_dict)

	# --------------------------------------------------------
	# QUEST DATA
	# --------------------------------------------------------

	var quest_data: Dictionary = {}

	for quest_id in QuestManager.active_quests:

		var quest: Quest = QuestManager.active_quests[quest_id]

		if quest == null:
			continue

		quest_data[quest_id] = {
			"quest_status": "active",
			"data": quest.to_save_dict()
		}

	for quest_id in QuestManager.completed_quests:

		var quest: Quest = QuestManager.completed_quests[quest_id]

		if quest == null:
			continue

		quest_data[quest_id] = {
			"quest_status": "completed",
			"data": quest.to_save_dict()
		}

	# --------------------------------------------------------
	# COINS
	# --------------------------------------------------------

	var current_coins: int = CurrencyManager.coins

	# --------------------------------------------------------
	# PROGRESS
	# --------------------------------------------------------

	_sync_collected_elements_from_party()

	var collected_elements: Array = (
		StudentDataManager.get_collected_elements()
	)

	var progress: Dictionary = {
		"elements_total": StudentDataManager.TOTAL_ELEMENTS,
		"elements_collected": collected_elements.size(),
		"collected_elements": collected_elements.duplicate()
	}

	# --------------------------------------------------------
	# BATTLE STATISTICS
	# --------------------------------------------------------

	# --------------------------------------------------------
	# ACCOUNT-LEVEL BATTLE STATISTICS
	# --------------------------------------------------------

	# Load lifetime statistics from the separate account file.
	var battle_stats: Dictionary = OfflineSaveManager.load_account_stats(uid)

	# Migrate existing in-memory statistics if no local account record exists.
	if battle_stats.is_empty():

		var existing_stats: Variant = (
			StudentDataManager.student_data.get("battle_stats", {})
		)

		if existing_stats is Dictionary:
			battle_stats = existing_stats.duplicate(true)

	for stat in [
		"battles_played",
		"battles_won",
		"battles_lost",
		"battles_escaped"
	]:
		battle_stats[stat] = int(battle_stats.get(stat, 0))

	match battle_outcome.to_lower():

		"victory":
			battle_stats["battles_played"] += 1
			battle_stats["battles_won"] += 1

		"defeat":
			battle_stats["battles_played"] += 1
			battle_stats["battles_lost"] += 1

		"escape", "escaped":
			battle_stats["battles_played"] += 1
			battle_stats["battles_escaped"] += 1

	# Update the in-memory account statistics.
	StudentDataManager.student_data["battle_stats"] = (
		battle_stats.duplicate(true)
	)

	# Save lifetime statistics separately from the playthrough.
	if not OfflineSaveManager.save_account_stats(uid, battle_stats):
		push_error("[SaveManager] Could not save account battle statistics.")
		return false

	# --------------------------------------------------------
	# PRESERVE EXISTING LOCAL WORLD DATA
	# --------------------------------------------------------

	var previous_record := OfflineSaveManager.load_local_record(uid)

	var previous_game_data: Dictionary = {}

	if not previous_record.is_empty():

		var previous_data: Variant = previous_record.get(
			"game_data",
			{}
		)

		if previous_data is Dictionary:
			previous_game_data = previous_data

	# --------------------------------------------------------
	# BUILD LOCAL GAME STATE
	# --------------------------------------------------------

	var local_game_data: Dictionary = {
		"player_name": previous_game_data.get("player_name", "Player"),
		"coins": current_coins,
		"current_scene": saved_scene,
		"player_position": saved_position,
		"party": firebase_party,
		"carried_party": carried_party_ids,
		"active_index": PartyManager.active_index,
		"inventory": firebase_inventory,
		"quest_data": quest_data,
		"switches": previous_game_data.get("switches", {}).duplicate(true),
		"variables": previous_game_data.get("variables", {}).duplicate(true),
		"play_time": int(previous_game_data.get("play_time", 0)),
		"badges": previous_game_data.get("badges", []).duplicate(),
		"completed_cutscenes": previous_game_data.get(
			"completed_cutscenes",
			{}
		),
		"opened_chests": previous_game_data.get(
			"opened_chests",
			[]
		),
		"progress": progress,
		"battle_stats": battle_stats
	}

	# SAVE LOCALLY BEFORE CONTACTING FIREBASE
	if not OfflineSaveManager.save_local_game(uid, local_game_data):
		push_error("[SaveManager] Battle local save failed.")
		return false

	StudentDataManager.student_data["progress"] = progress
	StudentDataManager.progress_updated.emit(progress)

	# --------------------------------------------------------
	# ATTEMPT FIREBASE SYNCHRONIZATION
	# --------------------------------------------------------

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		return false

	var existing_data: Dictionary = document.get_unsafe_document()

	# --------------------------------------------------------
	# MERGE BATTLE STATISTICS
	# --------------------------------------------------------

	var cloud_stats: Variant = existing_data.get("battle_stats", {})

	if cloud_stats is Dictionary:

		for stat in [
			"battles_played",
			"battles_won",
			"battles_lost",
			"battles_escaped"
		]:
			battle_stats[stat] = maxi(
				int(battle_stats.get(stat, 0)),
				int(cloud_stats.get(stat, 0))
			)

	StudentDataManager.student_data["battle_stats"] = (
		battle_stats.duplicate(true)
	)
	
	# Update the separate account statistics file with merged values.
	if not OfflineSaveManager.save_account_stats(uid, battle_stats):
		push_error("[SaveManager] Could not update merged account statistics.")
		return false
	
	
	# Update the local record with merged statistics.
	local_game_data["battle_stats"] = battle_stats

	if not OfflineSaveManager.save_local_game(uid, local_game_data):
		push_error("[SaveManager] Could not update local battle statistics.")
		return false

	# --------------------------------------------------------
	# BUILD FIREBASE GAME STATE
	# --------------------------------------------------------

	var existing_game_state: Variant = existing_data.get(
		"game_state",
		{}
	)

	var game_state: Dictionary = {}

	if existing_game_state is Dictionary:
		game_state = existing_game_state.duplicate(true)

	game_state["has_save"] = true
	game_state["current_scene"] = saved_scene
	game_state["player_position"] = saved_position
	game_state["coins"] = current_coins
	game_state["active_index"] = PartyManager.active_index
	game_state["party"] = firebase_party
	game_state["carried_party"] = carried_party_ids
	game_state["inventory"] = firebase_inventory
	game_state["quest_data"] = quest_data
	game_state["switches"] = local_game_data["switches"]
	game_state["variables"] = local_game_data["variables"]
	game_state["play_time"] = local_game_data["play_time"]
	game_state["badges"] = local_game_data["badges"]
	game_state["completed_cutscenes"] = local_game_data["completed_cutscenes"]
	game_state["opened_chests"] = local_game_data["opened_chests"]

	document.add_or_update_field("game_state", game_state)
	document.add_or_update_field("progress", progress)
	document.add_or_update_field("battle_stats", battle_stats)
	
	# Keep an exact snapshot of the local save being uploaded.
	var uploaded_game_data: Dictionary = local_game_data.duplicate(true)
	
	var result: FirestoreDocument = await students.update(document)

	if result == null:
		return false

	# --------------------------------------------------------
	# CONFIRM SUCCESSFUL SYNCHRONIZATION
	# --------------------------------------------------------

	# Check whether a newer local save was created during upload.
	var latest_record := OfflineSaveManager.load_local_record(uid)

	if latest_record.is_empty():
		return false

	var latest_game_data: Variant = latest_record.get(
		"game_data",
		{}
	)

	if not latest_game_data is Dictionary:
		return false

	# Preserve pending status if local progress changed.
	if latest_game_data != uploaded_game_data:
		print("[SaveManager] Local save changed during battle upload. Sync remains pending.")
		return false

	if not OfflineSaveManager.set_pending_sync(uid, false):
		return false

	StudentDataManager.student_data["progress"] = progress
	StudentDataManager.progress_updated.emit(progress)

	await update_leaderboard_data()

	return true



# ============================================================
# QUEST-ONLY AUTOMATIC SAVE
# ============================================================

func auto_save_quest_data(reason: String = "") -> void:

	if auto_save_in_progress:

		while auto_save_in_progress:
			await get_tree().process_frame

	await _save_quest_data_only()


# ============================================================
# SAVE QUEST DATA ONLY
# ============================================================

func _save_quest_data_only() -> bool:

	if not StudentDataManager.is_student_logged_in():
		return false

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		return false

	# --------------------------------------------------------
	# BUILD QUEST DATA
	# --------------------------------------------------------

	var quest_data: Dictionary = {}

	for quest_id in QuestManager.active_quests:

		var quest: Quest = QuestManager.active_quests[quest_id]

		if quest == null:
			continue

		quest_data[quest_id] = {
			"quest_status": "active",
			"data": quest.to_save_dict()
		}

	for quest_id in QuestManager.completed_quests:

		var quest: Quest = QuestManager.completed_quests[quest_id]

		if quest == null:
			continue

		quest_data[quest_id] = {
			"quest_status": "completed",
			"data": quest.to_save_dict()
		}

	# --------------------------------------------------------
	# LOAD EXISTING LOCAL SAVE
	# --------------------------------------------------------

	var local_record := OfflineSaveManager.load_local_record(uid)

	# Create a complete local snapshot if one does not exist.
	if local_record.is_empty():

		await save_game()

		local_record = OfflineSaveManager.load_local_record(uid)

	if local_record.is_empty():
		push_error("[SaveManager] Could not create local quest save.")
		return false

	var local_game_data: Variant = local_record.get(
		"game_data",
		{}
	)

	if not local_game_data is Dictionary:
		push_error("[SaveManager] Local quest save data is invalid.")
		return false

	# Update only quest data.
	local_game_data["quest_data"] = quest_data

	if not OfflineSaveManager.save_local_game(
		uid,
		local_game_data
	):
		push_error("[SaveManager] Local quest save failed.")
		return false

	# --------------------------------------------------------
	# ATTEMPT FIREBASE SYNCHRONIZATION
	# --------------------------------------------------------

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		return true

	var existing_data: Dictionary = document.get_unsafe_document()

	var existing_game_state: Variant = existing_data.get(
		"game_state",
		{}
	)

	var game_state: Dictionary = {}

	if existing_game_state is Dictionary:
		game_state = existing_game_state.duplicate(true)

	game_state["quest_data"] = quest_data

	document.add_or_update_field(
		"game_state",
		game_state
	)

	var result: FirestoreDocument = await students.update(document)

	if result == null:
		return true

	return true



# ============================================================
# CURRENCY-ONLY AUTOMATIC SAVE
# ============================================================

func auto_save_currency(reason: String = "") -> void:

	if auto_save_in_progress:

		while auto_save_in_progress:
			await get_tree().process_frame

	await _save_currency_only()


# ============================================================
# SAVE CURRENCY ONLY
# ============================================================

func _save_currency_only() -> bool:

	if not StudentDataManager.is_student_logged_in():
		return false

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		return false

	# --------------------------------------------------------
	# LOAD EXISTING LOCAL SAVE
	# --------------------------------------------------------

	var local_record := OfflineSaveManager.load_local_record(uid)

	if local_record.is_empty():

		await save_game()

		local_record = OfflineSaveManager.load_local_record(uid)

	if local_record.is_empty():
		push_error("[SaveManager] Could not create local currency save.")
		return false

	var local_game_data: Variant = local_record.get(
		"game_data",
		{}
	)

	if not local_game_data is Dictionary:
		push_error("[SaveManager] Local currency save data is invalid.")
		return false

	# --------------------------------------------------------
	# SAVE COINS LOCALLY
	# --------------------------------------------------------

	var current_coins: int = CurrencyManager.coins

	local_game_data["coins"] = current_coins

	if not OfflineSaveManager.save_local_game(
		uid,
		local_game_data
	):
		push_error("[SaveManager] Local currency save failed.")
		return false

	# --------------------------------------------------------
	# ATTEMPT FIREBASE SYNCHRONIZATION
	# --------------------------------------------------------

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		return true

	var existing_data: Dictionary = document.get_unsafe_document()

	var existing_game_state: Variant = existing_data.get(
		"game_state",
		{}
	)

	var game_state: Dictionary = {}

	if existing_game_state is Dictionary:
		game_state = existing_game_state.duplicate(true)

	game_state["coins"] = current_coins

	document.add_or_update_field(
		"game_state",
		game_state
	)

	var result: FirestoreDocument = await students.update(document)

	if result == null:
		return true

	return true



# ============================================================
# START NEW GAME
# ============================================================

func start_new_game() -> bool:

	print("[SaveManager] ========================================")
	print("[SaveManager] STARTING NEW GAME")
	print("[SaveManager] ========================================")

	if not StudentDataManager.is_student_logged_in():
		print("[SaveManager] New Game cancelled: student is not logged in.")
		return false

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] New Game cancelled: student UID is empty.")
		return false

	# ========================================================
	# CREATE FRESH PLAYTHROUGH STATE
	# ========================================================

	var new_game_state: Dictionary = {
		"has_save": false,
		"current_scene": "",
		"player_position": {
			"x": 0.0,
			"y": 0.0
		},
		"coins": 0,
		"active_index": 0,
		"party": [],
		"carried_party": [],
		"inventory": [],
		"quest_data": {},
		"switches": {},
		"variables": {},
		"play_time": 0,
		"badges": [],
		"completed_cutscenes": {},
		"opened_chests": []
	}

	# ========================================================
	# SAVE THE RESET LOCALLY FIRST
	# ========================================================

	var new_local_game_data: Dictionary = {
		"player_name": "",
		"coins": 0,
		"current_scene": "",
		"player_position": {
			"x": 0.0,
			"y": 0.0
		},
		"party": [],
		"carried_party": [],
		"active_index": 0,
		"inventory": [],
		"quest_data": {},
		"switches": {},
		"variables": {},
		"play_time": 0,
		"badges": [],
		"completed_cutscenes": {},
		"opened_chests": [],
		"progress": {
			"elements_total": StudentDataManager.TOTAL_ELEMENTS,
			"elements_collected": 0,
			"collected_elements": []
		},
		"has_save": false
	}

	if not OfflineSaveManager.save_local_game(uid, new_local_game_data):
		print("[SaveManager] Failed to save new-game reset locally.")
		return false

	# ========================================================
	# RESET STUDENT DATA IN MEMORY
	# ========================================================

	StudentDataManager.student_data["game_state"] = (
		new_game_state.duplicate(true)
	)

	StudentDataManager.student_data["progress"] = (
		new_local_game_data["progress"].duplicate(true)
	)

	# ========================================================
	# RESET LOCAL RUNTIME GAME STATE
	# ========================================================

	save_data = SaveData.new()

	completed_cutscenes.clear()
	opened_chests.clear()
	saved_carried_party_ids.clear()

	global.return_position = Vector2.ZERO
	global.spawn_point_name = ""
	global.return_scene = ""

	# --------------------------------------------------------
	# PARTY
	# --------------------------------------------------------

	PartyManager.party.clear()
	PartyManager.carried_party.clear()
	PartyManager.active_index = 0

	# --------------------------------------------------------
	# INVENTORY
	# --------------------------------------------------------

	InventoryManager.inventory.clear()
	InventoryManager.inventory_changed.emit()

	# --------------------------------------------------------
	# CURRENCY
	# --------------------------------------------------------

	CurrencyManager.set_coins(0)

	# --------------------------------------------------------
	# QUESTS
	# --------------------------------------------------------

	QuestManager.active_quests.clear()
	QuestManager.completed_quests.clear()
	QuestManager.tracked_quest = null

	QuestManager.quest_list_updated.emit()
	QuestManager.refresh_npc_quest_indicators()

	# --------------------------------------------------------
	# ELEMENT PROGRESS
	# --------------------------------------------------------

	StudentDataManager.clear_runtime_progress()

	StudentDataManager.student_data["progress"] = (
		new_local_game_data["progress"].duplicate(true)
	)

	# ========================================================
	# ACCOUNT-LEVEL STATISTICS ARE PRESERVED
	# ========================================================

	# Do not clear OfflineSaveManager account statistics.
	# Lifetime battle statistics must survive a new game.

	print("[SaveManager] New-game reset saved locally.")
	print("[SaveManager] Lifetime battle statistics preserved.")

	# ========================================================
	# ATTEMPT CLOUD RESET IF ONLINE
	# ========================================================

	if not StudentDataManager.is_offline_student():

		var sync_success: bool = await sync_local_save_to_firebase(uid)

		if sync_success:
			print("[SaveManager] New-game reset synchronized with Firebase.")
		else:
			print("[SaveManager] New-game reset remains pending synchronization.")

	print("[SaveManager] ========================================")
	print("[SaveManager] NEW GAME READY")
	print("[SaveManager] ========================================")

	return true


# ============================================================
# SAVE GAME
# ============================================================

func save_game() -> void:

	print("[SaveManager] Starting full game save...")

	if not StudentDataManager.is_student_logged_in():
		print("[SaveManager] Save cancelled: student not logged in.")
		return

	if global.player == null:
		print("[SaveManager] Save cancelled: global.player is null.")
		return

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] Save cancelled: student UID is empty.")
		return

	save_data = SaveData.new()

	# ========================================================
	# PLAYER
	# ========================================================

	save_data.player_name = "Player"
	save_data.coins = CurrencyManager.coins
	save_data.current_scene = get_tree().current_scene.scene_file_path
	save_data.player_position = global.player.global_position

	print("[SaveManager] Saving scene: ", save_data.current_scene)
	print("[SaveManager] Saving player position: ", save_data.player_position)

	# ========================================================
	# PARTY
	# ========================================================

	save_data.party = PartyManager.party.duplicate(true)
	save_data.active_index = PartyManager.active_index

	print("[SaveManager] Saving party count: ", save_data.party.size())
	print("[SaveManager] Active Atomon index: ", save_data.active_index)

	# ========================================================
	# COLLECTED ELEMENTS
	# ========================================================

	_sync_collected_elements_from_party()

	# ========================================================
	# INVENTORY
	# ========================================================

	save_data.inventory = InventoryManager.inventory.duplicate(true)

	print("[SaveManager] Saving inventory count: ", save_data.inventory.size())

	# ========================================================
	# QUESTS
	# ========================================================

	save_data.quest_data.clear()

	for quest_id in QuestManager.active_quests:

		var quest: Quest = QuestManager.active_quests[quest_id]

		if quest == null:
			continue

		save_data.quest_data[quest_id] = {
			"quest_status": "active",
			"data": quest.to_save_dict()
		}

	for quest_id in QuestManager.completed_quests:

		var quest: Quest = QuestManager.completed_quests[quest_id]

		if quest == null:
			continue

		save_data.quest_data[quest_id] = {
			"quest_status": "completed",
			"data": quest.to_save_dict()
		}

	
	print("[SaveManager] Saving quest count: ", save_data.quest_data.size())

	# ========================================================
	# PREPARE LOCAL SAVE DATA
	# ========================================================

	var local_party_data: Array = []

	for atomon in save_data.party:
		if atomon == null:
			continue

		local_party_data.append(atomon.to_save_dict())


	var local_inventory_data: Array = []

	for item in save_data.inventory:
		if item == null:
			continue

		local_inventory_data.append(item.to_save_dict())


	# ========================================================
	# CARRIED PARTY
	# ========================================================

	var local_carried_party_ids: Array = []

	for atomon in PartyManager.get_carried_party():
		if atomon == null:
			continue

		local_carried_party_ids.append(atomon.instance_id)


	# ========================================================
	# PLAYER PROGRESS
	# ========================================================

	var local_progress: Dictionary = {}

	if StudentDataManager.student_data is Dictionary:
		var progress_value: Variant = StudentDataManager.student_data.get(
			"progress",
			{}
		)

		if progress_value is Dictionary:
			local_progress = progress_value.duplicate(true)


	# ========================================================
	# COMPLETE LOCAL GAME DATA
	# ========================================================

	var local_game_data: Dictionary = {
		"has_save": true,
		"player_name": save_data.player_name,
		"coins": save_data.coins,
		"current_scene": save_data.current_scene,
		"player_position": {
			"x": save_data.player_position.x,
			"y": save_data.player_position.y
		},
		"party": local_party_data,
		"carried_party": local_carried_party_ids,
		"active_index": save_data.active_index,
		"inventory": local_inventory_data,
		"quest_data": save_data.quest_data.duplicate(true),
		
		"switches": save_data.switches.duplicate(true),
		"variables": save_data.variables.duplicate(true),
		"play_time": save_data.play_time,
		"badges": save_data.badges.duplicate(),

		"battle_stats": StudentDataManager.student_data.get(
			"battle_stats",
			{}
		),
		"completed_cutscenes": completed_cutscenes.duplicate(true),
		"opened_chests": opened_chests.duplicate(),
		"progress": local_progress
	}


	# ========================================================
	# SAVE LOCALLY FIRST
	# ========================================================

	var local_saved: bool = OfflineSaveManager.save_local_game(
		uid,
		local_game_data
	)

	if not local_saved:
		push_error("[SaveManager] Local save failed. Cloud upload cancelled.")
		return

	print("[SaveManager] Local gameplay save completed.")


	# ========================================================
	# CLOUD SYNCHRONIZATION
	# ========================================================

	if not StudentDataManager.is_offline_student() \
	and FirebaseManager.is_authenticated() \
	and ConnectionManager.is_connected_to_internet:

		var cloud_saved: bool = await sync_local_save_to_firebase(uid)

		if cloud_saved:
			print("[SaveManager] Cloud sync successful.")
		else:
			print("[SaveManager] Cloud sync failed. Local save remains pending.")

	else:
		print("[SaveManager] Offline session or no internet connection.")
		print("[SaveManager] Local save remains pending sync.")



# ============================================================
# CUTSCENE STATE
# ============================================================

func is_cutscene_completed(cutscene_id: String) -> bool:

	if cutscene_id.is_empty():
		return false

	return completed_cutscenes.has(cutscene_id)


func complete_cutscene(cutscene_id: String) -> void:

	if cutscene_id.is_empty():
		return

	completed_cutscenes[cutscene_id] = true


func clear_completed_cutscenes() -> void:
	completed_cutscenes.clear()


# ============================================================
# SYNC COLLECTED ELEMENTS FROM CURRENT PARTY
# ============================================================

func _sync_collected_elements_from_party() -> void:

	for atomon in PartyManager.party:

		if atomon == null:
			continue

		if atomon.data == null:
			continue

		var symbol := str(
			atomon.data.chemical_symbol
		).strip_edges()

		if symbol.is_empty():
			continue

		if StudentDataManager.collected_elements.has(symbol):
			continue

		if StudentDataManager.collected_elements.size() >= StudentDataManager.TOTAL_ELEMENTS:
			break

		StudentDataManager.collected_elements.append(symbol)


# ============================================================
# LOAD GAME
# ============================================================

func load_game() -> void:

	if not StudentDataManager.is_student_logged_in():
		return

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		push_error("[SaveManager] Cannot load: student UID is empty.")
		return

	# --------------------------------------------------------
	# CHECK LOCAL SAVE FIRST
	# --------------------------------------------------------

	var local_record := OfflineSaveManager.load_local_record(uid)

	var local_pending := (
		not local_record.is_empty()
		and bool(local_record.get("pending_sync", false))
	)

	var cloud_loaded := false

	# --------------------------------------------------------
	# PRIORITIZE UNSYNCHRONIZED LOCAL PROGRESS
	# --------------------------------------------------------

	if local_pending:

		var local_game_data: Variant = local_record.get(
			"game_data",
			{}
		)

		if not local_game_data is Dictionary:
			push_error("[SaveManager] Pending local save is invalid.")
			return

		_apply_local_save_data(local_game_data)

	else:

		# ----------------------------------------------------
		# LOAD FROM FIREBASE
		# ----------------------------------------------------

		if StudentDataManager.is_offline_student():
			cloud_loaded = false
		else:
			cloud_loaded = await download_from_firebase()

		# ----------------------------------------------------
		# FALL BACK TO LOCAL SAVE
		# ----------------------------------------------------

		if not cloud_loaded:

			if local_record.is_empty():
				return

			var local_game_data: Variant = local_record.get(
				"game_data",
				{}
			)

			if not local_game_data is Dictionary:
				push_error("[SaveManager] Local save data is invalid.")
				return

			_apply_local_save_data(local_game_data)

	# --------------------------------------------------------
	# VALIDATE SAVE DATA
	# --------------------------------------------------------

	if save_data == null:
		push_error("[SaveManager] Cannot restore: save_data is null.")
		return

	if save_data.current_scene.is_empty():
		push_error("[SaveManager] Cannot restore: saved scene is empty.")
		return

	# --------------------------------------------------------
	# RESTORE COINS
	# --------------------------------------------------------

	CurrencyManager.set_coins(save_data.coins)

	# --------------------------------------------------------
	# CLEAR CURRENT PARTY
	# --------------------------------------------------------

	PartyManager.party.clear()
	PartyManager.carried_party.clear()
	PartyManager.active_index = 0

	# --------------------------------------------------------
	# CHANGE TO SAVED SCENE
	# --------------------------------------------------------

	var scene_result := await get_tree().change_scene_to_file(
		save_data.current_scene
	)

	if scene_result != OK:
		push_error("[SaveManager] Failed to load saved scene.")
		return

	await get_tree().process_frame
	await get_tree().process_frame

	# --------------------------------------------------------
	# RESTORE PLAYER POSITION
	# --------------------------------------------------------

	if global.player != null:
		global.player.global_position = save_data.player_position
	else:
		push_error("[SaveManager] Player node is missing after scene load.")

	# --------------------------------------------------------
	# RESTORE ATOMON COLLECTION
	# --------------------------------------------------------

	_restore_saved_party()

	# --------------------------------------------------------
	# RESTORE CARRIED PARTY
	# --------------------------------------------------------

	_restore_carried_party()

	# --------------------------------------------------------
	# RESTORE INVENTORY
	# --------------------------------------------------------

	apply_saved_inventory_state()

	# --------------------------------------------------------
	# RESTORE QUESTS
	# --------------------------------------------------------

	apply_saved_quest_state()

	print("[SaveManager] Game restore complete.")


# ============================================================
# RESTORE SAVED PARTY
# ============================================================

func _restore_saved_party() -> void:

	var firebase_party: Array = save_data.firebase_party_data

	if firebase_party.is_empty():
		print("[SaveManager] No saved Atomon collection to restore.")
		return

	PartyManager.party.clear()
	PartyManager.carried_party.clear()
	PartyManager.active_index = 0

	PartyManager.load_saved_collection(
		firebase_party
	)

	if PartyManager.party.size() > 0:

		PartyManager.active_index = clampi(
			save_data.active_index,
			0,
			PartyManager.party.size() - 1
		)

	print(
		"[SaveManager] Collection restored: ",
		PartyManager.party.size(),
		" Atomons."
	)


# ============================================================
# FIREBASE UPLOAD
# ============================================================

func upload_to_firebase() -> bool:

	if save_data == null:
		print("[SaveManager] Firebase upload cancelled: save_data is null.")
		return false

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] Firebase upload cancelled: UID is empty.")
		return false

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		print("[SaveManager] Firebase upload failed: student document not found.")
		return false

	# ========================================================
	# SERIALIZE COMPLETE PARTY
	# ========================================================

	var firebase_party: Array = []

	for atomon in save_data.party:

		if atomon == null:
			continue

		var atomon_dict := atomon.to_save_dict()

		if atomon_dict.is_empty():
			continue

		firebase_party.append(atomon_dict)

	# ========================================================
	# SERIALIZE INVENTORY
	# ========================================================

	var firebase_inventory: Array = []

	for item in save_data.inventory:

		if item == null:
			continue

		var item_dict := item.to_save_dict()

		if item_dict.is_empty():
			continue

		firebase_inventory.append(item_dict)

	# ========================================================
	# PROGRESS
	# ========================================================

	var collected_elements: Array = (
		StudentDataManager.get_collected_elements()
	)

	var progress: Dictionary = {
		"elements_total":
			StudentDataManager.TOTAL_ELEMENTS,

		"elements_collected":
			collected_elements.size(),

		"collected_elements":
			collected_elements.duplicate()
	}

	# ========================================================
	# CARRIED PARTY
	# ========================================================

	var carried_party_ids: Array[String] = []

	for carried_atomon in PartyManager.get_carried_party():

		if carried_atomon == null:
			continue

		if carried_atomon.instance_id.is_empty():
			continue

		carried_party_ids.append(
			carried_atomon.instance_id
		)

	# ========================================================
	# GAME STATE
	# ========================================================

	var game_state := {

		"has_save": true,

		"current_scene":
			save_data.current_scene,

		"player_position": {

			"x":
				save_data.player_position.x,

			"y":
				save_data.player_position.y
		},

		"coins":
			save_data.coins,

		"active_index":
			save_data.active_index,

		"party":
			firebase_party,

		"carried_party":
			carried_party_ids,

		"inventory":
			firebase_inventory,

		"quest_data":
			save_data.quest_data,

		"switches":
			save_data.switches.duplicate(true),

		"variables":
			save_data.variables.duplicate(true),

		"play_time":
			save_data.play_time,

		"badges":
			save_data.badges.duplicate(),

		"completed_cutscenes":
			completed_cutscenes.duplicate(true),
		
		"opened_chests": opened_chests.duplicate()
	}

	# ========================================================
	# PLAYER PROFILE
	# ========================================================

	document.add_or_update_field(
		"display_name",
		PlayerManager.display_name
	)

	document.add_or_update_field(
		"character_id",
		(
			PlayerManager.selected_character.character_id
			if PlayerManager.selected_character != null
			else ""
		)
	)

	# ========================================================
	# UPDATE FIRESTORE
	# ========================================================

	document.add_or_update_field(
		"game_state",
		game_state
	)

	document.add_or_update_field(
		"progress",
		progress
	)
	
	# ========================================================
	# ACCOUNT-LEVEL BATTLE STATISTICS
	# ========================================================

	var battle_stats: Dictionary = OfflineSaveManager.load_account_stats(
		StudentDataManager.get_student_uid()
	)

	# Fallback for existing sessions that have not cached statistics yet.
	if battle_stats.is_empty():

		var existing_stats: Variant = (
			StudentDataManager.student_data.get("battle_stats", {})
		)

		if existing_stats is Dictionary:
			battle_stats = existing_stats.duplicate(true)

	if not battle_stats.is_empty():
		StudentDataManager.student_data["battle_stats"] = battle_stats.duplicate(true)

		document.add_or_update_field(
			"battle_stats",
			battle_stats
		)

	print("[SaveManager] Uploading game state to Firebase...")
	print("[SaveManager] Scene: ", save_data.current_scene)
	print("[SaveManager] Party: ", firebase_party.size())
	print("[SaveManager] Carried party: ", carried_party_ids.size())
	print("[SaveManager] Inventory: ", firebase_inventory.size())

	var result: FirestoreDocument = await students.update(document)

	if result == null:
		print("[SaveManager] ERROR: Firebase game save failed.")
		return false

	StudentDataManager.student_data["progress"] = progress

	StudentDataManager.progress_updated.emit(progress)

	print("[SaveManager] Firebase game save successful.")

	# Update public leaderboard data.
	await update_leaderboard_data()

	return true


# ============================================================
# UPDATE PUBLIC LEADERBOARD DATA
# ============================================================

func update_leaderboard_data() -> bool:

	if not StudentDataManager.is_student_logged_in():
		print("[SaveManager] Leaderboard update cancelled: student not logged in.")
		return false

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] Leaderboard update cancelled: UID is empty.")
		return false

	# ========================================================
	# GET CURRENT STUDENT DATA
	# ========================================================

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var student_document: FirestoreDocument = (
		await students.get_doc(uid)
	)

	if student_document == null:
		print(
			"[SaveManager] Leaderboard update failed: ",
			"student document not found."
		)
		return false

	var student_data: Dictionary = (
		student_document.get_unsafe_document()
	)

	# ========================================================
	# BASIC INFORMATION
	# ========================================================

	var student_name := str(
		student_data.get(
			"name",
			PlayerManager.display_name
		)
	)

	var section := str(
		student_data.get(
			"section",
			"Unassigned"
		)
	)

	# ========================================================
	# PROGRESS
	# ========================================================

	var progress: Dictionary = student_data.get(
		"progress",
		{}
	)

	if not progress is Dictionary:
		progress = {}

	var elements_collected := int(
		progress.get(
			"elements_collected",
			0
		)
	)

	var elements_total := int(
		progress.get(
			"elements_total",
			StudentDataManager.TOTAL_ELEMENTS
		)
	)

	# ========================================================
	# BATTLE STATISTICS
	# ========================================================

	var battle_stats: Dictionary = student_data.get(
		"battle_stats",
		{}
	)

	if not battle_stats is Dictionary:
		battle_stats = {}

	var battles_played := int(
		battle_stats.get(
			"battles_played",
			0
		)
	)

	var battles_won := int(
		battle_stats.get(
			"battles_won",
			0
		)
	)

	var battles_lost := int(
		battle_stats.get(
			"battles_lost",
			0
		)
	)

	var battles_escaped := int(
		battle_stats.get(
			"battles_escaped",
			0
		)
	)

	var win_rate := 0.0

	if battles_played > 0:
		win_rate = (
			float(battles_won)
			/ float(battles_played)
			* 100.0
		)

	# ========================================================
	# QUIZ STATISTICS
	# ========================================================

	var assessment: Dictionary = student_data.get(
		"assessment",
		{}
	)

	if not assessment is Dictionary:
		assessment = {}

	var total_quizzes := 0
	var completed_quizzes := 0
	var quiz_score_total := 0.0

	for assessment_id in assessment:

		if not str(assessment_id).begins_with("quiz_"):
			continue

		var quiz_data = assessment[assessment_id]

		if not quiz_data is Dictionary:
			continue

		total_quizzes += 1

		if not bool(
			quiz_data.get(
				"completed",
				false
			)
		):
			continue

		completed_quizzes += 1

		quiz_score_total += float(
			quiz_data.get(
				"percentage",
				0.0
			)
		)

	var average_quiz_score := 0.0

	if completed_quizzes > 0:
		average_quiz_score = (
			quiz_score_total
			/ float(completed_quizzes)
		)

	# ========================================================
	# COLLECTION PERCENTAGE
	# ========================================================

	var collection_percentage := 0.0

	if elements_total > 0:
		collection_percentage = (
			float(elements_collected)
			/ float(elements_total)
			* 100.0
		)

	# ========================================================
	# OVERALL SCORE
	# ========================================================

	var overall_total := collection_percentage
	var overall_parts := 1

	if completed_quizzes > 0:
		overall_total += average_quiz_score
		overall_parts += 1

	if battles_played > 0:
		overall_total += win_rate
		overall_parts += 1

	var overall_score := (
		overall_total
		/ float(overall_parts)
	)

	# ========================================================
	# LEADERBOARD COLLECTION
	# ========================================================

	var leaderboard: FirestoreCollection = (
		Firebase.Firestore.collection("leaderboard")
	)

	var leaderboard_document: FirestoreDocument = (
		await leaderboard.get_doc(uid)
	)

	# ========================================================
	# DATA THAT IS SAFE TO SHOW ON LEADERBOARD
	# ========================================================

	var leaderboard_data: Dictionary = {
		"uid": uid,
		"name": student_name,
		"section": section,
		"elements_collected": elements_collected,
		"elements_total": elements_total,
		"battles_played": battles_played,
		"battles_won": battles_won,
		"battles_lost": battles_lost,
		"battles_escaped": battles_escaped,
		"win_rate": win_rate,
		"average_quiz_score": average_quiz_score,
		"completed_quizzes": completed_quizzes,
		"total_quizzes": total_quizzes,
		"overall_score": overall_score
	}

	# ========================================================
	# CREATE NEW LEADERBOARD DOCUMENT
	# ========================================================

	if leaderboard_document == null:

		var created_document: FirestoreDocument = (
			await leaderboard.add(
				uid,
				leaderboard_data
			)
		)

		if created_document == null:
			print(
				"[SaveManager] Leaderboard creation failed."
			)
			return false

	# ========================================================
	# UPDATE EXISTING LEADERBOARD DOCUMENT
	# ========================================================

	else:

		for field_name in leaderboard_data:

			leaderboard_document.add_or_update_field(
				field_name,
				leaderboard_data[field_name]
			)

		var updated_document: FirestoreDocument = (
			await leaderboard.update(
				leaderboard_document
			)
		)

		if updated_document == null:
			print(
				"[SaveManager] Leaderboard update failed."
			)
			return false

	print(
		"[SaveManager] Leaderboard updated successfully. UID: ",
		uid
	)

	return true

# ============================================================
# FIREBASE DOWNLOAD
# ============================================================

func download_from_firebase() -> bool:

	if not StudentDataManager.is_student_logged_in():
		return false

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		return false

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		return false

	var cloud_data: Dictionary = document.get_unsafe_document()

	# ========================================================
	# PLAYER PROFILE
	# ========================================================

	if cloud_data.has("display_name"):
		PlayerManager.display_name = str(cloud_data["display_name"])

	if cloud_data.has("character_id"):

		var character_id := str(cloud_data["character_id"])

		if not character_id.is_empty():
			if PlayerManager.has_method("set_character_by_id"):
				PlayerManager.set_character_by_id(character_id)

	# ========================================================
	# GAME STATE
	# ========================================================

	var game_state: Variant = cloud_data.get("game_state", {})

	if not game_state is Dictionary:
		return false

	if not bool(game_state.get("has_save", false)):
		return false

	# ========================================================
	# CREATE SAVE DATA
	# ========================================================

	save_data = SaveData.new()

	save_data.player_name = PlayerManager.display_name

	save_data.current_scene = str(
		game_state.get("current_scene", "")
	)

	if save_data.current_scene.is_empty():
		return false

	# ========================================================
	# PLAYER POSITION
	# ========================================================

	var saved_position: Variant = game_state.get(
		"player_position",
		{}
	)

	if saved_position is Dictionary:

		save_data.player_position = Vector2(
			float(saved_position.get("x", 0.0)),
			float(saved_position.get("y", 0.0))
		)

	# ========================================================
	# COINS AND ACTIVE ATOMON
	# ========================================================

	save_data.coins = int(game_state.get("coins", 0))
	save_data.active_index = int(game_state.get("active_index", 0))

	# ========================================================
	# PARTY
	# ========================================================

	var saved_party: Variant = game_state.get("party", [])

	if saved_party is Array:
		save_data.firebase_party_data = saved_party
	else:
		save_data.firebase_party_data = []

	# ========================================================
	# CARRIED PARTY
	# ========================================================

	saved_carried_party_ids.clear()

	var carried_party: Variant = game_state.get(
		"carried_party",
		[]
	)

	if carried_party is Array:

		for party_id in carried_party:

			var id_string := str(party_id).strip_edges()

			if not id_string.is_empty():
				saved_carried_party_ids.append(id_string)

	# ========================================================
	# INVENTORY
	# ========================================================

	var saved_inventory: Variant = game_state.get(
		"inventory",
		[]
	)

	if saved_inventory is Array:
		save_data.firebase_inventory_data = saved_inventory
	else:
		save_data.firebase_inventory_data = []

	# ========================================================
	# QUESTS
	# ========================================================

	var saved_quests: Variant = game_state.get(
		"quest_data",
		{}
	)

	if saved_quests is Dictionary:
		save_data.quest_data = saved_quests.duplicate(true)
	else:
		save_data.quest_data = {}

	# ========================================================
	# WORLD DATA
	# ========================================================

	var saved_switches: Variant = game_state.get("switches", {})

	if saved_switches is Dictionary:
		save_data.switches = saved_switches.duplicate(true)

	var saved_variables: Variant = game_state.get("variables", {})

	if saved_variables is Dictionary:
		save_data.variables = saved_variables.duplicate(true)

	save_data.play_time = int(game_state.get("play_time", 0))

	var saved_badges: Variant = game_state.get("badges", [])

	save_data.badges.clear()

	if saved_badges is Array:
		for badge in saved_badges:
			save_data.badges.append(str(badge))

	# ========================================================
	# CUTSCENES
	# ========================================================

	var saved_cutscenes: Variant = game_state.get(
		"completed_cutscenes",
		{}
	)

	if saved_cutscenes is Dictionary:
		completed_cutscenes = saved_cutscenes.duplicate(true)
	else:
		completed_cutscenes = {}

	# ========================================================
	# OPENED CHESTS
	# ========================================================

	opened_chests.clear()

	var saved_chests: Variant = game_state.get(
		"opened_chests",
		[]
	)

	if saved_chests is Array:

		for chest_id in saved_chests:

			var chest_id_string := str(chest_id).strip_edges()

			if not chest_id_string.is_empty():
				opened_chests.append(chest_id_string)

	# ========================================================
	# STUDENT PROGRESS
	# ========================================================

	var progress: Variant = cloud_data.get("progress", {})

	if not progress is Dictionary:
		progress = {}

	progress = progress.duplicate(true)

	if not progress.has("elements_total"):
		progress["elements_total"] = StudentDataManager.TOTAL_ELEMENTS

	if not progress.has("collected_elements"):
		progress["collected_elements"] = []

	if not progress.has("elements_collected"):
		progress["elements_collected"] = 0

	StudentDataManager.student_data["progress"] = progress

	StudentDataManager.collected_elements.clear()

	var saved_elements: Variant = progress.get(
		"collected_elements",
		[]
	)

	if saved_elements is Array:

		for symbol in saved_elements:

			var clean_symbol := str(symbol).strip_edges()

			if not clean_symbol.is_empty() and not StudentDataManager.collected_elements.has(clean_symbol):
				StudentDataManager.collected_elements.append(clean_symbol)

	progress["elements_collected"] = (
		StudentDataManager.collected_elements.size()
	)

	StudentDataManager.student_data["progress"] = progress
	StudentDataManager.progress_is_loaded = true

	# ========================================================
	# BATTLE STATISTICS
	# ========================================================

	var battle_stats: Variant = cloud_data.get("battle_stats", {})

	if battle_stats is Dictionary:

		StudentDataManager.student_data["battle_stats"] = (
			battle_stats.duplicate(true)
		)

		if not OfflineSaveManager.save_account_stats(uid, battle_stats):
			push_warning("[SaveManager] Could not cache account battle statistics.")

	# ========================================================
	# BUILD COMPLETE LOCAL SAVE
	# ========================================================

	var local_game_data: Dictionary = {
		"has_save": true,
		"player_name": PlayerManager.display_name,
		"coins": save_data.coins,
		"current_scene": save_data.current_scene,
		"player_position": {
			"x": save_data.player_position.x,
			"y": save_data.player_position.y
		},
		"party": save_data.firebase_party_data.duplicate(true),
		"carried_party": saved_carried_party_ids.duplicate(),
		"active_index": save_data.active_index,
		"inventory": save_data.firebase_inventory_data.duplicate(true),
		"quest_data": save_data.quest_data.duplicate(true),
		"switches": save_data.switches.duplicate(true),
		"variables": save_data.variables.duplicate(true),
		"play_time": save_data.play_time,
		"badges": save_data.badges.duplicate(),
		"completed_cutscenes": completed_cutscenes.duplicate(true),
		"opened_chests": opened_chests.duplicate(),
		"progress": progress.duplicate(true),
		"battle_stats": StudentDataManager.student_data.get(
			"battle_stats",
			{}
		).duplicate(true)
	}

	# ========================================================
	# CACHE DOWNLOADED SAVE LOCALLY
	# ========================================================

	if not OfflineSaveManager.save_local_game(uid, local_game_data):
		push_warning("[SaveManager] Cloud save loaded, but local caching failed.")
		return true

	# The data came from Firebase, so this local copy is synchronized.
	if not OfflineSaveManager.set_pending_sync(uid, false):
		push_warning("[SaveManager] Could not mark downloaded save as synchronized.")

	print("[SaveManager] Cloud save downloaded and cached locally.")

	return true


# ============================================================
# APPLY SAVED PARTY STATE
# ============================================================

func apply_saved_party_state() -> void:

	if save_data == null:
		return

	var firebase_party: Array = save_data.firebase_party_data

	if firebase_party.is_empty():
		return

	for saved_atom in firebase_party:

		if not saved_atom is Dictionary:
			continue

		var saved_instance_id := str(
			saved_atom.get(
				"instance_id",
				""
			)
		).strip_edges()

		if saved_instance_id.is_empty():
			continue

		var found_atomon: AtomonInstance = null

		for atomon in PartyManager.party:

			if atomon == null:
				continue

			if atomon.instance_id != saved_instance_id:
				continue

			found_atomon = atomon
			break

		if found_atomon == null:
			continue

		found_atomon.apply_save_dict(saved_atom)

	if PartyManager.party.size() > 0:

		PartyManager.active_index = clampi(
			save_data.active_index,
			0,
			PartyManager.party.size() - 1
		)


# ============================================================
# RESTORE CARRIED PARTY
# ============================================================

func _restore_carried_party() -> void:

	if saved_carried_party_ids.is_empty():
		print("[SaveManager] No saved carried party to restore.")
		return

	var restored_carried_party: Array[AtomonInstance] = []

	for saved_id in saved_carried_party_ids:

		var found_atomon: AtomonInstance = null

		for atomon in PartyManager.party:

			if atomon == null:
				continue

			if atomon.instance_id != saved_id:
				continue

			found_atomon = atomon
			break

		if found_atomon == null:
			continue

		restored_carried_party.append(
			found_atomon
		)

	if restored_carried_party.is_empty():
		print("[SaveManager] WARNING: Could not restore carried party.")
		return

	PartyManager.set_carried_party(
		restored_carried_party
	)

	print(
		"[SaveManager] Carried party successfully restored: ",
		restored_carried_party.size()
	)


# ============================================================
# APPLY SAVED INVENTORY STATE
# ============================================================

func apply_saved_inventory_state() -> void:

	if save_data == null:
		return

	var saved_inventory: Array = save_data.firebase_inventory_data

	InventoryManager.inventory.clear()

	for saved_item in saved_inventory:

		if not saved_item is Dictionary:
			continue

		var item_id := str(
			saved_item.get("item_id", "")
		)

		if item_id.is_empty():
			continue

		var item_data: ItemData = ItemDatabase.get_item(item_id)

		if item_data == null:
			push_warning(
				"[SaveManager] Unknown inventory item: " + item_id
			)
			continue

		var item_instance := ItemInstance.new()
		item_instance.data = item_data
		item_instance.apply_save_dict(saved_item)

		InventoryManager.add_item(item_instance)



# ============================================================
# APPLY SAVED QUEST STATE
# ============================================================

func apply_saved_quest_state() -> void:

	if save_data == null:
		return

	QuestManager.active_quests.clear()
	QuestManager.completed_quests.clear()
	QuestManager.tracked_quest = null

	for quest_id in save_data.quest_data:

		var saved_entry: Variant = save_data.quest_data[quest_id]

		if not saved_entry is Dictionary:
			continue

		var quest_status := str(
			saved_entry.get("quest_status", "")
		)

		var saved_quest_data: Variant = saved_entry.get("data", {})

		if not saved_quest_data is Dictionary:
			continue

		if not QuestManager.quest_database.has(quest_id):
			continue

		var quest: Quest = (
			QuestManager.quest_database[quest_id].duplicate(true)
		)

		quest.apply_save_dict(saved_quest_data)

		if quest_status == "active":
			QuestManager.active_quests[quest_id] = quest

		elif quest_status == "completed":
			QuestManager.completed_quests[quest_id] = quest

	if not QuestManager.active_quests.is_empty():

		var first_quest: Quest = (
			QuestManager.active_quests.values()[0]
		)

		QuestManager.set_tracked_quest(first_quest)

	QuestManager.quest_list_updated.emit()


# ============================================================
# COLLECT GAME DATA
# ============================================================

func collect_game_data() -> void:

	if save_data == null:
		save_data = SaveData.new()

	if global.player != null:

		save_data.current_scene = (
			get_tree().current_scene.scene_file_path
		)

		save_data.player_position = (
			global.player.global_position
		)

	save_data.coins = CurrencyManager.coins

	save_data.party = (
		PartyManager.party.duplicate(true)
	)

	save_data.active_index = (
		PartyManager.active_index
	)

	save_data.inventory = (
		InventoryManager.inventory.duplicate(true)
	)


# ============================================================
# APPLY GAME DATA
# ============================================================

func apply_game_data() -> void:

	if save_data == null:
		return

	PartyManager.party = save_data.party

	PartyManager.active_index = (
		save_data.active_index
	)

	CurrencyManager.set_coins(
		save_data.coins
	)

	InventoryManager.inventory.clear()

	for item in save_data.inventory:

		if item == null:
			continue

		InventoryManager.add_item(
			item.duplicate(true)
	)

func mark_chest_opened(chest_id: String) -> void:
	if not opened_chests.has(chest_id):
		opened_chests.append(chest_id)
		print("[SaveManager] Chest marked opened: ", chest_id)

func is_chest_opened(chest_id: String) -> bool:
	return opened_chests.has(chest_id)




func _apply_local_save_data(data: Dictionary) -> void:

	save_data = SaveData.new()

	save_data.player_name = data.get("player_name", "Player")
	save_data.coins = int(data.get("coins", 0))
	save_data.current_scene = data.get("current_scene", "")

	# ========================================================
	# PLAYER POSITION
	# ========================================================

	var position_data: Variant = data.get(
		"player_position",
		{}
	)

	if not position_data is Dictionary:
		position_data = {}

	save_data.player_position = Vector2(
		float(position_data.get("x", 0.0)),
		float(position_data.get("y", 0.0))
	)

	# ========================================================
	# PARTY
	# ========================================================

	save_data.firebase_party_data = data.get("party", [])

	saved_carried_party_ids.clear()

	var saved_carried_data: Variant = data.get("carried_party", [])

	if saved_carried_data is Array:
		for instance_id in saved_carried_data:
			saved_carried_party_ids.append(str(instance_id))

	save_data.active_index = int(
		data.get("active_index", 0)
	)

	# ========================================================
	# INVENTORY
	# ========================================================

	save_data.firebase_inventory_data = data.get(
		"inventory",
		[]
	)

	# ========================================================
	# QUESTS
	# ========================================================

	save_data.quest_data = data.get(
		"quest_data",
		{}
	)

	# ========================================================
	# WORLD DATA
	# ========================================================

	var saved_switches: Variant = data.get("switches", {})
	if saved_switches is Dictionary:
		save_data.switches = saved_switches.duplicate(true)

	var saved_variables: Variant = data.get("variables", {})
	if saved_variables is Dictionary:
		save_data.variables = saved_variables.duplicate(true)

	save_data.play_time = int(data.get("play_time", 0))

	var saved_badges: Variant = data.get("badges", [])

	save_data.badges.clear()

	if saved_badges is Array:
		for badge in saved_badges:
			save_data.badges.append(str(badge))

	# ========================================================
	# WORLD PROGRESS
	# ========================================================

	var saved_cutscenes: Variant = data.get(
		"completed_cutscenes",
		{}
	)

	if saved_cutscenes is Dictionary:
		completed_cutscenes = saved_cutscenes.duplicate(true)
	else:
		completed_cutscenes = {}

	var saved_chests: Variant = data.get(
		"opened_chests",
		[]
	)

	opened_chests.clear()

	if saved_chests is Array:
		for chest_id in saved_chests:
			opened_chests.append(str(chest_id))

	# ========================================================
	# COLLECTED ELEMENTS
	# ========================================================

	var progress: Variant = data.get("progress", {})

	if not progress is Dictionary:
		progress = {}

	StudentDataManager.student_data["progress"] = (
		progress.duplicate(true)
	)

	StudentDataManager.collected_elements.clear()

	var saved_elements: Variant = progress.get(
		"collected_elements",
		[]
	)

	if saved_elements is Array:
		for symbol in saved_elements:

			var clean_symbol := str(symbol).strip_edges()

			if not clean_symbol.is_empty() and not StudentDataManager.collected_elements.has(clean_symbol):
				StudentDataManager.collected_elements.append(clean_symbol)

	StudentDataManager.progress_is_loaded = true

	# ========================================================
	# BATTLE STATISTICS
	# ========================================================

	var battle_stats: Variant = data.get("battle_stats", {})

	if battle_stats is Dictionary:
		StudentDataManager.student_data["battle_stats"] = (
			battle_stats.duplicate(true)
		)




func sync_local_save_to_firebase(uid: String) -> bool:

	if uid.is_empty():
		return false

	var local_record := OfflineSaveManager.load_local_record(uid)

	if local_record.is_empty():
		return false

	if not bool(local_record.get("pending_sync", false)):
		return true

	var game_data: Variant = local_record.get("game_data", {})

	if not game_data is Dictionary:
		push_error("[SaveManager] Local game data is invalid.")
		return false

	# Keep a snapshot of exactly what is being uploaded.
	var uploaded_game_data: Dictionary = game_data.duplicate(true)

	# --------------------------------------------------------
	# CHECK WHETHER THIS IS A NEW-GAME RESET
	# --------------------------------------------------------

	var has_save := bool(game_data.get("has_save", true))
	var saved_scene := str(game_data.get("current_scene", ""))

	# A normal save must have a scene.
	# A new-game reset is allowed to have no scene.
	if has_save and saved_scene.is_empty():
		return false

	# --------------------------------------------------------
	# CONNECT TO FIREBASE
	# --------------------------------------------------------

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		return false

	# --------------------------------------------------------
	# BUILD GAME STATE
	# --------------------------------------------------------

	var position_data: Variant = game_data.get(
		"player_position",
		{}
	)

	if not position_data is Dictionary:
		position_data = {}

	var game_state: Dictionary = {
		"has_save": has_save,
		"current_scene": saved_scene,
		"player_position": {
			"x": float(position_data.get("x", 0.0)),
			"y": float(position_data.get("y", 0.0))
		},
		"coins": int(game_data.get("coins", 0)),
		"active_index": int(game_data.get("active_index", 0)),
		"party": game_data.get("party", []),
		"carried_party": game_data.get("carried_party", []),
		"inventory": game_data.get("inventory", []),
		"quest_data": game_data.get("quest_data", {}),
		"switches": game_data.get("switches", {}),
		"variables": game_data.get("variables", {}),
		"play_time": int(game_data.get("play_time", 0)),
		"badges": game_data.get("badges", []),
		"completed_cutscenes": game_data.get("completed_cutscenes", {}),
		"opened_chests": game_data.get("opened_chests", [])
	}

	# --------------------------------------------------------
	# BUILD PROGRESS
	# --------------------------------------------------------

	var progress: Variant = game_data.get("progress", {})

	if not progress is Dictionary:
		progress = {}

	# --------------------------------------------------------
	# UPDATE FIRESTORE
	# --------------------------------------------------------

	document.add_or_update_field(
		"game_state",
		game_state
	)

	document.add_or_update_field(
		"progress",
		progress
	)

	# ========================================================
	# ACCOUNT-LEVEL BATTLE STATISTICS
	# ========================================================

	var battle_stats: Dictionary = (
		OfflineSaveManager.load_account_stats(uid)
	)

	# Migrate statistics from older local saves if necessary.
	if battle_stats.is_empty():

		var old_stats: Variant = game_data.get("battle_stats", {})

		if old_stats is Dictionary and not old_stats.is_empty():

			battle_stats = old_stats.duplicate(true)

			OfflineSaveManager.save_account_stats(
				uid,
				battle_stats
			)

	if not battle_stats.is_empty():

		StudentDataManager.student_data["battle_stats"] = (
			battle_stats.duplicate(true)
		)

		document.add_or_update_field(
			"battle_stats",
			battle_stats
		)

	# --------------------------------------------------------
	# SAVE TO FIRESTORE
	# --------------------------------------------------------

	var result: FirestoreDocument = await students.update(document)

	if result == null:
		return false

	# --------------------------------------------------------
	# CONFIRM SYNCHRONIZATION
	# --------------------------------------------------------

	var latest_record := OfflineSaveManager.load_local_record(uid)

	if latest_record.is_empty():
		return false

	var latest_game_data: Variant = latest_record.get("game_data", {})

	if not latest_game_data is Dictionary:
		return false

	# Do not mark a newer local save as synchronized.
	if latest_game_data != uploaded_game_data:
		return false

	if not OfflineSaveManager.set_pending_sync(uid, false):
		return false

	StudentDataManager.student_data["progress"] = progress

	StudentDataManager.progress_updated.emit(progress)

	await update_leaderboard_data()

	print("[SaveManager] Local game state synchronized.")

	return true

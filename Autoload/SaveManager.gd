
extends Node

var save_data: SaveData = null
var completed_cutscenes: Dictionary = {}
var saved_carried_party_ids: Array[String] = []

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

	print("[SaveManager] Battle auto-save started. Outcome: ", battle_outcome)

	if not StudentDataManager.is_student_logged_in():
		print("[SaveManager] Battle auto-save cancelled: student not logged in.")
		return false

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] Battle auto-save cancelled: UID is empty.")
		return false

	if has_node("/root/BattleControllerGlobal"):

		if BattleControllerGlobal.has_method("save_player_hp"):
			BattleControllerGlobal.save_player_hp()

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		print("[SaveManager] Battle auto-save failed: student document not found.")
		return false

	var existing_data: Dictionary = document.get_unsafe_document()

	# --------------------------------------------------------
	# BATTLE STATISTICS
	# --------------------------------------------------------

	var battle_stats: Dictionary = existing_data.get(
		"battle_stats",
		{
			"battles_played": 0,
			"battles_won": 0,
			"battles_lost": 0,
			"battles_escaped": 0
		}
	)

	if not battle_stats is Dictionary:
		battle_stats = {}

	battle_stats["battles_played"] = int(
		battle_stats.get("battles_played", 0)
	)

	battle_stats["battles_won"] = int(
		battle_stats.get("battles_won", 0)
	)

	battle_stats["battles_lost"] = int(
		battle_stats.get("battles_lost", 0)
	)

	battle_stats["battles_escaped"] = int(
		battle_stats.get("battles_escaped", 0)
	)

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

	if not battle_outcome.is_empty():

		document.add_or_update_field(
			"battle_stats",
			battle_stats
		)

		StudentDataManager.student_data["battle_stats"] = (
			battle_stats.duplicate(true)
		)

	# --------------------------------------------------------
	# EXISTING GAME STATE
	# --------------------------------------------------------

	var existing_game_state: Dictionary = existing_data.get(
		"game_state",
		{}
	)

	if not existing_game_state is Dictionary:
		existing_game_state = {}

	# --------------------------------------------------------
	# PARTY
	# --------------------------------------------------------

	var firebase_party: Array = []

	for atomon in PartyManager.party:

		if atomon == null:
			continue

		if atomon.data == null:
			continue

		var atomon_dict: Dictionary = atomon.to_save_dict()

		if atomon_dict.is_empty():
			continue

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

		carried_party_ids.append(
			carried_atomon.instance_id
		)

	# --------------------------------------------------------
	# INVENTORY
	# --------------------------------------------------------

	var firebase_inventory: Array = []

	for item in InventoryManager.inventory:

		if item == null:
			continue

		var item_dict: Dictionary = item.to_save_dict()

		if item_dict.is_empty():
			continue

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
		"elements_total":
			StudentDataManager.TOTAL_ELEMENTS,

		"elements_collected":
			collected_elements.size(),

		"collected_elements":
			collected_elements.duplicate()
	}

	# --------------------------------------------------------
	# PRESERVE MAP INFORMATION
	# --------------------------------------------------------

	var saved_scene := str(
		existing_game_state.get(
			"current_scene",
			"res://Scenes/Areas/start_map.tscn"
		)
	)

	var saved_position = existing_game_state.get(
		"player_position",
		{
			"x": 0.0,
			"y": 0.0
		}
	)

	# --------------------------------------------------------
	# BUILD GAME STATE
	# --------------------------------------------------------

	var game_state: Dictionary = existing_game_state.duplicate(true)

	game_state["has_save"] = true
	game_state["current_scene"] = saved_scene
	game_state["player_position"] = saved_position
	game_state["coins"] = current_coins
	game_state["active_index"] = PartyManager.active_index
	game_state["party"] = firebase_party
	game_state["carried_party"] = carried_party_ids
	game_state["inventory"] = firebase_inventory
	game_state["quest_data"] = quest_data

	document.add_or_update_field(
		"game_state",
		game_state
	)

	document.add_or_update_field(
		"progress",
		progress
	)

	var result: FirestoreDocument = await students.update(document)

	if result == null:
		print("[SaveManager] Battle auto-save failed: Firebase update returned null.")
		return false

	StudentDataManager.student_data["progress"] = progress

	StudentDataManager.progress_updated.emit(progress)

	print("[SaveManager] Battle auto-save successful.")

	# Update the public leaderboard after the battle save.
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
		print("[SaveManager] Quest save cancelled: student not logged in.")
		return false

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] Quest save cancelled: UID is empty.")
		return false

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		print("[SaveManager] Quest save failed: student document not found.")
		return false

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

	var existing_data: Dictionary = document.get_unsafe_document()

	var existing_game_state: Dictionary = existing_data.get(
		"game_state",
		{}
	)

	if not existing_game_state is Dictionary:
		existing_game_state = {}

	existing_game_state["quest_data"] = quest_data

	document.add_or_update_field(
		"game_state",
		existing_game_state
	)

	var result: FirestoreDocument = await students.update(document)

	if result == null:
		print("[SaveManager] Quest save failed: Firebase update returned null.")
		return false

	print("[SaveManager] Quest data saved successfully.")

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
		print("[SaveManager] Currency save cancelled: student not logged in.")
		return false

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] Currency save cancelled: UID is empty.")
		return false

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		print("[SaveManager] Currency save failed: student document not found.")
		return false

	var existing_data: Dictionary = document.get_unsafe_document()

	var existing_game_state: Dictionary = existing_data.get(
		"game_state",
		{}
	)

	if not existing_game_state is Dictionary:
		existing_game_state = {}

	existing_game_state["coins"] = CurrencyManager.coins

	document.add_or_update_field(
		"game_state",
		existing_game_state
	)

	var result: FirestoreDocument = await students.update(document)

	if result == null:
		print("[SaveManager] Currency save failed: Firebase update returned null.")
		return false

	print("[SaveManager] Currency saved successfully. Coins: ", CurrencyManager.coins)

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

	await upload_to_firebase()

	print("[SaveManager] Full game save finished.")


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

	print("[SaveManager] ========================================")
	print("[SaveManager] Starting game restore...")
	print("[SaveManager] ========================================")

	if not StudentDataManager.is_student_logged_in():
		print("[SaveManager] Load cancelled: student is not logged in.")
		return

	print("[SaveManager] Student is logged in.")
	print("[SaveManager] Downloading save data from Firebase...")

	var success := await download_from_firebase()

	if not success:
		print("[SaveManager] Game restore stopped: no valid save data.")
		return

	print("[SaveManager] Firebase save data downloaded successfully.")

	if save_data == null:
		print("[SaveManager] Game restore stopped: save_data is null.")
		return

	# ========================================================
	# COINS
	# ========================================================

	CurrencyManager.set_coins(save_data.coins)

	print("[SaveManager] Coins restored: ", save_data.coins)

	# ========================================================
	# CLEAR CURRENT PARTY
	# ========================================================

	PartyManager.party.clear()
	PartyManager.carried_party.clear()
	PartyManager.active_index = 0

	print("[SaveManager] Cleared current party before restore.")

	# ========================================================
	# CHANGE TO SAVED SCENE
	# ========================================================

	if save_data.current_scene.is_empty():
		print("[SaveManager] Game restore stopped: saved scene is empty.")
		return

	print("[SaveManager] Saved scene: ", save_data.current_scene)
	print("[SaveManager] Changing to saved scene...")

	var scene_result := await get_tree().change_scene_to_file(
		save_data.current_scene
	)

	if scene_result != OK:
		print("[SaveManager] ERROR: Failed to change to saved scene.")
		return

	await get_tree().process_frame
	await get_tree().process_frame

	print("[SaveManager] Saved scene loaded successfully.")

	# ========================================================
	# RESTORE PLAYER POSITION
	# ========================================================

	if global.player != null:

		global.player.global_position = save_data.player_position

		print(
			"[SaveManager] Player position restored: ",
			save_data.player_position
		)

	else:

		print(
			"[SaveManager] WARNING: global.player is null after scene load."
		)

	# ========================================================
	# RESTORE COMPLETE ATOMON COLLECTION
	# ========================================================

	print(
		"[SaveManager] Restoring Atomon collection. Saved count: ",
		save_data.firebase_party_data.size()
	)

	_restore_saved_party()

	print(
		"[SaveManager] Atomon collection restored. Current count: ",
		PartyManager.party.size()
	)

	# ========================================================
	# RESTORE EXACT CARRIED PARTY
	# ========================================================

	print(
		"[SaveManager] Restoring carried party. Saved IDs: ",
		saved_carried_party_ids.size()
	)

	_restore_carried_party()

	print(
		"[SaveManager] Carried party restored. Current count: ",
		PartyManager.carried_party.size()
	)

	# ========================================================
	# RESTORE INVENTORY
	# ========================================================

	apply_saved_inventory_state()

	print(
		"[SaveManager] Inventory restored. Current count: ",
		InventoryManager.inventory.size()
	)

	# ========================================================
	# RESTORE QUESTS
	# ========================================================

	apply_saved_quest_state()

	print(
		"[SaveManager] Quest state restored. Active quests: ",
		QuestManager.active_quests.size(),
		" | Completed quests: ",
		QuestManager.completed_quests.size()
	)

	print("[SaveManager] ========================================")
	print("[SaveManager] GAME RESTORE COMPLETE")
	print("[SaveManager] ========================================")


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

		"completed_cutscenes":
			completed_cutscenes.duplicate(true)
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
		print("[SaveManager] Firebase download cancelled: student not logged in.")
		return false

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] Firebase download cancelled: UID is empty.")
		return false

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		print("[SaveManager] Firebase download failed: student document not found.")
		return false

	var student_data: Dictionary = document.get_unsafe_document()

	# ========================================================
	# PLAYER PROFILE
	# ========================================================

	if student_data.has("display_name"):
		PlayerManager.display_name = str(
			student_data["display_name"]
		)

	if student_data.has("character_id"):
		var character_id := str(
			student_data["character_id"]
		)

		if not character_id.is_empty():
			if PlayerManager.has_method("set_character_by_id"):
				PlayerManager.set_character_by_id(character_id)

	# ========================================================
	# GAME STATE
	# ========================================================

	var game_state: Dictionary = student_data.get(
		"game_state",
		{}
	)

	if not game_state is Dictionary:
		print("[SaveManager] No valid game_state found.")
		return false

	var has_save := bool(
		game_state.get(
			"has_save",
			false
		)
	)

	if not has_save:
		print("[SaveManager] Student does not have an existing save.")
		return false

	# ========================================================
	# CREATE SAVE DATA
	# ========================================================

	save_data = SaveData.new()

	save_data.current_scene = str(
		game_state.get(
			"current_scene",
			"res://Scenes/Areas/start_map.tscn"
		)
	)

	# ========================================================
	# PLAYER POSITION
	# ========================================================

	var saved_position = game_state.get(
		"player_position",
		{
			"x": 0.0,
			"y": 0.0
		}
	)

	if saved_position is Dictionary:

		save_data.player_position = Vector2(
			float(saved_position.get("x", 0.0)),
			float(saved_position.get("y", 0.0))
		)

	# ========================================================
	# COINS
	# ========================================================

	save_data.coins = int(
		game_state.get(
			"coins",
			0
		)
	)

	# ========================================================
	# ACTIVE ATOMON
	# ========================================================

	save_data.active_index = int(
		game_state.get(
			"active_index",
			0
		)
	)

	# ========================================================
	# PARTY
	# ========================================================

	save_data.firebase_party_data = game_state.get(
		"party",
		[]
	)

	if not save_data.firebase_party_data is Array:
		save_data.firebase_party_data = []

	# ========================================================
	# CARRIED PARTY
	# ========================================================

	saved_carried_party_ids.clear()

	var carried_party = game_state.get(
		"carried_party",
		[]
	)

	if carried_party is Array:

		for party_id in carried_party:

			var id_string := str(
				party_id
			).strip_edges()

			if not id_string.is_empty():
				saved_carried_party_ids.append(
					id_string
				)

	# ========================================================
	# INVENTORY
	# ========================================================

	save_data.firebase_inventory_data = game_state.get(
		"inventory",
		[]
	)

	if not save_data.firebase_inventory_data is Array:
		save_data.firebase_inventory_data = []

	# ========================================================
	# QUEST DATA
	# ========================================================

	save_data.quest_data = game_state.get(
		"quest_data",
		{}
	)

	if not save_data.quest_data is Dictionary:
		save_data.quest_data = {}

	# ========================================================
	# CUTSCENES
	# ========================================================

	completed_cutscenes = game_state.get(
		"completed_cutscenes",
		{}
	)

	if not completed_cutscenes is Dictionary:
		completed_cutscenes = {}

	# ========================================================
	# PROGRESS
	# ========================================================

	var progress: Dictionary = student_data.get(
		"progress",
		{}
	)

	if progress is Dictionary:

		StudentDataManager.student_data["progress"] = (
			progress.duplicate(true)
		)

		print(
			"[SaveManager] Progress restored. Elements collected: ",
			progress.get("elements_collected", 0),
			"/",
			progress.get(
				"elements_total",
				StudentDataManager.TOTAL_ELEMENTS
			)
		)

		StudentDataManager.student_data["progress"] = (
			progress.duplicate(true)
		)

	# ========================================================
	# DEBUG
	# ========================================================

	print("[SaveManager] Save data downloaded successfully.")
	print("[SaveManager] Saved scene: ", save_data.current_scene)
	print("[SaveManager] Saved position: ", save_data.player_position)
	print("[SaveManager] Saved coins: ", save_data.coins)
	print(
		"[SaveManager] Saved Atomon collection: ",
		save_data.firebase_party_data.size()
	)
	print(
		"[SaveManager] Saved carried party: ",
		saved_carried_party_ids.size()
	)
	print(
		"[SaveManager] Saved inventory: ",
		save_data.firebase_inventory_data.size()
	)
	print(
		"[SaveManager] Saved quests: ",
		save_data.quest_data.size()
	)

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

	var firebase_inventory: Array = (
		save_data.firebase_inventory_data
	)

	InventoryManager.inventory.clear()

	if firebase_inventory.is_empty():
		print("[SaveManager] No saved inventory to restore.")
		return

	for saved_item in firebase_inventory:

		if not saved_item is Dictionary:
			continue

		var item_id := str(
			saved_item.get(
				"item_id",
				""
			)
		)

		if item_id.is_empty():
			continue

		var item_data: ItemData = (
			ItemDatabase.get_item(item_id)
		)

		if item_data == null:
			continue

		var item_instance := ItemInstance.new()

		item_instance.data = item_data

		item_instance.apply_save_dict(
			saved_item
		)

		InventoryManager.add_item(
			item_instance
		)

	print(
		"[SaveManager] Inventory restore complete: ",
		InventoryManager.inventory.size(),
		" items."
	)


# ============================================================
# APPLY SAVED QUEST STATE
# ============================================================

func apply_saved_quest_state() -> void:

	if save_data == null:
		return

	if save_data.quest_data.is_empty():
		print("[SaveManager] No saved quest state to restore.")
		return

	QuestManager.active_quests.clear()
	QuestManager.completed_quests.clear()
	QuestManager.tracked_quest = null

	for quest_id in save_data.quest_data:

		var saved_entry = save_data.quest_data[quest_id]

		if not saved_entry is Dictionary:
			continue

		var quest_status := str(
			saved_entry.get(
				"quest_status",
				""
			)
		)

		var saved_quest_data = saved_entry.get(
			"data",
			{}
		)

		if not saved_quest_data is Dictionary:
			continue

		if not QuestManager.quest_database.has(quest_id):
			continue

		var quest: Quest = (
			QuestManager
			.quest_database[quest_id]
			.duplicate(true)
		)

		quest.apply_save_dict(
			saved_quest_data
		)

		if quest_status == "active":

			QuestManager.active_quests[quest_id] = quest

		elif quest_status == "completed":

			QuestManager.completed_quests[quest_id] = quest

	if not QuestManager.active_quests.is_empty():

		var first_quest: Quest = (
			QuestManager
			.active_quests
			.values()[0]
		)

		QuestManager.set_tracked_quest(
			first_quest
		)

	QuestManager.quest_list_updated.emit()

	print("[SaveManager] Quest restore complete.")


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

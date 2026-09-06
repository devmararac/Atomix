extends Node

var save_data: SaveData = null

# ============================================================
# AUTOMATIC SAVE STATE
# ============================================================

var auto_save_in_progress: bool = false
var auto_save_queued: bool = false

# ============================================================
# AUTOMATIC SAVE
# ============================================================

func auto_save(reason: String = "") -> void:

	print(
		"[SaveManager] AUTO-SAVE REQUESTED",
		" | Reason: ",
		reason
	)

	# If a save is already happening, remember that another
	# save was requested instead of starting multiple saves.
	if auto_save_in_progress:

		print(
			"[SaveManager] Auto-save already in progress."
		)

		print(
			"[SaveManager] Queuing another auto-save."
		)

		auto_save_queued = true

		return


	auto_save_in_progress = true

	print(
		"[SaveManager] Starting automatic save..."
	)

	await save_game()

	auto_save_in_progress = false

	print(
		"[SaveManager] Automatic save finished."
	)


	# If another important action happened while saving,
	# perform one more save using the latest game state.
	if auto_save_queued:

		print(
			"[SaveManager] Another save was requested during saving."
		)

		auto_save_queued = false

		await auto_save(
			"Queued auto-save"
		)

# ============================================================
# QUEST-ONLY AUTOMATIC SAVE
# ============================================================

func auto_save_quest_data(reason: String = "") -> void:

	print(
		"[SaveManager] QUEST-ONLY AUTO-SAVE REQUESTED",
		" | Reason: ",
		reason
	)

	# Wait for a normal full save to finish first.
	if auto_save_in_progress:

		print(
			"[SaveManager] Full auto-save is currently running."
		)

		print(
			"[SaveManager] Waiting before saving quest data..."
		)

		while auto_save_in_progress:
			await get_tree().process_frame

	print(
		"[SaveManager] Starting quest-only automatic save..."
	)

	var success := await _save_quest_data_only()

	if success:

		print(
			"[SaveManager] Quest-only automatic save completed."
		)

	else:

		print(
			"[SaveManager] Quest-only automatic save FAILED."
		)


# ============================================================
# SAVE QUEST DATA ONLY
# ============================================================

func _save_quest_data_only() -> bool:

	if not StudentDataManager.is_student_logged_in():

		print(
			"[SaveManager] Cannot save quest data. No student is logged in."
		)

		return false

	var uid: String = (
		StudentDataManager.get_student_uid()
	)

	if uid.is_empty():

		print(
			"[SaveManager] Cannot save quest data. UID is empty."
		)

		return false

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = (
		await students.get_doc(uid)
	)

	if document == null:

		print(
			"[SaveManager] Student document does not exist: ",
			uid
		)

		return false

	# --------------------------------------------------------
	# Build current quest data
	# --------------------------------------------------------

	var quest_data: Dictionary = {}

	for quest_id in QuestManager.active_quests:

		var quest: Quest = (
			QuestManager.active_quests[quest_id]
		)

		if quest == null:
			continue

		quest_data[quest_id] = {
			"quest_status": "active",
			"data": quest.to_save_dict()
		}


	for quest_id in QuestManager.completed_quests:

		var quest: Quest = (
			QuestManager.completed_quests[quest_id]
		)

		if quest == null:
			continue

		quest_data[quest_id] = {
			"quest_status": "completed",
			"data": quest.to_save_dict()
		}

	print(
		"[SaveManager] Quest data to save: ",
		quest_data
	)

	# --------------------------------------------------------
	# IMPORTANT:
	# Get the existing game_state first.
	#
	# We do NOT create a new game_state.
	# We do NOT change:
	#   has_save
	#   current_scene
	#   player_position
	#   coins
	#   party
	#   inventory
	# --------------------------------------------------------

	var existing_data: Dictionary = (
		document.get_unsafe_document()
	)

	var existing_game_state: Dictionary = (
		existing_data.get(
			"game_state",
			{}
		)
	)

	if not existing_game_state is Dictionary:

		existing_game_state = {}

	# Only replace quest_data.
	existing_game_state["quest_data"] = quest_data

	# --------------------------------------------------------
	# Upload only the updated game_state
	# --------------------------------------------------------

	document.add_or_update_field(
		"game_state",
		existing_game_state
	)

	print(
		"[SaveManager] Saving QUEST DATA ONLY..."
	)

	var result: FirestoreDocument = (
		await students.update(document)
	)

	if result == null:

		print(
			"[SaveManager] Failed to save quest data."
		)

		return false

	print(
		"[SaveManager] Quest data saved successfully."
	)

	return true

# ============================================================
# CURRENCY-ONLY AUTOMATIC SAVE
# ============================================================

func auto_save_currency(reason: String = "") -> void:

	print(
		"[SaveManager] CURRENCY-ONLY AUTO-SAVE REQUESTED",
		" | Reason: ",
		reason
	)

	# Wait for a normal full save to finish first.
	if auto_save_in_progress:

		print(
			"[SaveManager] Full auto-save is currently running."
		)

		print(
			"[SaveManager] Waiting before saving currency..."
		)

		while auto_save_in_progress:
			await get_tree().process_frame

	print(
		"[SaveManager] Starting currency-only automatic save..."
	)

	var success := await _save_currency_only()

	if success:

		print(
			"[SaveManager] Currency-only automatic save completed."
		)

	else:

		print(
			"[SaveManager] Currency-only automatic save FAILED."
		)


# ============================================================
# SAVE CURRENCY ONLY
# ============================================================

func _save_currency_only() -> bool:

	if not StudentDataManager.is_student_logged_in():

		print(
			"[SaveManager] Cannot save currency. No student is logged in."
		)

		return false

	var uid: String = (
		StudentDataManager.get_student_uid()
	)

	if uid.is_empty():

		print(
			"[SaveManager] Cannot save currency. UID is empty."
		)

		return false

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = (
		await students.get_doc(uid)
	)

	if document == null:

		print(
			"[SaveManager] Student document does not exist: ",
			uid
		)

		return false

	# --------------------------------------------------------
	# Get the existing game state.
	#
	# We only change the coins value.
	# Everything else remains untouched.
	# --------------------------------------------------------

	var existing_data: Dictionary = (
		document.get_unsafe_document()
	)

	var existing_game_state: Dictionary = (
		existing_data.get(
			"game_state",
			{}
		)
	)

	if not existing_game_state is Dictionary:

		existing_game_state = {}

	# --------------------------------------------------------
	# Update ONLY coins.
	# --------------------------------------------------------

	existing_game_state["coins"] = CurrencyManager.coins

	print(
		"[SaveManager] Currency to save: ",
		CurrencyManager.coins
	)

	# --------------------------------------------------------
	# Put the updated game_state back into the document.
	# --------------------------------------------------------

	document.add_or_update_field(
		"game_state",
		existing_game_state
	)

	print(
		"[SaveManager] Saving CURRENCY DATA ONLY..."
	)

	var result: FirestoreDocument = (
		await students.update(document)
	)

	if result == null:

		print(
			"[SaveManager] Failed to save currency."
		)

		return false

	print(
		"[SaveManager] Currency saved successfully."
	)

	return true


# ============================================================
# SAVE GAME
# ============================================================

func save_game() -> void:

	if not StudentDataManager.is_student_logged_in():
		print("[SaveManager] Cannot save. No student is logged in.")
		return

	if global.player == null:
		print("[SaveManager] Cannot save. Player does not exist.")
		return

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] Cannot save. Student UID is empty.")
		return

	print("[SaveManager] ========================================")
	print("[SaveManager] STARTING SAVE")
	print("[SaveManager] UID: ", uid)
	print("[SaveManager] ========================================")

	save_data = SaveData.new()


	# ========================================================
	# PLAYER
	# ========================================================

	save_data.player_name = "Player"
	save_data.coins = CurrencyManager.coins
	save_data.current_scene = get_tree().current_scene.scene_file_path
	save_data.player_position = global.player.global_position

	print("[SaveManager] Scene: ", save_data.current_scene)
	print("[SaveManager] Position: ", save_data.player_position)
	print("[SaveManager] Coins: ", save_data.coins)


	# ========================================================
	# PARTY
	# ========================================================

	save_data.party = PartyManager.party.duplicate(true)
	save_data.active_index = PartyManager.active_index

	print("[SaveManager] ===== SAVING PARTY =====")

	for atomon in PartyManager.party:

		if atomon == null:
			continue

		if atomon.data == null:
			continue

		print(
			"[SaveManager] ",
			atomon.data.chemical_symbol,
			" -> ",
			atomon.data.atom_name,
			" PP: ",
			atomon.current_pp
		)

	print(
		"[SaveManager] Party size: ",
		save_data.party.size()
	)


	# ========================================================
	# COLLECTED ELEMENTS
	#
	# IMPORTANT:
	# CraftingUI does NOT save to Firebase.
	#
	# We only synchronize the LOCAL collected-elements array
	# from the current party here.
	#
	# Firebase receives this only during save_game().
	# ========================================================

	_sync_collected_elements_from_party()

	print(
		"[SaveManager] Collected elements before Firebase save: ",
		StudentDataManager.get_collected_elements()
	)


	# ========================================================
	# INVENTORY
	# ========================================================

	save_data.inventory = InventoryManager.inventory.duplicate(true)

	print(
		"[SaveManager] Inventory size: ",
		save_data.inventory.size()
	)


	# ========================================================
	# QUESTS
	# ========================================================

	save_data.quest_data.clear()


	# --------------------------------------------------------
	# ACTIVE QUESTS
	# --------------------------------------------------------

	for quest_id in QuestManager.active_quests:

		var quest: Quest = QuestManager.active_quests[quest_id]

		if quest == null:
			continue

		save_data.quest_data[quest_id] = {
			"quest_status": "active",
			"data": quest.to_save_dict()
		}


	# --------------------------------------------------------
	# COMPLETED QUESTS
	# --------------------------------------------------------

	for quest_id in QuestManager.completed_quests:

		var quest: Quest = QuestManager.completed_quests[quest_id]

		if quest == null:
			continue

		save_data.quest_data[quest_id] = {
			"quest_status": "completed",
			"data": quest.to_save_dict()
		}


	print(
		"[SaveManager] Quest data: ",
		save_data.quest_data
	)


	# ========================================================
	# UPLOAD EVERYTHING
	# ========================================================

	var success := await upload_to_firebase()

	if success:

		print("[SaveManager] ========================================")
		print("[SaveManager] SAVE COMPLETED SUCCESSFULLY")
		print("[SaveManager] ========================================")

	else:

		print("[SaveManager] ========================================")
		print("[SaveManager] SAVE FAILED")
		print("[SaveManager] ========================================")


# ============================================================
# SYNC COLLECTED ELEMENTS FROM CURRENT PARTY
# ============================================================

func _sync_collected_elements_from_party() -> void:

	print(
		"[SaveManager] ===== SYNCING COLLECTED ELEMENTS FROM PARTY ====="
	)

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

		if (
			StudentDataManager.collected_elements.size()
			>= StudentDataManager.TOTAL_ELEMENTS
		):
			break

		StudentDataManager.collected_elements.append(symbol)

		print(
			"[SaveManager] Locally registered crafted element: ",
			symbol
		)

	print(
		"[SaveManager] Total collected elements: ",
		StudentDataManager.collected_elements.size()
	)


# ============================================================
# LOAD GAME
# ============================================================

func load_game() -> void:

	if not StudentDataManager.is_student_logged_in():
		print("[SaveManager] Cannot load. No student is logged in.")
		return

	print(
		"[SaveManager] Downloading student's saved game..."
	)

	var success := await download_from_firebase()

	if not success:

		print(
			"[SaveManager] No saved game found."
		)

		return

	if save_data == null:

		print(
			"[SaveManager] Save data is null."
		)

		return


	# ========================================================
	# COINS
	# ========================================================

	CurrencyManager.set_coins(
		save_data.coins
	)


	# ========================================================
	# CLEAR CURRENT PARTY BEFORE RESTORING SAVE
	# ========================================================

	PartyManager.party.clear()
	PartyManager.active_index = 0


	# ========================================================
	# INVENTORY
	# ========================================================

	InventoryManager.inventory.clear()

	print(
		"[SaveManager] Loading inventory..."
	)

	apply_saved_inventory_state()


	# ========================================================
	# CHANGE TO SAVED SCENE
	# ========================================================

	if save_data.current_scene.is_empty():

		print(
			"[SaveManager] Saved scene is empty."
		)

		return

	print(
		"[SaveManager] Loading scene: ",
		save_data.current_scene
	)

	@warning_ignore("redundant_await")
	await get_tree().change_scene_to_file(
		save_data.current_scene
	)

	await get_tree().process_frame
	await get_tree().process_frame


	# ========================================================
	# RESTORE PLAYER POSITION
	# ========================================================

	if global.player != null:

		global.player.global_position = (
			save_data.player_position
		)

		print(
			"[SaveManager] Player position restored: ",
			save_data.player_position
		)

	else:

		print(
			"[SaveManager] Player not found after scene load."
		)


	# ========================================================
	# RESTORE PARTY
	#
	# Party must be rebuilt from Firebase save data.
	# ========================================================

	_restore_saved_party()


	# ========================================================
	# RESTORE PARTY INSTANCE STATE
	# ========================================================

	apply_saved_party_state()


	# ========================================================
	# RESTORE INVENTORY INSTANCE STATE
	# ========================================================

	apply_saved_inventory_state()


	# ========================================================
	# RESTORE QUEST STATE
	# ========================================================

	apply_saved_quest_state()


	print(
		"[SaveManager] Game loading completed."
	)


# ============================================================
# RESTORE SAVED PARTY SPECIES
# ============================================================

func _restore_saved_party() -> void:

	if save_data == null:
		return

	var firebase_party: Array = (
		save_data.firebase_party_data
	)

	if firebase_party.is_empty():

		print(
			"[SaveManager] No saved party to restore."
		)

		return

	print(
		"[SaveManager] ===== RESTORING PARTY ====="
	)

	for saved_atom in firebase_party:

		if not saved_atom is Dictionary:
			continue

		var symbol := str(
			saved_atom.get(
				"chemical_symbol",
				""
			)
		).strip_edges()

		if symbol.is_empty():
			continue

		if not AtomonDatabase.ELEMENTS.has(symbol):

			print(
				"[SaveManager] Element not found in database: ",
				symbol
			)

			continue

		var element: AtomonData = (
			AtomonDatabase.ELEMENTS[symbol]
		)

		var atomon: AtomonInstance = (
			PartyManager.add_species(element)
		)

		if atomon == null:

			print(
				"[SaveManager] Failed to restore: ",
				symbol
			)

			continue

		print(
			"[SaveManager] Restored Atomon species: ",
			symbol
		)


	if PartyManager.party.size() > 0:

		PartyManager.active_index = clampi(
			save_data.active_index,
			0,
			PartyManager.party.size() - 1
		)


	print(
		"[SaveManager] Final restored party size: ",
		PartyManager.party.size()
	)


# ============================================================
# FIREBASE UPLOAD
# ============================================================

func upload_to_firebase() -> bool:

	if save_data == null:

		print(
			"[SaveManager] Cannot upload. Save data is null."
		)

		return false

	var uid: String = (
		StudentDataManager.get_student_uid()
	)

	if uid.is_empty():

		print(
			"[SaveManager] Cannot upload. UID is empty."
		)

		return false

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = (
		await students.get_doc(uid)
	)

	if document == null:

		print(
			"[SaveManager] Student document does not exist: ",
			uid
		)

		return false


	# ========================================================
	# SERIALIZE PARTY
	# ========================================================

	var firebase_party: Array = []

	for atomon in save_data.party:

		if atomon == null:
			continue

		var atomon_dict := (
			atomon.to_save_dict()
		)

		if atomon_dict.is_empty():
			continue

		firebase_party.append(
			atomon_dict
		)

	print(
		"[SaveManager] Firebase party size: ",
		firebase_party.size()
	)


	# ========================================================
	# SERIALIZE INVENTORY
	# ========================================================

	var firebase_inventory: Array = []

	for item in save_data.inventory:

		if item == null:
			continue

		var item_dict := (
			item.to_save_dict()
		)

		if item_dict.is_empty():
			continue

		firebase_inventory.append(
			item_dict
		)

	print(
		"[SaveManager] Firebase inventory size: ",
		firebase_inventory.size()
	)


	# ========================================================
	# PROGRESS
	# ========================================================

	var collected_elements: Array = (
		StudentDataManager.get_collected_elements()
	)

	var elements_collected: int = (
		collected_elements.size()
	)

	var progress: Dictionary = {

		"elements_total":
			StudentDataManager.TOTAL_ELEMENTS,

		"elements_collected":
			elements_collected,

		"collected_elements":
			collected_elements.duplicate()
	}

	print(
		"[SaveManager] Firebase progress: ",
		progress
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

		"inventory":
			firebase_inventory,

		"quest_data":
			save_data.quest_data
	}


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


	print(
		"[SaveManager] Uploading game state..."
	)

	print(
		"[SaveManager] UID: ",
		uid
	)

	print(
		"[SaveManager] Game state: ",
		game_state
	)

	print(
		"[SaveManager] Progress: ",
		progress
	)


	var result: FirestoreDocument = (
		await students.update(document)
	)

	if result == null:

		print(
			"[SaveManager] Failed to upload game state."
		)

		return false


	# ========================================================
	# UPDATE LOCAL STUDENT DATA
	# ========================================================

	StudentDataManager.student_data["progress"] = (
		progress
	)

	StudentDataManager.progress_updated.emit(
		progress
	)


	print(
		"[SaveManager] Game state uploaded successfully."
	)

	print(
		"[SaveManager] Progress uploaded successfully."
	)

	return true


# ============================================================
# FIREBASE DOWNLOAD
# ============================================================

func download_from_firebase() -> bool:

	var uid: String = (
		StudentDataManager.get_student_uid()
	)

	if uid.is_empty():

		print(
			"[SaveManager] Cannot download. UID is empty."
		)

		return false

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	var document: FirestoreDocument = (
		await students.get_doc(uid)
	)

	if document == null:

		print(
			"[SaveManager] Student document does not exist: ",
			uid
		)

		return false

	var data: Dictionary = (
		document.get_unsafe_document()
	)

	if not data.has("game_state"):

		print(
			"[SaveManager] No game_state found for student."
		)

		return false

	var game_state: Dictionary = (
		data["game_state"]
	)


	# ========================================================
	# CHECK SAVE
	# ========================================================

	var has_save: bool = bool(
		game_state.get(
			"has_save",
			false
		)
	)

	print(
		"[SaveManager] Has save: ",
		has_save
	)

	if not has_save:

		print(
			"[SaveManager] Student has no saved game yet."
		)

		return false


	# ========================================================
	# CREATE SAVE DATA
	# ========================================================

	save_data = SaveData.new()


	# ========================================================
	# PLAYER
	# ========================================================

	save_data.current_scene = str(
		game_state.get(
			"current_scene",
			"res://Scenes/Areas/start_map.tscn"
		)
	)


	var position_data: Dictionary = (
		game_state.get(
			"player_position",
			{
				"x": 0.0,
				"y": 0.0
			}
		)
	)


	save_data.player_position = Vector2(

		float(
			position_data.get(
				"x",
				0.0
			)
		),

		float(
			position_data.get(
				"y",
				0.0
			)
		)
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
	# ACTIVE INDEX
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

	var firebase_party = (
		game_state.get(
			"party",
			[]
		)
	)

	if firebase_party is Array:

		print(
			"[SaveManager] Firebase party entries: ",
			firebase_party.size()
		)

		save_data.firebase_party_data = (
			firebase_party.duplicate(true)
		)


	# ========================================================
	# INVENTORY
	# ========================================================

	var firebase_inventory = (
		game_state.get(
			"inventory",
			[]
		)
	)

	if firebase_inventory is Array:

		print(
			"[SaveManager] Firebase inventory entries: ",
			firebase_inventory.size()
		)

		save_data.firebase_inventory_data = (
			firebase_inventory.duplicate(true)
		)


	# ========================================================
	# PROGRESS
	# ========================================================

	var firebase_progress = (
		data.get(
			"progress",
			{}
		)
	)

	if firebase_progress is Dictionary:

		var saved_elements = (
			firebase_progress.get(
				"collected_elements",
				[]
			)
		)

		StudentDataManager.collected_elements.clear()

		if saved_elements is Array:

			for symbol in saved_elements:

				var clean_symbol := (
					str(symbol).strip_edges()
				)

				if clean_symbol.is_empty():
					continue

				if not StudentDataManager.collected_elements.has(
					clean_symbol
				):

					StudentDataManager.collected_elements.append(
						clean_symbol
					)


		firebase_progress["elements_collected"] = (
			StudentDataManager.collected_elements.size()
		)

		StudentDataManager.student_data["progress"] = (
			firebase_progress
		)

		print(
			"[SaveManager] Collected elements loaded: ",
			StudentDataManager.collected_elements
		)

	else:

		print(
			"[SaveManager] No valid progress data found."
		)


	# ========================================================
	# QUESTS
	# ========================================================

	var firebase_quest_data = (
		game_state.get(
			"quest_data",
			{}
		)
	)

	if firebase_quest_data is Dictionary:

		print(
			"[SaveManager] Firebase quest entries: ",
			firebase_quest_data.size()
		)

		save_data.quest_data = (
			firebase_quest_data.duplicate(true)
		)

	else:

		print(
			"[SaveManager] Firebase quest data is invalid."
		)


	print(
		"[SaveManager] Game state downloaded."
	)

	print(
		"[SaveManager] Scene: ",
		save_data.current_scene
	)

	print(
		"[SaveManager] Position: ",
		save_data.player_position
	)

	print(
		"[SaveManager] Coins: ",
		save_data.coins
	)

	print(
		"[SaveManager] Active index: ",
		save_data.active_index
	)

	print(
		"[SaveManager] Party entries: ",
		firebase_party.size()
	)

	return true


# ============================================================
# APPLY SAVED PARTY STATE
# ============================================================

func apply_saved_party_state() -> void:

	if save_data == null:
		return

	var firebase_party: Array = (
		save_data.firebase_party_data
	)

	if firebase_party.is_empty():

		print(
			"[SaveManager] No saved party state to apply."
		)

		return

	print(
		"[SaveManager] Applying saved party state..."
	)


	for saved_atom in firebase_party:

		if not saved_atom is Dictionary:
			continue

		var symbol := str(
			saved_atom.get(
				"chemical_symbol",
				""
			)
		)

		if symbol.is_empty():
			continue


		for atomon in PartyManager.party:

			if atomon == null:
				continue

			if atomon.data == null:
				continue

			if atomon.data.chemical_symbol != symbol:
				continue


			atomon.apply_save_dict(
				saved_atom
			)

			print(
				"[SaveManager] Restored state: ",
				symbol,
				" -> ",
				atomon.data.atom_name,
				" PP: ",
				atomon.current_pp
			)

			break


	if PartyManager.party.size() > 0:

		PartyManager.active_index = clampi(
			save_data.active_index,
			0,
			PartyManager.party.size() - 1
		)

	print(
		"[SaveManager] Saved party state applied."
	)


# ============================================================
# APPLY SAVED INVENTORY STATE
# ============================================================

func apply_saved_inventory_state() -> void:

	if save_data == null:

		print(
			"[SaveManager] ERROR: save_data is null"
		)

		return

	var firebase_inventory: Array = (
		save_data.firebase_inventory_data
	)

	print(
		"[SaveManager] ===== APPLYING INVENTORY ====="
	)

	print(
		"[SaveManager] Firebase inventory count: ",
		firebase_inventory.size()
	)

	InventoryManager.inventory.clear()

	if firebase_inventory.is_empty():

		print(
			"[SaveManager] No saved inventory."
		)

		return


	for saved_item in firebase_inventory:

		if not saved_item is Dictionary:

			print(
				"[SaveManager] ERROR: saved item is not Dictionary"
			)

			continue


		var item_id := str(
			saved_item.get(
				"item_id",
				""
			)
		)

		if item_id.is_empty():

			print(
				"[SaveManager] ERROR: Item ID is empty"
			)

			continue


		var item_data: ItemData = (
			ItemDatabase.get_item(item_id)
		)

		if item_data == null:

			print(
				"[SaveManager] ItemDatabase cannot find: ",
				item_id
			)

			continue


		var item_instance := (
			ItemInstance.new()
		)

		item_instance.data = item_data

		item_instance.apply_save_dict(
			saved_item
		)

		InventoryManager.add_item(
			item_instance
		)

		print(
			"[SaveManager] RESTORED: ",
			item_id,
			" x",
			item_instance.quantity
		)


	print(
		"[SaveManager] FINAL INVENTORY COUNT: ",
		InventoryManager.inventory.size()
	)


# ============================================================
# APPLY SAVED QUEST STATE
# ============================================================

func apply_saved_quest_state() -> void:

	if save_data == null:

		print(
			"[SaveManager] ERROR: save_data is null"
		)

		return

	if save_data.quest_data.is_empty():

		print(
			"[SaveManager] No saved quest data."
		)

		return

	print(
		"[SaveManager] ===== APPLYING QUEST STATE ====="
	)

	QuestManager.active_quests.clear()
	QuestManager.completed_quests.clear()
	QuestManager.tracked_quest = null


	for quest_id in save_data.quest_data:

		var saved_entry = (
			save_data.quest_data[quest_id]
		)

		if not saved_entry is Dictionary:
			continue


		var quest_status := str(
			saved_entry.get(
				"quest_status",
				""
			)
		)


		var saved_quest_data = (
			saved_entry.get(
				"data",
				{}
			)
		)

		if not saved_quest_data is Dictionary:
			continue


		if not QuestManager.quest_database.has(
			quest_id
		):

			print(
				"[SaveManager] Quest not found in database: ",
				quest_id
			)

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

			QuestManager.active_quests[
				quest_id
			] = quest

			print(
				"[SaveManager] RESTORED ACTIVE QUEST: ",
				quest_id
			)


		elif quest_status == "completed":

			QuestManager.completed_quests[
				quest_id
			] = quest

			print(
				"[SaveManager] RESTORED COMPLETED QUEST: ",
				quest_id
			)


	if not QuestManager.active_quests.is_empty():

		var first_quest: Quest = (
			QuestManager
			.active_quests
			.values()[0]
		)

		QuestManager.set_tracked_quest(
			first_quest
		)


	print(
		"[SaveManager] Active quests restored: ",
		QuestManager.active_quests.size()
	)

	print(
		"[SaveManager] Completed quests restored: ",
		QuestManager.completed_quests.size()
	)

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

	save_data.coins = (
		CurrencyManager.coins
	)

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

	PartyManager.party = (
		save_data.party
	)

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

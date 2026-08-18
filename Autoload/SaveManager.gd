extends Node


var save_data: SaveData = null


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

	var uid := StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] Cannot save. Student UID is empty.")
		return


	save_data = SaveData.new()


	# --------------------------------------------------------
	# PLAYER
	# --------------------------------------------------------

	save_data.player_name = "Player"
	save_data.coins = CurrencyManager.coins

	save_data.current_scene = (
		get_tree().current_scene.scene_file_path
	)

	save_data.player_position = (
		global.player.global_position
	)


	# --------------------------------------------------------
	# PARTY
	# --------------------------------------------------------

	save_data.party = PartyManager.party.duplicate(true)
	save_data.active_index = PartyManager.active_index

	print("===== SAVING PARTY =====")

	for atomon in PartyManager.party:

		if atomon != null and atomon.data != null:

			print(
				"[SaveManager] ",
				atomon.data.chemical_symbol,
				" -> ",
				atomon.data.atom_name,
				" PP: ",
				atomon.current_pp
			)


	# --------------------------------------------------------
	# INVENTORY
	# --------------------------------------------------------

	save_data.inventory = (
		InventoryManager.inventory.duplicate(true)
	)


	print("[SaveManager] Scene: ", save_data.current_scene)
	print("[SaveManager] Position: ", save_data.player_position)
	print("[SaveManager] Coins: ", save_data.coins)
	print("[SaveManager] Party size: ", save_data.party.size())
	print("[SaveManager] Inventory size: ", save_data.inventory.size())


	# --------------------------------------------------------
	# UPLOAD
	# --------------------------------------------------------

	await upload_to_firebase()


# ============================================================
# LOAD GAME
# ============================================================

func load_game() -> void:

	if not StudentDataManager.is_student_logged_in():
		print("[SaveManager] Cannot load. No student is logged in.")
		return


	print("[SaveManager] Downloading student's saved game...")

	var success := await download_from_firebase()

	if not success:
		print("[SaveManager] No saved game found.")
		return

	if save_data == null:
		print("[SaveManager] Save data is null.")
		return


	# --------------------------------------------------------
	# COINS
	# --------------------------------------------------------

	CurrencyManager.set_coins(
		save_data.coins
	)


	# --------------------------------------------------------
	# INVENTORY
	# --------------------------------------------------------

	InventoryManager.inventory.clear()

	for item in save_data.inventory:

		if item == null:
			continue

		InventoryManager.add_item(
			item.duplicate(true)
		)

	print(
		"[SaveManager] Inventory loaded: ",
		InventoryManager.inventory.size()
	)


	# --------------------------------------------------------
	# CHANGE TO SAVED SCENE
	# --------------------------------------------------------

	if save_data.current_scene.is_empty():
		print("[SaveManager] Saved scene is empty.")
		return


	print(
		"[SaveManager] Loading scene: ",
		save_data.current_scene
	)

	await get_tree().change_scene_to_file(
		save_data.current_scene
	)

	await get_tree().process_frame
	await get_tree().process_frame


	# --------------------------------------------------------
	# RESTORE PLAYER POSITION
	# --------------------------------------------------------

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


	# --------------------------------------------------------
	# RESTORE PARTY INSTANCE STATE
	# --------------------------------------------------------

	apply_saved_party_state()


# ============================================================
# FIREBASE UPLOAD
# ============================================================

func upload_to_firebase() -> bool:

	if save_data == null:
		print("[SaveManager] Cannot upload. Save data is null.")
		return false


	var uid := StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] Cannot upload. UID is empty.")
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
	# SERIALIZE PARTY
	# --------------------------------------------------------

	var firebase_party: Array = []

	for atomon in save_data.party:

		if atomon == null:
			continue

		var atomon_dict := atomon.to_save_dict()

		if atomon_dict.is_empty():
			continue

		firebase_party.append(
			atomon_dict
		)


	print(
		"[SaveManager] Firebase party size: ",
		firebase_party.size()
	)


	# --------------------------------------------------------
	# SERIALIZE INVENTORY
	# --------------------------------------------------------

	var firebase_inventory := {}

	# Keep this empty for now because ItemInstance
	# serialization has not been implemented yet.


	# --------------------------------------------------------
	# GAME STATE
	# --------------------------------------------------------

	var game_state := {

		"has_save": true,

		"current_scene":
			save_data.current_scene,

		"player_position": {
			"x": save_data.player_position.x,
			"y": save_data.player_position.y
		},

		"coins":
			save_data.coins,

		"active_index":
			save_data.active_index,

		"party":
			firebase_party,

		"inventory":
			firebase_inventory
	}


	document.add_or_update_field(
		"game_state",
		game_state
	)


	print("[SaveManager] Uploading game state...")
	print("[SaveManager] UID: ", uid)
	print("[SaveManager] Game state: ", game_state)


	var result: FirestoreDocument = (
		await students.update(document)
	)


	if result == null:

		print(
			"[SaveManager] Failed to upload game state."
		)

		return false


	print(
		"[SaveManager] Game state uploaded successfully."
	)

	return true


# ============================================================
# FIREBASE DOWNLOAD
# ============================================================

func download_from_firebase() -> bool:

	var uid := StudentDataManager.get_student_uid()

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


	# --------------------------------------------------------
	# CHECK SAVE
	# --------------------------------------------------------

	var has_save: bool = bool(
		game_state.get("has_save", false)
	)


	print(
		"[SaveManager] Has save: ",
		has_save
	)


	if not has_save:

		print(
			"[SaveManager] Student has no saved game yet."
		)

		print(
			"[SaveManager] Using scene's default starting position."
		)

		return false


	# --------------------------------------------------------
	# CREATE SAVE DATA
	# --------------------------------------------------------

	save_data = SaveData.new()


	# --------------------------------------------------------
	# PLAYER
	# --------------------------------------------------------

	save_data.current_scene = str(
		game_state.get(
			"current_scene",
			"res://Scenes/Areas/start_map.tscn"
		)
	)


	var position_data: Dictionary = (
		game_state.get(
			"player_position",
			{"x": 0.0, "y": 0.0}
		)
	)


	save_data.player_position = Vector2(
		float(position_data.get("x", 0.0)),
		float(position_data.get("y", 0.0))
	)


	# --------------------------------------------------------
	# COINS
	# --------------------------------------------------------

	save_data.coins = int(
		game_state.get("coins", 0)
	)


	# --------------------------------------------------------
	# ACTIVE INDEX
	# --------------------------------------------------------

	save_data.active_index = int(
		game_state.get("active_index", 0)
	)


	# --------------------------------------------------------
	# PARTY SAVE DATA
	#
	# We DON'T reconstruct the Atomons here.
	#
	# PartyManager already reconstructs them from
	# progress.collected_elements.
	#
	# We only keep the Firebase dictionaries temporarily.
	# --------------------------------------------------------

	var firebase_party = game_state.get(
		"party",
		[]
	)

	if firebase_party is Array:

		print(
			"[SaveManager] Firebase party entries: ",
			firebase_party.size()
		)

		# Store them temporarily.
		#
		# We use metadata on SaveData because the actual
		# AtomonData Resources should NOT come from Firebase.

		save_data.firebase_party_data = (
			firebase_party.duplicate(true)
		)


	# --------------------------------------------------------
	# INVENTORY
	# --------------------------------------------------------

	# Inventory serialization will be implemented later.

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

	if not "firebase_party_data" in save_data:
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


		# Find matching Atomon in current party.
		for atomon in PartyManager.party:

			if atomon == null:
				continue

			if atomon.data == null:
				continue


			if atomon.data.chemical_symbol != symbol:
				continue


			# ------------------------------------------------
			# RESTORE INSTANCE STATE
			# ------------------------------------------------

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


	# Restore active index AFTER party has been restored.

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

		if item != null:

			InventoryManager.add_item(
				item.duplicate(true)
			)

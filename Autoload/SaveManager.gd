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

	# Create save data
	save_data = SaveData.new()

	# --------------------------------------------------------
	# PLAYER
	# --------------------------------------------------------

	save_data.player_name = "Player"
	save_data.coins = CurrencyManager.coins

	save_data.current_scene = get_tree().current_scene.scene_file_path
	save_data.player_position = global.player.global_position

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
				atomon.data.atom_name,
				" PP: ",
				atomon.current_pp
			)

	# --------------------------------------------------------
	# INVENTORY
	# --------------------------------------------------------

	save_data.inventory = InventoryManager.inventory.duplicate(true)

	print("[SaveManager] Scene: ", save_data.current_scene)
	print("[SaveManager] Position: ", save_data.player_position)
	print("[SaveManager] Coins: ", save_data.coins)
	print("[SaveManager] Party size: ", save_data.party.size())
	print("[SaveManager] Inventory size: ", save_data.inventory.size())

	# --------------------------------------------------------
	# UPLOAD TO FIREBASE
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

	CurrencyManager.set_coins(save_data.coins)

	# --------------------------------------------------------
	# PARTY
	# --------------------------------------------------------

	# IMPORTANT:
	# PartyManager.load_saved_party() already restored the
	# student's Atomons from:
	#
	# StudentDataManager.progress.collected_elements
	#
	# Do NOT clear PartyManager.party here.
	#
	# game_state.party is currently only a placeholder in
	# Firestore and is not serialized yet.

	PartyManager.active_index = save_data.active_index

	print(
		"[SaveManager] Keeping restored party: ",
		PartyManager.party.size()
	)

	# --------------------------------------------------------
	# INVENTORY
	# --------------------------------------------------------

	# Inventory is also currently a placeholder in Firestore.
	# Only restore it if actual inventory data exists.
	if save_data.inventory != null:

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

		global.player.global_position = save_data.player_position

		print(
			"[SaveManager] Player position restored: ",
			save_data.player_position
		)

	else:
		print("[SaveManager] Player not found after scene load.")


# ============================================================
# UPLOAD TO FIREBASE
# ============================================================

func upload_to_firebase() -> bool:

	if save_data == null:
		print("[SaveManager] Cannot upload. Save data is null.")
		return false

	var uid := StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] Cannot upload. UID is empty.")
		return false

	var students: FirestoreCollection = Firebase.Firestore.collection(
		"students"
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		print(
			"[SaveManager] Student document does not exist: ",
			uid
		)
		return false

	# --------------------------------------------------------
	# FIRESTORE GAME STATE
	# --------------------------------------------------------

	var game_state := {
		"has_save": true,

		"current_scene": save_data.current_scene,

		"player_position": {
			"x": save_data.player_position.x,
			"y": save_data.player_position.y
		},

		"coins": save_data.coins,

		"active_index": save_data.active_index,

		# ----------------------------------------------------
		# TEMPORARY PLACEHOLDERS
		# ----------------------------------------------------
		# Do NOT put AtomonInstance objects directly into
		# Firestore yet.
		#
		# The student's actual collected Atomons are currently
		# stored in progress.collected_elements.
		"party": [],

		"inventory": {}
	}

	document.add_or_update_field(
		"game_state",
		game_state
	)

	print("[SaveManager] Uploading game state...")
	print("[SaveManager] UID: ", uid)
	print("[SaveManager] Game state: ", game_state)

	var result: FirestoreDocument = await students.update(
		document
	)

	if result == null:
		print("[SaveManager] Failed to upload game state.")
		return false

	print("[SaveManager] Game state uploaded successfully.")

	return true


# ============================================================
# DOWNLOAD FROM FIREBASE
# ============================================================

func download_from_firebase() -> bool:

	var uid := StudentDataManager.get_student_uid()

	if uid.is_empty():
		print("[SaveManager] Cannot download. UID is empty.")
		return false

	var students: FirestoreCollection = Firebase.Firestore.collection(
		"students"
	)

	var document: FirestoreDocument = await students.get_doc(uid)

	if document == null:
		print(
			"[SaveManager] Student document does not exist: ",
			uid
		)
		return false

	var data: Dictionary = document.get_unsafe_document()

	if not data.has("game_state"):
		print("[SaveManager] No game_state found for student.")
		return false

	var game_state: Dictionary = data["game_state"]

	# --------------------------------------------------------
	# CHECK IF A REAL SAVE EXISTS
	# --------------------------------------------------------

	var has_save: bool = bool(
		game_state.get("has_save", false)
	)

	print("[SaveManager] Has save: ", has_save)

	if not has_save:

		print(
			"[SaveManager] Student has no saved game yet."
		)

		print(
			"[SaveManager] Using scene's default starting position."
		)

		# IMPORTANT:
		# Do NOT create SaveData here.
		# Do NOT load (0, 0).
		#
		# The normal scene/player starting position will be used.

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

	var position_data: Dictionary = game_state.get(
		"player_position",
		{"x": 0.0, "y": 0.0}
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
	# ACTIVE PARTY INDEX
	# --------------------------------------------------------

	save_data.active_index = int(
		game_state.get("active_index", 0)
	)

	# --------------------------------------------------------
	# INVENTORY
	# --------------------------------------------------------

	# Inventory serialization is not implemented yet.
	# Start with an empty inventory until we serialize it.

	save_data.inventory = []

	# --------------------------------------------------------
	# PARTY
	# --------------------------------------------------------

	# Party serialization is not implemented yet.
	# The actual party is restored by:
	#
	# PartyManager.load_saved_party()
	#
	# from progress.collected_elements.

	save_data.party = []

	print("[SaveManager] Game state downloaded.")
	print("[SaveManager] Scene: ", save_data.current_scene)
	print("[SaveManager] Position: ", save_data.player_position)
	print("[SaveManager] Coins: ", save_data.coins)
	print("[SaveManager] Active index: ", save_data.active_index)

	return true


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

	save_data.active_index = PartyManager.active_index

	save_data.inventory = (
		InventoryManager.inventory.duplicate(true)
	)


# ============================================================
# APPLY GAME DATA
# ============================================================

func apply_game_data() -> void:

	if save_data == null:
		return

	# IMPORTANT:
	# Do not replace PartyManager.party here because the party
	# is currently restored through collected_elements.

	PartyManager.active_index = save_data.active_index

	CurrencyManager.set_coins(
		save_data.coins
	)

	InventoryManager.inventory.clear()

	for item in save_data.inventory:

		if item != null:

			InventoryManager.add_item(
				item.duplicate(true)
			)

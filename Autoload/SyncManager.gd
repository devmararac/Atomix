
extends Node

var is_syncing: bool = false


func _ready() -> void:

	ConnectionManager.connection_changed.connect(
		_on_connection_changed
	)

	# Check the current connection when the game starts.
	if ConnectionManager.is_connected_to_internet:
		await sync_pending_save()


func _on_connection_changed(is_connected: bool) -> void:

	if is_connected:
		await sync_pending_save()


func sync_pending_save() -> bool:

	if is_syncing:
		return false

	if not StudentDataManager.is_student_logged_in():
		return false

	if not ConnectionManager.is_connected_to_internet:
		return false

	# IMPORTANT:
	# An offline student session is not Firebase authentication.
	# Never attempt cloud synchronization without real Firebase authentication.
	if not FirebaseManager.is_authenticated():
		print("[SyncManager] Waiting for Firebase authentication.")
		print("[SyncManager] Local changes remain pending.")
		return false

	var uid: String = StudentDataManager.get_student_uid()

	if uid.is_empty():
		return false

	is_syncing = true

	# ========================================================
	# SYNC PENDING PLAYER PROFILE
	# ========================================================

	var profile_success: bool = await (
		StudentDataManager.sync_pending_player_profile()
	)

	if profile_success:
		print("[SyncManager] Player profile synchronization complete.")
	else:
		print("[SyncManager] Player profile synchronization failed.")

	# ========================================================
	# SYNC PENDING GAME SAVE
	# ========================================================

	var save_success: bool = true

	if OfflineSaveManager.has_pending_sync(uid):

		save_success = await SaveManager.sync_local_save_to_firebase(uid)

		if save_success:
			print("[SyncManager] Pending game save synchronized.")
		else:
			print("[SyncManager] Pending game save synchronization failed.")

	is_syncing = false

	return profile_success and save_success

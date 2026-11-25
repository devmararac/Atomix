extends Node

# =========================================================
# RESPAWN MANAGER
# Keeps collected items and defeated wild Atomons
# from respawning immediately when changing scenes.
# =========================================================

# Stores spawn ID -> respawn timestamp (milliseconds)
var respawn_data: Dictionary = {}


# ---------------------------------------------------------
# REGISTER A REMOVED OBJECT
# ---------------------------------------------------------
func register_respawn(spawn_id: String, cooldown: float) -> void:

	if spawn_id.is_empty():
		push_warning("[RespawnManager] Spawn ID is empty!")
		return

	var respawn_time := Time.get_ticks_msec() + int(cooldown * 1000.0)

	respawn_data[spawn_id] = respawn_time

	print(
		"[RespawnManager] Registered: ",
		spawn_id,
		" | Respawn in ",
		cooldown,
		" seconds."
	)


# ---------------------------------------------------------
# CHECK IF AN OBJECT SHOULD EXIST
# ---------------------------------------------------------
func can_spawn(spawn_id: String) -> bool:

	if spawn_id.is_empty():
		return true

	# Never removed before
	if not respawn_data.has(spawn_id):
		return true

	var respawn_time: int = respawn_data[spawn_id]
	var current_time := Time.get_ticks_msec()

	# Cooldown has expired
	if current_time >= respawn_time:

		respawn_data.erase(spawn_id)

		print(
			"[RespawnManager] Respawn available: ",
			spawn_id
		)

		return true

	# Still waiting for cooldown
	return false


# ---------------------------------------------------------
# GET REMAINING COOLDOWN
# ---------------------------------------------------------
func get_remaining_time(spawn_id: String) -> float:

	if not respawn_data.has(spawn_id):
		return 0.0

	var remaining_ms: int = (
		respawn_data[spawn_id] - Time.get_ticks_msec()
	)

	return maxf(remaining_ms / 1000.0, 0.0)


# ---------------------------------------------------------
# CLEAR A SPAWN RECORD (OPTIONAL)
# ---------------------------------------------------------
func clear_respawn(spawn_id: String) -> void:

	respawn_data.erase(spawn_id)

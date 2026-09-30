extends CanvasLayer

# ============================================================
# UI
# ============================================================

@onready var rankings_container: VBoxContainer = $Panel/Panel/ScrollContainer/VBoxContainer


# ============================================================
# DATA
# ============================================================

var leaderboard_data: Array[Dictionary] = []


# ============================================================
# FIREBASE
# ============================================================

func _ready() -> void:
	print("[Leaderboard] Initializing...")

	# Remove the two placeholder slots from the scene.
	clear_rank_slots()

	# Load students from Firestore.
	await load_leaderboard()


# ============================================================
# CLEAR PLACEHOLDER SLOTS
# ============================================================

func clear_rank_slots() -> void:
	for child in rankings_container.get_children():
		child.queue_free()


# ============================================================
# LOAD LEADERBOARD
# ============================================================

func load_leaderboard() -> void:

	print("[Leaderboard] Loading students from Firebase...")

	var students: FirestoreCollection = (
		Firebase.Firestore.collection("students")
	)

	# Get all student documents.
	var documents = await students.get_all()

	if documents == null:
		print("[Leaderboard] Failed to retrieve student documents.")
		return

	leaderboard_data.clear()

	for document in documents:

		if document == null:
			continue

		var data: Dictionary = (
			document.get_unsafe_document()
		)

		if data.is_empty():
			continue

		# ----------------------------------------------------
		# STUDENT NAME
		# ----------------------------------------------------

		var student_name := str(
			data.get("name", "Unknown Student")
		)

		# ----------------------------------------------------
		# PROGRESS
		# ----------------------------------------------------

		var progress = data.get("progress", {})

		if not progress is Dictionary:
			progress = {}

		var elements_collected := int(
			progress.get("elements_collected", 0)
		)

		var elements_total := int(
			progress.get("elements_total", 118)
		)

		# ----------------------------------------------------
		# ADD STUDENT
		# ----------------------------------------------------

		leaderboard_data.append({
			"name": student_name,
			"elements_collected": elements_collected,
			"elements_total": elements_total
		})

		print(
			"[Leaderboard] ",
			student_name,
			" | Atomons: ",
			elements_collected,
			"/",
			elements_total
		)

	# Sort highest Atomons collected first.
	leaderboard_data.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["elements_collected"]) > int(b["elements_collected"])
	)

	print(
		"[Leaderboard] Students loaded: ",
		leaderboard_data.size()
	)

	build_rankings()


# ============================================================
# BUILD RANKINGS
# ============================================================

func build_rankings() -> void:

	clear_rank_slots()

	for index in range(leaderboard_data.size()):

		var student: Dictionary = leaderboard_data[index]

		var rank_slot := preload(
			"res://Scenes/UI/rank_slot.tscn"
		).instantiate()

		rankings_container.add_child(rank_slot)

		setup_rank_slot(
			rank_slot,
			index + 1,
			student
		)


# ============================================================
# SETUP RANK SLOT
# ============================================================

func setup_rank_slot(
	rank_slot: Control,
	rank: int,
	student: Dictionary
) -> void:

	var rank_label: Label = (
		rank_slot.get_node("HBoxContainer/Rank")
	)

	var name_label: Label = (
		rank_slot.get_node("HBoxContainer/Name")
	)

	var collected_label: Label = (
		rank_slot.get_node("HBoxContainer/AtomonCollected")
	)

	rank_label.text = str(rank)

	name_label.text = str(
		student.get("name", "Unknown Student")
	)

	collected_label.text = (
		str(student.get("elements_collected", 0))
		+ "/"
		+ str(student.get("elements_total", 118))
	)

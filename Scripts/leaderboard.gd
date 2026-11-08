
extends CanvasLayer


# ============================================================
# UI
# ============================================================

@onready var rankings_container: VBoxContainer = $Panel/Panel/ScrollContainer/VBoxContainer
@onready var category_option: OptionButton = $Panel/Category/CategoryOption
@onready var section_option: OptionButton = $Panel/Section/SectionOption
@onready var details_panel: Panel = $Panel/Details


# ============================================================
# DATA
# ============================================================

const MAX_VISIBLE_RANKINGS := 10

var all_students: Array[Dictionary] = []
var leaderboard_data: Array[Dictionary] = []
var current_details_uid: String = ""


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[Leaderboard] Initializing...")

	if not category_option.item_selected.is_connected(_on_category_selected):
		category_option.item_selected.connect(_on_category_selected)

	if not section_option.item_selected.is_connected(_on_section_selected):
		section_option.item_selected.connect(_on_section_selected)

	details_panel.visible = false

	clear_rank_slots()

	await load_leaderboard()


# ============================================================
# LOAD LEADERBOARD
# ============================================================

func load_leaderboard() -> void:

	print("[Leaderboard] Loading leaderboard from Firestore REST...")

	all_students.clear()

	# ========================================================
	# FIREBASE AUTH
	# ========================================================

	var auth_data: Dictionary = Firebase.Firestore.auth

	if auth_data.is_empty() or not auth_data.has("idtoken"):

		print(
			"[Leaderboard] Firestore authentication token is missing."
		)

		return

	# ========================================================
	# FIREBASE PROJECT ID
	# ========================================================

	var project_id := get_firebase_project_id()

	if project_id.is_empty():

		print(
			"[Leaderboard] Firebase Project ID could not be determined."
		)

		return

	# ========================================================
	# LEADERBOARD REST URL
	# ========================================================
	#
	# IMPORTANT:
	# We now read from /leaderboard instead of /students.
	#
	# The leaderboard collection contains only the public
	# information needed by this screen.
	# ========================================================

	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+ project_id
		+ "/databases/(default)/documents/leaderboard?pageSize=300"
	)

	var headers := PackedStringArray([
		"Authorization: Bearer " + str(auth_data["idtoken"]),
		"Content-Type: application/json"
	])

	var next_page_token := ""

	# ========================================================
	# PAGINATION
	# ========================================================

	while true:

		var request_url := url

		if not next_page_token.is_empty():

			request_url += (
				"&pageToken="
				+ next_page_token.uri_encode()
			)

		var http := HTTPRequest.new()

		add_child(http)

		var error := http.request(
			request_url,
			headers,
			HTTPClient.METHOD_GET
		)

		if error != OK:

			http.queue_free()

			print(
				"[Leaderboard] REST request failed: ",
				error
			)

			return

		var response: Array = await http.request_completed

		var response_code: int = response[1]

		var response_body: PackedByteArray = response[3]

		http.queue_free()

		# ====================================================
		# HTTP ERROR
		# ====================================================

		if response_code != 200:

			print(
				"[Leaderboard] Firestore REST response: ",
				response_code
			)

			print(
				"[Leaderboard] Response: ",
				response_body.get_string_from_utf8()
			)

			return

		# ====================================================
		# PARSE JSON
		# ====================================================

		var json := JSON.new()

		if json.parse(
			response_body.get_string_from_utf8()
		) != OK:

			print(
				"[Leaderboard] Invalid Firestore REST response."
			)

			return

		var response_data = json.data

		if not response_data is Dictionary:
			return

		# ====================================================
		# DOCUMENTS
		# ====================================================

		var documents: Array = response_data.get(
			"documents",
			[]
		)

		for document in documents:

			if not document is Dictionary:
				continue

			var student := decode_firestore_document(
				document
			)

			if student.is_empty():
				continue

			# =================================================
			# LEADERBOARD DOCUMENT
			# =================================================
			#
			# SaveManager already calculates the leaderboard
			# values before writing this document.
			# =================================================

			all_students.append(
				build_leaderboard_student(
					student
				)
			)

		# ====================================================
		# NEXT PAGE
		# ====================================================

		next_page_token = str(
			response_data.get(
				"nextPageToken",
				""
			)
		)

		if next_page_token.is_empty():
			break

	# ========================================================
	# FINISHED LOADING
	# ========================================================

	print(
		"[Leaderboard] Leaderboard entries loaded: ",
		all_students.size()
	)

	populate_section_filter()

	apply_filters_and_sort()


# ============================================================
# BUILD STUDENT DATA
# ============================================================

func build_leaderboard_student(
	data: Dictionary
) -> Dictionary:

	# ========================================================
	# VALUES WRITTEN BY SAVEMANAGER
	# ========================================================

	var elements_collected := int(
		data.get(
			"elements_collected",
			0
		)
	)

	var elements_total := int(
		data.get(
			"elements_total",
			118
		)
	)

	var battles_played := int(
		data.get(
			"battles_played",
			0
		)
	)

	var battles_won := int(
		data.get(
			"battles_won",
			0
		)
	)

	var battles_lost := int(
		data.get(
			"battles_lost",
			0
		)
	)

	var battles_escaped := int(
		data.get(
			"battles_escaped",
			0
		)
	)

	var win_rate := float(
		data.get(
			"win_rate",
			0.0
		)
	)

	var average_quiz_score := float(
		data.get(
			"average_quiz_score",
			0.0
		)
	)

	var completed_quizzes := int(
		data.get(
			"completed_quizzes",
			0
		)
	)

	var total_quizzes := int(
		data.get(
			"total_quizzes",
			0
		)
	)

	var overall_score := float(
		data.get(
			"overall_score",
			0.0
		)
	)

	return {
		"uid": str(
			data.get(
				"uid",
				""
			)
		),

		"name": str(
			data.get(
				"name",
				"Unknown Student"
			)
		),

		"section": str(
			data.get(
				"section",
				"Unassigned"
			)
		),

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


# ============================================================
# SECTION FILTER
# ============================================================

func populate_section_filter() -> void:

	section_option.clear()

	section_option.add_item(
		"All Sections"
	)

	var sections: Array[String] = []

	for student in all_students:

		var section := str(
			student.get(
				"section",
				""
			)
		).strip_edges()

		if section.is_empty():
			continue

		if section not in sections:
			sections.append(section)

	sections.sort()

	for section in sections:

		section_option.add_item(
			section
		)

	section_option.select(0)


# ============================================================
# FILTER + SORT
# ============================================================

func apply_filters_and_sort() -> void:

	leaderboard_data.clear()

	var selected_section := section_option.get_item_text(
		section_option.selected
	)

	for student in all_students:

		if selected_section != "All Sections":

			if str(
				student.get(
					"section",
					""
				)
			) != selected_section:

				continue

		leaderboard_data.append(
			student
		)

	leaderboard_data.sort_custom(
		_sort_students
	)

	build_rankings()


func _sort_students(
	a: Dictionary,
	b: Dictionary
) -> bool:

	var category := category_option.get_item_text(
		category_option.selected
	)

	var a_value := get_category_value(
		a,
		category
	)

	var b_value := get_category_value(
		b,
		category
	)

	if a_value == b_value:

		return (
			str(
				a.get(
					"name",
					""
				)
			).to_lower()
			<
			str(
				b.get(
					"name",
					""
				)
			).to_lower()
		)

	return a_value > b_value


func get_category_value(
	student: Dictionary,
	category: String
) -> float:

	match category:

		"Overall":
			return float(
				student.get(
					"overall_score",
					0.0
				)
			)

		"Atomons Collected":
			return float(
				student.get(
					"elements_collected",
					0
				)
			)

		"Battles Won":
			return float(
				student.get(
					"battles_won",
					0
				)
			)

		"Quiz Score":
			return float(
				student.get(
					"average_quiz_score",
					0.0
				)
			)

		_:
			return 0.0


# ============================================================
# DROPDOWN EVENTS
# ============================================================

func _on_category_selected(
	_index: int
) -> void:

	apply_filters_and_sort()


func _on_section_selected(
	_index: int
) -> void:

	apply_filters_and_sort()


# ============================================================
# RANKINGS
# ============================================================

func clear_rank_slots() -> void:

	for child in rankings_container.get_children():

		child.queue_free()


func build_rankings() -> void:

	clear_rank_slots()

	var visible_count := mini(
		leaderboard_data.size(),
		MAX_VISIBLE_RANKINGS
	)

	for index in range(visible_count):

		var student: Dictionary = (
			leaderboard_data[index]
		)

		var rank_slot := preload(
			"res://Scenes/UI/rank_slot.tscn"
		).instantiate()

		rankings_container.add_child(
			rank_slot
		)

		if rank_slot is BaseButton:

			rank_slot.pressed.connect(
				_on_rank_slot_pressed.bind(
					student
				)
			)

		setup_rank_slot(
			rank_slot,
			index + 1,
			student
		)


# ============================================================
# RANK SLOT
# ============================================================

func setup_rank_slot(
	rank_slot: Control,
	rank: int,
	student: Dictionary
) -> void:

	var rank_label: Label = rank_slot.get_node(
		"HBoxContainer/Rank"
	)

	var name_label: Label = rank_slot.get_node(
		"HBoxContainer/Name"
	)

	var section_label: Label = rank_slot.get_node(
		"HBoxContainer/Section"
	)

	var collected_label: Label = rank_slot.get_node(
		"HBoxContainer/AtomonCollected"
	)

	rank_label.text = str(
		rank
	)

	name_label.text = str(
		student.get(
			"name",
			"Unknown Student"
		)
	)

	section_label.text = str(
		student.get(
			"section",
			"Unassigned"
		)
	)

	collected_label.text = (
		str(
			student.get(
				"elements_collected",
				0
			)
		)
		+ "/"
		+ str(
			student.get(
				"elements_total",
				118
			)
		)
	)


# ============================================================
# DETAILS
# ============================================================

func _on_rank_slot_pressed(
	student: Dictionary
) -> void:

	current_details_uid = str(
		student.get(
			"uid",
			""
		)
	)

	show_student_details(
		student
	)


func show_student_details(
	student: Dictionary
) -> void:

	details_panel.visible = true

	$Panel/Details/Name.text = str(
		student.get(
			"name",
			"Unknown Student"
		)
	)

	$Panel/Details/Section.text = (
		"Section: "
		+
		str(
			student.get(
				"section",
				"Unassigned"
			)
		)
	)

	$Panel/Details/TextureRect/Rank.text = (
		"Rank: "
		+
		str(
			get_student_rank(
				student
			)
		)
	)

	$Panel/Details/VBoxContainer/AtomonCollected/Title2.text = (
		str(
			student.get(
				"elements_collected",
				0
			)
		)
		+
		"/"
		+
		str(
			student.get(
				"elements_total",
				118
			)
		)
	)

	$Panel/Details/VBoxContainer/Winrate/Title2.text = (
		"%.1f%%"
		%
		float(
			student.get(
				"win_rate",
				0.0
			)
		)
	)

	$Panel/Details/VBoxContainer/BattlesPlayed/Title2.text = str(
		student.get(
			"battles_played",
			0
		)
	)

	$Panel/Details/VBoxContainer/BattlesWon/Title2.text = str(
		student.get(
			"battles_won",
			0
		)
	)

	$Panel/Details/VBoxContainer/BattlesLost/Title2.text = str(
		student.get(
			"battles_lost",
			0
		)
	)

	# ========================================================
	# COINS
	# ========================================================
	#
	# The new leaderboard collection intentionally does not
	# contain private game-state data such as coins.
	#
	# Therefore this displays 0 unless SaveManager later
	# explicitly adds coins to the public leaderboard data.
	# ========================================================

	$Panel/Details/VBoxContainer/Coins/Title2.text = str(
		student.get(
			"coins",
			0
		)
	)

	$Panel/Details/VBoxContainer/Quiz/Title2.text = (
		"%.1f%%"
		%
		float(
			student.get(
				"average_quiz_score",
				0.0
			)
		)
	)


func get_student_rank(
	student: Dictionary
) -> int:

	for index in range(
		leaderboard_data.size()
	):

		if str(
			leaderboard_data[index].get(
				"uid",
				""
			)
		) == str(
			student.get(
				"uid",
				""
			)
		):

			return index + 1

	return 0


# ============================================================
# FIREBASE HELPERS
# ============================================================

func get_firebase_project_id() -> String:

	if Firebase.Firestore._config.has(
		"projectId"
	):

		return str(
			Firebase.Firestore._config[
				"projectId"
			]
		)

	if "FIREBASE_PROJECT_ID" in FirebaseConfig:

		return str(
			FirebaseConfig.FIREBASE_PROJECT_ID
		)

	if "PROJECT_ID" in FirebaseConfig:

		return str(
			FirebaseConfig.PROJECT_ID
		)

	return ""


func decode_firestore_document(
	document: Dictionary
) -> Dictionary:

	var student: Dictionary = {}

	var fields = document.get(
		"fields",
		{}
	)

	if fields is Dictionary:

		for field_name in fields:

			student[field_name] = (
				_decode_firestore_value(
					fields[field_name]
				)
			)

	var document_name := str(
		document.get(
			"name",
			""
		)
	)

	if not document_name.is_empty():

		student["uid"] = (
			document_name.get_file()
		)

	return student


func _decode_firestore_value(
	value: Dictionary
):

	if value.has("stringValue"):

		return value["stringValue"]


	if value.has("integerValue"):

		return int(
			value["integerValue"]
		)


	if value.has("doubleValue"):

		return float(
			value["doubleValue"]
		)


	if value.has("booleanValue"):

		return value["booleanValue"]


	if value.has("timestampValue"):

		return value["timestampValue"]


	if value.has("nullValue"):

		return null


	if value.has("arrayValue"):

		var result: Array = []

		var values = value["arrayValue"].get(
			"values",
			[]
		)

		for item in values:

			result.append(
				_decode_firestore_value(
					item
				)
			)

		return result


	if value.has("mapValue"):

		var result: Dictionary = {}

		var fields = value["mapValue"].get(
			"fields",
			{}
		)

		for field_name in fields:

			result[field_name] = (
				_decode_firestore_value(
					fields[field_name]
				)
			)

		return result


func _on_texture_button_pressed() -> void:
	details_panel.hide()


func _on_close_leaderboard_pressed() -> void:
	print(
		"CLOSING LEADERBOARD"
	)
	if details_panel:
		details_panel.show()
	
	if global.player:
		global.player.can_move = true
	
	queue_free()

extends Control


# ============================================================
# STUDENT DATA
# ============================================================

var student_data: Dictionary = {}


# ============================================================
# HEADER
# ============================================================

@onready var back_button: Button = $PageBackground/MarginContainer/VBoxContainer/Header/BackButton


# ============================================================
# LEFT PANEL — STUDENT INFORMATION
# ============================================================

@onready var student_name_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/StudentName

@onready var student_id_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/StudentID

@onready var email_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/Email

@onready var section_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/AcademicInfo/Section

@onready var school_year_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/AcademicInfo/SchoolYear

@onready var status_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/Status

@onready var rank_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/Rank

@onready var last_active_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/LeftPanel/MarginContainer/VBoxContainer/LastActive


# ============================================================
# RIGHT PANEL — ELEMENT PROGRESS
# ============================================================

@onready var elements_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ProgressPanel/MarginContainer/VBoxContainer/ElementsLabel

@onready var progress_bar: ProgressBar = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ProgressPanel/MarginContainer/VBoxContainer/ProgressBar

@onready var progress_text: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ProgressPanel/MarginContainer/VBoxContainer/ProgressText


# ============================================================
# RIGHT PANEL — LEARNING MODULES
# ============================================================

@onready var modules_completed_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ModulesPanel/MarginContainer/VBoxContainer/ModulesCompleted

@onready var modules_progress: ProgressBar = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ModulesPanel/MarginContainer/VBoxContainer/ModulesProgress

@onready var modules_progress_text: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ModulesPanel/MarginContainer/VBoxContainer/ModulesProgressText


# ============================================================
# RIGHT PANEL — ASSESSMENTS
# ============================================================

@onready var total_assessments_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/AssessmentsPanel/MarginContainer/VBoxContainer/TotalAssessments

@onready var completed_assessments_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/AssessmentsPanel/MarginContainer/VBoxContainer/CompletedAssessments

@onready var average_score_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/AssessmentsPanel/MarginContainer/VBoxContainer/AverageScore

@onready var latest_score_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/AssessmentsPanel/MarginContainer/VBoxContainer/LatestScore


# ============================================================
# RIGHT PANEL — GAME PROGRESS
# ============================================================

@onready var coins_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/GameProgressPanel/MarginContainer/VBoxContainer/Coins

@onready var party_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/GameProgressPanel/MarginContainer/VBoxContainer/Party

@onready var save_status_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/GameProgressPanel/MarginContainer/VBoxContainer/SaveStatus


# ============================================================
# RIGHT PANEL — RECENT ACTIVITY
# ============================================================

@onready var activity_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/ActivityPanel/MarginContainer/VBoxContainer/Activity


# ============================================================
# RIGHT PANEL — ACADEMIC HISTORY
# ============================================================

@onready var history_label: Label = $PageBackground/MarginContainer/VBoxContainer/Content/RightPanel/MarginContainer/ScrollContainer/VBoxContainer/AcademicHistoryPanel/MarginContainer/VBoxContainer/History


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	if not back_button.pressed.is_connected(
		_on_back_pressed
	):

		back_button.pressed.connect(
			_on_back_pressed
		)


	if not student_data.is_empty():

		display_student()


# ============================================================
# SET STUDENT DATA
# ============================================================

func set_student_data(
	data: Dictionary
) -> void:

	student_data = data

	print(
		"[StudentProfile] Student data received."
	)

	if is_node_ready():

		display_student()


# ============================================================
# SET STUDENT
# ============================================================

func set_student(
	data: Dictionary
) -> void:

	set_student_data(data)


# ============================================================
# SETUP
# ============================================================

func setup(
	data: Dictionary
) -> void:

	set_student_data(data)


# ============================================================
# BACK BUTTON
# ============================================================

func _on_back_pressed() -> void:

	hide()


# ============================================================
# DISPLAY STUDENT
# ============================================================

func display_student() -> void:

	if student_data.is_empty():

		print(
			"[StudentProfile] No student data."
		)

		return


	var student_name: String = str(
		student_data.get(
			"name",
			"Unknown Student"
		)
	)


	print(
		"[StudentProfile] Displaying student: ",
		student_name
	)


	# ========================================================
	# BASIC INFORMATION
	# ========================================================

	var student_id: String = str(
		student_data.get(
			"student_id",
			"-"
		)
	)

	var email: String = str(
		student_data.get(
			"email",
			"No email"
		)
	)

	var section: String = str(
		student_data.get(
			"section",
			"-"
		)
	)

	var school_year: String = str(
		student_data.get(
			"school_year",
			"-"
		)
	)


	student_name_label.text = student_name

	student_id_label.text = (
		"Student ID: %s"
		% student_id
	)

	email_label.text = email

	section_label.text = (
		"Section: %s"
		% section
	)

	school_year_label.text = (
		"School Year: %s"
		% school_year
	)


	# ========================================================
	# LAST ACTIVE
	# ========================================================

	var last_active: int = get_last_active_timestamp(
		student_data
	)


	last_active_label.text = format_last_active(
		last_active
	)


	# ========================================================
	# STATUS
	# ========================================================

	if is_student_active(
		student_data
	):

		status_label.text = "● Active"

	else:

		status_label.text = "● Inactive"


	# ========================================================
	# GAME STATE
	# ========================================================

	var game_state: Dictionary = {}

	var game_state_value = student_data.get(
		"game_state",
		{}
	)

	if game_state_value is Dictionary:

		game_state = game_state_value


	# ========================================================
	# RANK
	# ========================================================

	var rank = game_state.get(
		"rank",
		student_data.get(
			"rank",
			"-"
		)
	)

	rank_label.text = str(rank)


	# ========================================================
	# DISPLAY ALL SECTIONS
	# ========================================================

	display_element_progress()

	display_module_progress()

	display_assessment()

	display_game_progress()

	display_recent_activity()

	display_academic_history()


# ============================================================
# GET LAST ACTIVE TIMESTAMP
# ============================================================

func get_last_active_timestamp(
	data: Dictionary
) -> int:

	var value = data.get(
		"last_active",
		0
	)


	if value is int:

		return int(value)


	if value is float:

		return int(value)


	if value is String:

		var cleaned: String = value.strip_edges()


		if cleaned.is_valid_int():

			return int(cleaned)


		if cleaned.is_valid_float():

			return int(
				float(cleaned)
			)


	return 0


# ============================================================
# IS STUDENT ACTIVE
# ============================================================

func is_student_active(
	data: Dictionary
) -> bool:

	var timestamp: int = get_last_active_timestamp(
		data
	)


	if timestamp <= 0:

		return false


	var current_time: int = int(
		Time.get_unix_time_from_system()
	)


	var elapsed: int = (
		current_time
		-
		timestamp
	)


	return elapsed >= 0 and elapsed <= 300


# ============================================================
# ELEMENT PROGRESS
# ============================================================

func display_element_progress() -> void:

	var progress_value = student_data.get(
		"progress",
		{}
	)


	if not progress_value is Dictionary:

		elements_label.text = "Elements Collected: 0 / 118"

		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 0

		progress_text.text = "0%"

		return


	var progress: Dictionary = progress_value


	var collected: int = int(
		progress.get(
			"elements_collected",
			0
		)
	)


	var total: int = int(
		progress.get(
			"elements_total",
			118
		)
	)


	if total <= 0:

		total = 118


	collected = clamp(
		collected,
		0,
		total
	)


	var percentage: float = (
		float(collected)
		/
		float(total)
		*
		100.0
	)


	percentage = clamp(
		percentage,
		0.0,
		100.0
	)


	elements_label.text = (
		"Elements Collected: %d / %d"
		% [
			collected,
			total
		]
	)


	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = percentage


	progress_text.text = (
		"%d%%"
		% int(round(percentage))
	)


	print(
		"[StudentProfile] Element progress: ",
		collected,
		"/",
		total
	)


# ============================================================
# MODULE PROGRESS
# ============================================================

func display_module_progress() -> void:

	var lesson_value = student_data.get(
		"lesson_progress",
		{}
	)


	if not lesson_value is Dictionary:

		set_module_progress(
			0,
			0
		)

		return


	var lesson_progress: Dictionary = lesson_value


	# --------------------------------------------------------
	# IMPORTANT:
	# The current database only contains:
	#
	# lesson_progress
	#     name
	#
	# There are currently no individual module records.
	#
	# Therefore we must NOT pretend there are 8 modules.
	# --------------------------------------------------------

	var total_modules: int = 0
	var completed_modules: int = 0


	for lesson_id in lesson_progress:

		if lesson_id == "name":

			continue


		var lesson_value_data = lesson_progress[
			lesson_id
		]


		if not lesson_value_data is Dictionary:

			continue


		total_modules += 1


		var lesson: Dictionary = lesson_value_data


		var lesson_status: String = str(
			lesson.get(
				"status",
				""
			)
		).to_lower()


		if (
			lesson_status == "completed"
			or lesson_status == "complete"
		):

			completed_modules += 1


	set_module_progress(
		completed_modules,
		total_modules
	)


	print(
		"[StudentProfile] Module progress: ",
		completed_modules,
		"/",
		total_modules
	)


# ============================================================
# SET MODULE PROGRESS
# ============================================================

func set_module_progress(
	completed: int,
	total: int
) -> void:

	if total <= 0:

		modules_completed_label.text = (
			"Modules Completed: 0 / 0"
		)

		modules_progress.min_value = 0
		modules_progress.max_value = 100
		modules_progress.value = 0

		modules_progress_text.text = (
			"No module progress yet"
		)

		return


	var percentage: float = (
		float(completed)
		/
		float(total)
		*
		100.0
	)


	percentage = clamp(
		percentage,
		0.0,
		100.0
	)


	modules_completed_label.text = (
		"Modules Completed: %d / %d"
		% [
			completed,
			total
		]
	)


	modules_progress.min_value = 0
	modules_progress.max_value = 100
	modules_progress.value = percentage


	modules_progress_text.text = (
		"%d%%"
		% int(round(percentage))
	)


# ============================================================
# ASSESSMENTS
# ============================================================

func display_assessment() -> void:

	var assessment_value = student_data.get(
		"assessment",
		{}
	)


	if not assessment_value is Dictionary:

		set_assessment(
			0,
			0,
			0.0,
			0.0
		)

		return


	var assessment: Dictionary = assessment_value


	# ========================================================
	# DO NOT USE THE SUMMARY FIELDS
	#
	# The database currently contains stale values:
	#
	# total_assessments = 0
	# completed_assessments = 0
	# average_score = 0
	# latest_score = 0
	#
	# Instead, inspect every quiz_xxx record.
	# ========================================================

	var total_assessments: int = 0
	var completed_assessments: int = 0

	var score_total: float = 0.0
	var latest_score: float = 0.0

	var latest_timestamp: int = 0


	for assessment_id in assessment:

		var assessment_entry = assessment[
			assessment_id
		]


		# Only process actual quiz records.
		if not str(assessment_id).begins_with(
			"quiz_"
		):

			continue


		if not assessment_entry is Dictionary:

			continue


		var quiz: Dictionary = assessment_entry


		total_assessments += 1


		var completed: bool = bool(
			quiz.get(
				"completed",
				false
			)
		)


		if not completed:

			continue


		completed_assessments += 1


		var percentage: float = float(
			quiz.get(
				"percentage",
				0.0
			)
		)


		score_total += percentage


		# ----------------------------------------------------
		# Determine the latest completed assessment.
		# ----------------------------------------------------

		var completed_timestamp: int = get_timestamp_from_value(
			quiz.get(
				"completed_at",
				0
			)
		)


		if completed_timestamp >= latest_timestamp:

			latest_timestamp = completed_timestamp

			latest_score = percentage


		print(
			"[StudentProfile] Assessment found: ",
			str(
				quiz.get(
					"quiz_title",
					assessment_id
				)
			),
			" | Score: ",
			quiz.get(
				"score",
				0
			),
			"/",
			quiz.get(
				"total_questions",
				0
			),
			" | ",
			percentage,
			"%"
		)


	var average_score: float = 0.0


	if completed_assessments > 0:

		average_score = (
			score_total
			/
			float(completed_assessments)
		)


	# If there are completed assessments but no
	# recognizable timestamp, use the last encountered
	# completed quiz as a fallback.
	if (
		completed_assessments > 0
		and latest_timestamp == 0
	):

		latest_score = get_latest_assessment_percentage(
			assessment
		)


	set_assessment(
		total_assessments,
		completed_assessments,
		average_score,
		latest_score
	)


	print(
		"[StudentProfile] Real assessment statistics:"
	)

	print(
		"  Total: ",
		total_assessments
	)

	print(
		"  Completed: ",
		completed_assessments
	)

	print(
		"  Average: ",
		average_score,
		"%"
	)

	print(
		"  Latest: ",
		latest_score,
		"%"
	)


# ============================================================
# SET ASSESSMENT
# ============================================================

func set_assessment(
	total: int,
	completed: int,
	average: float,
	latest: float
) -> void:

	total_assessments_label.text = (
		"Total Assessments: %d"
		% total
	)

	completed_assessments_label.text = (
		"Completed: %d"
		% completed
	)

	average_score_label.text = (
		"Average Score: %d%%"
		% int(round(average))
	)

	latest_score_label.text = (
		"Latest Score: %d%%"
		% int(round(latest))
	)


# ============================================================
# GET TIMESTAMP FROM FIREBASE VALUE
# ============================================================

func get_timestamp_from_value(
	value
) -> int:

	# --------------------------------------------------------
	# Integer timestamp
	# --------------------------------------------------------

	if value is int:

		return int(value)


	# --------------------------------------------------------
	# Float timestamp
	# --------------------------------------------------------

	if value is float:

		return int(value)


	# --------------------------------------------------------
	# Firebase timestamp dictionary
	#
	# Possible format:
	# {
	#     "seconds": 1234567890,
	#     "nanos": 0
	# }
	# --------------------------------------------------------

	if value is Dictionary:

		var timestamp_data: Dictionary = value


		if timestamp_data.has("seconds"):

			var seconds_value = timestamp_data.get(
				"seconds",
				0
			)


			if seconds_value is int:

				return int(seconds_value)


			if seconds_value is float:

				return int(seconds_value)


			if str(seconds_value).is_valid_int():

				return int(
					str(seconds_value)
				)


	# --------------------------------------------------------
	# String
	# --------------------------------------------------------

	if value is String:

		var text: String = value.strip_edges()


		if text.is_empty():

			return 0


		if text.is_valid_int():

			return int(text)


		if text.is_valid_float():

			return int(
				float(text)
			)


	return 0


# ============================================================
# FALLBACK LATEST ASSESSMENT
# ============================================================

func get_latest_assessment_percentage(
	assessment: Dictionary
) -> float:

	var latest_percentage: float = 0.0


	for assessment_id in assessment:

		if not str(assessment_id).begins_with(
			"quiz_"
		):

			continue


		var assessment_entry = assessment[
			assessment_id
		]


		if not assessment_entry is Dictionary:

			continue


		var quiz: Dictionary = assessment_entry


		if not bool(
			quiz.get(
				"completed",
				false
			)
		):

			continue


		latest_percentage = float(
			quiz.get(
				"percentage",
				0.0
			)
		)


	return latest_percentage


# ============================================================
# GAME PROGRESS
# ============================================================

func display_game_progress() -> void:

	var game_state_value = student_data.get(
		"game_state",
		{}
	)


	if not game_state_value is Dictionary:

		coins_label.text = "Coins: 0"
		party_label.text = "Party: 0 / 15"
		save_status_label.text = "Save Status: No Save"

		return


	var game_state: Dictionary = game_state_value


	# ========================================================
	# COINS
	# ========================================================

	var coins: int = int(
		game_state.get(
			"coins",
			0
		)
	)


	coins_label.text = (
		"Coins: %d"
		% coins
	)


	# ========================================================
	# PARTY
	# ========================================================

	var party_count: int = 0


	var party_value = game_state.get(
		"party",
		[]
	)


	if party_value is Array:

		party_count = party_value.size()


	party_label.text = (
		"Party: %d / 15"
		% party_count
	)


	# ========================================================
	# SAVE STATUS
	# ========================================================

	var has_save: bool = bool(
		game_state.get(
			"has_save",
			false
		)
	)


	if has_save:

		save_status_label.text = (
			"Save Status: Available"
		)

	else:

		save_status_label.text = (
			"Save Status: No Save"
		)


# ============================================================
# RECENT ACTIVITY
# ============================================================

func display_recent_activity() -> void:

	var activity_value = student_data.get(
		"recent_activity",
		null
	)


	# ========================================================
	# EXPLICIT RECENT ACTIVITY
	# ========================================================

	if activity_value is Array:

		var activities: Array = activity_value


		if activities.is_empty():

			activity_label.text = (
				"No recent activity."
			)

		else:

			var activity_text: String = ""


			for item in activities:

				activity_text += (
					str(item)
					+
					"\n"
				)


			activity_label.text = (
				activity_text.strip_edges()
			)

		return


	# ========================================================
	# BUILD ACTIVITY FROM REAL SAVED GAME DATA
	# ========================================================

	var activity_lines: Array[String] = []


	# --------------------------------------------------------
	# Quest activity
	# --------------------------------------------------------

	var quest_value = student_data.get(
		"game_state",
		{}
	)


	if quest_value is Dictionary:

		var game_state: Dictionary = quest_value


		var quest_data_value = game_state.get(
			"quest_data",
			{}
		)


		if quest_data_value is Dictionary:

			var quest_data: Dictionary = quest_data_value


			for quest_id in quest_data:

				var quest_value_data = quest_data[
					quest_id
				]


				if not quest_value_data is Dictionary:

					continue


				var quest: Dictionary = quest_value_data


				var quest_status: String = str(
					quest.get(
						"quest_status",
						""
					)
				).to_lower()


				if quest_status == "completed":

					activity_lines.append(
						"✓ Quest completed: "
						+
						get_readable_quest_name(
							str(quest_id)
						)
					)


		# ----------------------------------------------------
		# Current game location
		# ----------------------------------------------------

		var current_scene: String = str(
			game_state.get(
				"current_scene",
				""
			)
		)


		if not current_scene.is_empty():

			activity_lines.append(
				"Current location: "
				+
				get_scene_name(
					current_scene
				)
			)


		# ----------------------------------------------------
		# Save status
		# ----------------------------------------------------

		var has_save: bool = bool(
			game_state.get(
				"has_save",
				false
			)
		)


		if has_save:

			activity_lines.append(
				"Game progress saved."
			)


	if activity_lines.is_empty():

		activity_label.text = (
			"No recent activity."
		)

	else:

		activity_label.text = (
			"\n".join(activity_lines)
		)


# ============================================================
# ACADEMIC HISTORY
# ============================================================

func display_academic_history() -> void:

	var history_value = student_data.get(
		"academic_history",
		{}
	)


	if history_value is Dictionary:

		var history: Dictionary = history_value


		if history.is_empty():

			history_label.text = (
				"No previous academic history."
			)

			return


		var history_text: String = ""


		for history_id in history:

			var history_entry = history[
				history_id
			]


			history_text += (
				str(history_id)
				+
				": "
				+
				str(history_entry)
				+
				"\n"
			)


		history_label.text = (
			history_text.strip_edges()
		)

		return


	if history_value is Array:

		var history_array: Array = history_value


		if history_array.is_empty():

			history_label.text = (
				"No previous academic history."
			)

			return


		var history_text: String = ""


		for item in history_array:

			history_text += (
				str(item)
				+
				"\n"
			)


		history_label.text = (
			history_text.strip_edges()
		)

		return


	if history_value is String:

		if not history_value.strip_edges().is_empty():

			history_label.text = (
				history_value
			)

			return


	history_label.text = (
		"No previous academic history."
	)


# ============================================================
# READABLE QUEST NAME
# ============================================================

func get_readable_quest_name(
	quest_id: String
) -> String:

	var result: String = quest_id.replace(
		"_",
		" "
	)


	return result.capitalize()


# ============================================================
# FORMAT LAST ACTIVE
# ============================================================

func format_last_active(
	timestamp: int
) -> String:

	if timestamp <= 0:

		return "Never"


	var current_time: int = int(
		Time.get_unix_time_from_system()
	)


	var elapsed: int = (
		current_time
		-
		timestamp
	)


	if elapsed < 0:

		return "Just now"


	if elapsed < 60:

		return "Just now"


	if elapsed < 3600:

		var minutes: int = int(
			elapsed / 60
		)

		return "%d min ago" % minutes


	if elapsed < 86400:

		var hours: int = int(
			elapsed / 3600
		)

		return "%d hr ago" % hours


	if elapsed < 604800:

		var days: int = int(
			elapsed / 86400
		)

		return "%d day%s ago" % [
			days,
			"" if days == 1 else "s"
		]


	var datetime: Dictionary = (
		Time.get_datetime_dict_from_unix_time(
			timestamp
		)
	)


	return "%04d-%02d-%02d" % [
		datetime.year,
		datetime.month,
		datetime.day
	]


# ============================================================
# SCENE NAME
# ============================================================

func get_scene_name(
	scene_path: String
) -> String:

	if scene_path.is_empty():

		return "Unknown"


	var file_name: String = scene_path.get_file()

	file_name = file_name.get_basename()

	file_name = file_name.replace(
		"_",
		" "
	)


	return file_name.capitalize()

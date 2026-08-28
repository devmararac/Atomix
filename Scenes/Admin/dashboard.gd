extends Control


# ============================================================
# UI REFERENCES
# ============================================================

@onready var rows: VBoxContainer = $Background/MarginContainer/VBoxContainer/StudentTable/ScrollContainer/Rows
@onready var empty_state: Panel = $Background/MarginContainer/VBoxContainer/StudentTable/EmptyState
@onready var refresh_button: Button = $Background/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/RefreshPanel/RefreshButton
@onready var search_input: LineEdit = $Background/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SearchPanel/SearchBar
@onready var filter_button: OptionButton = $Background/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/FilterPanel/FilterButton
@onready var sort_button: OptionButton = $Background/MarginContainer/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SortPanel/SortButton


# ============================================================
# STATISTIC CARDS
# ============================================================

@onready var total_student_value: Label = $Background/MarginContainer/VBoxContainer/StatsRow/TotalStudent/MarginContainer/HBoxContainer/VBoxContainer/Value
@onready var collection_value: Label = $Background/MarginContainer/VBoxContainer/StatsRow/Collection/MarginContainer/HBoxContainer/VBoxContainer/Value
@onready var top_score_value: Label = $Background/MarginContainer/VBoxContainer/StatsRow/TopScore/MarginContainer/HBoxContainer/VBoxContainer/Value
@onready var needs_attention_value: Label = $Background/MarginContainer/VBoxContainer/StatsRow/NeedsAttention/MarginContainer/HBoxContainer/VBoxContainer/Value

@onready var total_student_title: Label = $Background/MarginContainer/VBoxContainer/StatsRow/TotalStudent/MarginContainer/HBoxContainer/VBoxContainer/Title
@onready var collection_title: Label = $Background/MarginContainer/VBoxContainer/StatsRow/Collection/MarginContainer/HBoxContainer/VBoxContainer/Title
@onready var top_score_title: Label = $Background/MarginContainer/VBoxContainer/StatsRow/TopScore/MarginContainer/HBoxContainer/VBoxContainer/Title
@onready var needs_attention_title: Label = $Background/MarginContainer/VBoxContainer/StatsRow/NeedsAttention/MarginContainer/HBoxContainer/VBoxContainer/Title

@onready var total_student_subtitle: Label = $Background/MarginContainer/VBoxContainer/StatsRow/TotalStudent/MarginContainer/HBoxContainer/VBoxContainer/Subtitle
@onready var collection_subtitle: Label = $Background/MarginContainer/VBoxContainer/StatsRow/Collection/MarginContainer/HBoxContainer/VBoxContainer/Subtitle
@onready var top_score_subtitle: Label = $Background/MarginContainer/VBoxContainer/StatsRow/TopScore/MarginContainer/HBoxContainer/VBoxContainer/Subtitle
@onready var needs_attention_subtitle: Label = $Background/MarginContainer/VBoxContainer/StatsRow/NeedsAttention/MarginContainer/HBoxContainer/VBoxContainer/Subtitle




# ============================================================
# STUDENT ROW SCENE
# ============================================================

const STUDENT_ROW = preload(
	"res://Scenes/Admin/student_row.tscn"
)


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	total_student_title.text = "TOTAL STUDENTS"
	collection_title.text = "COLLECTION"
	top_score_title.text = "TOP SCORE"
	needs_attention_title.text = "NEEDS ATTENTION"

	total_student_subtitle.text = "Enrolled This Term"
	collection_subtitle.text = "of 118 Elements"
	top_score_subtitle.text = "Highest Student Score"
	needs_attention_subtitle.text = "Below 30% Progress"
	
	
	
	# --------------------------------------------------------
	# BUTTON CONNECTIONS
	# --------------------------------------------------------

	if not refresh_button.pressed.is_connected(
		_on_refresh_pressed
	):

		refresh_button.pressed.connect(
			_on_refresh_pressed
		)


	if not search_input.text_changed.is_connected(
		_on_search_changed
	):

		search_input.text_changed.connect(
			_on_search_changed
	)


	if not filter_button.item_selected.is_connected(
		_on_filter_changed
	):

		filter_button.item_selected.connect(
			_on_filter_changed
	)


	if not sort_button.item_selected.is_connected(
		_on_sort_changed
	):

		sort_button.item_selected.connect(
			_on_sort_changed
		)


	# --------------------------------------------------------
	# TEACHER DATA MANAGER
	# --------------------------------------------------------

	if not TeacherDataManager.students_loaded.is_connected(
		_on_students_loaded
	):

		TeacherDataManager.students_loaded.connect(
			_on_students_loaded
	)


	if not TeacherDataManager.students_error.is_connected(
		_on_students_error
	):

		TeacherDataManager.students_error.connect(
			_on_students_error
		)


	# --------------------------------------------------------
	# INITIAL STATE
	# --------------------------------------------------------

	load_students()


# ============================================================
# BUTTONS
# ============================================================

func _on_refresh_pressed() -> void:

	load_students()


# ============================================================
# SEARCH / FILTER / SORT
# ============================================================

func _on_search_changed(
	_text: String
) -> void:

	display_students()


func _on_filter_changed(
	_index: int
) -> void:

	display_students()


func _on_sort_changed(
	_index: int
) -> void:

	display_students()


# ============================================================
# ROW MANAGEMENT
# ============================================================

func clear_rows() -> void:

	for child in rows.get_children():

		# Do not delete the original scene placeholder
		# if you still have one inside Rows.
		#
		# Since the dashboard creates rows dynamically,
		# all children are removed.

		child.queue_free()


# ============================================================
# LOAD STUDENTS
# ============================================================

func load_students() -> void:

	print(
		"[Dashboard] Requesting student data..."
	)

	clear_rows()

	empty_state.hide()

	TeacherDataManager.load_students()


# ============================================================
# STUDENTS LOADED
# ============================================================

func _on_students_loaded(
	student_list: Array
) -> void:

	print(
		"[Dashboard] Received ",
		student_list.size(),
		" students."
	)

	# --------------------------------------------------------
	# UPDATE DASHBOARD CARDS
	# --------------------------------------------------------

	update_stat_cards(
		student_list
	)

	# --------------------------------------------------------
	# UPDATE STUDENT TABLE
	# --------------------------------------------------------

	display_students()


# ============================================================
# STUDENT LOAD ERROR
# ============================================================

func _on_students_error(
	error
) -> void:

	print(
		"[Dashboard] Firebase error: ",
		error
	)

	clear_rows()

	empty_state.show()

	# Reset cards

	total_student_value.text = "0"

	collection_value.text = "0%"


# ============================================================
# STATISTIC CARDS
# ============================================================

func update_stat_cards(
	student_list: Array
) -> void:

	var total_students: int = student_list.size()

	total_student_value.text = str(
		total_students
	)


	# ========================================================
	# AVERAGE COMPLETION
	# ========================================================

	var total_collected: int = 0
	var total_possible: int = 0


	for student_data in student_list:

		total_collected += get_elements_collected(
			student_data
		)

		total_possible += get_elements_total(
			student_data
		)


	if total_possible > 0:

		var average_completion: float = (
			float(total_collected)
			/
			float(total_possible)
			*
			100.0
		)

		collection_value.text = "%d%%" % int(
			round(average_completion)
		)

	else:

		collection_value.text = "0%"


	# ========================================================
	# FIND TOP STUDENT
	# ========================================================

	var top_student_name: String = "No students"

	var top_student_progress: float = 0.0


	for student_data in student_list:

		var progress: float = get_student_progress(
			student_data
		)

		if progress > top_student_progress:

			top_student_progress = progress

			top_student_name = get_student_name(
				student_data
			)


	top_score_value.text = "%d%%" % int(
		round(top_student_progress)
	)


	# ========================================================
	# NEEDS ATTENTION
	# Students below 30%
	# ========================================================

	var needs_attention_count: int = 0


	for student_data in student_list:

		if get_student_progress(student_data) < 30.0:

			needs_attention_count += 1


	needs_attention_value.text = str(
		needs_attention_count
	)




# ============================================================
# DISPLAY STUDENTS
# ============================================================

func display_students() -> void:

	clear_rows()


	var all_students: Array[Dictionary] = (
		TeacherDataManager.get_students()
	)


	var filtered_students: Array[Dictionary] = []


	var search_text: String = (
		search_input.text
		.strip_edges()
		.to_lower()
	)


	# ========================================================
	# SEARCH
	# ========================================================

	for student_data in all_students:

		var student_name: String = str(
			student_data.get(
				"name",
				""
			)
		).to_lower()


		var email: String = str(
			student_data.get(
				"email",
				""
			)
		).to_lower()


		var student_id: String = str(
			student_data.get(
				"student_id",
				""
			)
		).to_lower()


		var section: String = str(
			student_data.get(
				"section",
				""
			)
		).to_lower()


		var school_year: String = str(
			student_data.get(
				"school_year",
				""
			)
		).to_lower()


		# ----------------------------------------------------
		# NO SEARCH TEXT
		# ----------------------------------------------------

		if search_text.is_empty():

			filtered_students.append(
				student_data
			)

			continue


		# ----------------------------------------------------
		# SEARCH
		# ----------------------------------------------------

		if (
			student_name.contains(search_text)
			or email.contains(search_text)
			or student_id.contains(search_text)
			or section.contains(search_text)
			or school_year.contains(search_text)
		):

			filtered_students.append(
				student_data
			)


	# ========================================================
	# FILTER
	# ========================================================

	var filter_index: int = (
		filter_button.selected
	)


	if filter_index == 1:

		filtered_students = (
			get_active_students(
				filtered_students
			)
		)


	elif filter_index == 2:

		filtered_students = (
			get_inactive_students(
				filtered_students
			)
		)


	# ========================================================
	# SORT
	# ========================================================

	var sort_index: int = (
		sort_button.selected
	)


	if sort_index == 0:

		# ----------------------------------------------------
		# NAME A-Z
		# ----------------------------------------------------

		filtered_students.sort_custom(
			func(
				a: Dictionary,
				b: Dictionary
			) -> bool:

				return str(
					a.get(
						"name",
						""
					)
				).to_lower() < str(
					b.get(
						"name",
						""
					)
				).to_lower()
		)


	elif sort_index == 1:

		# ----------------------------------------------------
		# PROGRESS HIGHEST FIRST
		# ----------------------------------------------------

		filtered_students.sort_custom(
			func(
				a: Dictionary,
				b: Dictionary
			) -> bool:

				return (
					get_student_progress(a)
					>
					get_student_progress(b)
				)
		)


	elif sort_index == 2:

		# ----------------------------------------------------
		# ELEMENTS COLLECTED HIGHEST FIRST
		# ----------------------------------------------------

		filtered_students.sort_custom(
			func(
				a: Dictionary,
				b: Dictionary
			) -> bool:

				return (
					get_elements_collected(a)
					>
					get_elements_collected(b)
				)
		)


	# ========================================================
	# EMPTY STATE
	# ========================================================

	if filtered_students.is_empty():

		empty_state.show()

		return


	empty_state.hide()


	# ========================================================
	# CREATE STUDENT ROWS
	# ========================================================

	var number: int = 1


	for student_data in filtered_students:

		var row: Control = (
			STUDENT_ROW.instantiate()
		)


		rows.add_child(
			row
		)


		setup_student_row(
			row,
			student_data,
			number
		)


		number += 1


# ============================================================
# GET STUDENT ID
# ============================================================

func get_student_id(
	data: Dictionary
) -> String:

	return str(
		data.get(
			"student_id",
			""
		)
	)


# ============================================================
# GET STUDENT NAME
# ============================================================

func get_student_name(
	data: Dictionary
) -> String:

	return str(
		data.get(
			"name",
			"Unknown Student"
		)
	)


# ============================================================
# GET STUDENT SECTION
# ============================================================

func get_student_section(
	data: Dictionary
) -> String:

	return str(
		data.get(
			"section",
			""
		)
	)


# ============================================================
# GET SCHOOL YEAR
# ============================================================

func get_school_year(
	data: Dictionary
) -> String:

	return str(
		data.get(
			"school_year",
			""
		)
	)


# ============================================================
# GET EMAIL
# ============================================================

func get_student_email(
	data: Dictionary
) -> String:

	return str(
		data.get(
			"email",
			"No email"
		)
	)


# ============================================================
# PROGRESS
# ============================================================

func get_elements_collected(
	data: Dictionary
) -> int:

	var progress_value = data.get(
		"progress",
		{}
	)


	if not progress_value is Dictionary:

		return 0


	var progress: Dictionary = (
		progress_value
	)


	return clamp(
		int(
			progress.get(
				"elements_collected",
				0
			)
		),
		0,
		118
	)


func get_elements_total(
	data: Dictionary
) -> int:

	var progress_value = data.get(
		"progress",
		{}
	)


	if not progress_value is Dictionary:

		return 118


	var progress: Dictionary = (
		progress_value
	)


	var total := int(
		progress.get(
			"elements_total",
			118
		)
	)


	if total <= 0:

		return 118


	return total


func get_student_progress(
	data: Dictionary
) -> float:

	var collected: int = (
		get_elements_collected(
			data
		)
	)


	var total: int = (
		get_elements_total(
			data
		)


	)


	if total <= 0:

		return 0.0


	return clamp(
		float(collected)
		/
		float(total)
		*
		100.0,
		0.0,
		100.0
	)


# ============================================================
# ACTIVITY FILTER
# ============================================================

func get_active_students(
	student_list: Array[Dictionary]
) -> Array[Dictionary]:

	var result: Array[Dictionary] = []


	var current_time := int(
		Time.get_unix_time_from_system()
	)


	for student_data in student_list:

		var last_active := int(
			student_data.get(
				"last_active",
				0
			)
		)


		if last_active <= 0:

			continue


		var elapsed := (
			current_time
			-
			last_active
		)


		if elapsed <= 300:

			result.append(
				student_data
			)


	return result


func get_inactive_students(
	student_list: Array[Dictionary]
) -> Array[Dictionary]:

	var result: Array[Dictionary] = []


	var current_time := int(
		Time.get_unix_time_from_system()
	)


	for student_data in student_list:

		var last_active := int(
			student_data.get(
				"last_active",
				0
			)
		)


		if last_active <= 0:

			result.append(
				student_data
			)

			continue


		var elapsed := (
			current_time
			-
			last_active
		)


		if elapsed > 300:

			result.append(
				student_data
			)


	return result


# ============================================================
# STUDENT ROW
# ============================================================

func setup_student_row(
	row: Control,
	data: Dictionary,
	number: int
) -> void:

	var number_label: Label = row.get_node(
		"MarginContainer/Columns/Control/Number"
	)


	var student_id_label: Label = row.get_node(
		"MarginContainer/Columns/Control/StudentInfo/Control/StudentID"
	)


	var name_label: Label = row.get_node(
		"MarginContainer/Columns/Control/StudentInfo/Control/Name"
	)


	var email_label: Label = row.get_node(
		"MarginContainer/Columns/Control/Email"
	)


	var section_label: Label = row.get_node(
		"MarginContainer/Columns/Control/Section"
	)


	var elements_label: Label = row.get_node(
		"MarginContainer/Columns/Control/Elements"
	)


	var progress_bar: ProgressBar = row.get_node(
		"MarginContainer/Columns/Control/ProgressContainer/ProgressBar"
	)


	var progress_text: Label = row.get_node(
		"MarginContainer/Columns/Control/ProgressContainer/ProgressText"
	)


	var status_label: Label = row.get_node(
		"MarginContainer/Columns/Control/Status"
	)


	var last_active_label: Label = row.get_node(
		"MarginContainer/Columns/Control/LastActive"
	)


	# ========================================================
	# BASIC INFORMATION
	# ========================================================

	var student_name: String = (
		get_student_name(
			data
		)
	)


	var email: String = (
		get_student_email(
			data
		)
	)


	var student_id: String = (
		get_student_id(
			data
		)
	)


	var section: String = (
		get_student_section(
			data
		)
	)


	var school_year: String = (
		get_school_year(
			data
		)
	)


	print(
		"[Dashboard] Row: ",
		student_id,
		" | ",
		student_name,
		" | ",
		section,
		" | ",
		school_year
	)


	# ========================================================
	# NUMBER
	# ========================================================

	number_label.text = (
		"%02d" % number
	)


	# ========================================================
	# INFORMATION
	# ========================================================

	student_id_label.text = student_id

	name_label.text = student_name

	email_label.text = email

	section_label.text = section


	# ========================================================
	# ELEMENT PROGRESS
	# ========================================================

	var collected: int = (
		get_elements_collected(
			data
		)
	)


	var total: int = (
		get_elements_total(
			data
		)
	)


	var progress_percent: float = (
		get_student_progress(
			data
		)
	)


	elements_label.text = (
		"%d / %d"
		%
		[
			collected,
			total
		]
	)


	# ========================================================
	# PROGRESS BAR
	# ========================================================

	progress_bar.min_value = 0

	progress_bar.max_value = 100

	progress_bar.value = (
		progress_percent
	)


	progress_text.text = (
		"%d%%"
		%
		int(
			round(
				progress_percent
			)
		)
	)


	# ========================================================
	# STATUS / LAST ACTIVE
	# ========================================================

	var last_active := int(
		data.get(
			"last_active",
			0
		)
	)


	if last_active <= 0:

		status_label.text = "Inactive"

		last_active_label.text = "Never"

	else:

		var current_time := int(
			Time.get_unix_time_from_system()
		)


		var elapsed := (
			current_time
			-
			last_active
		)


		if elapsed <= 300:

			status_label.text = "Active"

		else:

			status_label.text = "Inactive"


		last_active_label.text = (
			format_last_active(
				last_active
			)
		)


# ============================================================
# FORMAT LAST ACTIVE
# ============================================================

func format_last_active(
	timestamp: int
) -> String:

	if timestamp <= 0:

		return "Never"


	var current_time := int(
		Time.get_unix_time_from_system()
	)


	var elapsed := (
		current_time
		-
		timestamp
	)


	if elapsed < 0:

		return "Just now"


	if elapsed < 60:

		return "Just now"


	if elapsed < 3600:

		var minutes := int(
			elapsed / 60
		)

		return "%d min ago" % minutes


	if elapsed < 86400:

		var hours := int(
			elapsed / 3600
		)

		return "%d hr ago" % hours


	if elapsed < 604800:

		var days := int(
			elapsed / 86400
		)

		return "%d day%s ago" % [
			days,
			"" if days == 1 else "s"
		]


	var datetime := (
		Time.get_datetime_dict_from_unix_time(
			timestamp
		)
	)


	return "%04d-%02d-%02d" % [
		datetime.year,
		datetime.month,
		datetime.day
	]

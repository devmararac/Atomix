
extends Control

signal students_imported


# ============================================================
# UI REFERENCES
# ============================================================

@onready var browse_button: Button = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/DropPanel/VBoxContainer/BrowseButton
@onready var file_label: Label = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/FileLabel
@onready var preview_rows: VBoxContainer = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/PreviewPanel/ScrollContainer/PreviewRows
@onready var status_label: Label = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var cancel_button: Button = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/Buttons/CancelButton
@onready var import_button: Button = $PageBackground/CenterContainer/Panel/MarginContainer/VBoxContainer/Buttons/ImportButton
@onready var file_dialog: FileDialog = $FileDialog


# ============================================================
# DATA
# ============================================================

var imported_students: Array[Dictionary] = []
var is_importing: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	hide()

	import_button.disabled = true

	clear_preview()

	show_status("No students loaded.")


# ============================================================
# BROWSE
# ============================================================

func _on_browse_button_pressed() -> void:
	print("[ImportStudents] Opening CSV file dialog.")
	file_dialog.popup_centered_ratio()


# ============================================================
# FILE SELECTED
# ============================================================

func _on_file_selected(path: String) -> void:
	print("[ImportStudents] Selected file: ", path)

	file_label.text = path.get_file()

	clear_preview()
	imported_students.clear()

	import_button.disabled = true

	show_status("Reading CSV file...")

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		print("[ImportStudents] Failed to open CSV file.")
		show_status("Unable to open the selected CSV file.")
		return

	var csv_text := file.get_as_text()

	file.close()

	if csv_text.strip_edges().is_empty():
		show_status("The CSV file is empty.")
		return

	parse_csv(csv_text)


# ============================================================
# CSV PARSER
# ============================================================

func parse_csv(csv_text: String) -> void:
	var lines := csv_text.split("\n", false)

	if lines.is_empty():
		show_status("No CSV data found.")
		return

	# ========================================================
	# HEADER
	# ========================================================

	var header_line := lines[0].strip_edges()

	var headers := parse_csv_line(header_line)

	if headers.size() < 6:
		show_status("Invalid CSV header. Expected 6 columns.")
		return

	var normalized_headers: Array[String] = []

	for header in headers:
		normalized_headers.append(
			header.strip_edges().to_lower()
		)

	print("[ImportStudents] Headers: ", normalized_headers)


	# ========================================================
	# FIND COLUMN INDEXES
	# ========================================================

	var name_index := find_header(
		normalized_headers,
		[
			"student name",
			"name"
		]
	)

	var id_index := find_header(
		normalized_headers,
		[
			"student id",
			"student_id",
			"id"
		]
	)

	var section_index := find_header(
		normalized_headers,
		[
			"section"
		]
	)

	var email_index := find_header(
		normalized_headers,
		[
			"email"
		]
	)

	var password_index := find_header(
		normalized_headers,
		[
			"password"
		]
	)

	var school_year_index := find_header(
		normalized_headers,
		[
			"school year",
			"school_year",
			"schoolyear"
		]
	)


	# ========================================================
	# HEADER VALIDATION
	# ========================================================

	if name_index == -1:
		show_status("CSV is missing the Student Name column.")
		return

	if id_index == -1:
		show_status("CSV is missing the Student ID column.")
		return

	if section_index == -1:
		show_status("CSV is missing the Section column.")
		return

	if email_index == -1:
		show_status("CSV is missing the Email column.")
		return

	if password_index == -1:
		show_status("CSV is missing the Password column.")
		return

	if school_year_index == -1:
		show_status("CSV is missing the School Year column.")
		return


	# ========================================================
	# STUDENT ROWS
	# ========================================================

	var invalid_count := 0

	for line_index in range(1, lines.size()):

		var line := lines[line_index].strip_edges()

		if line.is_empty():
			continue

		var values := parse_csv_line(line)

		if values.size() < 6:
			print(
				"[ImportStudents] Skipping malformed row: ",
				line_index + 1
			)

			invalid_count += 1
			continue


		var student_data := {
			"name":
				get_csv_value(
					values,
					name_index
				),

			"student_id":
				get_csv_value(
					values,
					id_index
				),

			"section":
				get_csv_value(
					values,
					section_index
				),

			"email":
				get_csv_value(
					values,
					email_index
				),

			"password":
				get_csv_value(
					values,
					password_index
				),

			"school_year":
				get_csv_value(
					values,
					school_year_index
				)
		}


		# ====================================================
		# VALIDATE ROW
		# ====================================================

		if (
			student_data["name"].is_empty()
			or
			student_data["student_id"].is_empty()
			or
			student_data["section"].is_empty()
			or
			student_data["email"].is_empty()
			or
			student_data["password"].is_empty()
			or
			student_data["school_year"].is_empty()
		):

			print(
				"[ImportStudents] Skipping incomplete row: ",
				line_index + 1
			)

			invalid_count += 1
			continue


		# ====================================================
		# ADD VALID STUDENT
		# ====================================================

		imported_students.append(student_data)


	# ========================================================
	# RESULT
	# ========================================================

	print(
		"[ImportStudents] Valid students: ",
		imported_students.size()
	)

	print(
		"[ImportStudents] Invalid students: ",
		invalid_count
	)


	if imported_students.is_empty():
		show_status("No valid student records were found.")
		import_button.disabled = true
		return


	display_preview()

	import_button.disabled = false

	show_status(
		str(imported_students.size())
		+ " student(s) ready to import/update."
	)


# ============================================================
# CSV LINE PARSER
# ============================================================

func parse_csv_line(line: String) -> Array[String]:

	var result: Array[String] = []

	var current := ""

	var inside_quotes := false

	var i := 0

	while i < line.length():

		var character := line[i]

		if character == "\"":

			if (
				inside_quotes
				and
				i + 1 < line.length()
				and
				line[i + 1] == "\""
			):

				current += "\""

				i += 2

				continue

			inside_quotes = not inside_quotes

		elif character == "," and not inside_quotes:

			result.append(
				current.strip_edges()
			)

			current = ""

		else:

			current += character

		i += 1


	result.append(
		current.strip_edges()
	)

	return result


# ============================================================
# FIND HEADER
# ============================================================

func find_header(
	headers: Array[String],
	names: Array[String]
) -> int:

	for i in range(headers.size()):

		for expected_name in names:

			if headers[i] == expected_name:
				return i

	return -1


# ============================================================
# GET CSV VALUE
# ============================================================

func get_csv_value(
	values: Array[String],
	index: int
) -> String:

	if index < 0:
		return ""

	if index >= values.size():
		return ""

	return values[index].strip_edges()


# ============================================================
# DISPLAY PREVIEW
# ============================================================

func display_preview() -> void:

	clear_preview()

	var number := 1

	for student_data in imported_students:

		var panel := PanelContainer.new()

		panel.custom_minimum_size = Vector2(
			0,
			48
		)

		var label := Label.new()

		label.text = (
			str(number)
			+ ". "
			+ str(student_data["student_id"])
			+ "  |  "
			+ str(student_data["name"])
			+ "  |  "
			+ str(student_data["section"])
			+ "  |  "
			+ str(student_data["email"])
			+ "  |  "
			+ str(student_data["school_year"])
		)

		label.add_theme_color_override(
			"font_color",
			Color(
				0.470588,
				0.352941,
				0.235294,
				1
			)
		)

		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		panel.add_child(label)

		preview_rows.add_child(panel)

		number += 1


# ============================================================
# CLEAR PREVIEW
# ============================================================

func clear_preview() -> void:

	for child in preview_rows.get_children():
		child.queue_free()


# ============================================================
# STATUS
# ============================================================

func show_status(message: String) -> void:
	status_label.text = message


# ============================================================
# CANCEL
# ============================================================

func _on_cancel_button_pressed() -> void:

	if is_importing:
		return

	print("[ImportStudents] Cancelled.")

	hide()

	imported_students.clear()

	clear_preview()

	file_label.text = "No file selected."

	import_button.disabled = true

	show_status("No students loaded.")


# ============================================================
# IMPORT
# ============================================================

func _on_import_button_pressed() -> void:

	if is_importing:
		return

	if imported_students.is_empty():

		show_status(
			"No students to import."
		)

		return


	is_importing = true

	browse_button.disabled = true
	import_button.disabled = true
	cancel_button.disabled = true


	var total := imported_students.size()

	var created_count := 0
	var updated_count := 0
	var unchanged_count := 0
	var failed_count := 0


	# ========================================================
	# IMPORT EACH STUDENT
	# ========================================================

	for i in range(total):

		var student_data: Dictionary = imported_students[i]

		show_status(
			"Processing student "
			+ str(i + 1)
			+ " of "
			+ str(total)
			+ "..."
		)

		print(
			"[ImportStudents] Processing: ",
			student_data["name"]
		)


		# ====================================================
		# FIND EXISTING STUDENT
		#
		# IMPORTANT:
		# This DOES NOT use Firebase.Firestore.query().
		# ====================================================

		var existing_student := await find_student_by_id(
			student_data["student_id"]
		)


		# ====================================================
		# EXISTING STUDENT
		# ====================================================

		if not existing_student.is_empty():

			var existing_uid := str(
				existing_student.get(
					"uid",
					""
				)
			)


			if existing_uid.is_empty():

				print(
					"[ImportStudents] Existing student has no UID: ",
					student_data["student_id"]
				)

				failed_count += 1

				continue


			print(
				"[ImportStudents] Existing student found: ",
				student_data["student_id"],
				" | UID: ",
				existing_uid
			)


			var update_result := await update_existing_student(
				existing_uid,
				existing_student,
				student_data
			)


			if update_result == "updated":

				updated_count += 1

			elif update_result == "unchanged":

				unchanged_count += 1

			else:

				failed_count += 1


			continue


		# ====================================================
		# NEW STUDENT
		# ====================================================

		print(
			"[ImportStudents] Student ID not found. Creating: ",
			student_data["name"]
		)


		var auth_result := await create_firebase_account(
			student_data["email"],
			student_data["password"]
		)


		# ====================================================
		# NEW ACCOUNT CREATED
		# ====================================================

		if not auth_result.is_empty():

			var uid := str(
				auth_result.get(
					"localId",
					""
				)
			)


			if uid.is_empty():

				print(
					"[ImportStudents] Firebase did not return UID."
				)

				failed_count += 1

				continue


			var firestore_success := await create_student_document(
				uid,
				student_data["name"],
				student_data["student_id"],
				student_data["section"],
				student_data["email"],
				student_data["school_year"]
			)


			if firestore_success:

				created_count += 1

			else:

				failed_count += 1


			continue


		# ====================================================
		# EMAIL ALREADY EXISTS
		# ====================================================

		if await firebase_email_exists(
			student_data["email"]
		):

			print(
				"[ImportStudents] Firebase account already exists: ",
				student_data["email"]
			)


			var existing_email_student := await find_student_by_email(
				student_data["email"]
			)


			if not existing_email_student.is_empty():

				var email_uid := str(
					existing_email_student.get(
						"uid",
						""
					)
				)


				if not email_uid.is_empty():

					var email_update_result := await update_existing_student(
						email_uid,
						existing_email_student,
						student_data
					)


					if email_update_result == "updated":

						updated_count += 1

					elif email_update_result == "unchanged":

						unchanged_count += 1

					else:

						failed_count += 1

				else:

					print(
						"[ImportStudents] Existing email has no UID."
					)

					failed_count += 1

			else:

				print(
					"[ImportStudents] Email exists in Auth but no matching Firestore student was found: ",
					student_data["email"]
				)

				failed_count += 1

		else:

			print(
				"[ImportStudents] Failed to create account: ",
				student_data["email"]
			)

			failed_count += 1


	# ========================================================
	# COMPLETE
	# ========================================================

	is_importing = false

	browse_button.disabled = false
	cancel_button.disabled = false


	var changed_count := (
		created_count
		+
		updated_count
	)


	if (
		changed_count > 0
		and
		failed_count == 0
	):

		show_status(
			str(created_count)
			+ " created. "
			+ str(updated_count)
			+ " updated. "
			+ str(unchanged_count)
			+ " unchanged."
		)

	elif changed_count > 0:

		show_status(
			str(created_count)
			+ " created. "
			+ str(updated_count)
			+ " updated. "
			+ str(unchanged_count)
			+ " unchanged. "
			+ str(failed_count)
			+ " failed."
		)

	elif unchanged_count > 0 and failed_count == 0:

		show_status(
			"Nothing new to update. "
			+ str(unchanged_count)
			+ " student(s) unchanged."
		)

	else:

		show_status(
			"No students were changed. "
			+ str(failed_count)
			+ " failed."
		)


	print("[ImportStudents] Import complete.")
	print("[ImportStudents] Created: ", created_count)
	print("[ImportStudents] Updated: ", updated_count)
	print("[ImportStudents] Unchanged: ", unchanged_count)
	print("[ImportStudents] Failed: ", failed_count)


	if changed_count > 0:

		students_imported.emit()

		imported_students.clear()

		clear_preview()

		file_label.text = "No file selected."

		import_button.disabled = true

	else:

		import_button.disabled = false


# ============================================================
# FIREBASE AUTH - CREATE ACCOUNT
# ============================================================

func create_firebase_account(
	email: String,
	password: String
) -> Dictionary:

	var http := HTTPRequest.new()

	add_child(http)

	var url: String = (
		"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="
		+
		FirebaseConfig.FIREBASE_API_KEY
	)

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var body := JSON.stringify({
		"email": email,
		"password": password,
		"returnSecureToken": true
	})

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:

		print(
			"[ImportStudents] HTTP request failed: ",
			error
		)

		http.queue_free()

		return {}


	var response: Array = (
		await http.request_completed
	)

	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text := (
		response_body.get_string_from_utf8()
	)

	print(
		"[ImportStudents] Firebase Auth response: ",
		response_code
	)


	var json := JSON.new()

	var parse_error := json.parse(
		response_text
	)


	if parse_error != OK:

		print(
			"[ImportStudents] Invalid Firebase response."
		)

		http.queue_free()

		return {}


	var data = json.data


	if response_code != 200:

		print(
			"[ImportStudents] Firebase Auth error: ",
			data
		)

		if data is Dictionary:

			if data.has("error"):

				print(
					"[ImportStudents] Error details: ",
					data["error"]
				)

		http.queue_free()

		return {}


	http.queue_free()


	if data is Dictionary:
		return data

	return {}


# ============================================================
# CHECK IF EMAIL EXISTS
# ============================================================

func firebase_email_exists(
	email: String
) -> bool:

	var http := HTTPRequest.new()

	add_child(http)

	var url: String = (
		"https://identitytoolkit.googleapis.com/v1/accounts:createAuthUri?key="
		+
		FirebaseConfig.FIREBASE_API_KEY
	)

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var body := JSON.stringify({
		"identifier": email,
		"continueUri": "http://localhost"
	})

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)


	if error != OK:

		print(
			"[ImportStudents] Email existence check failed: ",
			error
		)

		http.queue_free()

		return false


	var response: Array = (
		await http.request_completed
	)

	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text := (
		response_body.get_string_from_utf8()
	)

	http.queue_free()


	if response_code != 200:
		return false


	var json := JSON.new()

	var parse_error := json.parse(
		response_text
	)


	if parse_error != OK:
		return false


	var data = json.data


	if not data is Dictionary:
		return false


	return bool(
		data.get(
			"registered",
			false
		)
	)


# ============================================================
# FIRESTORE REST - GET ALL STUDENTS
#
# This replaces Firebase.Firestore.query().
# ============================================================

func get_all_students_rest() -> Array:

	var http := HTTPRequest.new()

	add_child(http)


	# Make sure we have authentication.
	var auth_data: Dictionary = Firebase.Firestore.auth


	if auth_data.is_empty():

		print(
			"[ImportStudents] No Firestore authentication."
		)

		Firebase.Auth.login_anonymous()

		var auth_result: Array = (
			await Firebase.Auth.auth_request
		)


		if (
			auth_result.is_empty()
			or
			auth_result[0] != 1
		):

			print(
				"[ImportStudents] Anonymous authentication failed."
			)

			http.queue_free()

			return []


		auth_data = Firebase.Firestore.auth


	if not auth_data.has("idtoken"):

		print(
			"[ImportStudents] Firebase authentication has no idtoken."
		)

		http.queue_free()

		return []


	# ========================================================
	# FIRESTORE PROJECT ID
	# ========================================================

	var project_id := get_firebase_project_id()

	if project_id.is_empty():

		print(
			"[ImportStudents] Could not determine Firebase Project ID."
		)

		http.queue_free()

		return []


	var database_name := "(default)"


	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+
		project_id
		+
		"/databases/"
		+
		database_name
		+
		"/documents/students"
	)


	var headers := PackedStringArray([
		"Authorization: Bearer "
		+
		str(auth_data["idtoken"]),

		"Content-Type: application/json"
	])


	print(
		"[ImportStudents] REST GET students collection."
	)


	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)


	if error != OK:

		print(
			"[ImportStudents] Firestore REST request failed: ",
			error
		)

		http.queue_free()

		return []


	var response: Array = (
		await http.request_completed
	)

	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text := (
		response_body.get_string_from_utf8()
	)


	http.queue_free()


	print(
		"[ImportStudents] Firestore REST response: ",
		response_code
	)


	if response_code != 200:

		print(
			"[ImportStudents] Firestore REST error: ",
			response_text
		)

		return []


	var json := JSON.new()

	var parse_error := json.parse(
		response_text
	)


	if parse_error != OK:

		print(
			"[ImportStudents] Invalid Firestore REST response."
		)

		return []


	var data = json.data


	if not data is Dictionary:
		return []


	var documents: Array = data.get(
		"documents",
		[]
	)


	return documents


# ============================================================
# GET FIREBASE PROJECT ID
# ============================================================

func get_firebase_project_id() -> String:

	# Most GodotFirebase configurations use projectId.
	# We first try FirebaseConfig.PROJECT_ID through the
	# config dictionary exposed by the Firebase singleton.

	if Firebase.Firestore._config.has("projectId"):

		return str(
			Firebase.Firestore._config["projectId"]
		)


	# Fallback: try common FirebaseConfig names.
	var config_script = FirebaseConfig


	if "FIREBASE_PROJECT_ID" in config_script:

		return str(
			config_script.FIREBASE_PROJECT_ID
		)


	if "PROJECT_ID" in config_script:

		return str(
			config_script.PROJECT_ID
		)


	print(
		"[ImportStudents] Firebase Project ID not found."
	)

	return ""


# ============================================================
# FIRESTORE REST VALUE DECODER
# ============================================================

func decode_firestore_value(
	value: Dictionary
):

	if value.has("stringValue"):
		return str(value["stringValue"])

	if value.has("integerValue"):
		return int(value["integerValue"])

	if value.has("doubleValue"):
		return float(value["doubleValue"])

	if value.has("booleanValue"):
		return bool(value["booleanValue"])

	if value.has("nullValue"):
		return null

	if value.has("timestampValue"):
		return str(value["timestampValue"])

	if value.has("referenceValue"):
		return str(value["referenceValue"])

	if value.has("geoPointValue"):

		return value["geoPointValue"]

	if value.has("bytesValue"):
		return str(value["bytesValue"])

	if value.has("arrayValue"):

		var array_result: Array = []

		var array_data: Dictionary = (
			value["arrayValue"]
		)

		var values: Array = array_data.get(
			"values",
			[]
		)

		for item in values:

			if item is Dictionary:

				array_result.append(
					decode_firestore_value(item)
				)

		return array_result


	if value.has("mapValue"):

		var map_result: Dictionary = {}

		var map_data: Dictionary = (
			value["mapValue"]
		)

		var fields: Dictionary = map_data.get(
			"fields",
			{}
		)

		for key in fields.keys():

			var field_value = fields[key]

			if field_value is Dictionary:

				map_result[key] = (
					decode_firestore_value(
						field_value
					)
				)

		return map_result


	return null


# ============================================================
# FIRESTORE REST DOCUMENT DECODER
# ============================================================

func decode_firestore_document(
	document: Dictionary
) -> Dictionary:

	var result: Dictionary = {}

	var fields: Dictionary = document.get(
		"fields",
		{}
	)


	for field_name in fields.keys():

		var field_value = fields[field_name]

		if field_value is Dictionary:

			result[field_name] = (
				decode_firestore_value(
					field_value
				)
			)


	# ========================================================
	# DOCUMENT NAME
	# ========================================================

	var document_name := str(
		document.get(
			"name",
			""
		)
	)


	if not document_name.is_empty():

		var parts := document_name.split("/")

		if not parts.is_empty():

			result["uid"] = parts[parts.size() - 1]


	return result


# ============================================================
# FIND STUDENT BY STUDENT ID
#
# NO Firebase.Firestore.query().
# ============================================================

func find_student_by_id(
	student_id: String
) -> Dictionary:

	print(
		"[ImportStudents] Searching student ID: ",
		student_id
	)


	var documents := await get_all_students_rest()


	if documents.is_empty():

		print(
			"[ImportStudents] No student documents returned."
		)

		return {}


	var target_id := (
		student_id
		.strip_edges()
	)


	for document in documents:

		if not document is Dictionary:
			continue


		var data := decode_firestore_document(
			document
		)


		var found_id := str(
			data.get(
				"student_id",
				""
			)
		).strip_edges()


		if found_id == target_id:

			print(
				"[ImportStudents] Student found: ",
				student_id,
				" | UID: ",
				data.get(
					"uid",
					""
				)
			)

			return data


	print(
		"[ImportStudents] Student ID not found: ",
		student_id
	)

	return {}


# ============================================================
# FIND STUDENT BY EMAIL
#
# NO Firebase.Firestore.query().
# ============================================================

func find_student_by_email(
	email: String
) -> Dictionary:

	print(
		"[ImportStudents] Searching student email: ",
		email
	)


	var documents := await get_all_students_rest()


	if documents.is_empty():

		print(
			"[ImportStudents] No student documents returned."
		)

		return {}


	var target_email := (
		email
		.strip_edges()
		.to_lower()
	)


	for document in documents:

		if not document is Dictionary:
			continue


		var data := decode_firestore_document(
			document
		)


		var stored_email := str(
			data.get(
				"email",
				""
			)
		).strip_edges().to_lower()


		if stored_email == target_email:

			print(
				"[ImportStudents] Student found by email: ",
				email,
				" | UID: ",
				data.get(
					"uid",
					""
				)
			)

			return data


	print(
		"[ImportStudents] Student email not found: ",
		email
	)

	return {}


# ============================================================
# FIRESTORE REST - PATCH DOCUMENT
# ============================================================

func firestore_patch_document(
	collection_name: String,
	document_id: String,
	data: Dictionary
) -> bool:

	var http := HTTPRequest.new()

	add_child(http)


	var auth_data: Dictionary = Firebase.Firestore.auth


	if auth_data.is_empty():

		Firebase.Auth.login_anonymous()

		var auth_result: Array = (
			await Firebase.Auth.auth_request
		)


		if (
			auth_result.is_empty()
			or
			auth_result[0] != 1
		):

			print(
				"[ImportStudents] Authentication failed."
			)

			http.queue_free()

			return false


		auth_data = Firebase.Firestore.auth


	if not auth_data.has("idtoken"):

		print(
			"[ImportStudents] No Firebase ID token."
		)

		http.queue_free()

		return false


	var project_id := get_firebase_project_id()


	if project_id.is_empty():

		http.queue_free()

		return false


	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+
		project_id
		+
		"/databases/(default)/documents/"
		+
		collection_name
		+
		"/"
		+
		document_id
	)


	var headers := PackedStringArray([
		"Authorization: Bearer "
		+
		str(auth_data["idtoken"]),

		"Content-Type: application/json"
	])


	var firestore_fields := Utilities.dict2fields(
		data
	)


	var update_mask: Array[String] = []

	for field_name in data.keys():
		update_mask.append(str(field_name))


	var update_mask_query := ""

	for field_path in update_mask:

		if not update_mask_query.is_empty():
			update_mask_query += "&"

		update_mask_query += (
			"updateMask.fieldPaths="
			+
			field_path.uri_encode()
		)


	var url_with_mask := url

	if not update_mask_query.is_empty():
		url_with_mask += "?" + update_mask_query


	var body := JSON.stringify({
		"fields": firestore_fields.fields
	})


	print(
		"[ImportStudents] PATCH ",
		collection_name,
		"/",
		document_id
	)


	var error := http.request(
		url_with_mask,
		headers,
		HTTPClient.METHOD_PATCH,
		body
	)


	if error != OK:

		print(
			"[ImportStudents] PATCH request failed: ",
			error
		)

		http.queue_free()

		return false


	var response: Array = (
		await http.request_completed
	)

	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text := (
		response_body.get_string_from_utf8()
	)


	http.queue_free()


	print(
		"[ImportStudents] PATCH response: ",
		response_code
	)


	if response_code < 200 or response_code >= 300:

		print(
			"[ImportStudents] PATCH error: ",
			response_text
		)

		return false


	return true


# ============================================================
# UPDATE EXISTING STUDENT
# ============================================================

func update_existing_student(
	uid: String,
	existing_student: Dictionary,
	csv_student: Dictionary
) -> String:

	print(
		"[ImportStudents] Updating student: ",
		csv_student["student_id"]
	)


	# ========================================================
	# DETECT CHANGES
	# ========================================================

	var changed := false


	if str(
		existing_student.get(
			"name",
			""
		)
	) != str(csv_student["name"]):

		changed = true


	if str(
		existing_student.get(
			"section",
			""
		)
	) != str(csv_student["section"]):

		changed = true


	if str(
		existing_student.get(
			"email",
			""
		)
	) != str(csv_student["email"]):

		changed = true


	if str(
		existing_student.get(
			"school_year",
			""
		)
	) != str(csv_student["school_year"]):

		changed = true


	if not changed:

		print(
			"[ImportStudents] No new data for: ",
			csv_student["student_id"]
		)

		return "unchanged"


	# ========================================================
	# USERS DOCUMENT
	# ========================================================

	var user_update := {
		"name":
			csv_student["name"],

		"email":
			csv_student["email"],

		"school_year":
			csv_student["school_year"],

		"role":
			"student",

		"status":
			"active"
	}


	print(
		"[ImportStudents] Updating users document: ",
		uid
	)


	var users_success := await firestore_patch_document(
		"users",
		uid,
		user_update
	)


	if not users_success:

		print(
			"[ImportStudents] Failed to update users document."
		)

		return "failed"


	# ========================================================
	# STUDENTS DOCUMENT
	# ========================================================

	var student_update := {

		"uid":
			uid,

		"name":
			csv_student["name"],

		"email":
			csv_student["email"],

		"role":
			"student",

		"student_id":
			csv_student["student_id"],

		"grade_level":
			"11",

		"section":
			csv_student["section"],

		"school_year":
			csv_student["school_year"],

		"status":
			"active"
	}


	print(
		"[ImportStudents] Updating students document: ",
		uid
	)


	var students_success := await firestore_patch_document(
		"students",
		uid,
		student_update
	)


	if not students_success:

		print(
			"[ImportStudents] Failed to update students document."
		)

		return "failed"


	print(
		"[ImportStudents] Student updated successfully: ",
		csv_student["name"]
	)


	return "updated"


# ============================================================
# FIRESTORE CREATE
# ============================================================

func create_student_document(
	uid: String,
	student_name: String,
	student_id: String,
	section: String,
	email: String,
	school_year: String
) -> bool:

	var timestamp := int(
		Time.get_unix_time_from_system()
	)


	# ========================================================
	# USERS DOCUMENT
	# ========================================================

	var user_data := {

		"name":
			student_name,

		"email":
			email,

		"role":
			"student",

		"status":
			"active",

		"school_year":
			school_year,

		"created_at":
			timestamp,

		"last_active":
			0
	}


	print(
		"[ImportStudents] Creating users document: ",
		uid
	)


	var users_success := await firestore_create_document(
		"users",
		uid,
		user_data
	)


	if not users_success:

		print(
			"[ImportStudents] Failed to create users document."
		)

		return false


	# ========================================================
	# STUDENTS DOCUMENT
	# ========================================================

	var student_data := {

		"uid":
			uid,

		"name":
			student_name,

		"email":
			email,

		"role":
			"student",

		"student_id":
			student_id,

		"grade_level":
			"11",

		"section":
			section,

		"school_year":
			school_year,

		"status":
			"active",

		"created_at":
			timestamp,

		"last_active":
			0,


		# ====================================================
		# STUDENT PROGRESS
		# ====================================================

		"progress": {

			"elements_total":
				118,

			"elements_collected":
				0,

			"collected_elements":
				[],

			"overall_percentage":
				0.0
		},


		# ====================================================
		# LESSON PROGRESS
		# ====================================================

		"lesson_progress":
			{},


		# ====================================================
		# ASSESSMENT
		# ====================================================

		"assessment": {

			"total_assessments":
				0,

			"completed_assessments":
				0,

			"average_score":
				0.0,

			"latest_score":
				0.0
		},


		# ====================================================
		# ACADEMIC HISTORY
		# ====================================================

		"academic_history":
			{},


		# ====================================================
		# GAME STATE
		# ====================================================

		"game_state": {

			"has_save":
				false,

			"current_scene":
				"res://Scenes/Areas/start_map.tscn",

			"player_position": {

				"x":
					0.0,

				"y":
					0.0
			},

			"coins":
				0,

			"active_index":
				0,

			"party":
				[],

			"inventory":
				[],

			"quest_data":
				{}
		}
	}


	print(
		"[ImportStudents] Creating students document: ",
		uid
	)


	var students_success := await firestore_create_document(
		"students",
		uid,
		student_data
	)


	if not students_success:

		print(
			"[ImportStudents] Failed to create students document."
		)

		return false


	print(
		"[ImportStudents] Student document created: ",
		student_name
	)


	return true


# ============================================================
# FIRESTORE REST - CREATE DOCUMENT
# ============================================================

func firestore_create_document(
	collection_name: String,
	document_id: String,
	data: Dictionary
) -> bool:

	var http := HTTPRequest.new()

	add_child(http)


	var auth_data: Dictionary = Firebase.Firestore.auth


	if auth_data.is_empty():

		Firebase.Auth.login_anonymous()

		var auth_result: Array = (
			await Firebase.Auth.auth_request
		)


		if (
			auth_result.is_empty()
			or
			auth_result[0] != 1
		):

			print(
				"[ImportStudents] Authentication failed."
			)

			http.queue_free()

			return false


		auth_data = Firebase.Firestore.auth


	if not auth_data.has("idtoken"):

		http.queue_free()

		return false


	var project_id := get_firebase_project_id()


	if project_id.is_empty():

		http.queue_free()

		return false


	var url := (
		"https://firestore.googleapis.com/v1/projects/"
		+
		project_id
		+
		"/databases/(default)/documents/"
		+
		collection_name
		+
		"?documentId="
		+
		document_id.uri_encode()
	)


	var headers := PackedStringArray([
		"Authorization: Bearer "
		+
		str(auth_data["idtoken"]),

		"Content-Type: application/json"
	])


	var firestore_fields := Utilities.dict2fields(
		data
	)


	var body := JSON.stringify({
		"fields":
			firestore_fields.fields
	})


	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)


	if error != OK:

		print(
			"[ImportStudents] Create document request failed: ",
			error
		)

		http.queue_free()

		return false


	var response: Array = (
		await http.request_completed
	)

	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text := (
		response_body.get_string_from_utf8()
	)


	http.queue_free()


	print(
		"[ImportStudents] Create document response: ",
		response_code
	)


	if response_code < 200 or response_code >= 300:

		print(
			"[ImportStudents] Create document error: ",
			response_text
		)

		return false


	return true

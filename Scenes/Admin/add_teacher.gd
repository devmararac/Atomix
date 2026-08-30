
extends Control

signal teacher_created


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var name_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/NameInput
@onready var email_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/EmailInput
@onready var password_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/PasswordInput
@onready var school_year_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/SchoolYearInput
@onready var sections_input: LineEdit = $FormPanel/MarginContainer/VBoxContainer/SectionsInput

@onready var create_button: Button = $FormPanel/MarginContainer/VBoxContainer/ButtonContainer/CreateButton
@onready var cancel_button: Button = $FormPanel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton

@onready var status_label: Label = $FormPanel/MarginContainer/VBoxContainer/StatusLabel


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	print("[AddTeacher] Add Teacher form opened.")


# ============================================================
# CREATE BUTTON
# ============================================================

func _on_create_button_pressed() -> void:

	status_label.text = "Creating teacher..."

	create_button.disabled = true
	cancel_button.disabled = true

	# --------------------------------------------------------
	# Get form values
	# Explicit String types prevent Godot inference errors.
	# --------------------------------------------------------

	var teacher_name: String = str(
		name_input.text
	).strip_edges()

	var email: String = str(
		email_input.text
	).strip_edges()

	var password: String = str(
		password_input.text
	)

	var school_year: String = str(
		school_year_input.text
	).strip_edges()

	var sections_text: String = str(
		sections_input.text
	).strip_edges()


	# --------------------------------------------------------
	# Parse assigned sections
	#
	# Example:
	# 11-A, 11-B, 11-C
	# --------------------------------------------------------

	var assigned_sections: Array = []

	if not sections_text.is_empty():

		var section_parts: PackedStringArray = (
			sections_text.split(",")
		)

		for section_part: String in section_parts:

			var cleaned_section: String = (
				section_part.strip_edges()
			)

			if not cleaned_section.is_empty():

				assigned_sections.append(
					cleaned_section
				)


	# --------------------------------------------------------
	# Create teacher
	# --------------------------------------------------------

	var success: bool = await create_teacher(
		teacher_name,
		email,
		password,
		school_year,
		assigned_sections
	)


	if success:

		status_label.text = "Teacher created successfully!"

		print(
			"[AddTeacher] Teacher creation completed."
		)

		teacher_created.emit()

		await get_tree().create_timer(
			0.5
		).timeout

		queue_free()

	else:

		status_label.text = "Failed to create teacher."

		create_button.disabled = false
		cancel_button.disabled = false


# ============================================================
# CANCEL
# ============================================================

func _on_cancel_button_pressed() -> void:

	print(
		"[AddTeacher] Cancelled."
	)

	queue_free()


# ============================================================
# CREATE FIREBASE AUTHENTICATION ACCOUNT
# ============================================================

func create_firebase_account(
	email: String,
	password: String
	) -> Dictionary:

	var http := HTTPRequest.new()

	add_child(http)

	var url: String = (
		"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="
		+ FirebaseConfig.FIREBASE_API_KEY
	)

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var body := JSON.stringify({
		"email": email,
		"password": password,
		"returnSecureToken": true
	})

	print(
		"[AddTeacher] Creating Firebase Authentication account..."
	)

	var error: int = http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:

		print(
			"[AddTeacher] HTTP request failed: ",
			error
		)

		http.queue_free()

		return {}


	var response: Array = await http.request_completed

	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text: String = (
		response_body.get_string_from_utf8()
	)

	print(
		"[AddTeacher] Firebase Auth response: ",
		response_code
	)


	var json := JSON.new()

	var parse_error: int = json.parse(
		response_text
	)

	if parse_error != OK:

		print(
			"[AddTeacher] Invalid Firebase response."
		)

		http.queue_free()

		return {}


	var data = json.data

	if response_code != 200:

		print(
			"[AddTeacher] Firebase Auth error: ",
			data
		)

		http.queue_free()

		return {}


	http.queue_free()

	return data


# ============================================================
# CREATE TEACHER
# ============================================================

func create_teacher(
	teacher_name: String,
	email: String,
	password: String,
	school_year: String,
	assigned_sections: Array
	) -> bool:

	teacher_name = teacher_name.strip_edges()
	email = email.strip_edges()
	school_year = school_year.strip_edges()


	# ========================================================
	# VALIDATION
	# ========================================================

	if teacher_name.is_empty():

		print(
			"[AddTeacher] Teacher name is empty."
		)

		return false


	if email.is_empty():

		print(
			"[AddTeacher] Email is empty."
		)

		return false


	if password.is_empty():

		print(
			"[AddTeacher] Password is empty."
		)

		return false


	if password.length() < 6:

		print(
			"[AddTeacher] Password must be at least 6 characters."
		)

		return false


	if school_year.is_empty():

		print(
			"[AddTeacher] School year is empty."
		)

		return false


	# ========================================================
	# CREATE FIREBASE AUTH ACCOUNT
	# ========================================================

	print(
		"[AddTeacher] Creating teacher: ",
		teacher_name
	)

	var auth_result: Dictionary = (
		await create_firebase_account(
			email,
			password
		)
	)


	if auth_result.is_empty():

		print(
			"[AddTeacher] Failed to create Firebase account."
		)

		return false


	# Firebase returns the UID as "localId".

	var uid: String = str(
		auth_result.get(
			"localId",
			""
		)
	)


	if uid.is_empty():

		print(
			"[AddTeacher] Firebase did not return a UID."
		)

		return false


	print(
		"[AddTeacher] Teacher UID: ",
		uid
	)


	# ========================================================
	# TIMESTAMP
	# ========================================================

	var timestamp: int = int(
		Time.get_unix_time_from_system()
	)


	# ========================================================
	# USERS DOCUMENT
	# ========================================================

	var user_data: Dictionary = {

		"name":
			teacher_name,

		"email":
			email,

		"role":
			"teacher",

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
		"[AddTeacher] Creating users document: ",
		uid
	)


	var users_success: bool = (
		await firestore_create_document(
			"users",
			uid,
			user_data
		)
	)


	if not users_success:

		print(
			"[AddTeacher] Failed to create users document."
		)

		return false


	# ========================================================
	# TEACHERS DOCUMENT
	# ========================================================

	var teacher_data: Dictionary = {

		"uid":
			uid,

		"name":
			teacher_name,

		"email":
			email,

		"role":
			"teacher",

		"status":
			"active",

		"school_year":
			school_year,

		"assigned_sections":
			assigned_sections,

		"created_at":
			timestamp,

		"last_active":
			0
	}


	print(
		"[AddTeacher] Creating teachers document: ",
		uid
	)


	var teachers_success: bool = (
		await firestore_create_document(
			"teachers",
			uid,
			teacher_data
		)
	)


	if not teachers_success:

		print(
			"[AddTeacher] Failed to create teachers document."
		)

		return false


	# ========================================================
	# SUCCESS
	# ========================================================

	print(
		"[AddTeacher] ================================="
	)

	print(
		"[AddTeacher] Teacher created successfully!"
	)

	print(
		"[AddTeacher] Name: ",
		teacher_name
	)

	print(
		"[AddTeacher] Email: ",
		email
	)

	print(
		"[AddTeacher] UID: ",
		uid
	)

	print(
		"[AddTeacher] School Year: ",
		school_year
	)

	print(
		"[AddTeacher] Assigned Sections: ",
		assigned_sections
	)

	print(
		"[AddTeacher] ================================="
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


	# ========================================================
	# FIRESTORE AUTHENTICATION
	# ========================================================

	var auth_data: Dictionary = Firebase.Firestore.auth

	if auth_data.is_empty():

		print(
			"[AddTeacher] Firestore authentication is missing."
		)

		http.queue_free()

		return false


	if not auth_data.has("idtoken"):

		print(
			"[AddTeacher] Firebase ID token is missing."
		)

		http.queue_free()

		return false


	var id_token: String = str(
		auth_data["idtoken"]
	)


	# ========================================================
	# PROJECT ID
	# ========================================================

	var project_id: String = ""

	if Firebase.Firestore._config.has(
		"projectId"
	):

		project_id = str(
			Firebase.Firestore._config[
				"projectId"
			]
		)


	if project_id.is_empty():

		print(
			"[AddTeacher] Firebase Project ID not found."
		)

		http.queue_free()

		return false


	# ========================================================
	# FIRESTORE REST URL
	# ========================================================

	var url: String = (
		"https://firestore.googleapis.com/v1/projects/"
		+ project_id
		+ "/databases/(default)/documents/"
		+ collection_name
		+ "/"
		+ document_id
	)


	# ========================================================
	# ENCODE FIRESTORE FIELDS
	# ========================================================

	var firestore_fields: Dictionary = (
		_encode_firestore_fields(data)
	)


	var request_body: String = JSON.stringify({
		"fields":
			firestore_fields
	})


	var headers := PackedStringArray([
		"Authorization: Bearer " + id_token,
		"Content-Type: application/json"
	])


	print(
		"[AddTeacher] Creating ",
		collection_name,
		"/",
		document_id
	)


	# ========================================================
	# SEND REQUEST
	# ========================================================

	var error: int = http.request(
		url,
		headers,
		HTTPClient.METHOD_PATCH,
		request_body
	)


	if error != OK:

		print(
			"[AddTeacher] Firestore request failed: ",
			error
		)

		http.queue_free()

		return false


	var response: Array = (
		await http.request_completed
	)


	var response_code: int = response[1]

	var response_body: PackedByteArray = response[3]

	var response_text: String = (
		response_body.get_string_from_utf8()
	)


	print(
		"[AddTeacher] Firestore response: ",
		response_code
	)


	if response_code < 200 or response_code >= 300:

		print(
			"[AddTeacher] Firestore error: ",
			response_text
		)

		http.queue_free()

		return false


	http.queue_free()

	return true


# ============================================================
# FIRESTORE FIELD ENCODER
# ============================================================

func _encode_firestore_fields(
	data: Dictionary
	) -> Dictionary:

	var fields: Dictionary = {}

	for key in data:

		fields[key] = (
			_encode_firestore_value(
				data[key]
			)
		)

	return fields


# ============================================================
# FIRESTORE VALUE ENCODER
# ============================================================

func _encode_firestore_value(
	value: Variant
	) -> Dictionary:

	if value is String:

		return {
			"stringValue":
				str(value)
		}


	if value is bool:

		return {
			"booleanValue":
				value
		}


	if value is int:

		return {
			"integerValue":
				str(value)
		}


	if value is float:

		return {
			"doubleValue":
				value
		}


	if value is Array:

		var values: Array = []

		for item in value:

			values.append(
				_encode_firestore_value(
					item
				)
			)

		return {
			"arrayValue": {
				"values": values
			}
		}


	if value is Dictionary:

		return {
			"mapValue": {
				"fields":
					_encode_firestore_fields(
						value
					)
			}
		}


	if value == null:

		return {
			"nullValue":
				null
		}


	return {
		"stringValue":
			str(value)
	}

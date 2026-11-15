
extends Node

const CLOUD_NAME := "ymiefwgl"
const UPLOAD_PRESET := "atomix_unsigned"

const MAX_CONVERSION_ATTEMPTS := 30
const CONVERSION_CHECK_INTERVAL := 2.0

const OFFICE_EXTENSIONS := [
	"doc", "docx",
	"ppt", "pptx",
	"xls", "xlsx"
]

const IMAGE_EXTENSIONS := [
	"png", "jpg", "jpeg", "webp"
]


func upload_file(
	file_path: String,
	callback_node: Node,
	callback_method: String
) -> void:
	_upload_file_async(file_path, callback_node, callback_method)


func _upload_file_async(
	file_path: String,
	callback_node: Node,
	callback_method: String
) -> void:

	if not FileAccess.file_exists(file_path):
		_finish(callback_node, callback_method, false, "File not found.")
		return

	var file := FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		_finish(callback_node, callback_method, false, "Unable to read file.")
		return

	var file_bytes := file.get_buffer(file.get_length())
	file.close()

	var file_name := file_path.uri_decode().get_file()

	print("[CloudinaryUploader] Normalized filename: ", file_name)
	
	var extension := file_path.get_extension().to_lower()

	if extension not in OFFICE_EXTENSIONS \
	and extension not in IMAGE_EXTENSIONS \
	and extension != "pdf":

		_finish(
			callback_node,
			callback_method,
			false,
			"Unsupported file format: " + extension
		)
		return

	var resource_type := "raw"

	# Images and PDFs use Cloudinary's image resource type.
	if extension in IMAGE_EXTENSIONS or extension == "pdf":
		resource_type = "image"

	var public_id := file_name

	if resource_type == "image":
		public_id = file_name.get_basename()

	# Replace characters that Cloudinary does not allow in public IDs.
	var invalid_characters := [
		"?", "&", "#", "\\", "%", "<", ">", "+"
	]

	for invalid_character in invalid_characters:
		public_id = public_id.replace(invalid_character, "_")

	public_id = public_id.strip_edges()

	print("[CloudinaryUploader] Safe public ID: ", public_id)

	var upload_url := (
		"https://api.cloudinary.com/v1_1/"
		+ CLOUD_NAME
		+ "/"
		+ resource_type
		+ "/upload"
	)

	var boundary := "----AtomixBoundary" + str(Time.get_ticks_usec())
	var body := PackedByteArray()

	_add_field(body, boundary, "upload_preset", UPLOAD_PRESET)
	_add_field(body, boundary, "public_id", public_id)

	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())

	body.append_array((
		"Content-Disposition: form-data; name=\"file\"; filename=\""
		+ file_name
		+ "\"\r\n"
	).to_utf8_buffer())

	body.append_array(
		"Content-Type: application/octet-stream\r\n\r\n".to_utf8_buffer()
	)

	body.append_array(file_bytes)
	body.append_array("\r\n".to_utf8_buffer())
	body.append_array(("--" + boundary + "--\r\n").to_utf8_buffer())

	var http := HTTPRequest.new()
	add_child(http)

	var headers := [
		"Content-Type: multipart/form-data; boundary=" + boundary
	]

	var request_error := http.request_raw(
		upload_url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if request_error != OK:
		http.queue_free()
		_finish(
			callback_node,
			callback_method,
			false,
			"Could not start Cloudinary upload."
		)
		return

	var response: Array = await http.request_completed
	http.queue_free()

	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	if response_code != 200 and response_code != 201:
		_finish(
			callback_node,
			callback_method,
			false,
			"Cloudinary upload failed: "
			+ response_body.get_string_from_utf8()
		)
		return

	var data = JSON.parse_string(response_body.get_string_from_utf8())
	
	print("[CloudinaryUploader] Upload response:")
	print(JSON.stringify(data, "\t"))

	var conversion_info: Variant = data.get("info", {})
	if conversion_info is Dictionary:
		print(
			"[CloudinaryUploader] Conversion information: ",
			JSON.stringify(conversion_info, "\t")
		)
	
	if not data is Dictionary:
		_finish(
			callback_node,
			callback_method,
			false,
			"Invalid Cloudinary response."
		)
		return

	var version := int(data.get("version", 0))

	if version <= 0:
		_finish(
			callback_node,
			callback_method,
			false,
			"Cloudinary did not return an asset version."
		)
		return
		
	var encoded_public_id := public_id.uri_encode()

	var pdf_url := ""

	if extension == "pdf":
		pdf_url = str(data.get("secure_url", ""))

	elif extension in OFFICE_EXTENSIONS:
		pdf_url = (
			"https://res.cloudinary.com/"
			+ CLOUD_NAME
			+ "/image/upload/v"
			+ str(version)
			+ "/"
			+ encoded_public_id
			+ ".pdf"
		)

	elif extension in IMAGE_EXTENSIONS:
		pdf_url = (
			"https://res.cloudinary.com/"
			+ CLOUD_NAME
			+ "/image/upload/v"
			+ str(version)
			+ "/"
			+ encoded_public_id
			+ ".pdf"
		)

	if pdf_url.is_empty():
		_finish(
			callback_node,
			callback_method,
			false,
			"Could not generate PDF URL."
		)
		return

	if extension in OFFICE_EXTENSIONS:
		var available := await _wait_for_pdf(pdf_url)

		if not available:
			_finish(
				callback_node,
				callback_method,
				false,
				"PDF conversion is taking too long. Please try again."
			)
			return

	_finish(callback_node, callback_method, true, pdf_url)


func _add_field(
	body: PackedByteArray,
	boundary: String,
	field_name: String,
	value: String
) -> void:

	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array((
		"Content-Disposition: form-data; name=\""
		+ field_name
		+ "\"\r\n\r\n"
	).to_utf8_buffer())
	body.append_array((value + "\r\n").to_utf8_buffer())



func _wait_for_pdf(pdf_url: String) -> bool:

	print("[CloudinaryUploader] Waiting for converted PDF:")
	print("[CloudinaryUploader] PDF URL: ", pdf_url)

	for attempt in range(MAX_CONVERSION_ATTEMPTS):

		await get_tree().create_timer(
			CONVERSION_CHECK_INTERVAL
		).timeout

		var http := HTTPRequest.new()
		add_child(http)

		http.timeout = 10.0

		var request_error := http.request(
			pdf_url,
			[],
			HTTPClient.METHOD_HEAD
		)

		if request_error != OK:
			print(
				"[CloudinaryUploader] Attempt ",
				attempt + 1,
				": Could not start HEAD request. Error: ",
				request_error
			)
			http.queue_free()
			continue

		var response: Array = await http.request_completed

		var request_result: int = response[0]
		var response_code: int = response[1]

		print(
			"[CloudinaryUploader] PDF check ",
			attempt + 1,
			"/",
			MAX_CONVERSION_ATTEMPTS,
			" | Request result: ",
			request_result,
			" | HTTP status: ",
			response_code
		)

		http.queue_free()

		if response_code >= 200 and response_code < 300:
			print("[CloudinaryUploader] Converted PDF is available.")
			return true

	print("[CloudinaryUploader] PDF availability check timed out.")
	return false



func _finish(
	callback_node: Node,
	callback_method: String,
	success: bool,
	message: String
) -> void:

	if is_instance_valid(callback_node):
		callback_node.call(callback_method, success, message)

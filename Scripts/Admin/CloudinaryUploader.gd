extends Node

# Your Cloudinary details
const CLOUD_NAME = "ymiefwgl"
const UPLOAD_PRESET = "atomix_unsigned"

func upload_file(file_path: String, callback_node: Node, callback_method: String):
	if not FileAccess.file_exists(file_path):
		callback_node.call(callback_method, false, "File not found on computer")
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	var file_bytes = file.get_buffer(file.get_length())
	file.close()

	var boundary = "----CloudinaryBoundary" + str(Time.get_ticks_usec())
	
	# We must use "raw" for PDFs, DOCX, PPTX, etc.
	var url = "https://api.cloudinary.com/v1_1/" + CLOUD_NAME + "/raw/upload"
	
	var body = PackedByteArray()
	
	# 1. Upload Preset (Required for unsigned upload)
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".to_utf8_buffer())
	body.append_array((UPLOAD_PRESET + "\r\n").to_utf8_buffer())

	# 2. The File itself
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	var file_name = file_path.get_file()
	body.append_array(("Content-Disposition: form-data; name=\"file\"; filename=\"" + file_name + "\"\r\n").to_utf8_buffer())
	body.append_array("Content-Type: application/octet-stream\r\n\r\n".to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array("\r\n".to_utf8_buffer())
	
	# 3. Tell Cloudinary to keep the exact filename (so it keeps the .pdf extension)
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array("Content-Disposition: form-data; name=\"public_id\"\r\n\r\n".to_utf8_buffer())
	body.append_array((file_name + "\r\n").to_utf8_buffer())
	
	# End Boundary
	body.append_array(("--" + boundary + "--\r\n").to_utf8_buffer())

	var headers = [
		"Content-Type: multipart/form-data; boundary=" + boundary
	]

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_upload_completed.bind(callback_node, callback_method))
	
	http.request_raw(url, headers, HTTPClient.METHOD_POST, body)

func _on_upload_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, callback_node: Node, callback_method: String):
	if response_code == 200 or response_code == 201:
		var data = JSON.parse_string(body.get_string_from_utf8())
		var secure_url = data["secure_url"] # This is the link to the file!
		callback_node.call(callback_method, true, secure_url)
	else:
		var error_msg = body.get_string_from_utf8()
		push_error("Cloudinary Upload Failed: " + error_msg)
		callback_node.call(callback_method, false, "Error " + str(response_code) + ": " + error_msg)

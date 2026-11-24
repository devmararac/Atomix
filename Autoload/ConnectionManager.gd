
extends Node

signal connection_changed(is_connected: bool)

const CHECK_INTERVAL := 5.0
const TEST_URL := "https://www.google.com/generate_204"
const FAILURE_THRESHOLD := 3

var is_connected_to_internet: bool = false
var http_request: HTTPRequest
var consecutive_failures: int = 0


func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.timeout = 5.0
	add_child(http_request)

	is_connected_to_internet = await _check_connection()

	print(
		"[ConnectionManager] Initial connection: ",
		"ONLINE" if is_connected_to_internet else "OFFLINE"
	)

	connection_changed.emit(is_connected_to_internet)

	_monitor_connection()


func _monitor_connection() -> void:
	while is_inside_tree():
		await get_tree().create_timer(CHECK_INTERVAL).timeout

		if not is_inside_tree():
			return

		var current_status: bool = await _check_connection()

		if current_status:
			consecutive_failures = 0

			if not is_connected_to_internet:
				is_connected_to_internet = true
				print("[ConnectionManager] Connection changed: ONLINE")
				connection_changed.emit(true)

		else:
			consecutive_failures += 1

			if (
				is_connected_to_internet
				and consecutive_failures >= FAILURE_THRESHOLD
			):
				is_connected_to_internet = false
				print("[ConnectionManager] Connection changed: OFFLINE")
				connection_changed.emit(false)


func _check_connection() -> bool:
	if OS.get_name() == "Web":
		return false

	if http_request == null:
		return false

	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return false

	var error := http_request.request(TEST_URL)

	if error != OK:
		return false

	var response: Array = await http_request.request_completed

	if response.size() < 4:
		return false

	var result: int = response[0]
	var response_code: int = response[1]

	return (
		result == HTTPRequest.RESULT_SUCCESS
		and response_code >= 200
		and response_code < 400
	)

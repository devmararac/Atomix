extends Control
class_name AtomiXAI

signal response_received(response_text)
signal request_failed(error_message)

@export var api_key = ""

const MODEL = "gemini-3.5-flash-lite"
const API_URL = "https://generativelanguage.googleapis.com/v1beta/models/" + MODEL + ":generateContent"

var http_request = HTTPRequest.new()

@onready var question_input = $"Atomix AI/LineEdit"
@onready var ask_button = $"Atomix AI/Button"
@onready var response_label = $"Atomix AI/RichTextLabel"


func _ready():
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

	ask_button.pressed.connect(_on_ask_pressed)

	response_received.connect(_on_response_received)
	request_failed.connect(_on_request_failed)

	response_label.text = "Ask me a chemistry question."


func _on_ask_pressed():
	var question = question_input.text.strip_edges()

	if question.is_empty():
		response_label.text = "Please enter a question."
		return

	response_label.text = "Thinking..."
	ask_button.disabled = true

	ask_ai(question)


func ask_ai(question):
	if api_key.is_empty():
		request_failed.emit("Gemini API key is missing.")
		return

	var headers = [
		"Content-Type: application/json",
		"x-goog-api-key: " + api_key
	]

	var request_body = {
		"contents": [
			{
				"parts": [
					{
						"text": question
					}
				]
			}
		]
	}

	var json_body = JSON.stringify(request_body)

	var error = http_request.request(
		API_URL,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

	if error != OK:
		request_failed.emit(
			"Failed to send request. Error code: " + str(error)
		)


func _on_request_completed(result, response_code, headers, body):
	ask_button.disabled = false

	var response_text = body.get_string_from_utf8()

	if response_code != 200:
		request_failed.emit(
			"Gemini API error " + str(response_code) + "\n\n" + response_text
		)
		return

	var data = JSON.parse_string(response_text)

	if data == null:
		request_failed.emit("Could not parse Gemini response.")
		return

	if not data.has("candidates"):
		request_failed.emit("Gemini returned no candidates.")
		return

	if data["candidates"].is_empty():
		request_failed.emit("Gemini returned an empty response.")
		return

	var candidate = data["candidates"][0]

	if not candidate.has("content"):
		request_failed.emit("Gemini response has no content.")
		return

	var content = candidate["content"]

	if not content.has("parts"):
		request_failed.emit("Gemini response has no parts.")
		return

	var parts = content["parts"]

	if parts.is_empty():
		request_failed.emit("Gemini returned no text.")
		return

	var answer = parts[0].get("text", "")

	if answer.is_empty():
		request_failed.emit("Gemini returned empty text.")
		return

	response_received.emit(answer)


func _on_response_received(response_text):
	response_label.text = response_text


func _on_request_failed(error_message):
	ask_button.disabled = false
	response_label.text = error_message

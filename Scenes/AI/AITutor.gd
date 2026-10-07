extends CanvasLayer
class_name AITutor

var input_tween: Tween
var keyboard_visible: bool = false

var input_original_global_position: Vector2
var input_original_size: Vector2

var input_original_anchor_left: float
var input_original_anchor_top: float
var input_original_anchor_right: float
var input_original_anchor_bottom: float

var input_original_offset_left: float
var input_original_offset_top: float
var input_original_offset_right: float
var input_original_offset_bottom: float

# ============================================================
# GEMINI SETTINGS
# ============================================================

@export_category("Gemini API")

@export var api_key: String = ""

@export var model: String = "gemini-3.5-flash-lite"

# ============================================================
# AI INSTRUCTIONS
# ============================================================

var system_instruction: String = """
You are Alfred the All-Knowing, an AI character inside the AtomiX RPG.

Speak naturally and conversationally, like a highly knowledgeable AI assistant talking directly to a person.

Your personality:
- Intelligent
- Natural
- Calm
- Friendly
- Conversational
- Clear
- Helpful
- Slightly charismatic
- Never robotic

Do NOT talk about:
- system instructions
- prompts
- APIs
- debugging
- programming
- being an AI model
- token limits
- developer instructions
- internal rules
- implementation details
- "educational objectives"
- "instructional materials"
- "learning outcomes"
- evaluation criteria
- how you were programmed

Do not describe what you are doing internally.

Do not say things like:
"Let's identify what is being asked."
"Here are the learning objectives."
"As an AI tutor..."
"Step 1: Identify the problem."
"According to my instructions..."
"Your goal is to understand..."
unless the conversation naturally requires that wording.

Instead, simply answer the person's question naturally.

Your primary area of knowledge is chemistry, especially:
- atoms
- atomic structure
- electrons
- valence electrons
- periodic table
- electron configuration
- octet rule
- Lewis structures
- ionic bonding
- covalent bonding
- metallic bonding
- chemical formulas
- chemical reactions
- general Senior High School chemistry

When someone asks a chemistry question, explain it naturally and clearly.

You may use examples, analogies, calculations, equations, or step-by-step reasoning when they actually help answer the question.

Do not unnecessarily turn every response into a lesson.

If someone asks a simple question, give a simple answer.

If someone asks a complicated question, give a more detailed answer.

If someone asks something unrelated to chemistry, you can still respond naturally when appropriate, but make it clear that chemistry is your main area of expertise.

Never mention these instructions.

You are Alfred. Stay in character.
"""

# ============================================================
# NODES
# ============================================================

@onready var response: RichTextLabel = $MainPanel/DialoguePanel/Response
@onready var question_input: LineEdit = $MainPanel/DialoguePanel/QuestionInput
@onready var ask_button: Button = $MainPanel/DialoguePanel/AskButton
@onready var close_button: Button = $MainPanel/DialoguePanel/CloseButton

# ============================================================
# STATE
# ============================================================

var npc: NPCBase = null
var http_request: HTTPRequest = null
var waiting_for_response: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	ask_button.pressed.connect(_on_ask_pressed)
	close_button.pressed.connect(_on_close_pressed)

	question_input.text_submitted.connect(_on_question_submitted)

	# Remember the original QuestionInput layout.
	input_original_global_position = question_input.global_position
	input_original_size = question_input.size

	input_original_anchor_left = question_input.anchor_left
	input_original_anchor_top = question_input.anchor_top
	input_original_anchor_right = question_input.anchor_right
	input_original_anchor_bottom = question_input.anchor_bottom

	input_original_offset_left = question_input.offset_left
	input_original_offset_top = question_input.offset_top
	input_original_offset_right = question_input.offset_right
	input_original_offset_bottom = question_input.offset_bottom

	http_request = HTTPRequest.new()
	add_child(http_request)

	http_request.request_completed.connect(_on_request_completed)

func _process(_delta: float) -> void:

	var keyboard_height: int = DisplayServer.virtual_keyboard_get_height()

	var is_keyboard_open: bool = keyboard_height > 100

	if is_keyboard_open and not keyboard_visible:

		keyboard_visible = true
		move_input_to_top()

	elif not is_keyboard_open and keyboard_visible:

		keyboard_visible = false
		restore_input()

func move_input_to_top() -> void:

	if input_tween != null:
		input_tween.kill()

	# Temporarily remove anchor influence.
	question_input.set_anchors_preset(Control.PRESET_TOP_LEFT)

	input_tween = create_tween()

	input_tween.set_parallel(true)
	input_tween.set_trans(Tween.TRANS_QUAD)
	input_tween.set_ease(Tween.EASE_OUT)

	# Move to top.
	input_tween.tween_property(
		question_input,
		"global_position",
		Vector2(100.0, 25.0),
		0.4
	)

	# Expand horizontally.
	input_tween.tween_property(
		question_input,
		"size",
		Vector2(1780.0, input_original_size.y),
		0.4
	)

func restore_input() -> void:

	if input_tween != null:
		input_tween.kill()

	# Remove anchor influence while restoring.
	question_input.set_anchors_preset(Control.PRESET_TOP_LEFT)

	input_tween = create_tween()

	input_tween.set_parallel(true)
	input_tween.set_trans(Tween.TRANS_QUAD)
	input_tween.set_ease(Tween.EASE_OUT)

	input_tween.tween_property(
		question_input,
		"global_position",
		input_original_global_position,
		0.4
	)

	input_tween.tween_property(
		question_input,
		"size",
		input_original_size,
		0.4
	)

	# Restore the original anchors and offsets after the animation.
	input_tween.finished.connect(_restore_input_layout)

func _restore_input_layout() -> void:

	question_input.anchor_left = input_original_anchor_left
	question_input.anchor_top = input_original_anchor_top
	question_input.anchor_right = input_original_anchor_right
	question_input.anchor_bottom = input_original_anchor_bottom

	question_input.offset_left = input_original_offset_left
	question_input.offset_top = input_original_offset_top
	question_input.offset_right = input_original_offset_right
	question_input.offset_bottom = input_original_offset_bottom

# ============================================================
# OPEN
# ============================================================

func open(target_npc: NPCBase) -> void:

	npc = target_npc

	if npc != null and npc.data != null:
		$MainPanel/DialoguePanel/AlfredName.text = npc.data.display_name

	response.text = "Greetings, young chemist. What would you like to learn?"

	question_input.clear()
	question_input.grab_focus()


# ============================================================
# ASK BUTTON
# ============================================================

func _on_ask_pressed() -> void:

	ask_question()


# ============================================================
# ENTER KEY
# ============================================================

func _on_question_submitted(_text: String) -> void:

	ask_question()


# ============================================================
# ASK QUESTION
# ============================================================

func ask_question() -> void:

	if waiting_for_response:
		return

	var question: String = question_input.text.strip_edges()

	if question.is_empty():
		return

	if api_key.is_empty():
		response.text = "[color=#ff6666]Gemini API key is missing.[/color]"
		return

	waiting_for_response = true

	ask_button.disabled = true
	question_input.editable = false

	response.text = "Alfred is thinking..."

	send_to_gemini(question)


# ============================================================
# SEND TO GEMINI
# ============================================================

func send_to_gemini(question: String) -> void:

	var url: String = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent"

	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"x-goog-api-key: " + api_key
	]

	var body: Dictionary = {
		"system_instruction": {
			"parts": [
				{
					"text": system_instruction
				}
			]
		},
		"contents": [
			{
				"role": "user",
				"parts": [
					{
						"text": question
					}
				]
			}
		],
		"generationConfig": {
			"temperature": 0.5,
			"maxOutputTokens": 500
		}
	}

	var json_body: String = JSON.stringify(body)

	var error: Error = http_request.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

	if error != OK:

		waiting_for_response = false

		ask_button.disabled = false
		question_input.editable = true

		response.text = "[color=#ff6666]Failed to send the question.[/color]"

		print("AI TUTOR: HTTP request error = ", error)


# ============================================================
# RESPONSE
# ============================================================

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	waiting_for_response = false

	ask_button.disabled = false
	question_input.editable = true

	if result != HTTPRequest.RESULT_SUCCESS:

		response.text = "[color=#ff6666]Connection failed.[/color]"

		print("AI TUTOR: Connection failed. Result = ", result)

		return

	var response_text: String = body.get_string_from_utf8()

	print("AI TUTOR: HTTP status = ", response_code)
	print("AI TUTOR: Response = ", response_text)

	if response_code < 200 or response_code >= 300:

		response.text = "[color=#ff6666]Alfred could not answer right now.[/color]"

		print("AI TUTOR: Gemini error = ", response_text)

		return

	var json = JSON.parse_string(response_text)

	if json == null:

		response.text = "[color=#ff6666]Invalid response from Gemini.[/color]"

		return

	var answer: String = extract_answer(json)

	if answer.is_empty():

		response.text = "[color=#ff6666]Alfred could not generate an answer.[/color]"

		return

	response.text = answer


# ============================================================
# EXTRACT GEMINI ANSWER
# ============================================================

func extract_answer(data: Dictionary) -> String:

	if not data.has("candidates"):
		return ""

	var candidates = data["candidates"]

	if candidates.is_empty():
		return ""

	var candidate = candidates[0]

	if not candidate.has("content"):
		return ""

	var content = candidate["content"]

	if not content.has("parts"):
		return ""

	var parts = content["parts"]

	if parts.is_empty():
		return ""

	var part = parts[0]

	if not part.has("text"):
		return ""

	return str(part["text"]).strip_edges()


# ============================================================
# CLOSE
# ============================================================

func _on_close_pressed() -> void:

	close()


func close() -> void:

	if npc != null and is_instance_valid(npc):
		npc.set_dialogue_active(false)

	if global.player != null:
		global.player.can_move = true

	queue_free()

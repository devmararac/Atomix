extends Control


@onready var display_name_value: Label = $PlayerPage/PlayerInfoPanel/DisplayNameValue
@onready var student_name_value: Label = $PlayerPage/PlayerInfoPanel/StudentNameValue
@onready var progress_value: Label = $PlayerPage/PlayerInfoPanel/ProgressValue
@onready var active_atomon_slots = $PlayerPage/PlayerInfoPanel/VBoxContainer/AtomonSlots

@onready var character_background: TextureRect = $PlayerPage/CharacterPanel/Preview
@onready var character_preview: AnimatedSprite2D = $PlayerPage/CharacterPanel/AnimatedSprite2D
@onready var atomon_slots: Array[Node] = [
	$PlayerPage/PlayerInfoPanel/VBoxContainer/AtomonSlots/Slot,
	$PlayerPage/PlayerInfoPanel/VBoxContainer/AtomonSlots/Slot2,
	$PlayerPage/PlayerInfoPanel/VBoxContainer/AtomonSlots/Slot3,
	$PlayerPage/PlayerInfoPanel/VBoxContainer/AtomonSlots/Slot4,
	$PlayerPage/PlayerInfoPanel/VBoxContainer/AtomonSlots/Slot5
]

func _ready() -> void:
	update_player_page()
	refresh_active_atomons()


func update_player_page() -> void:
	update_player_information()
	update_character_preview()


func update_player_information() -> void:

	# -----------------------------------------
	# DISPLAY NAME
	# -----------------------------------------

	if PlayerManager.display_name != "":
		display_name_value.text = PlayerManager.display_name
	else:
		display_name_value.text = "Player"


	# -----------------------------------------
	# STUDENT NAME
	# -----------------------------------------

	if StudentDataManager.student_data.has("name"):
		var student_name := str(
			StudentDataManager.student_data["name"]
		).strip_edges()

		if not student_name.is_empty():
			student_name_value.text = student_name
		else:
			student_name_value.text = "Student"
	else:
		student_name_value.text = "Student"


	# -----------------------------------------
	# PROGRESS
	# -----------------------------------------

	var collected := StudentDataManager.collected_elements.size()

	progress_value.text = str(collected) + " / " + str(
		StudentDataManager.TOTAL_ELEMENTS
	) + " Elements"


func update_character_preview() -> void:

	if PlayerManager.selected_character == null:
		print("[PlayerPage] No selected character.")
		return

	var frames: SpriteFrames = PlayerManager.selected_character.sprite_frames

	if frames == null:
		print("[PlayerPage] ERROR: SpriteFrames is null.")
		return

	# Apply selected character
	character_preview.sprite_frames = frames

	# Scale 32x32 pixel character for the Player Page
	character_preview.scale = Vector2(8, 8)

	# Play idle
	if frames.has_animation("idle"):
		character_preview.animation = "idle"
		character_preview.frame = 0
		character_preview.play("idle")
	else:
		print("[PlayerPage] ERROR: Selected character has no idle animation.")
		return

	# Make sure the sprite is visible
	character_preview.visible = true

	# Center the character inside the preview texture
	var preview_center := (
		character_background.position
		+ character_background.size / 2.0
	)

	character_preview.position = preview_center
	print(
		"[PlayerPage] Character preview applied: ",
		PlayerManager.selected_character.character_name
	)

	print(
		"[PlayerPage] Character centered at: ",
		character_preview.position
	)

func refresh_active_atomons() -> void:

	var battle_party: Array[AtomonInstance] = PartyManager.get_battle_party()

	for i in range(atomon_slots.size()):

		var slot = atomon_slots[i]

		if i < battle_party.size():
			var atomon: AtomonInstance = battle_party[i]

			if atomon != null:
				_update_atomon_slot(slot, atomon)
			else:
				_clear_atomon_slot(slot)

		else:
			_clear_atomon_slot(slot)

func _update_atomon_slot(slot: Node, atomon: AtomonInstance) -> void:

	if not slot.has_method("set_atomon"):
		push_warning(
			"PlayerPage: Atomon slot does not have set_atomon()."
		)
		return

	slot.set_atomon(atomon)


func _clear_atomon_slot(slot: Node) -> void:

	if slot.has_method("clear"):
		slot.clear()

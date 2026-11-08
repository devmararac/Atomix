extends CanvasLayer

var selected_character: CharacterData = null

# ============================================================
# UI REFERENCES
# ============================================================

@onready var selected_label: Label = $"Root/Columns/Input Panel/VBox/SelectedLabel"
@onready var display_name: LineEdit = $"Root/Columns/Input Panel/VBox/DisplayName"
@onready var character_preview: AnimatedSprite2D = $"Root/Columns/Character Preview/VBox/Preview BG/AnimatedSprite2D"

# ============================================================
# READY
# ============================================================

func _ready() -> void:
	$"Root/Columns/Input Panel/VBox/CharacterButtons/Character01".pressed.connect(
		func(): select_character("character_01")
	)
	$"Root/Columns/Input Panel/VBox/CharacterButtons/Character02".pressed.connect(
		func(): select_character("character_02")
	)
	$"Root/Columns/Input Panel/VBox/CharacterButtons/Character03".pressed.connect(
		func(): select_character("character_03")
	)
	$"Root/Columns/Input Panel/VBox/CharacterButtons/Character04".pressed.connect(
		func(): select_character("character_04")
	)
	$"Root/Columns/Input Panel/VBox/StartButton".pressed.connect(
		_on_continue_pressed
	)

	character_preview.visible = false

# ============================================================
# CHARACTER SELECTION
# ============================================================

func select_character(character_id: String) -> void:
	match character_id:
		"character_01":
			selected_character = preload("res://Resources/Characters/Default.tres")
		"character_02":
			selected_character = preload("res://Resources/Characters/Alfred.tres")
		"character_03":
			selected_character = preload("res://Resources/Characters/Deejhay.tres")
		"character_04":
			selected_character = preload("res://Resources/Characters/Dianne.tres")
		_:
			print("[CharacterSetup] Unknown character ID: ", character_id)
			return

	if selected_character == null:
		return

	selected_label.text = "Selected: " + selected_character.character_name
	update_character_preview()

# ============================================================
# CHARACTER PREVIEW
# ============================================================

func update_character_preview() -> void:
	if selected_character == null:
		return

	if selected_character.sprite_frames == null:
		print("[CharacterSetup] ERROR: SpriteFrames is null.")
		return

	character_preview.sprite_frames = selected_character.sprite_frames
	character_preview.scale = Vector2(8, 8)
	character_preview.centered = true
	character_preview.position = $"Root/Columns/Character Preview/VBox/Preview BG".size / 2.0
	character_preview.flip_h = false

	if character_preview.sprite_frames.has_animation("idle"):
		character_preview.animation = "idle"
		character_preview.frame = 0
		character_preview.play("idle")
	else:
		print("[CharacterSetup] ERROR: Character has no idle animation.")
		return

	character_preview.visible = true

# ============================================================
# CONTINUE
# ============================================================

func _on_continue_pressed() -> void:
	var name = display_name.text.strip_edges()

	if selected_character == null:
		selected_label.text = "Selected: Please choose a character."
		return

	if name.is_empty():
		display_name.grab_focus()
		return

	PlayerManager.display_name = name
	PlayerManager.set_character(selected_character)

	var success: bool = await StudentDataManager.save_player_profile(
		name,
		selected_character.character_id
	)

	if not success:
		print("[CharacterSetup] ERROR: Failed to save player profile.")
		return

	get_tree().change_scene_to_file("res://Scenes/Cutscenes/tutorial.tscn")

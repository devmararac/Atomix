extends CanvasLayer

var selected_character: CharacterData = null


# ============================================================
# UI REFERENCES
# ============================================================

@onready var selected_label: Label = $"Input Panel/SelectedLabel"

@onready var display_name: LineEdit = $"Input Panel/DisplayName"

@onready var character_preview: AnimatedSprite2D = $"Character Preview/Preview BG/AnimatedSprite2D"


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	# --------------------------------------------------------
	# CHARACTER BUTTONS
	# --------------------------------------------------------

	$"Input Panel/CharacterButtons/Character01".pressed.connect(
		func():
			select_character("character_01")
	)

	$"Input Panel/CharacterButtons/Character02".pressed.connect(
		func():
			select_character("character_02")
	)

	$"Input Panel/CharacterButtons/Character03".pressed.connect(
		func():
			select_character("character_03")
	)

	$"Input Panel/CharacterButtons/Character04".pressed.connect(
		func():
			select_character("character_04")
	)

	# --------------------------------------------------------
	# CONTINUE BUTTON
	# --------------------------------------------------------

	$"Input Panel/StartButton".pressed.connect(
		_on_continue_pressed
	)

	# --------------------------------------------------------
	# HIDE CHARACTER PREVIEW UNTIL A CHARACTER IS SELECTED
	# --------------------------------------------------------

	character_preview.visible = false


# ============================================================
# CHARACTER SELECTION
# ============================================================

func select_character(character_id: String) -> void:

	print(
		"[CharacterSetup] Selected character ID: ",
		character_id
	)


	match character_id:

		# ----------------------------------------------------
		# CHARACTER 1
		# ----------------------------------------------------

		"character_01":

			selected_character = preload(
				"res://Resources/Characters/Default.tres"
			)


		# ----------------------------------------------------
		# CHARACTER 2
		# ----------------------------------------------------

		"character_02":

			selected_character = preload(
				"res://Resources/Characters/Alfred.tres"
			)


		# ----------------------------------------------------
		# CHARACTER 3
		# ----------------------------------------------------

		"character_03":

			# selected_character = preload(
			# 	"res://Resources/Characters/Character03.tres"
			# )

			pass


		# ----------------------------------------------------
		# CHARACTER 4
		# ----------------------------------------------------

		"character_04":

			# selected_character = preload(
			# 	"res://Resources/Characters/Character04.tres"
			# )

			pass


		# ----------------------------------------------------
		# UNKNOWN
		# ----------------------------------------------------

		_:

			print(
				"[CharacterSetup] Unknown character ID: ",
				character_id
			)

			return


	# ========================================================
	# UPDATE UI
	# ========================================================

	if selected_character == null:
		return


	selected_label.text = (
		"Selected: "
		+ selected_character.character_name
	)


	# ========================================================
	# UPDATE CHARACTER PREVIEW
	# ========================================================

	update_character_preview()


	print(
		"[CharacterSetup] Character Name: ",
		selected_character.character_name
	)

	print(
		"[CharacterSetup] Character ID: ",
		selected_character.character_id
	)


# ============================================================
# CHARACTER PREVIEW
# ============================================================

func update_character_preview() -> void:

	if selected_character == null:
		return


	if selected_character.sprite_frames == null:

		print(
			"[CharacterSetup] ERROR: SpriteFrames is null."
		)

		return


	# --------------------------------------------------------
	# APPLY CHARACTER SPRITEFRAMES
	# --------------------------------------------------------

	character_preview.sprite_frames = (
		selected_character.sprite_frames
	)


	# --------------------------------------------------------
	# CHARACTER SCALE
	# --------------------------------------------------------

	character_preview.scale = Vector2(8, 8)


	# --------------------------------------------------------
	# CENTER SPRITE
	# --------------------------------------------------------

	character_preview.centered = true


	# --------------------------------------------------------
	# IDLE ANIMATION
	# --------------------------------------------------------

	if character_preview.sprite_frames.has_animation("idle"):

		character_preview.animation = "idle"
		character_preview.frame = 0
		character_preview.play("idle")

	else:

		print(
			"[CharacterSetup] ERROR: Character has no idle animation."
		)

		return


	character_preview.visible = true


# ============================================================
# CONTINUE
# ============================================================

func _on_continue_pressed() -> void:

	var name := display_name.text.strip_edges()


	# ========================================================
	# VALIDATE CHARACTER
	# ========================================================

	if selected_character == null:

		print(
			"[CharacterSetup] ERROR: No character selected."
		)

		selected_label.text = (
			"Selected: Please choose a character."
		)

		return


	# ========================================================
	# VALIDATE DISPLAY NAME
	# ========================================================

	if name.is_empty():

		print(
			"[CharacterSetup] ERROR: Display name is empty."
		)

		display_name.grab_focus()

		return


	# ========================================================
	# STORE PLAYER DATA LOCALLY
	# ========================================================

	PlayerManager.display_name = name

	PlayerManager.set_character(
		selected_character
	)


	print("==============================")
	print("PLAYER DATA")
	print(
		"Display Name: ",
		PlayerManager.display_name
	)
	print(
		"Character ID: ",
		PlayerManager.selected_character.character_id
	)
	print(
		"Character Name: ",
		PlayerManager.selected_character.character_name
	)
	print("==============================")


	# ========================================================
	# SAVE PLAYER PROFILE TO FIREBASE
	# ========================================================

	var success := await StudentDataManager.save_player_profile(
		name,
		selected_character.character_id
	)


	if not success:

		print(
			"[CharacterSetup] ERROR: Failed to save player profile."
		)

		return


	print(
		"[CharacterSetup] Player profile saved to Firebase."
	)


	# ========================================================
	# GO TO TUTORIAL
	# ========================================================

	get_tree().change_scene_to_file(
		"res://Scenes/Cutscenes/tutorial.tscn"
	)

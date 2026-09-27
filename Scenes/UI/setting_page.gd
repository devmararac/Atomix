extends Control

@onready var logout_button: TextureButton = $Content/LogoutContainer/Logout
@onready var music_slider: HSlider = $Content/MusicPanel/Margin/MusicVBox/MusicControls/MusicSlider
@onready var music_value: Label = $Content/MusicPanel/Margin/MusicVBox/MusicControls/MusicValue
@onready var sfx_slider: HSlider = $Content/SFXPanel/Margin/SFXVBox/SFXControls/SFXSlider
@onready var sfx_value: Label = $Content/SFXPanel/Margin/SFXVBox/SFXControls/SFXValue
@onready var save_progress_button: Button = $Content/Buttons/SaveProgress
@onready var profile_button: Button = $Content/Buttons/Profile


func _ready() -> void:
	# Initialize displayed volume values
	_update_music_value(music_slider.value)
	_update_sfx_value(sfx_slider.value)

	# Profile page is not implemented yet
	profile_button.disabled = true


# ============================================================
# MUSIC
# ============================================================

func _on_music_volume_changed(value: float) -> void:
	_update_music_value(value)

	# TODO:
	# Connect this to your AudioManager later.
	#
	# Example:
	# AudioServer.set_bus_volume_db(
	#     AudioServer.get_bus_index("Music"),
	#     linear_to_db(value / 100.0)
	# )


func _update_music_value(value: float) -> void:
	music_value.text = "%d%%" % int(value)


# ============================================================
# SOUND EFFECTS
# ============================================================

func _on_sfx_volume_changed(value: float) -> void:
	_update_sfx_value(value)

	# TODO:
	# Connect this to your AudioManager later.
	#
	# Example:
	# AudioServer.set_bus_volume_db(
	#     AudioServer.get_bus_index("SFX"),
	#     linear_to_db(value / 100.0)
	# )


func _update_sfx_value(value: float) -> void:
	sfx_value.text = "%d%%" % int(value)


# ============================================================
# SAVE PROGRESS
# ============================================================

func _on_save_progress_pressed() -> void:
	SfxManager.play_click()
	SaveManager.save_game()
	print("Save Progress pressed")


# ============================================================
# PROFILE
# ============================================================

func _on_profile_pressed() -> void:
	# Profile page does not exist yet.
	# This function is intentionally empty for now.
	print("Profile page is not available yet.")


# ============================================================
# LOG OUT
# ============================================================

func _on_logout_pressed() -> void:
	logout_button.disabled = true

	await get_tree().create_timer(0.5).timeout

	get_tree().change_scene_to_file(
		"res://Scenes/UI/MainMenu.tscn"
	)

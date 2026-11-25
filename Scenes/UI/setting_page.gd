
extends Control

@onready var logout_button: TextureButton = $Content/LogoutContainer/Logout
@onready var music_slider: HSlider = $Content/MusicPanel/Margin/MusicVBox/MusicControls/MusicSlider
@onready var music_value: Label = $Content/MusicPanel/Margin/MusicVBox/MusicControls/MusicValue
@onready var sfx_slider: HSlider = $Content/SFXPanel/Margin/SFXVBox/SFXControls/SFXSlider
@onready var sfx_value: Label = $Content/SFXPanel/Margin/SFXVBox/SFXControls/SFXValue
@onready var save_progress_button: Button = $Content/Buttons/SaveProgress
@onready var profile_button: Button = $Content/Buttons/Profile


func _ready() -> void:
	# Restore previously selected Master volume
	music_slider.value = SfxManager.master_volume
	_update_music_value(SfxManager.master_volume)

	# Restore SFX volume
	sfx_slider.value = SfxManager.sfx_volume
	_update_sfx_value(SfxManager.sfx_volume)


# ============================================================
# MUSIC
# ============================================================
func _on_music_volume_changed(value: float) -> void:
	_update_music_value(value)
	SfxManager.set_master_volume(value)

func _update_music_value(value: float) -> void:
	music_value.text = "%d%%" % int(value)


# ============================================================
# SOUND EFFECTS
# ============================================================

func _on_sfx_volume_changed(value: float) -> void:
	_update_sfx_value(value)
	SfxManager.set_sfx_volume(value)


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
	SfxManager.play_click()

	print("[Settings] Opening student profile.")

	if GameMenu.instance != null:
		print("[Settings] GameMenu found.")

		GameMenu.instance.change_page(
			preload("res://Scenes/UI/Student/student_settings.tscn")
		)
	else:
		push_error("[Settings] GameMenu instance is unavailable.")


# ============================================================
# LOG OUT
# ============================================================

func _on_logout_pressed() -> void:
	logout_button.disabled = true

	AuthManager.logout()

	await get_tree().create_timer(0.2).timeout

	get_tree().change_scene_to_file(
		"res://Scenes/UI/MainMenu.tscn"
	)

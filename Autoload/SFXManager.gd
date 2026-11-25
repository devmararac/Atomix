
extends Node

# ============================================================
# SOUND EFFECTS
# ============================================================

const CLICK = preload("res://Assets/Music/SFX/click_.wav")
const CLOSE = preload("res://Assets/Music/SFX/close.wav")
const SLOT_CLICK = preload("res://Assets/Music/SFX/slot_clicks.wav")
const ALERT = preload("res://Assets/Music/SFX/alert.wav")
const CHEST = preload("res://Assets/Music/SFX/chest_open.wav")
const EMOTE = preload("res://Assets/Music/SFX/emotes.wav")

# ============================================================
# MUSIC
# ============================================================

const NIGHT = preload("res://Assets/Music/SFX/Environment/night_sound.mp3")

# ============================================================
# AUDIO PLAYERS
# ============================================================

var player: AudioStreamPlayer
var music_player: AudioStreamPlayer

# Volume values (0-100)
var sfx_volume: float = 100.0
var music_volume: float = 100.0

var master_volume: float = 100.0

func _ready() -> void:

	# SFX PLAYER
	player = AudioStreamPlayer.new()
	player.bus = "Master"
	add_child(player)

	# MUSIC PLAYER
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)

	# Apply initial volumes
	set_sfx_volume(sfx_volume)
	set_music_volume(music_volume)


# ============================================================
# VOLUME CONTROL
# ============================================================

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 100.0)

	if player == null:
		return

	if sfx_volume <= 0.0:
		player.volume_db = -80.0
	else:
		player.volume_db = linear_to_db(sfx_volume / 100.0)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 100.0)

	if music_player == null:
		return

	if music_volume <= 0.0:
		music_player.volume_db = -80.0
	else:
		music_player.volume_db = linear_to_db(music_volume / 100.0)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 100.0)

	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus == -1:
		return

	AudioServer.set_bus_mute(master_bus, master_volume <= 0.0)

	if master_volume > 0.0:
		AudioServer.set_bus_volume_db(
			master_bus,
			linear_to_db(master_volume / 100.0)
		 )

# ============================================================
# SOUND EFFECT FUNCTIONS
# ============================================================

func play_click() -> void:
	player.stream = CLICK
	player.play()


func play_slot_click() -> void:
	player.stream = SLOT_CLICK
	player.play()


func alert() -> void:
	player.stream = ALERT
	player.play()


func close() -> void:
	player.stream = CLOSE
	player.play()


func play_emote() -> void:
	player.stream = EMOTE
	player.play()


func chest() -> void:
	player.stream = CHEST
	player.play()


# ============================================================
# MUSIC FUNCTIONS
# ============================================================

func night() -> void:
	music_player.stream = NIGHT
	music_player.play()

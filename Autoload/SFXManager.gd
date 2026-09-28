extends Node

# Interface
const CLICK = preload("res://Assets/Music/SFX/click_.wav")
const CLOSE = preload("res://Assets/Music/SFX/close.wav")
const SLOT_CLICK = preload("res://Assets/Music/SFX/slot_clicks.wav")
const ALERT = preload("res://Assets/Music/SFX/alert.wav")

#Musics
const NIGHT = preload("res://Assets/Music/SFX/Environment/night_sound.mp3")

# ENV_SFX
const EMOTE = preload("res://Assets/Music/SFX/emotes.wav")

var player: AudioStreamPlayer

func _ready():
	player = AudioStreamPlayer.new()
	player.volume_db = -10.0
	
	add_child(player)

func play_click():
	player.stream = CLICK
	player.play()

func play_slot_click():
	player.stream = SLOT_CLICK
	player.play()

func alert():
	player.stream = ALERT
	player.play()

func close():
	player.stream = CLOSE
	player.play()

func night():
	player.stream = NIGHT
	player.play()

func play_emote():
	player.stream = EMOTE
	player.play()

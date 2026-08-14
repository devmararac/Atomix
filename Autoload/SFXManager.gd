extends Node

const CLICK = preload("res://Assets/Music/SFX/click.wav")
const SLOT_CLICK = preload("res://Assets/Music/SFX/select_slots.wav")
const ALERT = preload("res://Assets/Music/SFX/alert.wav")

var player: AudioStreamPlayer

func _ready():
	player = AudioStreamPlayer.new()
	player.volume_db = -20.0
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

extends CharacterBody2D
class_name NPCBase

@export var data: NPCData

@onready var emote: Sprite2D = $Emote
@onready var display_name = $NameContainer/Label
@onready var sprite = $NpcSprite
@onready var indicator = $NpcSprite/Indicator
@onready var BubbleMarker = $BubbleMarker
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@export var show_navigation_path := false
const ANGRY = preload("res://Assets/Emotes/angry.png")
const WORRIED = preload("res://Assets/Emotes/worried.png")
const WEIRDED = preload("res://Assets/Emotes/weirded.png")
const THANKFUL = preload("res://Assets/Emotes/thankful.png")
const SLEEPY = preload("res://Assets/Emotes/sleepy.png")
const SHOCKED = preload("res://Assets/Emotes/shocked.png")
const LOL = preload("res://Assets/Emotes/lol.png")
const KISS = preload("res://Assets/Emotes/kiss.png")
const HAPPY = preload("res://Assets/Emotes/happy.png")
const GIGGLE = preload("res://Assets/Emotes/giggle.png")
const CURIOUS = preload("res://Assets/Emotes/curious.png")
const CLOWN = preload("res://Assets/Emotes/clown.png")
const ANNOYED = preload("res://Assets/Emotes/annoyed.png")

signal destination_reached

var joystick_controlled := false
var is_moving := false
var debug_path: PackedVector2Array = []
var emote_tween: Tween

func _ready():
	setup_npc()
	$Highlight.visible = false

func setup_npc():

	if data == null:
		push_warning("NPCData missing.")
		return
	
	display_name.text = data.display_name

	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
		sprite.play("idle")

	sprite.flip_h = data.facing_direction == NPCData.FacingDirection.LEFT

func interact():
	NpcManager.interact(self)

func show_indicator():
	indicator.visible = true

func hide_indicator():
	indicator.visible = false

func _physics_process(_delta):
	if joystick_controlled:
		var input_vector := Input.get_vector(
			"left",
			"right",
			"up",
			"down"
		)

		velocity = input_vector * data.move_speed

		if input_vector != Vector2.ZERO:
			if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("walk"):
				sprite.play("walk")
			else:
				sprite.play("idle")

			sprite.flip_h = input_vector.x < 0
		else:
			velocity = Vector2.ZERO
			sprite.play("idle")

		move_and_slide()
		return

	if not is_moving:
		return

	if navigation_agent.is_navigation_finished():
		is_moving = false
		velocity = Vector2.ZERO
		sprite.play("idle")
		destination_reached.emit()
		return

	var next_position = navigation_agent.get_next_path_position()
	debug_path = navigation_agent.get_current_navigation_path()

	if show_navigation_path:
		queue_redraw()

	var direction = (next_position - global_position).normalized()

	velocity = direction * data.move_speed
	move_and_slide()

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")
	else:
		sprite.play("idle")

	sprite.flip_h = velocity.x < 0

func walk_to(target: Vector2):
	navigation_agent.target_position = target
	is_moving = true


func _draw():

	if !show_navigation_path:
		return

	if debug_path.size() < 2:
		return

	for i in range(debug_path.size() - 1):
		draw_line(
			to_local(debug_path[i]),
			to_local(debug_path[i + 1]),
			Color.RED,
			2.0
		)

	for point in debug_path:
		draw_circle(to_local(point), 4, Color.YELLOW)

func show_emote(texture: Texture2D, duration: float = 2.5) -> void:
	if emote_tween:
		emote_tween.kill()

	emote.texture = texture
	emote.show()

	var base_position := emote.position
	emote.position = base_position + Vector2(0, 10)
	emote.scale = Vector2(0.8, 0.8)
	emote.modulate.a = 1.0

	emote_tween = create_tween()

	# Pop up
	emote_tween.set_trans(Tween.TRANS_BACK)
	emote_tween.set_ease(Tween.EASE_OUT)
	emote_tween.tween_property(
		emote,
		"position",
		base_position,
		0.35
	)

	# Scale up slightly
	emote_tween.parallel().tween_property(
		emote,
		"scale",
		Vector2.ONE,
		0.35
	)

	# Small bounce
	emote_tween.tween_property(
		emote,
		"position",
		base_position + Vector2(0, -5),
		0.12
	)

	emote_tween.tween_property(
		emote,
		"position",
		base_position,
		0.12
	)

	# Stay visible
	emote_tween.tween_interval(duration)

	# Fade out
	emote_tween.tween_property(
		emote,
		"modulate:a",
		0.0,
		0.25
	)

	# Hide and reset
	emote_tween.tween_callback(func():
		emote.hide()
		emote.texture = null
		emote.modulate.a = 1.0
		emote.scale = Vector2.ONE
		emote.position = base_position
	)

func play_emote(emote_name: String, duration: float = 2.5) -> void:
	var texture: Texture2D

	match emote_name.to_lower():
		"angry":
			texture = ANGRY
		"annoyed":
			texture = ANNOYED
		"clown":
			texture = CLOWN
		"curious":
			texture = CURIOUS
		"giggle":
			texture = GIGGLE
		"happy":
			texture = HAPPY
		"kiss":
			texture = KISS
		"lol":
			texture = LOL
		"shocked":
			texture = SHOCKED
		"sleepy":
			texture = SLEEPY
		"thankful":
			texture = THANKFUL
		"weirded":
			texture = WEIRDED
		"worried":
			texture = WORRIED
		_:
			push_warning("Unknown NPC emote: " + emote_name)
			return

	show_emote(texture, duration)

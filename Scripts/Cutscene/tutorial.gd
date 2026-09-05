extends Node2D

@onready var dianne = $Dianne
@onready var dianne_target = $DianneTarget

@onready var alfred = $Alfred
@onready var alfred_target = $AlfredTarget
@onready var alfred_target2 = $AlfredTarget2

@onready var deejhay = $Deejhay
@onready var deejhay_target = $DeejhayTarget

@onready var angelo = $Angelo
@onready var angelo_target = $AngeloTarget

@onready var elysa = $Elysa
@onready var elysa_target = $ElysaTarget

@onready var trishania = $Trishania
@onready var trishania_target = $TrishaniaTarget

@onready var hud = $HUD
@onready var minimap = $Minimap





# =========================================
# JOYSTICK TUTORIAL
# =========================================

var joystick_tutorial_active := false
var joystick_movement_time := 0.0

const REQUIRED_MOVEMENT_TIME := 2.0
var dialogic_layout

func _ready() -> void:
	hud.visible = false
	minimap.visible = false
	
	hud.get_node("QuestTracker").visible = false
	hud.get_node("ActionButtons").visible = false
	hud.get_node("MenuButtons").visible = false
	hud.get_node("HotBar").visible = false
	hud.get_node("VirtualJoystick").visible = false

	Dialogic.signal_event.connect(_on_dialogic_signal)

	await walk_dianne()

	# Start Dianne's conversation through NpcManager
	dialogic_layout = NpcManager.interact(dianne)

	dialogic_layout.register_character(
		trishania.data.dialogic_character,
		trishania.get_node("BubbleMarker")
)

	dialogic_layout.register_character(
		alfred.data.dialogic_character,
		alfred.get_node("BubbleMarker")
)

	dialogic_layout.register_character(
		deejhay.data.dialogic_character,
		deejhay.get_node("BubbleMarker")
)

	dialogic_layout.register_character(
		elysa.data.dialogic_character,
		elysa.get_node("BubbleMarker")
)

	dialogic_layout.register_character(
		angelo.data.dialogic_character,
		angelo.get_node("BubbleMarker")
)

func _process(delta: float) -> void:
	if joystick_tutorial_active:
		minimap.visible = false
	
	# Only check movement during the joystick tutorial
	if not joystick_tutorial_active:
		return

	# Dianne is actually moving
	if dianne.velocity.length() > 0:
		joystick_movement_time += delta

		# Player has moved Dianne enough
		if joystick_movement_time >= REQUIRED_MOVEMENT_TIME:
			complete_joystick_tutorial()

func face_character(character: Node2D, face_left: bool) -> void:
	character.sprite.flip_h = face_left
# =========================================
# DIANNE WALK-IN
# =========================================

func walk_dianne() -> void:
	var direction: Vector2 = dianne_target.global_position - dianne.global_position

	# Sprite faces right by default
	dianne.sprite.flip_h = direction.x < 0

	dianne.sprite.play("walk")

	var tween = create_tween()

	tween.tween_property(
		dianne,
		"global_position",
		dianne_target.global_position,
		4.0
	)

	await tween.finished

	dianne.sprite.play("idle")


func walk_dianne_back() -> void:
	var direction: Vector2 = dianne_target.global_position - dianne.global_position

	# Sprite faces right by default
	dianne.sprite.flip_h = direction.x < 0

	dianne.sprite.play("walk")

	var tween = create_tween()

	tween.tween_property(
		dianne,
		"global_position",
		dianne_target.global_position,
		2.0
	)

	await tween.finished

	dianne.sprite.play("idle")

# =========================================
# TRISHANIA WALK-IN
# =========================================

func walk_trishania() -> void:
	var direction: Vector2 = trishania_target.global_position - trishania.global_position

	# Trishania's sprite faces right by default
	trishania.sprite.flip_h = direction.x < 0

	trishania.sprite.play("walk")

	var tween = create_tween()

	tween.tween_property(
		trishania,
		"global_position",
		trishania_target.global_position,
		3.0
	)

	await tween.finished

	trishania.sprite.play("idle")

func walk_alfred() -> void:
	var direction: Vector2 = alfred_target.global_position - alfred.global_position

	# Alfred's sprite faces right by default
	alfred.sprite.flip_h = direction.x < 0

	alfred.sprite.play("walk")

	var tween = create_tween()

	tween.tween_property(
		alfred,
		"global_position",
		alfred_target.global_position,
		2.5
	)

	await tween.finished

	alfred.sprite.play("idle")

func walk_alfred2() -> void:
	var direction: Vector2 = alfred_target2.global_position - alfred.global_position

	# Alfred's sprite faces right by default
	alfred.sprite.flip_h = direction.x < 0

	alfred.sprite.play("walk")

	var tween = create_tween()

	tween.tween_property(
		alfred,
		"global_position",
		alfred_target2.global_position,
		2.5
	)

	await tween.finished

	alfred.sprite.play("idle")

func walk_deejhay() -> void:
	var direction: Vector2 = deejhay_target.global_position - deejhay.global_position

	# Alfred's sprite faces right by default
	deejhay.sprite.flip_h = direction.x < 0

	deejhay.sprite.play("walk")

	var tween = create_tween()

	tween.tween_property(
		deejhay,
		"global_position",
		deejhay_target.global_position,
		2.5
	)

	await tween.finished

	deejhay.sprite.play("idle")
# =========================================
# SHOW JOYSTICK
# =========================================
func joystick():
	hud.visible = true
	hud.get_node("VirtualJoystick").visible = true

func show_joystick() -> void:
	hud.visible = true
	hud.get_node("VirtualJoystick").visible = true

	dianne.joystick_controlled = true

	joystick_tutorial_active = true
	joystick_movement_time = 0.0

func action_buttons():
	hud.visible = true
	hud.get_node("ActionButtons").visible = true

func show_action_buttons() -> void:
	hud.visible = true
	hud.get_node("ActionButtons").visible = true

func item_bar():
	hud.visible = true
	hud.get_node("HotBar").visible = true

func minimap_show():
	minimap.visible = true

# =========================================
# COMPLETE JOYSTICK TUTORIAL
# =========================================

func complete_joystick_tutorial() -> void:

	joystick_tutorial_active = false

	# Dianne is no longer controllable
	dianne.joystick_controlled = false
	dianne.velocity = Vector2.ZERO
	dianne.sprite.play("idle")
	
	await walk_dianne_back()
	
	# Start Part 2
	Dialogic.start("dianne_line2")

	# Preserve already unlocked HUD elements
	keep_hud_progress()

func keep_hud_progress() -> void:
	hud.visible = true
	
	# Already unlocked — keep it visible
	hud.get_node("VirtualJoystick").visible = true

func _on_dialogic_signal(arg: String) -> void:

	match arg:

		"dianne_walk":
			await walk_dianne()

		"show_joystick":
			show_joystick()
		
		"joystick":
			joystick()
		
		"trishania_walk":
			walk_trishania()
		
		"show_action_buttons":
			show_action_buttons()
		
		"alfred_walk":
			walk_alfred()
		
		"alfred_walk_target2":
			walk_alfred2()
		
		"deejhay_walk":
			walk_deejhay()
		
		"show_item_bar":
			item_bar()
		# Character facing
		"dianne_face_left":
			face_character(dianne, true)

		"dianne_face_right":
			face_character(dianne, false)

		"trishania_face_left":
			face_character(trishania, true)

		"trishania_face_right":
			face_character(trishania, false)

		"alfred_face_left":
			face_character(alfred, true)

		"alfred_face_right":
			face_character(alfred, false)

		"deejhay_face_left":
			face_character(deejhay, true)

		"deejhay_face_right":
			face_character(deejhay, false)

		"angelo_face_left":
			face_character(angelo, true)

		"angelo_face_right":
			face_character(angelo, false)

		"elysa_face_left":
			face_character(elysa, true)

		"elysa_face_right":
			face_character(elysa, false)
		
		"show_minimap":
			minimap_show()
		
		"start_scene":
			get_tree().change_scene_to_file("res://Scenes/Cutscenes/classroom_cutscene.tscn")

extends CanvasLayer
class_name ControlTutorial

signal tutorial_finished

@onready var dim_top: ColorRect = $DimTop
@onready var dim_bottom: ColorRect = $DimBottom
@onready var dim_left: ColorRect = $DimLeft
@onready var dim_right: ColorRect = $DimRight
@onready var highlight: Panel = $Highlight
@onready var arrow: Node2D = $Arrow
@onready var panel: PanelContainer = $DescriptionPanel
@onready var title_label: Label = $DescriptionPanel/VBox/TitleLabel
@onready var desc_label: Label = $DescriptionPanel/VBox/DescLabel

var _arrow_tween: Tween
var _arrow_base_pos: Vector2
var _arrow_dir: Vector2 = Vector2.UP
var _active: bool = false


func _ready() -> void:
	hide()


# --- Public API ---------------------------------------------------------

## Highlights `target`, shows the title/description, starts the bouncing arrow,
## and waits until the player dismisses the step (or presses `advance_action`).
##
## target:           Control to spotlight (any node with a valid global rect)
## title, desc:      Text shown in the description panel
## arrow_offset:     Where the arrow sits relative to the target's top-center.
##                   e.g. Vector2(0, -80) = 80px above.
## advance_action:   If set, the step auto-advances when this InputMap action
##                   is pressed. If empty, the player taps/clicks/accepts to advance.
func show_step(
	target: CanvasItem,
	title: String,
	desc: String,
	arrow_offset: Vector2 = Vector2(0, -80),
	advance_action: StringName = &"",
	movement_seconds: float = 0.0
) -> void:
	_active = true
	visible = true

	# Let layout settle (containers need a frame to report final size)
	await get_tree().process_frame
	await get_tree().process_frame

	var rect := _get_screen_rect(target)

	_layout_dimmer(rect)
	_layout_highlight(rect)
	_layout_arrow(rect, arrow_offset)
	_layout_panel(rect)

	title_label.text = title
	desc_label.text = desc

	# Wait for the player to advance
	if movement_seconds > 0.0:
		await _wait_for_movement(movement_seconds)
	elif advance_action != &"":
		await _wait_for_action(advance_action)
	else:
		await _wait_for_dismiss()

	_active = false
	visible = false
	tutorial_finished.emit()

## Waits until the player has been moving for `duration` seconds.
## Uses the InputMap actions: left, right, up, down.
## Allows a tap-to-skip fallback once they've moved a little (1s).
func _wait_for_movement(duration: float) -> void:
	var is_dimmed := true
	
	# 1. Create a reliable timer for the 10 seconds
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)
	timer.start()
	
	# 2. Loop until the timer runs out
	while timer.time_left > 0.0 and visible:
		await get_tree().process_frame

		var moving := (
			Input.is_action_pressed("left") or
			Input.is_action_pressed("right") or
			Input.is_action_pressed("up") or
			Input.is_action_pressed("down")
		)

		# Disable dimmer when moving
		if moving and is_dimmed:
			_show_dimmer(false)
			is_dimmed = false
		# Re-enable dimmer when they stop
		elif not moving and not is_dimmed:
			_show_dimmer(true)
			is_dimmed = true
			
		# NO tap fallback for the movement step. We just let the 10s run out.
	
	# Cleanup
	timer.queue_free()
	
	# Make sure we turn the dimmer back on before leaving
	if not is_dimmed:
		_show_dimmer(true)

func _show_dimmer(show_it: bool) -> void:
	dim_top.visible = show_it
	dim_bottom.visible = show_it
	dim_left.visible = show_it
	dim_right.visible = show_it
	highlight.visible = show_it

## Returns the target's rect in screen (viewport) coordinates.
## Control -> get_global_rect(). TouchScreenButton -> texture size * scale
## at the node's canvas-space position.
func _get_screen_rect(target: CanvasItem) -> Rect2:
	if target is Control:
		return target.get_global_rect()

	if "texture_normal" in target and target.texture_normal:
		var s: Vector2 = target.texture_normal.get_size() * target.scale
		var origin := target.get_global_transform_with_canvas().origin
		return Rect2(origin, s)

	# Fallback (CanvasLayer, plain Node2D, etc.) — small box at the origin
	var p := target.get_global_transform_with_canvas().origin
	return Rect2(p, Vector2(64, 64))

# --- Layout -------------------------------------------------------------

func _layout_dimmer(r: Rect2) -> void:
	var vp := get_viewport().get_visible_rect().size

	dim_top.position = Vector2.ZERO
	dim_top.size = Vector2(vp.x, maxf(r.position.y, 0.0))

	var bottom_y := r.position.y + r.size.y
	dim_bottom.position = Vector2(0, bottom_y)
	dim_bottom.size = Vector2(vp.x, maxf(vp.y - bottom_y, 0.0))

	dim_left.position = Vector2(0, r.position.y)
	dim_left.size = Vector2(maxf(r.position.x, 0.0), r.size.y)

	var right_x := r.position.x + r.size.x
	dim_right.position = Vector2(right_x, r.position.y)
	dim_right.size = Vector2(maxf(vp.x - right_x, 0.0), r.size.y)


func _layout_highlight(r: Rect2) -> void:
	highlight.position = r.position
	highlight.size = r.size


func _layout_arrow(r: Rect2, offset: Vector2) -> void:
	var base := Vector2(r.position.x + r.size.x * 0.5, r.position.y) + offset
	arrow.position = base
	_arrow_base_pos = base
	
	# Make the arrow bigger
	arrow.scale = Vector2(2.0, 2.0)

	# Arrow points from base toward the target
	_arrow_dir = -offset.normalized() if offset.length() > 0.001 else Vector2.DOWN

	# The polygon points UP at rest. 
	# If the arrow is ABOVE the target (offset.y < 0), we rotate it 180 degrees (PI) to point DOWN.
	if offset.y < 0:
		arrow.rotation = PI
	else:
		arrow.rotation = 0

	_start_arrow_bounce()


func _layout_panel(r: Rect2) -> void:
	var vp := get_viewport().get_visible_rect().size

	# Force the container to recompute size for the new text
	panel.reset_size()
	await get_tree().process_frame

	var ps := panel.size
	var gap := 24.0 # Extra padding just in case

	# 1. Center horizontally
	var x := (vp.x * 0.5) - (ps.x * 0.5)
	
	# 2. Place at the top with padding (e.g., 80 pixels down from the top)
	var y := 80.0

	panel.position = Vector2(x, y)


# --- Arrow animation ----------------------------------------------------

func _start_arrow_bounce() -> void:
	if _arrow_tween and _arrow_tween.is_valid():
		_arrow_tween.kill()

	_arrow_tween = create_tween().set_loops()
	var far := _arrow_base_pos + _arrow_dir * 14.0
	_arrow_tween.tween_property(arrow, "position", far, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arrow_tween.tween_property(arrow, "position", _arrow_base_pos, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- Input / advancing --------------------------------------------------

func _wait_for_dismiss() -> void:
	# Accept / cancel / any click or tap dismisses
	while visible:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept") \
		or Input.is_action_just_pressed("ui_cancel"):
			return
		# Touch/mouse fallback (works even without an InputMap "ui_click")
		if _check_mouse_or_touch_pressed():
			return


func _wait_for_action(action: StringName) -> void:
	while visible:
		await get_tree().process_frame
		if Input.is_action_just_pressed(action):
			return


func _check_mouse_or_touch_pressed() -> bool:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	return Input.is_action_just_pressed("ui_accept")


# --- Safety -------------------------------------------------------------

func _exit_tree() -> void:
	if _arrow_tween and _arrow_tween.is_valid():
		_arrow_tween.kill()

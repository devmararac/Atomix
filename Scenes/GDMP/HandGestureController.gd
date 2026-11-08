extends Node

class_name HandGestureController

signal panel_toggle_requested
signal navigation_started
signal navigation_ended
signal right_hand_double_pinch # NEW: Right hand go-back signal

@export var left_hand_view: HandView
@export var right_hand_view: HandView # Reference to the right hand
@export var information_panel: CanvasLayer
@export var target_scroll: ScrollContainer

@export var pinch_threshold: float = 0.6
@export var hold_duration: float = 0.45
@export var double_pinch_window: float = 1.0
@export var scroll_sensitivity: float = 1500.0
@export var scroll_direction: float = 1.0

const THUMB_TIP: int = 4
const INDEX_TIP: int = 8

# --- LEFT HAND VARIABLES ---
var _pinch_active: bool = false
var _pinch_started_at: float = 0.0
var _pinch_started_position: Vector3 = Vector3.ZERO
var _last_index_position: Vector3 = Vector3.ZERO
var _last_tap_at: float = -1.0
var _is_navigating: bool = false

# --- RIGHT HAND VARIABLES ---
var _right_pinch_active: bool = false
var _right_last_tap_at: float = -1.0


func _process(_delta: float) -> void:
	_process_left_hand()
	_process_right_hand()

# ==========================================
# LEFT HAND LOGIC (Pinch, Tap, Scroll)
# ==========================================
func _process_left_hand() -> void:
	if left_hand_view == null or not left_hand_view.is_tracking():
		_reset_left_gesture()
		return

	var thumb_position: Vector3 = left_hand_view.get_landmark_global_position(THUMB_TIP)
	var index_position: Vector3 = left_hand_view.get_landmark_global_position(INDEX_TIP)

	var pinch_distance: float = thumb_position.distance_to(index_position)
	var is_pinching: bool = pinch_distance <= pinch_threshold

	if is_pinching and not _pinch_active:
		_begin_pinch(index_position)
	elif is_pinching and _pinch_active:
		_update_held_pinch(index_position)
	elif not is_pinching and _pinch_active:
		_end_pinch()

# ==========================================
# RIGHT HAND LOGIC (Double Pinch)
# ==========================================
func _process_right_hand() -> void:
	if right_hand_view == null or not right_hand_view.is_tracking():
		_right_pinch_active = false
		_right_last_tap_at = -1.0
		return

	var thumb_position: Vector3 = right_hand_view.get_landmark_global_position(THUMB_TIP)
	var index_position: Vector3 = right_hand_view.get_landmark_global_position(INDEX_TIP)

	var pinch_distance: float = thumb_position.distance_to(index_position)
	var is_pinching: bool = pinch_distance <= pinch_threshold

	# Detect the start of a pinch
	if is_pinching and not _right_pinch_active:
		_right_pinch_active = true
	
	# Detect the release of a pinch
	elif not is_pinching and _right_pinch_active:
		_right_pinch_active = false
		_register_right_tap()

func _register_right_tap() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0

	if _right_last_tap_at >= 0.0:
		var time_between_pinches: float = current_time - _right_last_tap_at
		if time_between_pinches <= double_pinch_window:
			_right_last_tap_at = -1.0
			print("RIGHT HAND DOUBLE PINCH DETECTED")
			right_hand_double_pinch.emit()
			return

	_right_last_tap_at = current_time

# ==========================================
# EXISTING LEFT HAND FUNCTIONS
# ==========================================
func _begin_pinch(index_position: Vector3) -> void:
	_pinch_active = true
	_pinch_started_at = Time.get_ticks_msec() / 1000.0
	_pinch_started_position = index_position
	_last_index_position = index_position

func _update_held_pinch(index_position: Vector3) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var held_time: float = current_time - _pinch_started_at

	if held_time >= hold_duration:
		if not _is_navigating:
			_is_navigating = true
			navigation_started.emit()
		_scroll_from_hand(index_position)

	_last_index_position = index_position

func _end_pinch() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var held_time: float = current_time - _pinch_started_at

	if _is_navigating:
		_is_navigating = false
		navigation_ended.emit()
	elif held_time < hold_duration:
		_register_tap(current_time)

	_pinch_active = false

func _register_tap(current_time: float) -> void:
	print("LEFT PINCH RELEASED")
	if _last_tap_at >= 0.0:
		var time_between_pinches: float = current_time - _last_tap_at
		if time_between_pinches <= double_pinch_window:
			_last_tap_at = -1.0
			print("LEFT DOUBLE PINCH DETECTED")
			if information_panel != null:
				information_panel.visible = not information_panel.visible
			panel_toggle_requested.emit()
			return
	_last_tap_at = current_time

func _scroll_from_hand(index_position: Vector3) -> void:
	if target_scroll == null:
		return
	var vertical_movement: float = index_position.y - _last_index_position.y
	target_scroll.scroll_vertical -= int(vertical_movement * scroll_sensitivity * scroll_direction)

func _reset_left_gesture() -> void:
	if _is_navigating:
		_is_navigating = false
		navigation_ended.emit()
	_pinch_active = false
	_last_tap_at = -1.0

extends CanvasLayer

@onready var popup_container: Control = $PopupContainer
@onready var texture_rect: TextureRect = $PopupContainer/TextureRect
@onready var chapter_label: Label = $PopupContainer/TextureRect/VBoxContainer/ChapterLabel
@onready var title_label: Label = $PopupContainer/TextureRect/VBoxContainer/TitleLabel
@onready var status_label: Label = $PopupContainer/TextureRect/VBoxContainer/Status

func _ready():
	visible = false
	popup_container.modulate.a = 0.0 # Start fully transparent
	# Removed the hidden_y positioning since we aren't sliding anymore

func show_popup(quest_name: String, chapter_text: String, status_text: String = "Started"):
	visible = true
	SfxManager.chest()
	title_label.text = quest_name
	chapter_label.text = chapter_text
	status_label.text = status_text
	
	# Set status color based on Started vs Completed
	if status_text.to_lower() == "completed":
		status_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5, 1)) # Gold
	else:
		status_label.add_theme_color_override("font_color", Color(1, 1, 1, 1)) # White

	# --- ANIMATION (FADE IN / FADE OUT) ---
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE) # Smooth fade curve
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# 1. Fade in (from 0 alpha to 1 alpha over 0.6 seconds)
	tween.tween_property(popup_container, "modulate:a", 1.0, 0.6)
	
	# 2. Wait for the player to read it (3.5 seconds)
	tween.tween_interval(3.5)
	
	# 3. Fade out (from 1 alpha to 0 alpha over 0.6 seconds)
	tween.tween_property(popup_container, "modulate:a", 0.0, 0.6)
	
	# 4. Hide the whole scene when done
	tween.tween_callback(func(): visible = false)

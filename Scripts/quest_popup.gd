extends CanvasLayer

@onready var popup_container: Control = $PopupContainer
@onready var texture_rect: TextureRect = $PopupContainer/TextureRect
@onready var chapter_label: Label = $PopupContainer/TextureRect/VBoxContainer/ChapterLabel
@onready var title_label: Label = $PopupContainer/TextureRect/VBoxContainer/TitleLabel
@onready var status_label: Label = $PopupContainer/TextureRect/VBoxContainer/Status

@onready var reward_container: GridContainer = $PopupContainer/Rewards/RewardContainer
@onready var rewards_panel: PanelContainer = $PopupContainer/Rewards

func _ready():
	visible = false
	popup_container.modulate.a = 0.0


func show_popup(
	quest_name: String,
	chapter_text: String,
	status_text: String = "Started"
):
	visible = true
	SfxManager.chest()

	title_label.text = quest_name
	chapter_label.text = chapter_text
	status_label.text = status_text
	# Show rewards only for completed quests
	rewards_panel.visible = status_text.to_lower() == "completed"

	# Set status color based on Started vs Completed
	if status_text.to_lower() == "completed":
		status_label.add_theme_color_override(
			"font_color",
			Color(0.9, 0.8, 0.5, 1)
		)
	else:
		status_label.add_theme_color_override(
			"font_color",
			Color(1, 1, 1, 1)
		)

	# --- ANIMATION (FADE IN / FADE OUT) ---
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# Fade in
	tween.tween_property(
		popup_container,
		"modulate:a",
		1.0,
		0.6
	)

	# Wait
	tween.tween_interval(3.5)

	# Fade out
	tween.tween_property(
		popup_container,
		"modulate:a",
		0.0,
		0.6
	)

	# Hide
	tween.tween_callback(func(): visible = false)


# ============================================================
# DISPLAY QUEST REWARDS
# ============================================================

func show_rewards(rewards: Array) -> void:

	# Clear previous rewards
	for child in reward_container.get_children():
		child.queue_free()

	for reward in rewards:

		if reward == null:
			continue

		if reward.reward_amount <= 0:
			continue

		# ----------------------------------------------------
		# COINS
		# ----------------------------------------------------

		if reward.reward_type == Reward.Type.COINS:

			var reward_box := HBoxContainer.new()
			reward_box.alignment = BoxContainer.ALIGNMENT_CENTER
			reward_box.add_theme_constant_override("separation", 6)

			# Coin Icon
			var coin_icon := TextureRect.new()
			coin_icon.texture = load("res://Assets/UX/Items/Key Items/coin.png")
			coin_icon.custom_minimum_size = Vector2(32, 32)
			coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

			# Coin Amount
			var coin_label := Label.new()
			coin_label.text = "x%d" % reward.reward_amount
			coin_label.add_theme_font_size_override("font_size", 20)
			coin_label.add_theme_color_override(
				"font_color",
				Color(0.95, 0.8, 0.3, 1)
			)
			coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

			reward_box.add_child(coin_icon)
			reward_box.add_child(coin_label)

			reward_container.add_child(reward_box)


		# ----------------------------------------------------
		# ITEMS
		# ----------------------------------------------------

		elif reward.reward_type == Reward.Type.ITEM:

			if reward.item_data == null:
				continue

			var reward_box := VBoxContainer.new()
			reward_box.alignment = BoxContainer.ALIGNMENT_CENTER

			var icon := TextureRect.new()
			icon.texture = reward.item_data.icon
			icon.custom_minimum_size = Vector2(48, 48)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

			var amount_label := Label.new()
			amount_label.text = "x%d" % reward.reward_amount
			amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			amount_label.add_theme_font_size_override(
				"font_size",
				18
			 )

			reward_box.add_child(icon)
			reward_box.add_child(amount_label)

			reward_container.add_child(reward_box)

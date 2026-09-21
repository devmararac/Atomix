extends Control

const PARTY_MANAGEMENT_SCENE := preload(
	"res://Scenes/UI/party_management.tscn"
)

@onready var display_name_value: Label = $PlayerPage/PlayerInfoPanel/DisplayNameValue
@onready var student_name_value: Label = $PlayerPage/PlayerInfoPanel/StudentNameValue
@onready var progress_value: Label = $PlayerPage/PlayerInfoPanel/ProgressValue

@onready var character_background: TextureRect = $PlayerPage/CharacterPanel/Preview
@onready var character_preview: AnimatedSprite2D = $PlayerPage/CharacterPanel/AnimatedSprite2D

@onready var battle_atomon_slots: Array[Node] = [
	$PlayerPage/PlayerInfoPanel/ScrollContainer/VBoxContainer/BattlePartySlots/Slot,
	$PlayerPage/PlayerInfoPanel/ScrollContainer/VBoxContainer/BattlePartySlots/Slot2,
	$PlayerPage/PlayerInfoPanel/ScrollContainer/VBoxContainer/BattlePartySlots/Slot3,
	$PlayerPage/PlayerInfoPanel/ScrollContainer/VBoxContainer/BattlePartySlots/Slot4,
	$PlayerPage/PlayerInfoPanel/ScrollContainer/VBoxContainer/BattlePartySlots/Slot5
]

@onready var reserve_atomon_slots: Array[Node] = [
	$PlayerPage/PlayerInfoPanel/ScrollContainer/VBoxContainer/ReserveSlots/Slot6,
	$PlayerPage/PlayerInfoPanel/ScrollContainer/VBoxContainer/ReserveSlots/Slot7,
	$PlayerPage/PlayerInfoPanel/ScrollContainer/VBoxContainer/ReserveSlots/Slot8
]

var selected_party_slot_index: int = -1


func _ready() -> void:
	update_player_page()
	refresh_carried_atomons()
	connect_party_slots()


# ============================================================
# PLAYER INFORMATION
# ============================================================

func update_player_page() -> void:
	update_player_information()
	update_character_preview()


func update_player_information() -> void:

	if PlayerManager.display_name != "":
		display_name_value.text = PlayerManager.display_name
	else:
		display_name_value.text = "Player"

	if StudentDataManager.student_data.has("name"):

		var student_name := str(
			StudentDataManager.student_data["name"]
		).strip_edges()

		if not student_name.is_empty():
			student_name_value.text = student_name
		else:
			student_name_value.text = "Student"

	else:
		student_name_value.text = "Student"

	var collected := StudentDataManager.collected_elements.size()

	progress_value.text = (
		str(collected)
		+ " / "
		+ str(StudentDataManager.TOTAL_ELEMENTS)
		+ " Elements"
	)


# ============================================================
# CHARACTER PREVIEW
# ============================================================

func update_character_preview() -> void:

	if PlayerManager.selected_character == null:
		return

	var frames: SpriteFrames = (
		PlayerManager.selected_character.sprite_frames
	)

	if frames == null:
		return

	character_preview.sprite_frames = frames
	character_preview.scale = Vector2(8, 8)

	if frames.has_animation("idle"):

		character_preview.animation = "idle"
		character_preview.frame = 0
		character_preview.play("idle")

	else:
		return

	character_preview.visible = true

	var preview_center := (
		character_background.position
		+ character_background.size / 2.0
	)

	character_preview.position = preview_center


# ============================================================
# PARTY SLOT CONNECTIONS
# ============================================================

func connect_party_slots() -> void:

	for i in range(battle_atomon_slots.size()):

		var slot: Node = battle_atomon_slots[i]

		if slot.has_signal("slot_clicked"):

			slot.slot_clicked.connect(
				_on_party_slot_clicked.bind(i)
			)

	for i in range(reserve_atomon_slots.size()):

		var slot: Node = reserve_atomon_slots[i]

		if slot.has_signal("slot_clicked"):

			slot.slot_clicked.connect(
				_on_party_slot_clicked.bind(
					5 + i
				)
			)


# ============================================================
# PARTY SLOT CLICKED
# ============================================================

func _on_party_slot_clicked(
	_current_atomon: AtomonInstance,
	carried_index: int
) -> void:

	selected_party_slot_index = carried_index

	print(
		"[PlayerPage] Opening party management for carried slot ",
		carried_index + 1
	)

	var party_management = (
		PARTY_MANAGEMENT_SCENE.instantiate()
	)

	add_child(party_management)

	party_management.set_target_index(
		carried_index
	)

	party_management.atomon_selected.connect(
		_on_management_atomon_selected
	)


# ============================================================
# REFRESH CARRIED ATOMONS
# ============================================================

func refresh_carried_atomons() -> void:

	refresh_battle_party()
	refresh_reserve_party()


func refresh_battle_party() -> void:

	var carried_party: Array[AtomonInstance] = (
		PartyManager.get_carried_party()
	)

	for i in range(battle_atomon_slots.size()):

		var slot: Node = battle_atomon_slots[i]

		if i < carried_party.size():

			var atomon: AtomonInstance = (
				carried_party[i]
			)

			if atomon != null:
				_update_atomon_slot(slot, atomon)
			else:
				_clear_atomon_slot(slot)

		else:
			_clear_atomon_slot(slot)


func refresh_reserve_party() -> void:

	var carried_party: Array[AtomonInstance] = (
		PartyManager.get_carried_party()
	)

	for i in range(reserve_atomon_slots.size()):

		var slot: Node = reserve_atomon_slots[i]

		var carried_index := (
			PartyManager.MAX_BATTLE_PARTY_SIZE
			+ i
		)

		if carried_index < carried_party.size():

			var atomon: AtomonInstance = (
				carried_party[carried_index]
			)

			if atomon != null:
				_update_atomon_slot(slot, atomon)
			else:
				_clear_atomon_slot(slot)

		else:
			_clear_atomon_slot(slot)


func _update_atomon_slot(
	slot: Node,
	atomon: AtomonInstance
) -> void:

	if not slot.has_method("set_atomon"):

		push_warning(
			"PlayerPage: Atomon slot does not have set_atomon()."
		)

		return

	slot.set_atomon(atomon)


func _clear_atomon_slot(slot: Node) -> void:

	if slot.has_method("clear_slot"):
		slot.clear_slot()


# ============================================================
# ATOMON SELECTED FROM MANAGEMENT
# ============================================================

func _on_management_atomon_selected(
	atomon: AtomonInstance
) -> void:

	if atomon == null:
		return

	if selected_party_slot_index < 0:
		return

	print(
		"[PlayerPage] Changing carried slot ",
		selected_party_slot_index + 1,
		" to ",
		atomon.data.alias
	)

	var success := (
		PartyManager.set_atomon_in_carried_slot(
			selected_party_slot_index,
			atomon
		)
	)

	if not success:

		print(
			"[PlayerPage] Failed to change carried Atomon."
		)

		selected_party_slot_index = -1
		return

	print(
		"[PlayerPage] Carried slot changed successfully."
	)

	refresh_carried_atomons()

	save_party_changes()

	selected_party_slot_index = -1


# ============================================================
# SAVE
# ============================================================

func save_party_changes() -> void:

	if SaveManager == null:

		push_warning(
			"[PlayerPage] SaveManager is not available."
		)

		return

	SaveManager.save_game()

	print(
		"[PlayerPage] Carried party changes saved."
	)

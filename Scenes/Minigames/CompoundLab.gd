class_name CompoundLab
extends Control


# ============================================================
# NODES
# ============================================================

@onready var workspace = $Workspace
@onready var element_list = $ElementPanel/Margin/Elements/Scroll/ElementList
@onready var discovery_count = $TopBar/Margin/Header/DiscoveryCount
@onready var search_box = $ElementPanel/Margin/Elements/SearchBox
@onready var clean_up_button = $BottomBar/Margin/Controls/CleanUpButton


# ============================================================
# TEMPORARY ELEMENT LIST
# ============================================================

var available_elements = [
	"H",
	"O",
	"C",
	"N",
	"Na",
	"Cl",
	"Mg",
	"Ca"
]


# ============================================================
# DISCOVERIES
# ============================================================

var discovered_compounds = []


# ============================================================
# START
# ============================================================

func _ready():
	_connect_element_buttons()

	search_box.text_changed.connect(_on_search_changed)
	clean_up_button.pressed.connect(_on_clean_up_pressed)

	_update_discovery_count()


# ============================================================
# ELEMENT BUTTONS
# ============================================================

func _connect_element_buttons():
	for element_button in element_list.get_children():
		if element_button is Button:
			element_button.pressed.connect(
				_on_element_pressed.bind(element_button.name)
			)


func _on_element_pressed(element_symbol):
	_spawn_element(element_symbol)


# ============================================================
# SPAWN ELEMENT
# ============================================================

func _spawn_element(element_symbol):
	var element = _create_element_object(element_symbol)

	if element == null:
		return

	workspace.add_child(element)

	var viewport_size = workspace.size

	var spawn_position = Vector2(
		randf_range(100.0, max(200.0, viewport_size.x - 450.0)),
		randf_range(120.0, max(200.0, viewport_size.y - 180.0))
	)

	element.position = spawn_position


func _create_element_object(element_symbol):
	var element = PanelContainer.new()

	element.custom_minimum_size = Vector2(110, 110)
	element.name = "Element_" + element_symbol

	var label = Label.new()

	label.text = element_symbol
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.add_theme_font_size_override("font_size", 36)

	element.add_child(label)

	element.set_meta("element_symbol", element_symbol)

	var drag_script = preload(
		"res://Scenes/Minigames/WorkspaceElement.gd"
	)

	element.set_script(drag_script)

	return element


# ============================================================
# SEARCH
# ============================================================

func _on_search_changed(search_text):
	var search = search_text.to_lower().strip_edges()

	for element_button in element_list.get_children():

		if not element_button is Button:
			continue

		var element_symbol = element_button.name.to_lower()
		var element_text = element_button.text.to_lower()

		if search == "":
			element_button.visible = true
			continue

		if element_symbol.contains(search):
			element_button.visible = true
		elif element_text.contains(search):
			element_button.visible = true
		else:
			element_button.visible = false


# ============================================================
# CLEAN UP
# ============================================================

func _on_clean_up_pressed():

	for child in workspace.get_children():
		child.queue_free()


# ============================================================
# DISCOVERY
# ============================================================

func discover_compound(compound_data):

	if compound_data == null:
		return

	if compound_data.formula in discovered_compounds:
		return

	discovered_compounds.append(compound_data.formula)

	_update_discovery_count()


func _update_discovery_count():

	discovery_count.text = "DISCOVERED  %d" % discovered_compounds.size()

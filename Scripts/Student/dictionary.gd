
extends Control

# ============================================================
# SCENE REFERENCES
# ============================================================

@onready var search_bar: LineEdit = $Panel/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/SearchPanel/SearchBar

@onready var filter_button: OptionButton = $Panel/VBoxContainer/ToolbarPanel/MarginContainer/HBoxContainer/FilterPanel/FilterButton

@onready var dictionary_list: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/VBoxContainer


# ============================================================
# DICTIONARY ROW SCENE
# ============================================================

const DICTIONARY_ROW = preload(
	"res://Scenes/UI/Student/dictionary_row.tscn"
)


# ============================================================
# DICTIONARY DATA
# ============================================================

var dictionary_data: Array[Dictionary] = [
	{
		"word": "Matter:",
		"category": "Basic Chemistry",
		"description": "Anything that has mass and occupies space. Everything around us, including air, water, and living things, is made of matter."
	},
	{
		"word": "Element:",
		"category": "Basic Chemistry",
		"description": "A pure substance made of only one kind of atom. Examples include Hydrogen, Oxygen, and Iron."
	},
	{
		"word": "Atomon:",
		"category": "Game Term",
		"description": "A short term for Atomic Monsters, is the Elements in the Periodic Table represented as Monsters."
	},
	{
		"word": "Atom:",
		"category": "Atomic Structure",
		"description": "The smallest unit of an element that still keeps the chemical properties of that element."
	},
	{
		"word": "Proton:",
		"category": "Atomic Structure",
		"description": "A positively charged particle found inside the nucleus of an atom.  Used as a Crafting Material"
	},
	{
		"word": "Neutron:",
		"category": "Atomic Structure",
		"description": "A particle with no electric charge found inside the nucleus of an atom.  Used as a Crafting Material"
	},
	{
		"word": "Electron:",
		"category": "Atomic Structure",
		"description": "A negatively charged particle found in the space surrounding an atom's nucleus.  Used as a Crafting Material"
	},
	{
		"word": "Nucleus:",
		"category": "Atomic Structure",
		"description": "The small, dense center of an atom. It contains protons and neutrons. Used as a Crafting Material"
	},
	{
		"word": "Atomic Number:",
		"category": "Atomic Structure",
		"description": "The number of protons in the nucleus of an atom. It identifies which element the atom belongs to."
	},
	{
		"word": "HP(Hit Points):",
		"category": "Atomon Game Stats",
		"description": "A numerical value that measures how much damage an Atomon can take. Calculated with Atomic Mass and Period Group"
	},
	{
		"word": "Attack:",
		"category": "Atomon Game Stats",
		"description": "A numerical value that measures how much damage an Atomon can deal. Ionization Energy"
	},
	{
		"word": "Special Attack:",
		"category": "Atomon Game Stats",
		"description": "A numerical value that measures how much special(magic) damage an Atomon can deal. Calculated with Electronegativity."
	},
	{
		"word": "Defense:",
		"category": "Atomon Game Stats",
		"description": "A numerical value that reduce an Atomon damage recieved. Calculated with Density."
	},
	{
		"word": "Special Defense:",
		"category": "Atomon Game Stats",
		"description": "A numerical value that reduce an Atomon special(magic) damage recieved. Calculated with Electron Affinity."
	},
	{
		"word": "Speed:",
		"category": "Atomon Game Stats",
		"description": "A numerical value that determine which Atomon Attack First. Calculated with the elements Phase and Atomic Mass."
	},
	{
		"word": "Isotope:",
		"category": "Atomic Structure",
		"description": "Atoms of the same element that have the same number of protons but different numbers of neutrons."
	},
	{
		"word": "Ion:",
		"category": "Chemical Bonding",
		"description": "An atom or group of atoms that has gained or lost electrons and therefore has an electric charge."
	},
	{
		"word": "Valence Electron:",
		"category": "Chemical Bonding",
		"description": "An electron in the outermost occupied shell of an atom. It plays an important role in chemical bonding."
	},
	{
		"word": "Octet Rule:",
		"category": "Chemical Bonding",
		"description": "A general rule stating that many atoms tend to gain, lose, or share electrons to achieve eight electrons in their outermost shell."
	},
	{
		"word": "Chemical Bond:",
		"category": "Chemical Bonding",
		"description": "An attractive force that holds atoms or ions together in a substance."
	},
	{
		"word": "Ionic Bond:",
		"category": "Chemical Bonding",
		"description": "An attraction between oppositely charged ions, commonly formed when electrons are transferred from one atom to another."
	},
	{
		"word": "Covalent Bond:",
		"category": "Chemical Bonding",
		"description": "A chemical bond formed when atoms share pairs of electrons."
	},
	{
		"word": "Molecule:",
		"category": "Chemical Bonding",
		"description": "A group of two or more atoms held together by covalent bonds."
	},
	{
		"word": "Compound:",
		"category": "Basic Chemistry",
		"description": "A pure substance made of two or more different elements chemically combined in fixed proportions. Used as the Fusion Skill Mechanic"
	},
	{
		"word": "Periodic Table:",
		"category": "Periodic Table",
		"description": "A chart that organizes chemical elements according to their atomic numbers and recurring chemical properties."
	},

	{
		"word": "Chemical Formula:",
		"category": "Chemical Bonding",
		"description": "A combination of element symbols and numbers that shows which elements are present in a substance and their proportions. Used to detirmine which Atomon are available for compound skill"
	}
]


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	search_bar.text_changed.connect(_on_search_text_changed)
	filter_button.item_selected.connect(_on_sort_selected)

	_populate_dictionary()

	print("[Dictionary] Loaded successfully.")


# ============================================================
# POPULATE DICTIONARY
# ============================================================

func _populate_dictionary() -> void:
	_clear_dictionary_list()

	var search_text: String = search_bar.text.strip_edges().to_lower()

	var filtered_entries: Array[Dictionary] = []

	for entry in dictionary_data:
		var word: String = entry["word"]

		if search_text.is_empty() or word.to_lower().contains(search_text):
			filtered_entries.append(entry)

	_sort_entries(filtered_entries)

	for entry in filtered_entries:
		var row = DICTIONARY_ROW.instantiate()

		if row == null:
			continue

		dictionary_list.add_child(row)

		var word_label: Label = row.get_node("VBoxContainer/Word")
		var description_label: Label = row.get_node("VBoxContainer/Description")

		word_label.text = entry["word"]
		description_label.text = entry["description"]

		row.mouse_filter = Control.MOUSE_FILTER_PASS

	if filtered_entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No matching terms found."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_override(
			"font",
			preload("res://Assets/Font/NicoPaint-Regular.woff")
		)
		empty_label.add_theme_font_size_override("font_size", 30)
		empty_label.add_theme_color_override(
			"font_color",
			Color(0.47, 0.35, 0.23)
		)
		dictionary_list.add_child(empty_label)

# ============================================================
# CLEAR LIST
# ============================================================

func _clear_dictionary_list() -> void:
	for child in dictionary_list.get_children():
		child.queue_free()


# ============================================================
# SEARCH
# ============================================================

func _on_search_text_changed(_new_text: String) -> void:
	_populate_dictionary()


# ============================================================
# SORTING
# ============================================================

func _on_sort_selected(index: int) -> void:
	_populate_dictionary()


func _sort_entries(entries: Array[Dictionary]) -> void:
	match filter_button.selected:
		1:
			entries.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return a["word"].to_lower() < b["word"].to_lower()
			)

		2:
			entries.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return a["word"].to_lower() > b["word"].to_lower()
			)

extends TextureButton

signal element_selected(element: AtomonData, crafted: bool)

var element_data: AtomonData
var is_crafted := false

const TYPE_BACKGROUNDS = {
	"Nonmetal": preload("res://Assets/UX/Icons/nonmetal.png"),
	"Post-transition Metal": preload("res://Assets/UX/Icons/post_transition_metal.png"),
	"Metalloid": preload("res://Assets/UX/Icons/metalloids.png"),
	"Noble Gas": preload("res://Assets/UX/Icons/noble_gas.png"),
	"Halogen": preload("res://Assets/UX/Icons/halogen.png"),
	"Alkali Metal": preload("res://Assets/UX/Icons/akali_metals.png"),
	"Alkaline Earth Metal": preload("res://Assets/UX/Icons/alkaline_metal.png"),
	"Transition Metal": preload("res://Assets/UX/Icons/transition_metal.png"),
	"Lanthanide": preload("res://Assets/UX/Icons/lanthanide.png"),
	"Actinide": preload("res://Assets/UX/Icons/actinide.png")
}


func set_element(element: AtomonData):
	element_data = element

	# Store the real data internally,
	# but DON'T display it yet.

	$"Atomic Symbol".text = "?"
	$"Atomic Mass".text = "?"
	$"Atomic Number".text = "?"
	$"Atomic Name".text = "?"

	$CraftedImage.texture = TYPE_BACKGROUNDS.get(element.element_type)

	# Every element starts uncrafted.
	set_crafted(false)


func set_crafted(value: bool):
	is_crafted = value

	$CraftedImage.visible = is_crafted

	if is_crafted:
		$"Atomic Symbol".text = element_data.chemical_symbol
		$"Atomic Mass".text = str(element_data.atomic_mass)
		$"Atomic Number".text = str(element_data.atomic_number)
		$"Atomic Name".text = element_data.atom_name
	else:
		$"Atomic Symbol".text = "44"
		$"Atomic Mass".text = "?.?????????"
		$"Atomic Number".text = "???"
		$"Atomic Name".text = "???????????"


func _pressed():
	print("ELEMENT BUTTON PRESSED")

	if element_data == null:
		print("ERROR: element_data is NULL")
		return

	print("Element: ", element_data.atom_name)
	
	element_selected.emit(element_data, is_crafted)

extends Node
class_name AtomonDatabase

const ELEMENTS := {
	# Period 1
	"H": preload("res://Resources/Atomons/Hydrogen.tres"),
	"He": preload("res://Resources/Atomons/helium.tres"),

	# Period 2
	"Li": preload("res://Resources/Atomons/lithium.tres"),
	"Be": preload("res://Resources/Atomons1/Beryllium.tres"),
	"B": preload("res://Resources/Atomons1/Boron.tres"),
	"C": preload("res://Resources/Atomons/Carbon.tres"),
	"N": preload("res://Resources/Atomons/Nitrogen.tres"),
	"O": preload("res://Resources/Atomons/Oxygen.tres"),
	"F": preload("res://Resources/Atomons/Fluorine.tres"),
	"Ne": preload("res://Resources/Atomons/Neon.tres"),

	# Period 3
	"Na": preload("res://Resources/Atomons/Sodium.tres"),
	"Mg": preload("res://Resources/Atomons1/Magnesium.tres"),
	"Al": preload("res://Resources/Atomons/Aluminium.tres"),
	"Si": preload("res://Resources/Atomons/Silicon.tres"),
	"P": preload("res://Resources/Atomons/Phosphorus.tres"),
	"S": preload("res://Resources/Atomons1/Sulfur.tres"),
	"Cl": preload("res://Resources/Atomons/Chlorine.tres"),
	"Ar": preload("res://Resources/Atomons/Argon.tres"),

	# Period 4
	"K": preload("res://Resources/Atomons1/Potassium.tres"),
	"Ca": preload("res://Resources/Atomons/Calcium.tres"),
	"Sc": preload("res://Resources/Atomons1/Scandium.tres"),
	"Ti": preload("res://Resources/Atomons1/Titanium.tres"),
	"V": preload("res://Resources/Atomons1/Vanadium.tres"),
	"Cr": preload("res://Resources/Atomons1/Chromium.tres"),
	"Mn": preload("res://Resources/Atomons1/Manganese.tres"),
	"Fe": preload("res://Resources/Atomons/Iron.tres"),
	"Co": preload("res://Resources/Atomons1/Cobalt.tres"),
	"Cu": preload("res://Resources/Atomons/Copper.tres"),
	"Zn": preload("res://Resources/Atomons1/Zinc.tres"),
	"Ga": preload("res://Resources/Atomons/Gallium.tres"),
	"Ge": preload("res://Resources/Atomons1/Germanium.tres"),
	#"As": preload("res://Resources/Atomons1/Arsenic.tres"),
	"Se": preload("res://Resources/Atomons1/Selenium.tres"),
	"Br": preload("res://Resources/Atomons/Bromine.tres"),
	#"Kr": preload("res://Resources/Atomons1/Krypton.tres"),

	# Period 5
	"Rb": preload("res://Resources/Atomons1/Rubidium.tres"),
	"Sr": preload("res://Resources/Atomons1/Strontium.tres"),
	"Y": preload("res://Resources/Atomons1/Yttrium.tres"),
	"Zr": preload("res://Resources/Atomons1/Zirconium.tres"),
	#"Nb": preload("res://Resources/Atomons1/Niobium.tres"),
	#"Mo": preload("res://Resources/Atomons1/Molybdenum.tres"),
	#"Tc": preload("res://Resources/Atomons1/Technetium.tres"),
	#"Ru": preload("res://Resources/Atomons1/Ruthenium.tres"),
	#"Rh": preload("res://Resources/Atomons1/Rhodium.tres"),
	#"Pd": preload("res://Resources/Atomons1/Palladium.tres"),
	#"Ag": preload("res://Resources/Atomons1/Silver.tres"),
	#"Cd": preload("res://Resources/Atomons1/Cadmium.tres"),
	#"In": preload("res://Resources/Atomons1/Indium.tres"),
	#"Sn": preload("res://Resources/Atomons1/Tin.tres"),
	#"Sb": preload("res://Resources/Atomons1/Antimony.tres"),
	#"Te": preload("res://Resources/Atomons1/Tellurium.tres"),
	#"I": preload("res://Resources/Atomons1/Iodine.tres"),
	#"Xe": preload("res://Resources/Atomons1/Xenon.tres"),

	# Period 6
	#"Cs": preload("res://Resources/Atomons1/Caesium.tres"),
	#"Ba": preload("res://Resources/Atomons1/Barium.tres"),

	# Lanthanides
	#"La": preload("res://Resources/Atomons1/Lanthanum.tres"),
	#"Ce": preload("res://Resources/Atomons1/Cerium.tres"),
	#"Pr": preload("res://Resources/Atomons1/Praseodymium.tres"),
	#"Nd": preload("res://Resources/Atomons1/Neodymium.tres"),
	#"Pm": preload("res://Resources/Atomons1/Promethium.tres"),
	#"Sm": preload("res://Resources/Atomons1/Samarium.tres"),
	#"Eu": preload("res://Resources/Atomons1/Europium.tres"),
	#"Gd": preload("res://Resources/Atomons1/Gadolinium.tres"),
	#"Tb": preload("res://Resources/Atomons1/Terbium.tres"),
	#"Dy": preload("res://Resources/Atomons1/Dysprosium.tres"),
	#"Ho": preload("res://Resources/Atomons1/Holmium.tres"),
	#"Er": preload("res://Resources/Atomons1/Erbium.tres"),
	#"Tm": preload("res://Resources/Atomons1/Thulium.tres"),
	#"Yb": preload("res://Resources/Atomons1/Ytterbium.tres"),
	#"Lu": preload("res://Resources/Atomons1/Lutetium.tres"),

	# Period 6 continued
	#"Hf": preload("res://Resources/Atomons1/Hafnium.tres"),
	#"Ta": preload("res://Resources/Atomons1/Tantalum.tres"),
	#"W": preload("res://Resources/Atomons1/Tungsten.tres"),
	#"Re": preload("res://Resources/Atomons1/Rhenium.tres"),
	#"Os": preload("res://Resources/Atomons1/Osmium.tres"),
	#"Ir": preload("res://Resources/Atomons1/Iridium.tres"),
	#"Pt": preload("res://Resources/Atomons1/Platinum.tres"),
	#"Au": preload("res://Resources/Atomons1/Gold.tres"),
	#"Hg": preload("res://Resources/Atomons1/Mercury.tres"),
	#"Tl": preload("res://Resources/Atomons1/Thallium.tres"),
	#"Pb": preload("res://Resources/Atomons1/Lead.tres"),
	#"Bi": preload("res://Resources/Atomons1/Bismuth.tres"),
	#"Po": preload("res://Resources/Atomons1/Polonium.tres"),
	#"At": preload("res://Resources/Atomons1/Astatine.tres"),
	#"Rn": preload("res://Resources/Atomons1/Radon.tres"),

	# Period 7
	#"Fr": preload("res://Resources/Atomons1/Francium.tres"),
	#"Ra": preload("res://Resources/Atomons1/Radium.tres"),

	# Actinides
	"Ac": preload("res://Resources/Atomons1/Actinium.tres"),
	#"Th": preload("res://Resources/Atomons1/Thorium.tres"),
	#"Pa": preload("res://Resources/Atomons1/Protactinium.tres"),
	#"U": preload("res://Resources/Atomons1/Uranium.tres"),
	#"Np": preload("res://Resources/Atomons1/Neptunium.tres"),
	#"Pu": preload("res://Resources/Atomons1/Plutonium.tres"),
	#"Am": preload("res://Resources/Atomons1/Americium.tres"),
	#"Cm": preload("res://Resources/Atomons1/Curium.tres"),
	#"Bk": preload("res://Resources/Atomons1/Berkelium.tres"),
	#"Cf": preload("res://Resources/Atomons1/Californium.tres"),
	#"Es": preload("res://Resources/Atomons1/Einsteinium.tres"),
	#"Fm": preload("res://Resources/Atomons1/Fermium.tres"),
	#"Md": preload("res://Resources/Atomons1/Mendelevium.tres"),
	#"No": preload("res://Resources/Atomons1/Nobelium.tres"),
	#"Lr": preload("res://Resources/Atomons1/Lawrencium.tres"),

	# Period 7 continued
	#"Rf": preload("res://Resources/Atomons1/Rutherfordium.tres"),
	#"Db": preload("res://Resources/Atomons1/Dubnium.tres"),
	#"Sg": preload("res://Resources/Atomons1/Seaborgium.tres"),
	#"Bh": preload("res://Resources/Atomons1/Bohrium.tres"),
	#"Hs": preload("res://Resources/Atomons1/Hassium.tres"),
	#"Mt": preload("res://Resources/Atomons1/Meitnerium.tres"),
	#"Ds": preload("res://Resources/Atomons1/Darmstadtium.tres"),
	#"Rg": preload("res://Resources/Atomons1/Roentgenium.tres"),
	#"Cn": preload("res://Resources/Atomons1/Copernicium.tres"),
	#"Nh": preload("res://Resources/Atomons1/Nihonium.tres"),
	#"Fl": preload("res://Resources/Atomons1/Flerovium.tres"),
	#"Mc": preload("res://Resources/Atomons1/Moscovium.tres"),
	#"Lv": preload("res://Resources/Atomons1/Livermorium.tres"),
	#"Ts": preload("res://Resources/Atomons1/Tennessine.tres"),
	#"Og": preload("res://Resources/Atomons1/Oganesson.tres"),
}

static func get_element(symbol: String) -> AtomonData:
	return ELEMENTS.get(symbol, null)


static func has_element(symbol: String) -> bool:
	return ELEMENTS.has(symbol)

	#"": preload(),

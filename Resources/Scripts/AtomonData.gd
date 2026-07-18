extends Resource
class_name AtomonData

# Identity
@export var atom_name : = ""
@export var chemical_symbol : = "" 
@export var atomic_number : = 1
@export var alias : = ""

# Visual

@export var sprite_frames: SpriteFrames
@export var symbol: Texture2D
@export var portrait: Texture2D

# Overworld
@export var move_speed := 20.0

# Scientific Properties Values as Stats 
# ===== Scientific Properties =====

@export var atomic_mass: float = 1.008                # HP
@export var density: float = 0.0000899                # Defense
@export var ionization_energy: float = 13.598         # Attack
@export var electronegativity: float = 2.3            # Special Attack
@export var electron_affinity: float = 72.8           # Special Defense

@export_range(0, 8)
var valence_electrons: int = 0                        # Fusion Gauge


@export_enum(
	"Alkali Metal",
	"Alkaline Earth Metal",
	"Transition Metal",
	"Post-transition Metal",
	"Metalloid",
	"Reactive Nonmetal",
	"Halogen",
	"Noble Gas",
	"Lanthanide",
	"Actinide"
)
var element_type: String = "Reactive Nonmetal"

@export_enum("Solid", "Liquid", "Gas")
var state: String = "Gas"                             # Speed Modifier

@export_enum("s", "p", "d", "f")
var block: String = "s"

@export var radioactive := false

@export_range(1, 7)
var period := 1

# Battle
@export var moves: Array[MoveData]


# Capture
@export var catch_rate := 100

# Economy
@export var sell_price := 50
@export var rarity := 1

# Encyclopedia
@export_multiline var description := ""

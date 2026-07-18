extends Resource
class_name MoveEffect

@export_enum(
	"Corrode",
	"Oxidize",
	"Catalyze",
	"Passivate",
	"Ionize",
	"Polarize",
	"Excite",
	"Stabilize",
	"Inhibit",
	"Neutralize"
)
var effect_name := "Corrode"

@export var value := 1
@export_range(0,100)
var chance := 100
@export var duration := 0

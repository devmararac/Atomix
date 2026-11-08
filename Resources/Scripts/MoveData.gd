extends Resource
class_name MoveData

@export var move_name := ""
@export_multiline var description := ""

@export_range(1,100)
var accuracy := 100

@export var priority := 0

@export var max_uses := 20   # (temporary replacement for PP)

@export var actions : Array[MoveAction] = []

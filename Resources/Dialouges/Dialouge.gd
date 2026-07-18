extends Resource

class_name Dialouge

@export var dialouges = {}

func load_from_json(file_path):
	var data = FileAccess.get_file_as_string(file_path)
	var parsed_data = JSON.parse_string(data)
	if parsed_data:
		dialouges = parsed_data
	else:
		print("Failed to parse: ", parsed_data)

func get_npc_dialouge(npc_id):
	if npc_id in dialouges:
		return dialouges[npc_id]["tree"]
	else:
		return[]

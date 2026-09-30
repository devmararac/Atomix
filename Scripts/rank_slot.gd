extends TextureButton

# ============================================================
# DATA
# ============================================================

var rank: int = 0
var student_data: Dictionary = {}


# ============================================================
# SETUP
# ============================================================

func setup(
	student: Dictionary,
	student_rank: int
) -> void:

	student_data = student
	rank = student_rank

	_update_display()


# ============================================================
# DISPLAY
# ============================================================

func _update_display() -> void:
	var rank_label := get_node_or_null("HBoxContainer/Rank") as Label
	var name_label := get_node_or_null("HBoxContainer/Name") as Label
	var section_label := get_node_or_null("HBoxContainer/Section") as Label
	var collected_label := get_node_or_null(
		"HBoxContainer/AtomonCollected"
	) as Label

	if rank_label:
		rank_label.text = str(rank)

	if name_label:
		name_label.text = str(
			student_data.get(
				"name",
				"Unknown Student"
			)
		)

	if section_label:
		section_label.text = str(
			student_data.get(
				"section",
				"Unassigned"
			)
		)

	if collected_label:
		collected_label.text = (
			str(
				student_data.get(
					"elements_collected",
					0
				)
			)
			+ "/"
			+ str(
				student_data.get(
					"elements_total",
					118
				)
			)
		)


# ============================================================
# GETTERS
# ============================================================

func get_student_data() -> Dictionary:
	return student_data


func get_rank() -> int:
	return rank

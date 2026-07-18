extends CanvasLayer

signal atomon_selected(index:int)
signal closed

@onready var slots = [
	$NinePatchRect/BG/ScrollContainer/GridContainer/slot_1,
	$NinePatchRect/BG/ScrollContainer/GridContainer/slot_2,
	$NinePatchRect/BG/ScrollContainer/GridContainer/slot_3,
	$NinePatchRect/BG/ScrollContainer/GridContainer/slot_4,
	$NinePatchRect/BG/ScrollContainer/GridContainer/slot_5,
]

func _ready():

	var party = PartyManager.get_party()

	for i in range(slots.size()):

		if i < party.size():

			slots[i].set_atomon(party[i])

			slots[i].slot_clicked.connect(
				func(_instance):
					_on_slot_clicked(i)
			)

		else:

			slots[i].clear_slot()


func _on_slot_clicked(index:int):

	atomon_selected.emit(index)


func _on_close_button_pressed():

	closed.emit()
	queue_free()

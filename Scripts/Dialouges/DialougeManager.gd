extends Node

@onready var dialouge_ui = $DialougeUI

var npc: Node = null

#Show Dialouge With Data
func show_dialouge(npc, text = "", options = {}):
	if text != "":
		#Show empty box
		dialouge_ui.show_dialouge(npc.npc_name, text, options)
	else:
		#Show quest related dialouges
		var quest_dialouge = npc.get_quest_dialouge()
		if quest_dialouge["text"] != "":
			dialouge_ui.show_dialouge(npc.npc_name, quest_dialouge["text"], quest_dialouge["options"])
		else:
		#Show non quest related dialouges
			var dialouge = npc.get_current_dialouge()
			if dialouge == null:
				return
			dialouge_ui.show_dialouge(npc.npc_name, dialouge["text"], dialouge["options"])

func hide_dialouge():
	dialouge_ui.hide_dialouge()

#Dialouge State management 
func handle_dialouge_choice(option):
	
	#Get current dialouge branch 
	var current_dialouge = npc.get_current_dialouge()
	if current_dialouge == null:
		return
	
	#Update state
	var next_state = current_dialouge["options"].get(option, "start")
	npc.set_dialouge_state(next_state)
	
	#Handle State Transitions
	if next_state == "end":
			show_dialouge(npc)
			return
	elif next_state == "exit":
		show_dialouge(npc)
		return
	elif next_state == "give_quests":
		if npc.dialouge_resource.get_npc_dialouge(npc.npc_id)[npc.current_branch_index]["branch_id"] == "npc_default":
			offer_remaining_quest()
		else:
			offer_quests(npc.dialouge_resource.get_npc_dialouge(npc.npc_id)[npc.current_branch_index]["branch_id"])
		show_dialouge(npc)
	else:
		show_dialouge(npc)

#At banch, offer all currently available quests
func offer_quests(branch_id: String):
	for quest in npc.quests:
		if quest.unlock_id == branch_id and quest.state == "not_started":
			npc.offer_quest(quest.quest_id)

#At default branch, offer all previously unaccepted quests
func offer_remaining_quest():
	for quest in npc.quests:
		if quest.state == "not_started":
			npc.offer_quest(quest.quest_id)

extends Node

const SAVE_PATH := "user://save.tres"

var save_data: SaveData = null

func save_game():

	save_data = SaveData.new()

	# Player
	save_data.player_name = "Player"
	save_data.coins = CurrencyManager.coins

	save_data.current_scene = get_tree().current_scene.scene_file_path
	save_data.player_position = global.player.global_position

	# Party
	save_data.party = PartyManager.party.duplicate(true)
	print("===== SAVING PARTY =====")
	for atomon in PartyManager.party:
		print(atomon.data.atom_name, atomon.current_pp)
	save_data.active_index = PartyManager.active_index

	# Inventory
	save_data.inventory = InventoryManager.inventory.duplicate(true)

	var error = ResourceSaver.save(save_data, SAVE_PATH)

	if error == OK:
		print("Game Saved!")
	else:
		print("Save Failed:", error)


func load_game():

	if !ResourceLoader.exists(SAVE_PATH):
		print("No save found.")
		return

	save_data = load(SAVE_PATH)
	CurrencyManager.set_coins(save_data.coins)

	# Party
	PartyManager.party.clear()

	for atomon in save_data.party:
		PartyManager.party.append(atomon.duplicate(true))

	PartyManager.active_index = save_data.active_index
	for i in range(save_data.party.size()):
		print(
			save_data.party[i].data.atom_name,
			" same object = ",
			save_data.party[i] == PartyManager.party[i]
		)

	# Inventory
	InventoryManager.inventory.clear()

	for item in save_data.inventory:
		InventoryManager.add_item(item.duplicate(true))
	
	await get_tree().change_scene_to_file(save_data.current_scene)
	await get_tree().process_frame
	await get_tree().process_frame

	global.player.global_position = save_data.player_position


func upload_to_firebase():
	pass


func download_from_firebase():
	pass


func collect_game_data():
	save_data.party = PartyManager.party
	save_data.current_scene = get_tree().current_scene.scene_file_path
	save_data.player_position = global.player.global_position


func apply_game_data():
	PartyManager.party = save_data.party

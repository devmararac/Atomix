class_name SaveData
extends Resource



# Player
@export var player_name := ""
@export var coins := 0

# Position
@export var current_scene := ""
@export var player_position := Vector2.ZERO

# Party
@export var party: Array[AtomonInstance]
@export var active_index := 0

# Firebase party state
@export var firebase_party_data: Array = []
@export var firebase_inventory_data: Array = []

# Inventory
@export var inventory: Array[ItemInstance] = []

# Quests
@export var completed_quests: Array[String] = []
@export var active_quests: Array[String] = []

# World
@export var switches := {}
@export var variables := {}

# Future
@export var play_time := 0
@export var badges: Array[String] = []

class_name SaveData
extends Resource


# ============================================================
# PLAYER
# ============================================================

@export var player_name := ""
@export var coins := 0


# ============================================================
# POSITION
# ============================================================

@export var current_scene := ""
@export var player_position := Vector2.ZERO


# ============================================================
# PARTY
# ============================================================

# Complete Atomon collection.
@export var party: Array[AtomonInstance] = []

# Currently active Battle Atomon index.
@export var active_index := 0


# ============================================================
# FIREBASE PARTY STATE
# ============================================================

# Complete collection saved to Firebase.
@export var firebase_party_data: Array = []

# Exact carried-party arrangement saved to Firebase.
#
# Each entry contains the instance_id of the Atomon occupying
# that carried slot.
#
# Index:
# 0-4 = Battle Party
# 5-7 = Reserve
#
# Empty slots are stored as an empty string.
@export var firebase_carried_party_data: Array = []


# ============================================================
# FIREBASE INVENTORY STATE
# ============================================================

@export var firebase_inventory_data: Array = []


# ============================================================
# INVENTORY
# ============================================================

@export var inventory: Array[ItemInstance] = []


# ============================================================
# QUESTS
# ============================================================

@export var quest_data: Dictionary = {}


# ============================================================
# WORLD
# ============================================================

@export var switches := {}
@export var variables := {}


# ============================================================
# FUTURE
# ============================================================

@export var play_time := 0
@export var badges: Array[String] = []

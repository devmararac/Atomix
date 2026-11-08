extends Node

signal coins_changed(new_amount: int)

var coins: int = 0

func add_coins(amount: int):
	if amount <= 0:
		return
	
	coins += amount
	coins_changed.emit(coins)

func remove_coins(amount: int):
	if amount <= 0:
		return
	
	coins = max(0, coins - amount)
	coins_changed.emit(coins)

func has_coins(amount: int) -> bool:
	return coins >= amount

func set_coins(amount: int):
	coins = max(0, amount)
	coins_changed.emit(coins)

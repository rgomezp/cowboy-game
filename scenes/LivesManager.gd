extends Node

signal lives_changed(lives: int)
signal life_lost(lives_remaining: int)

const MAX_LIVES: int = 3

var lives: int = 0

func reset():
	lives = 0
	lives_changed.emit(lives)

func add_life():
	if lives < MAX_LIVES:
		lives += 1
		lives_changed.emit(lives)
		return true
	return false

func remove_life() -> bool:
	if lives > 0:
		lives -= 1
		lives_changed.emit(lives)
		life_lost.emit(lives)
		return true
	return false

func has_lives() -> bool:
	return lives > 0

func is_at_max() -> bool:
	return lives >= MAX_LIVES

func get_lives() -> int:
	return lives

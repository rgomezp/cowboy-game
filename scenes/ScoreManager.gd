extends Node

signal score_updated(score: int)
signal high_score_updated(high_score: int)
signal score_delta(delta: int)  # Emitted when score changes, with the delta amount

var score : int = 0
var high_score : int = 0
const SCORE_MODIFIER : int = 100

func reset():
	score = 0
	score_updated.emit(score)

func add_score(amount: int, show_delta: bool = false):
	score += amount
	score_updated.emit(score)
	# Only emit the delta signal if explicitly requested (for bonus events)
	if show_delta:
		score_delta.emit(amount)

func check_high_score():
	if score > high_score:
		high_score = score
		high_score_updated.emit(high_score)

func get_display_score() -> int:
	return score / SCORE_MODIFIER

func get_display_high_score() -> int:
	return high_score / SCORE_MODIFIER

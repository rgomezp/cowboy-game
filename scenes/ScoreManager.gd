extends Node

signal score_updated(score: int)
signal high_score_updated(high_score: int)
signal score_delta(delta: int)  # Emitted when score changes, with the delta amount

var score : int = 0
var high_score : int = 0
const SCORE_MODIFIER : int = 100

const SAVE_FILE_PATH = "user://high_score.save"

func _ready():
	load_high_score()

func reset():
	score = 0
	score_updated.emit(score)

func add_score(amount: int, show_delta: bool = false):
	score += amount
	# Ensure score never goes below 0
	if score < 0:
		score = 0
	score_updated.emit(score)
	# Only emit the delta signal if explicitly requested (for bonus events)
	if show_delta:
		score_delta.emit(amount)

func check_high_score():
	if score > high_score:
		high_score = score
		save_high_score()
		high_score_updated.emit(high_score)

func save_high_score():
	var config = ConfigFile.new()
	config.set_value("score", "high_score", high_score)
	var error = config.save(SAVE_FILE_PATH)
	if error != OK:
		print("[ScoreManager] Failed to save high score: ", error)
	else:
		print("[ScoreManager] High score saved: ", high_score)

func load_high_score():
	var config = ConfigFile.new()
	var error = config.load(SAVE_FILE_PATH)
	if error != OK:
		# File doesn't exist or couldn't be loaded - use default value of 0
		print("[ScoreManager] No saved high score found, starting with 0")
		high_score = 0
		return
	
	var saved_high_score = config.get_value("score", "high_score", 0)
	if saved_high_score is int:
		high_score = saved_high_score
		print("[ScoreManager] Loaded high score: ", high_score)
		# Emit signal to update HUD with loaded high score
		high_score_updated.emit(high_score)
	else:
		print("[ScoreManager] Invalid high score data, using default value of 0")
		high_score = 0

func get_display_score() -> int:
	return int(float(score) / float(SCORE_MODIFIER))

func get_display_high_score() -> int:
	return int(float(high_score) / float(SCORE_MODIFIER))

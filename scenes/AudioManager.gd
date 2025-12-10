extends Node

# Audio manager for Connor's voice lines ONLY
# Ensures only one Connor voice line plays at a time using a mutex mechanism
# NOTE: This mutex does NOT affect background music or other game audio
# Only the Connor voice lines (alright, mhm, makes_sense, hwhat) are managed here

var audio_players: Dictionary = {}
var is_playing: bool = false
var current_player: AudioStreamPlayer = null

func initialize(players: Dictionary):
	# Initialize with dictionary of Connor voice line audio player nodes
	# Format: {"alright": $AlrightSound, "mhm": $MhmSound, ...}
	# NOTE: Only Connor's voice lines should be registered here
	audio_players = players
	print("[AudioManager] Initialized with ", audio_players.size(), " Connor voice line audio players")

func play_sound(sound_name: String, probability: float = 1.0) -> bool:
	# Play a Connor voice line if not already playing and probability check passes
	# Returns true if sound was played, false otherwise
	# NOTE: This mutex only prevents overlapping Connor voice lines, not other audio
	
	# Check if already playing (mutex for Connor voice lines only)
	if is_playing:
		print("[AudioManager] Connor voice line already playing, skipping: ", sound_name)
		return false
	
	# Check probability
	if randf() >= probability:
		print("[AudioManager] Probability check failed for: ", sound_name)
		return false
	
	# Get the audio player
	if not audio_players.has(sound_name):
		print("[AudioManager] ERROR: Sound not found: ", sound_name)
		return false
	
	var player = audio_players[sound_name]
	if not player or not player.stream:
		print("[AudioManager] ERROR: Player or stream not available for: ", sound_name)
		return false
	
	# Play the sound
	is_playing = true
	current_player = player
	player.play()
	print("[AudioManager] Playing sound: ", sound_name)
	
	# Connect to finished signal to reset mutex
	if not player.finished.is_connected(_on_audio_finished):
		player.finished.connect(_on_audio_finished)
	
	return true

func _on_audio_finished():
	# Called when current audio finishes playing
	print("[AudioManager] Audio finished, releasing mutex")
	is_playing = false
	current_player = null

func stop_current():
	# Force stop current audio (if any)
	if current_player and current_player.playing:
		current_player.stop()
		is_playing = false
		current_player = null
		print("[AudioManager] Forced stop of current audio")

func reset():
	# Reset audio manager state (stop any playing audio)
	stop_current()
	print("[AudioManager] Reset")

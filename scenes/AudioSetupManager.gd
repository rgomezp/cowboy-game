extends Node

# Manages audio setup including iOS initialization, music, and sound effects
# This is separate from AudioManager which handles voice line playback

var music_player: AudioStreamPlayer
var audio_manager: Node  # Reference to AudioManager for voice lines

func initialize(music_player_node: AudioStreamPlayer, audio_manager_instance: Node):
	music_player = music_player_node
	audio_manager = audio_manager_instance

func setup():
	# Initialize iOS audio session if on iOS
	_initialize_ios_audio()
	
	# Initialize Input singleton early on iOS to prevent motion handler crash
	_initialize_ios_input()
	
	# Setup music
	setup_music()
	
	# Setup sound effects
	setup_sound_effects()

func _initialize_ios_audio():
	# Configure audio for iOS - ensure audio session is active
	# This helps with audio playback on iOS devices
	if OS.get_name() == "iOS":
		# Set audio bus volume to ensure audio plays
		var master_bus = AudioServer.get_bus_index("Master")
		if master_bus >= 0:
			AudioServer.set_bus_volume_db(master_bus, 0.0)
		print("[AudioSetupManager] iOS audio session initialized")

func _initialize_ios_input():
	# Workaround for iOS motion handler crash on older devices (iPhone 7, etc.)
	# The crash occurs when Input::set_gravity() is called from motion handler
	# before the Input singleton's mutex is fully initialized.
	# By accessing Input methods early, we force initialization of the Input singleton
	# before any motion events can occur.
	if OS.get_name() == "iOS":
		# Force Input singleton initialization by accessing it
		# This ensures the internal mutex is initialized before motion handlers run
		var _gravity = Input.get_gravity()
		var _accel = Input.get_accelerometer()
		var _gyro = Input.get_gyroscope()
		# Access these even if we don't use them - just to force initialization
		print("[AudioSetupManager] iOS Input singleton initialized (motion handler workaround)")

func setup_music():
	# Load the music file
	var music_stream = load("res://assets/audio/songs/desert.mp3")
	if music_stream:
		music_player.stream = music_stream
		# Set music to loop (for AudioStreamMP3, AudioStreamOggVorbis, etc.)
		if music_stream is AudioStreamMP3:
			music_stream.loop = true
		elif music_stream is AudioStreamOggVorbis:
			music_stream.loop = true
		# Start playing
		music_player.play()
		print("[AudioSetupManager] Music started, playing: ", music_player.playing)

func reset_music():
	# Stop the music and restart from the beginning
	if music_player and music_player.stream:
		if music_player.playing:
			music_player.stop()
		music_player.play()

func setup_sound_effects():
	# Load sound effect audio streams
	# Note: Audio files need to be imported by Godot first (open project in editor)
	# Try both ResourceLoader.load() and load() in case files need to be imported first
	var alright_stream = null
	var mhm_stream = null
	var makes_sense_stream = null
	var hwhat_stream = null

	print("[AudioSetupManager] Loading sound effects...")

	# Try loading with ResourceLoader first (handles imported resources)
	# Using .ogg format as Godot doesn't support .m4a natively
	var alright_path = "res://assets/audio/connor/alright.ogg"
	if ResourceLoader.exists(alright_path):
		alright_stream = ResourceLoader.load(alright_path)
		print("[AudioSetupManager] alright.ogg exists in ResourceLoader")
	else:
		print("[AudioSetupManager] WARNING: alright.ogg not found in ResourceLoader, trying direct load")
		alright_stream = load(alright_path)

	var mhm_path = "res://assets/audio/connor/mhm.ogg"
	if ResourceLoader.exists(mhm_path):
		mhm_stream = ResourceLoader.load(mhm_path)
		print("[AudioSetupManager] mhm.ogg exists in ResourceLoader")
	else:
		print("[AudioSetupManager] WARNING: mhm.ogg not found in ResourceLoader, trying direct load")
		mhm_stream = load(mhm_path)

	var makes_sense_path = "res://assets/audio/connor/makes_sense.ogg"
	if ResourceLoader.exists(makes_sense_path):
		makes_sense_stream = ResourceLoader.load(makes_sense_path)
		print("[AudioSetupManager] makes_sense.ogg exists in ResourceLoader")
	else:
		print("[AudioSetupManager] WARNING: makes_sense.ogg not found in ResourceLoader, trying direct load")
		makes_sense_stream = load(makes_sense_path)

	var hwhat_path = "res://assets/audio/connor/hwhat.ogg"
	if ResourceLoader.exists(hwhat_path):
		hwhat_stream = ResourceLoader.load(hwhat_path)
		print("[AudioSetupManager] hwhat.ogg exists in ResourceLoader")
	else:
		print("[AudioSetupManager] WARNING: hwhat.ogg not found in ResourceLoader, trying direct load")
		hwhat_stream = load(hwhat_path)

	print("[AudioSetupManager] alright_stream loaded: ", alright_stream != null, " (type: ", typeof(alright_stream), ")")
	print("[AudioSetupManager] mhm_stream loaded: ", mhm_stream != null, " (type: ", typeof(mhm_stream), ")")
	print("[AudioSetupManager] makes_sense_stream loaded: ", makes_sense_stream != null, " (type: ", typeof(makes_sense_stream), ")")
	print("[AudioSetupManager] hwhat_stream loaded: ", hwhat_stream != null, " (type: ", typeof(hwhat_stream), ")")

	# Check if any streams failed to load
	if not alright_stream or not mhm_stream or not makes_sense_stream or not hwhat_stream:
		print("[AudioSetupManager] ========================================")
		print("[AudioSetupManager] WARNING: Some audio files failed to load!")
		print("[AudioSetupManager] Make sure the .ogg files exist and have been imported by Godot.")
		print("[AudioSetupManager] SOLUTION: Open the project in Godot editor to trigger audio import.")
		print("[AudioSetupManager] ========================================")

	# Get audio player nodes from parent (main scene)
	var parent = get_parent()
	if not parent:
		print("[AudioSetupManager] ERROR: No parent node found")
		return

	# Configure audio players
	if alright_stream and parent.has_node("AlrightSound"):
		var alright_player = parent.get_node("AlrightSound")
		alright_player.stream = alright_stream
		alright_player.volume_db = 0.0  # Set volume to 0dB (full volume)
		print("[AudioSetupManager] AlrightSound configured, stream type: ", alright_stream.get_class() if alright_stream else "null")
	else:
		print("[AudioSetupManager] ERROR: Failed to configure AlrightSound - stream: ", alright_stream, ", node: ", parent.has_node("AlrightSound"))

	if mhm_stream and parent.has_node("MhmSound"):
		var mhm_player = parent.get_node("MhmSound")
		mhm_player.stream = mhm_stream
		mhm_player.volume_db = 0.0
		print("[AudioSetupManager] MhmSound configured, stream type: ", mhm_stream.get_class() if mhm_stream else "null")
	else:
		print("[AudioSetupManager] ERROR: Failed to configure MhmSound - stream: ", mhm_stream, ", node: ", parent.has_node("MhmSound"))

	if makes_sense_stream and parent.has_node("MakesSenseSound"):
		var makes_sense_player = parent.get_node("MakesSenseSound")
		makes_sense_player.stream = makes_sense_stream
		makes_sense_player.volume_db = 0.0
		print("[AudioSetupManager] MakesSenseSound configured, stream type: ", makes_sense_stream.get_class() if makes_sense_stream else "null")
	else:
		print("[AudioSetupManager] ERROR: Failed to configure MakesSenseSound - stream: ", makes_sense_stream, ", node: ", parent.has_node("MakesSenseSound"))

	if hwhat_stream and parent.has_node("HwhatSound"):
		var hwhat_player = parent.get_node("HwhatSound")
		hwhat_player.stream = hwhat_stream
		hwhat_player.volume_db = 0.0
		print("[AudioSetupManager] HwhatSound configured, stream type: ", hwhat_stream.get_class() if hwhat_stream else "null")
	else:
		print("[AudioSetupManager] ERROR: Failed to configure HwhatSound - stream: ", hwhat_stream, ", node: ", parent.has_node("HwhatSound"))

	# Lower music volume to make sound effects more audible
	if music_player:
		music_player.volume_db = -10.0  # Lower music by 10dB
		print("[AudioSetupManager] Music volume lowered to -10dB")

	# Initialize audio manager for Connor's voice lines ONLY
	# NOTE: This mutex mechanism only applies to Connor's voice lines
	# Background music (MusicPlayer) and other audio are NOT affected by this mutex
	if audio_manager:
		var audio_players_dict = {
			"alright": parent.get_node("AlrightSound") if parent.has_node("AlrightSound") else null,
			"mhm": parent.get_node("MhmSound") if parent.has_node("MhmSound") else null,
			"makes_sense": parent.get_node("MakesSenseSound") if parent.has_node("MakesSenseSound") else null,
			"hwhat": parent.get_node("HwhatSound") if parent.has_node("HwhatSound") else null
		}
		audio_manager.initialize(audio_players_dict)
		print("[AudioSetupManager] AudioManager initialized (Connor voice lines only)")

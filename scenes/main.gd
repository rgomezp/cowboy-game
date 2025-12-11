extends Node

# Preload obstacles
var rock_scene = preload("res://scenes/obstacles/rock.tscn")
var agave_scene = preload("res://scenes/obstacles/agave.tscn")
var tnt_scene = preload("res://scenes/obstacles/tnt.tscn")
var butterfly_scene = preload("res://scenes/obstacles/butterfly.tscn")
var coin_scene = preload("res://scenes/items/Coin.tscn")
var furry_scene = preload("res://scenes/foes/furry/furry.tscn")
var troll_scene = preload("res://scenes/foes/troll/troll.tscn")
var texas_flag_scene = preload("res://scenes/specials/texas_flag.tscn")
var us_flag_scene = preload("res://scenes/specials/us_flag.tscn")
var cheerleader_scene = preload("res://scenes/specials/cheerleader.tscn")
var smoker_scene = preload("res://scenes/specials/smoker.tscn")
var devil_plush_scene = preload("res://scenes/specials/devil_plush.tscn")
var man_baby_scene = preload("res://scenes/specials/man_baby.tscn")
var motorcycle_scene = preload("res://scenes/specials/motorcycle.tscn")
var hollywood_2_scene = preload("res://scenes/specials/hollywood_2.tscn")
var rods_bbq_scene = preload("res://scenes/specials/rods_bbq.tscn")
var go_vegan_scene = preload("res://scenes/specials/go_vegan.tscn")
var pirate_scene = preload("res://scenes/specials/pirate.tscn")
var lizard_scene = preload("res://scenes/specials/lizard.tscn")
var dog_scene = preload("res://scenes/specials/dog.tscn")
var cat_scene = preload("res://scenes/specials/cat.tscn")

# Preload manager scripts
var ScoreManager = preload("res://scenes/ScoreManager.gd")
var ObstacleManager = preload("res://scenes/ObstacleManager.gd")
var ButterflySpawner = preload("res://scenes/ButterflySpawner.gd")
var CoinSpawner = preload("res://scenes/CoinSpawner.gd")
var CoinManager = preload("res://scenes/CoinManager.gd")
var FoeSpawner = preload("res://scenes/FoeSpawner.gd")
var FoeManager = preload("res://scenes/FoeManager.gd")
var CollisionHandler = preload("res://scenes/CollisionHandler.gd")
var SpecialEventManager = preload("res://scenes/SpecialEventManager.gd")
var PowerUpManager = preload("res://scenes/PowerUpManager.gd")
var LivesManager = preload("res://scenes/LivesManager.gd")
var AudioManager = preload("res://scenes/AudioManager.gd")
# Preload PowerUpBase first to ensure class_name is registered
# This ensures the class is available when other powerup scripts extend it
@warning_ignore("unused_private_class_variable")
var _powerup_base = preload("res://scenes/powerups/PowerUpBase.gd")
var GokartPowerUp = preload("res://scenes/powerups/GokartPowerUp.gd")
var ShotgunPowerUp = preload("res://scenes/powerups/ShotgunPowerUp.gd")
var HeartPowerUp = preload("res://scenes/powerups/HeartPowerUp.gd")

# Manager instances
var score_manager: Node
var obstacle_manager: Node
var butterfly_spawner: Node
var coin_spawner: Node
var coin_manager: Node
var foe_spawner: Node
var foe_manager: Node
var collision_handler: Node
var special_event_manager: Node
var powerup_manager: Node
var lives_manager: Node
var audio_manager: Node

const PLAYER_START_POS := Vector2i(19, 166)
const CAMERA_START_POS := Vector2i(540, 960)

var speed : float
const START_SPEED : int = 10
const SPEED_MODIFIER : int = 20_000
const MAX_SPEED : int = 15
var screen_size : Vector2i
var game_running : bool
var ground_height : int
var ground_width : int
var ground_1 : StaticBody2D
var ground_2 : StaticBody2D
var distance : int = 0  # Track actual distance traveled, separate from score
var game_over_in_progress : bool = false  # Track if game over is already triggered
var explosion_in_progress : bool = false  # Track if TNT explosion is playing (stops movement)
var player_immune : bool = false  # Track if player is in immunity period
var touch_start_detected : bool = false  # Track if touch was detected to start game

# Difficulty system
var current_difficulty_level : int = 1
var previous_difficulty_level : int = 1  # Track previous level to detect changes
const LEVEL_1_THRESHOLD : int = 0       # Start at level 1
const LEVEL_2_THRESHOLD : int = 37500  # Switch to level 2 at 37.5k distance
const LEVEL_3_THRESHOLD : int = 75000  # Switch to level 3 at 75k distance
const LEVEL_4_THRESHOLD : int = 112500 # Switch to level 4 at 112.5k distance

# Speed transition system
var target_speed : float = 10.0  # Target speed for current difficulty level
var transition_start_speed : float = 10.0  # Speed when transition started
var speed_transition_timer : float = 0.0  # Timer for speed transition (0-5 seconds)
const SPEED_TRANSITION_DURATION : float = 5.0  # 5 seconds to reach new speed

# Score delta display variables
var score_delta_timer: float = 0.0
var score_delta_color_white: bool = true  # Track color alternation

# Special event button result tracking
var special_button_result: String = ""  # "correct", "wrong", or "" (not pressed)
var special_button_reaction_time: float = -1.0  # Time taken for correct answers, -1.0 for incorrect/missed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Use viewport visible rect size instead of window size
	# This accounts for stretch mode "viewport" with aspect "expand"
	# which can make the visible area larger than the base viewport on wider devices
	screen_size = Vector2i(get_viewport().get_visible_rect().size)

	# Get both ground bodies (not just sprites)
	ground_1 = $Ground.get_node("Ground1")
	ground_2 = $Ground.get_node("Ground2")

	# Get dimensions from texture
	ground_width = ground_1.get_node("Sprite2D").texture.get_width()
	ground_height = ground_1.get_node("Sprite2D").texture.get_height()

	$GameOver.get_node("Button").pressed.connect(new_game)

	# Initialize managers
	setup_managers()

	# Hide score delta label initially
	$Hud.get_node("ScoreValueDelta").hide()

	# Initialize iOS audio session if on iOS
	_initialize_ios_audio()

	# Initialize Input singleton early on iOS to prevent motion handler crash
	# This ensures Input is fully initialized before motion events can occur
	_initialize_ios_input()

	# Setup music
	setup_music()

	# Setup sound effects
	setup_sound_effects()

	new_game()

func _input(event: InputEvent) -> void:
	# Detect touch input to start game (iOS/mobile support)
	if not game_running and event is InputEventScreenTouch:
		var touch_event = event as InputEventScreenTouch
		if touch_event.pressed:
			# Touch detected - mark for game start
			touch_start_detected = true

func setup_managers():
	# Create and add manager nodes
	score_manager = ScoreManager.new()
	add_child(score_manager)
	score_manager.score_updated.connect(_on_score_updated)
	score_manager.high_score_updated.connect(_on_high_score_updated)
	score_manager.score_delta.connect(_on_score_delta)
	# Ensure high score is loaded and HUD is updated after signal connections are made
	# This handles the case where _ready() was called before connections
	score_manager.load_high_score()

	obstacle_manager = ObstacleManager.new()
	add_child(obstacle_manager)
	obstacle_manager.obstacle_added.connect(_on_obstacle_added)

	var obstacle_types: Array[PackedScene] = [rock_scene, agave_scene, tnt_scene]
	var ground_sprite = ground_1.get_node("Sprite2D")
	obstacle_manager.initialize(obstacle_types, screen_size, ground_sprite)

	butterfly_spawner = ButterflySpawner.new()
	add_child(butterfly_spawner)
	butterfly_spawner.butterfly_spawned.connect(_on_butterfly_spawned)
	butterfly_spawner.initialize(butterfly_scene, screen_size)

	coin_spawner = CoinSpawner.new()
	add_child(coin_spawner)
	coin_spawner.coin_spawned.connect(_on_coin_spawned)
	# Ground top is at Y=1280
	coin_spawner.initialize(coin_scene, screen_size, 1280.0)

	coin_manager = CoinManager.new()
	add_child(coin_manager)
	coin_manager.coin_added.connect(_on_coin_added)
	coin_manager.initialize(screen_size)

	foe_manager = FoeManager.new()
	add_child(foe_manager)
	foe_manager.foe_added.connect(_on_foe_added)
	foe_manager.initialize(screen_size, obstacle_manager)

	foe_spawner = FoeSpawner.new()
	add_child(foe_spawner)
	foe_spawner.foe_spawned.connect(_on_foe_spawned)
	var foe_types: Array[PackedScene] = [furry_scene, troll_scene]
	foe_spawner.initialize(foe_types, screen_size, ground_sprite, obstacle_manager, foe_manager)

	# Set cross-references for coordination
	obstacle_manager.foe_manager = foe_manager

	collision_handler = CollisionHandler.new()
	add_child(collision_handler)
	collision_handler.player_hit_obstacle.connect(_on_player_hit_obstacle)
	collision_handler.player_bounced_on_butterfly.connect(_on_player_bounced_on_butterfly)
	collision_handler.player_jumped_on_foe.connect(_on_player_jumped_on_foe)
	collision_handler.initialize($Player, self)

	# Initialize lives manager
	lives_manager = LivesManager.new()
	add_child(lives_manager)
	lives_manager.life_lost.connect(_on_life_lost)

	# Initialize powerup manager first (needed by special event manager)
	powerup_manager = PowerUpManager.new()
	add_child(powerup_manager)
	var gokart_powerup = GokartPowerUp.new()
	var shotgun_powerup = ShotgunPowerUp.new()
	var heart_powerup = HeartPowerUp.new()
	var powerups: Array[PowerUpBase] = [gokart_powerup, shotgun_powerup, heart_powerup]
	powerup_manager.initialize(powerups, $PowerUpUI, lives_manager)
	powerup_manager.powerup_activated.connect(_on_powerup_activated)
	powerup_manager.powerup_deactivated.connect(_on_powerup_deactivated)
	$PowerUpUI.powerup_button_pressed.connect(powerup_manager.on_powerup_button_pressed)

	# Initialize HUD with lives manager
	$Hud.initialize(lives_manager)

	# Initialize powerup HUD
	$PowerUpHud.initialize(powerup_manager)

	special_event_manager = SpecialEventManager.new()
	add_child(special_event_manager)
	special_event_manager.special_event_started.connect(_on_special_event_started)
	special_event_manager.special_event_ended.connect(_on_special_event_ended)
	var special_types: Array[PackedScene] = [texas_flag_scene, us_flag_scene, cheerleader_scene, smoker_scene, devil_plush_scene, man_baby_scene, motorcycle_scene, hollywood_2_scene, rods_bbq_scene, go_vegan_scene, pirate_scene, lizard_scene, dog_scene, cat_scene]
	special_event_manager.initialize(special_types, screen_size, ground_sprite, $SpecialGround, $SpecialEventButtons, powerup_manager)

	# Connect button signals
	$SpecialEventButtons.button_pressed.connect(_on_special_button_pressed)
	$SpecialEventButtons.buttons_hidden.connect(_on_special_buttons_hidden)

func _initialize_ios_audio():
	# Configure audio for iOS - ensure audio session is active
	# This helps with audio playback on iOS devices
	if OS.get_name() == "iOS":
		# Set audio bus volume to ensure audio plays
		var master_bus = AudioServer.get_bus_index("Master")
		if master_bus >= 0:
			AudioServer.set_bus_volume_db(master_bus, 0.0)
		print("[Main] iOS audio session initialized")

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
		print("[Main] iOS Input singleton initialized (motion handler workaround)")

func setup_music():
	# Load the music file
	var music_stream = load("res://assets/audio/songs/desert.mp3")
	if music_stream:
		$MusicPlayer.stream = music_stream
		# Set music to loop (for AudioStreamMP3, AudioStreamOggVorbis, etc.)
		if music_stream is AudioStreamMP3:
			music_stream.loop = true
		elif music_stream is AudioStreamOggVorbis:
			music_stream.loop = true
		# Start playing
		$MusicPlayer.play()
		print("[Main] Music started, playing: ", $MusicPlayer.playing)

func reset_music():
	# Stop the music and restart from the beginning
	if $MusicPlayer and $MusicPlayer.stream:
		if $MusicPlayer.playing:
			$MusicPlayer.stop()
		$MusicPlayer.play()

func setup_sound_effects():
	# Load sound effect audio streams
	# Note: Audio files need to be imported by Godot first (open project in editor)
	# Try both ResourceLoader.load() and load() in case files need to be imported first
	var alright_stream = null
	var mhm_stream = null
	var makes_sense_stream = null
	var hwhat_stream = null

	print("[Main] Loading sound effects...")

	# Try loading with ResourceLoader first (handles imported resources)
	# Using .ogg format as Godot doesn't support .m4a natively
	var alright_path = "res://assets/audio/connor/alright.ogg"
	if ResourceLoader.exists(alright_path):
		alright_stream = ResourceLoader.load(alright_path)
		print("[Main] alright.ogg exists in ResourceLoader")
	else:
		print("[Main] WARNING: alright.ogg not found in ResourceLoader, trying direct load")
		alright_stream = load(alright_path)

	var mhm_path = "res://assets/audio/connor/mhm.ogg"
	if ResourceLoader.exists(mhm_path):
		mhm_stream = ResourceLoader.load(mhm_path)
		print("[Main] mhm.ogg exists in ResourceLoader")
	else:
		print("[Main] WARNING: mhm.ogg not found in ResourceLoader, trying direct load")
		mhm_stream = load(mhm_path)

	var makes_sense_path = "res://assets/audio/connor/makes_sense.ogg"
	if ResourceLoader.exists(makes_sense_path):
		makes_sense_stream = ResourceLoader.load(makes_sense_path)
		print("[Main] makes_sense.ogg exists in ResourceLoader")
	else:
		print("[Main] WARNING: makes_sense.ogg not found in ResourceLoader, trying direct load")
		makes_sense_stream = load(makes_sense_path)

	var hwhat_path = "res://assets/audio/connor/hwhat.ogg"
	if ResourceLoader.exists(hwhat_path):
		hwhat_stream = ResourceLoader.load(hwhat_path)
		print("[Main] hwhat.ogg exists in ResourceLoader")
	else:
		print("[Main] WARNING: hwhat.ogg not found in ResourceLoader, trying direct load")
		hwhat_stream = load(hwhat_path)

	print("[Main] alright_stream loaded: ", alright_stream != null, " (type: ", typeof(alright_stream), ")")
	print("[Main] mhm_stream loaded: ", mhm_stream != null, " (type: ", typeof(mhm_stream), ")")
	print("[Main] makes_sense_stream loaded: ", makes_sense_stream != null, " (type: ", typeof(makes_sense_stream), ")")
	print("[Main] hwhat_stream loaded: ", hwhat_stream != null, " (type: ", typeof(hwhat_stream), ")")

	# Check if any streams failed to load
	if not alright_stream or not mhm_stream or not makes_sense_stream or not hwhat_stream:
		print("[Main] ========================================")
		print("[Main] WARNING: Some audio files failed to load!")
		print("[Main] Make sure the .ogg files exist and have been imported by Godot.")
		print("[Main] SOLUTION: Open the project in Godot editor to trigger audio import.")
		print("[Main] ========================================")

	if alright_stream and $AlrightSound:
		$AlrightSound.stream = alright_stream
		$AlrightSound.volume_db = 0.0  # Set volume to 0dB (full volume)
		print("[Main] AlrightSound configured, stream type: ", alright_stream.get_class() if alright_stream else "null")
	else:
		print("[Main] ERROR: Failed to configure AlrightSound - stream: ", alright_stream, ", node: ", $AlrightSound != null)

	if mhm_stream and $MhmSound:
		$MhmSound.stream = mhm_stream
		$MhmSound.volume_db = 0.0
		print("[Main] MhmSound configured, stream type: ", mhm_stream.get_class() if mhm_stream else "null")
	else:
		print("[Main] ERROR: Failed to configure MhmSound - stream: ", mhm_stream, ", node: ", $MhmSound != null)

	if makes_sense_stream and $MakesSenseSound:
		$MakesSenseSound.stream = makes_sense_stream
		$MakesSenseSound.volume_db = 0.0
		print("[Main] MakesSenseSound configured, stream type: ", makes_sense_stream.get_class() if makes_sense_stream else "null")
	else:
		print("[Main] ERROR: Failed to configure MakesSenseSound - stream: ", makes_sense_stream, ", node: ", $MakesSenseSound != null)

	if hwhat_stream and $HwhatSound:
		$HwhatSound.stream = hwhat_stream
		$HwhatSound.volume_db = 0.0
		print("[Main] HwhatSound configured, stream type: ", hwhat_stream.get_class() if hwhat_stream else "null")
	else:
		print("[Main] ERROR: Failed to configure HwhatSound - stream: ", hwhat_stream, ", node: ", $HwhatSound != null)

	# Lower music volume to make sound effects more audible
	if $MusicPlayer:
		$MusicPlayer.volume_db = -10.0  # Lower music by 10dB
		print("[Main] Music volume lowered to -10dB")

	# Initialize audio manager for Connor's voice lines ONLY
	# NOTE: This mutex mechanism only applies to Connor's voice lines
	# Background music (MusicPlayer) and other audio are NOT affected by this mutex
	audio_manager = AudioManager.new()
	add_child(audio_manager)
	var audio_players_dict = {
		"alright": $AlrightSound,
		"mhm": $MhmSound,
		"makes_sense": $MakesSenseSound,
		"hwhat": $HwhatSound
	}
	audio_manager.initialize(audio_players_dict)
	print("[Main] AudioManager initialized (Connor voice lines only)")

func new_game():
	# Reset game over and explosion flags
	game_over_in_progress = false
	explosion_in_progress = false

	# Reset managers
	score_manager.reset()
	obstacle_manager.reset()
	butterfly_spawner.reset()
	coin_spawner.reset()
	coin_manager.reset()
	foe_spawner.reset()
	foe_manager.reset()
	special_event_manager.reset()
	if powerup_manager:
		powerup_manager.reset()
	if lives_manager:
		lives_manager.reset()
	if audio_manager:
		audio_manager.reset()
	if $Hud:
		$Hud.reset()

	# Ensure all spawners are enabled (in case game was restarted during a special event)
	set_all_spawning_enabled(true)

	game_running = false
	get_tree().paused = false
	distance = 0  # Reset distance
	current_difficulty_level = 1  # Reset to level 1
	previous_difficulty_level = 1  # Reset previous level
	target_speed = 10.0  # Reset to level 1 speed
	transition_start_speed = 10.0  # Reset transition start speed
	speed_transition_timer = SPEED_TRANSITION_DURATION  # Set to complete so speed is immediately at target
	speed = 10.0  # Set initial speed

	# Reset the nodes
	$Player.position = PLAYER_START_POS
	$Player.velocity = Vector2i(0, 0)
	$Camera2D.position = CAMERA_START_POS
	# Position ground bodies (collision moves with them)
	$Ground.position = Vector2i(0, 0)
	ground_1.position.x = 0
	ground_2.position.x = ground_width

	# Reset HUD and game over scene
	$Hud.get_node("StartLabel").show()
	$GameOver.hide()

	# Hide score delta label
	var delta_label = $Hud.get_node("ScoreValueDelta")
	delta_label.hide()
	score_delta_timer = 0.0

	# Reset music to play from the beginning
	reset_music()

	# Play "alright" when game starts/restarts
	if audio_manager:
		audio_manager.play_sound("alright")

func update_difficulty_level():
	# Determine difficulty level based on distance
	var new_level = 1
	if distance >= LEVEL_4_THRESHOLD:
		new_level = 4
	elif distance >= LEVEL_3_THRESHOLD:
		new_level = 3
	elif distance >= LEVEL_2_THRESHOLD:
		new_level = 2
	else:
		new_level = 1

	# Calculate target speed for the current/new level
	var new_target_speed = 10.0
	if new_level == 1:
		new_target_speed = 10.0
	elif new_level == 2:
		new_target_speed = 12.0
	elif new_level == 3:
		new_target_speed = 14.0
	else:  # Level 4
		new_target_speed = 16.0

	# Check if level changed
	if new_level != current_difficulty_level:
		# Level changed - start speed transition
		previous_difficulty_level = current_difficulty_level
		current_difficulty_level = new_level
		transition_start_speed = speed  # Start transition from current speed
		speed_transition_timer = 0.0  # Reset timer
		target_speed = new_target_speed

		print("[Main] Difficulty level changed to ", current_difficulty_level, ", transitioning speed from ", transition_start_speed, " to ", target_speed)
	else:
		# Level didn't change, but ensure target_speed is set (for initial case)
		target_speed = new_target_speed

func update_hud_difficulty_level():
	# Update HUD with current difficulty level for debugging
	if not $Hud.has_node("DifficultyLevel"):
		# Create difficulty level label if it doesn't exist
		var level_label = Label.new()
		level_label.name = "DifficultyLevel"
		level_label.text = "Level: " + str(current_difficulty_level)
		level_label.position = Vector2(54, 10)
		var font = load("res://assets/fonts/retro.ttf")
		if font:
			level_label.add_theme_font_override("font", font)
		level_label.add_theme_font_size_override("font_size", 40)
		$Hud.add_child(level_label)
	else:
		$Hud.get_node("DifficultyLevel").text = "Level: " + str(current_difficulty_level)

# Game logic happens here
func _process(delta: float) -> void:
	if game_running:
		# Update powerup manager (only if initialized)
		if powerup_manager:
			powerup_manager.update(delta, self)

		# Update difficulty level based on distance
		update_difficulty_level()

		# Calculate speed with gradual transition
		# If we're in a transition, interpolate between start and target speed
		if speed_transition_timer < SPEED_TRANSITION_DURATION:
			speed_transition_timer += delta
			var progress = min(speed_transition_timer / SPEED_TRANSITION_DURATION, 1.0)  # Clamp to 0-1
			# Linear interpolation from start speed to target speed
			speed = lerpf(transition_start_speed, target_speed, progress)
		else:
			# Transition complete, use target speed directly
			speed = target_speed

		# Apply powerup speed modifier (e.g., from gokart)
		speed *= powerup_manager.get_speed_modifier()

		# Update obstacle manager with current difficulty level
		obstacle_manager.set_difficulty_level(current_difficulty_level)

		# Generate obstacles (returns array - single at level 1, pair at level 2+)
		# Use actual camera position for accurate spawning
		var new_obstacles = obstacle_manager.generate_obstacle(distance, $Camera2D.position.x)
		for new_obstacle in new_obstacles:
			if new_obstacle:
				obstacle_manager.add_obstacle(new_obstacle)

		# Update butterfly spawner with current difficulty level
		butterfly_spawner.set_difficulty_level(current_difficulty_level)

		# Check butterfly spawning (always single, frequency adjusts with difficulty)
		# Use actual camera position for accurate spawning
		var butterfly = butterfly_spawner.update(delta, distance, $Camera2D.position.x)
		if butterfly:
			obstacle_manager.add_obstacle(butterfly)

		# Check coin spawning (use actual camera position for accurate spawning)
		var coin = coin_spawner.update(delta, distance, $Camera2D.position.x)
		if coin:
			coin_manager.add_coin(coin)

		# Update foe spawner with current difficulty level
		foe_spawner.set_difficulty_level(current_difficulty_level)

		# Check foe spawning (always single, frequency adjusts with difficulty)
		# Use actual camera position for accurate spawning
		var foe = foe_spawner.update(distance, $Camera2D.position.x)
		if foe:
			foe_manager.add_foe(foe)

		# Move player position & camera (only if not in explosion)
		if not explosion_in_progress:
			$Player.position.x += speed
			$Camera2D.position.x += speed

			# Update distance based on actual movement
			distance += int(speed)

			# Update score (separate from distance)
			# Don't show delta for continuous movement score updates
			score_manager.add_score(int(speed), false)

		# Update ground bodies - swap whichever one is off-screen to the front
		var camera_left_edge = $Camera2D.position.x - float(screen_size.x) / 2.0

		# If ground 1 is completely off-screen to the left, move it ahead of ground 2
		if ground_1.position.x + ground_width < camera_left_edge:
			ground_1.position.x = ground_2.position.x + ground_width

		# If ground 2 is completely off-screen to the left, move it ahead of ground 1
		if ground_2.position.x + ground_width < camera_left_edge:
			ground_2.position.x = ground_1.position.x + ground_width

		# Cleanup off-screen obstacles
		obstacle_manager.cleanup_off_screen_obstacles($Camera2D.position.x)
		# Cleanup off-screen coins
		coin_manager.cleanup_off_screen_coins($Camera2D.position.x)
		# Cleanup off-screen foes
		foe_manager.cleanup_off_screen_foes($Camera2D.position.x)

		# Update special event manager (only if no powerup is active)
		# Special events are paused during powerups, but will resume when powerup ends
		if not powerup_manager.is_powerup_active():
			special_event_manager.update(delta, speed, $Camera2D.position.x)

		# Update score delta display timer
		if score_delta_timer > 0.0:
			score_delta_timer -= delta
			if score_delta_timer <= 0.0:
				# Hide label after 1 second
				$Hud.get_node("ScoreValueDelta").hide()
				score_delta_timer = 0.0

		# Update HUD with current difficulty level
		update_hud_difficulty_level()
	else:
		# Check for keyboard or touch input to start game
		var start_input = Input.is_action_pressed("ui_accept") or touch_start_detected

		if start_input:
			game_running = true
			$Hud.get_node("StartLabel").hide()
			touch_start_detected = false  # Reset touch flag

# Signal handlers
func _on_score_updated(_score: int):
	$Hud.get_node("ScoreValue").text = str(score_manager.get_display_score())

func _on_high_score_updated(_high_score: int):
	$Hud.get_node("HighScoreValue").text = str(score_manager.get_display_high_score())

func _on_score_delta(delta: int):
	# Convert raw score to display score (divide by SCORE_MODIFIER which is 100)
	var display_delta = int(float(delta) / 100.0)

	# Only show meaningful score changes (filter out 0)
	if display_delta == 0:
		return

	# Display the score delta for 1 second
	var delta_label = $Hud.get_node("ScoreValueDelta")

	# Format as +100, +10, -500, etc. (negative values already have minus sign)
	if display_delta > 0:
		delta_label.text = "+" + str(display_delta)
	else:
		delta_label.text = str(display_delta)  # Negative values already have minus sign

	# If timer is already running (multiple events within 1 second), alternate color
	if score_delta_timer > 0.0:
		score_delta_color_white = not score_delta_color_white
	else:
		# First event, start with white
		score_delta_color_white = true

	# Reset timer to 1 second (extends display time if multiple events occur)
	score_delta_timer = 1.0

	# Set color (white or black)
	if score_delta_color_white:
		delta_label.modulate = Color.WHITE
	else:
		delta_label.modulate = Color.BLACK

	# Show the label
	delta_label.show()

func _on_obstacle_added(obstacle: Node):
	collision_handler.connect_obstacle_signals(obstacle)

func _on_butterfly_spawned(_butterfly: Node):
	# Butterfly is already positioned by ButterflySpawner
	pass

func _on_coin_spawned(_coin: Node):
	# Coin is already positioned by CoinSpawner
	pass

func _on_coin_added(_coin: Node):
	# Coins handle their own collision detection, no need to connect signals
	pass

func _on_foe_spawned(_foe: Node):
	# Foe is already positioned by FoeSpawner
	pass

func _on_foe_added(foe: Node):
	collision_handler.connect_obstacle_signals(foe)

func _on_player_hit_obstacle(obstacle: Node):
	# Prevent multiple triggers during immunity or game over
	if game_over_in_progress or player_immune:
		return

	# Check if obstacle is TNT - handle TNT explosion separately
	if _is_tnt(obstacle):
		# Remove from obstacle manager immediately
		if obstacle_manager.obstacles.has(obstacle):
			obstacle_manager.obstacles.erase(obstacle)

		# Trigger explosion animation
		if obstacle.has_method("trigger_explosion"):
			# Check if player has lives - if so, use a life after explosion (no bounce)
			if lives_manager and lives_manager.has_lives():
				# Connect to explosion finished signal to use a life
				if obstacle.has_signal("explosion_finished"):
					# Disconnect first to avoid duplicate connections
					if obstacle.explosion_finished.is_connected(_on_tnt_explosion_finished_with_life):
						obstacle.explosion_finished.disconnect(_on_tnt_explosion_finished_with_life)
					obstacle.explosion_finished.connect(_on_tnt_explosion_finished_with_life)
				# Trigger explosion with from_collision=true but apply_bounce=false (no bounce, just animation)
				obstacle.trigger_explosion(true, false)
			else:
				# No lives - connect to game over handler (apply bounce for game over effect)
				if obstacle.has_signal("explosion_finished"):
					# Disconnect first to avoid duplicate connections
					if obstacle.explosion_finished.is_connected(_on_tnt_explosion_finished_game_over):
						obstacle.explosion_finished.disconnect(_on_tnt_explosion_finished_game_over)
					obstacle.explosion_finished.connect(_on_tnt_explosion_finished_game_over)
				# Trigger explosion with bounce (game over scenario)
				obstacle.trigger_explosion(true, true)
		else:
			# Fallback if script not attached
			# Check if player has lives
			if lives_manager and lives_manager.has_lives():
				lives_manager.remove_life()
			else:
				game_over()
		return

	# Not TNT - check if player has lives for other obstacles
	if lives_manager and lives_manager.has_lives():
		# Use a life and trigger immunity/blinking
		lives_manager.remove_life()
		# Note: _on_life_lost will handle the blinking and immunity
		return

	# No lives remaining - proceed with game over
	game_over()

func _on_player_bounced_on_butterfly(obstacle: Node):
	# Player jumped on the butterfly from the top - bounce and destroy it
	var bounce_velocity = -1200  # Slightly less than jump velocity for a nice bounce
	$Player.velocity.y = bounce_velocity
	# Play destroy animation before removing
	if obstacle.has_node("AnimatedSprite2D"):
		var animated_sprite = obstacle.get_node("AnimatedSprite2D")
		if animated_sprite.has_method("destroy"):
			animated_sprite.destroy()
	# Remove from manager's list (but don't queue_free yet - let animation finish)
	if obstacle_manager.obstacles.has(obstacle):
		obstacle_manager.obstacles.erase(obstacle)
	# Award 100 points for bouncing on a butterfly (100 * 100 = 10000 raw score)
	score_manager.add_score(100 * 100, true)  # Show delta for bonus event

	# Play "mhm" sound 50% of the time when butterfly is destroyed
	if audio_manager:
		audio_manager.play_sound("mhm", 0.5)

func _on_player_jumped_on_foe(foe: Node):
	# Player jumped on the foe from the top - bounce and destroy it
	# Note: CollisionHandler already disabled main collision, but we ensure it here too as backup
	if foe and is_instance_valid(foe):
		var bounce_velocity = -1200  # Slightly less than jump velocity for a nice bounce
		# Ensure player is slightly above the foe to prevent being stuck
		var foe_top = foe.position.y - 50  # Approximate top of foe
		if $Player.position.y >= foe_top:
			$Player.position.y = foe_top - 5
		$Player.velocity.y = bounce_velocity
		if foe.has_method("destroy"):
			foe.destroy()
		# Remove from manager's list (but don't queue_free yet - let animation finish)
		if foe_manager.foes.has(foe):
			foe_manager.foes.erase(foe)
		# Award 200 points for destroying a foe (200 * 100 = 20000 raw score)
		score_manager.add_score(200 * 100, true)  # Show delta for bonus event

		# Play "mhm" sound 20% of the time when foe is destroyed
		if audio_manager:
			audio_manager.play_sound("mhm", 0.2)

func game_over():
	# Prevent multiple game over calls
	if game_over_in_progress:
		return
	game_over_in_progress = true

	score_manager.check_high_score()
	get_tree().paused = true
	game_running = false
	$GameOver.show()

func _is_tnt(obstacle: Node) -> bool:
	# Check if obstacle is TNT by name or script path
	if obstacle.name == "TNT":
		return true
	if obstacle.get_script() != null and obstacle.get_script().resource_path != null:
		if "tnt" in obstacle.get_script().resource_path.to_lower():
			return true
	# Check scene file path if available
	if obstacle.has_method("get_scene_file_path"):
		var scene_path = obstacle.get_scene_file_path()
		if scene_path and "tnt" in scene_path.to_lower():
			return true
	return false

func set_explosion_in_progress(value: bool) -> void:
	# Setter method for TNT script to control explosion state
	explosion_in_progress = value

func _on_tnt_explosion_finished_with_life() -> void:
	# TNT explosion finished - player has lives, so use a life
	explosion_in_progress = false
	if lives_manager and lives_manager.has_lives():
		lives_manager.remove_life()
		# Note: _on_life_lost will handle the blinking and immunity

func _on_tnt_explosion_finished_game_over() -> void:
	# Trigger game over after explosion animation finishes
	# Reset explosion flag (though game_over will pause anyway)
	explosion_in_progress = false
	# No lives remaining - proceed with game over
	game_over()

func _on_life_lost(lives_remaining: int):
	# Player lost a life - trigger blinking and immunity
	if lives_remaining >= 0:
		start_player_immunity()
	else:
		# No lives remaining - should have been handled in collision, but just in case
		game_over()

func start_player_immunity():
	# Start player blinking and immunity period
	player_immune = true
	$Player.start_blinking(3)  # Blink 3 times
	# Immunity duration: 3 blinks * 2 toggles * 0.2 seconds = 1.2 seconds total
	# We'll end immunity after blinking completes (handled in player.stop_blinking)

func end_player_immunity():
	# Called when player finishes blinking
	player_immune = false
	print("[Main] Player immunity ended")

# Spawning control methods for special events
func set_obstacle_spawning_enabled(enabled: bool):
	var was_disabled = not obstacle_manager.is_spawning_enabled()
	print("[Main] set_obstacle_spawning_enabled: enabled=", enabled, ", was_disabled=", was_disabled, ", distance=", distance)
	obstacle_manager.set_spawning_enabled(enabled)
	# Sync distance when re-enabling to fix timing after powerups
	if enabled and was_disabled:
		print("[Main] Syncing obstacle distance...")
		obstacle_manager.sync_distance(distance)

func set_foe_spawning_enabled(enabled: bool):
	var was_disabled = not foe_spawner.is_spawning_enabled()
	print("[Main] set_foe_spawning_enabled: enabled=", enabled, ", was_disabled=", was_disabled, ", distance=", distance)
	foe_spawner.set_spawning_enabled(enabled)
	# Sync distance when re-enabling to fix timing after powerups
	if enabled and was_disabled:
		print("[Main] Syncing foe distance...")
		foe_spawner.sync_distance(distance)

func set_coin_spawning_enabled(enabled: bool):
	var was_disabled = not coin_spawner.is_spawning_enabled()
	print("[Main] set_coin_spawning_enabled: enabled=", enabled, ", was_disabled=", was_disabled, ", distance=", distance)
	coin_spawner.set_spawning_enabled(enabled)
	# Reset timer when re-enabling to fix timing after powerups
	if enabled and was_disabled:
		print("[Main] Resetting coin timer...")
		coin_spawner.reset_timer()

func set_butterfly_spawning_enabled(enabled: bool):
	var was_disabled = not butterfly_spawner.is_spawning_enabled()
	print("[Main] set_butterfly_spawning_enabled: enabled=", enabled, ", was_disabled=", was_disabled, ", distance=", distance)
	butterfly_spawner.set_spawning_enabled(enabled)
	# Reset timer when re-enabling to fix timing after powerups
	if enabled and was_disabled:
		print("[Main] Resetting butterfly timer...")
		butterfly_spawner.reset_timer()

# Convenience method to enable/disable all spawning
func set_all_spawning_enabled(enabled: bool):
	set_obstacle_spawning_enabled(enabled)
	set_foe_spawning_enabled(enabled)
	set_coin_spawning_enabled(enabled)
	set_butterfly_spawning_enabled(enabled)

func _on_special_event_started():
	# Disable obstacles, foes, and butterflies (keep coins enabled)
	set_obstacle_spawning_enabled(false)
	set_foe_spawning_enabled(false)
	set_butterfly_spawning_enabled(false)

	# Hide powerup UI if it's active to prevent conflicts
	if powerup_manager and powerup_manager.has_method("is_powerup_ui_active"):
		if powerup_manager.is_powerup_ui_active():
			# Cancel powerup selection/display if active
			if powerup_manager.has_method("reset"):
				powerup_manager.reset()

	# Show "Special Event!" message
	$SpecialEventHud.show_special_event()

	# Reset button result tracking
	special_button_result = ""
	special_button_reaction_time = -1.0

func _on_special_event_ended():
	# Re-enable all spawners immediately, regardless of powerup status
	# This ensures spawning resumes even if a powerup is active
	set_obstacle_spawning_enabled(true)
	set_foe_spawning_enabled(true)
	set_butterfly_spawning_enabled(true)
	print("[Main] Special event ended - spawning re-enabled")

func _on_special_button_pressed(is_good: bool):
	# Process button presses at any time after buttons are shown
	# No longer restrict to only after sprite enters view
	var buttons_ui = $SpecialEventButtons

	# Get the timer value (time since sprite entered view, or 0.0 if not yet entered)
	var reaction_time = buttons_ui.get_timer_value()
	print("[Main] _on_special_button_pressed: reaction_time=", reaction_time, ", sprite_entered_view=", buttons_ui.has_sprite_entered_view())

	# Player pressed a button - check if they got it right
	var special_path = special_event_manager.get_current_special_scene_path()
	if special_path.is_empty():
		# No sprite path available yet - don't score
		return

	var is_actually_good = SpecialSpriteData.is_good_sprite(special_path)

	if is_good == is_actually_good:
		# Correct answer - award 500 points (500 * 100 = 50000 raw score)
		score_manager.add_score(500 * 100, true)  # Show delta for bonus event
		special_button_result = "correct"
		special_button_reaction_time = reaction_time  # Store reaction time for correct answers

		# Play appropriate sound based on which button was pressed and was correct
		if audio_manager:
			if is_good and is_actually_good:
				# "Makes Sense" button was pressed and was correct
				audio_manager.play_sound("makes_sense")
			elif not is_good and not is_actually_good:
				# "Hwwat?" button was pressed and was correct
				audio_manager.play_sound("hwhat")
	else:
		# Wrong answer - deduct 500 points (500 * 100 = 50000 raw score)
		score_manager.add_score(-500 * 100, true)  # Show delta for penalty
		special_button_result = "wrong"
		special_button_reaction_time = -1.0  # Don't show time for wrong answers

	# Buttons are already hidden by the button press handler (which sets force_hide = true)
	# Mark that a button was pressed - event will end when special leaves screen
	special_event_manager.mark_button_pressed()

func _on_special_buttons_hidden(was_pressed: bool, _too_early: bool):
	# Show outcome message when buttons are hidden
	# Note: _too_early is always false now since we removed the "too early" restriction

	if was_pressed:
		# Button was pressed - show result based on whether it was correct or wrong
		if special_button_result == "correct":
			$SpecialEventHud.show_outcome("nice", special_button_reaction_time)
			# Hide special event buttons before starting powerup selection
			$SpecialEventButtons.visible = false
			# Trigger powerup selection on correct answer
			powerup_manager.start_powerup_selection()
		elif special_button_result == "wrong":
			$SpecialEventHud.show_outcome("oops")
		else:
			# Button was pressed but result wasn't set (shouldn't happen, but handle gracefully)
			$SpecialEventHud.show_outcome("miss")
	else:
		# No button was pressed - show "Miss"
		$SpecialEventHud.show_outcome("miss")

func _on_powerup_button_pressed(_powerup_name: String):
	# This is handled by PowerUpManager, but we can add additional logic here if needed
	pass

func _on_powerup_activated(_powerup_name: String):
	# Play "alright" sound when powerup is activated
	if audio_manager:
		audio_manager.play_sound("alright")

	# Powerup was activated - mark that event should end when special leaves screen
	# Don't end immediately - let special object leave screen naturally
	# This ensures spawning resumes so the powerup has targets to use
	if special_event_manager.get_event_active():
		print("[Main] Powerup activated during special event - will end when special leaves screen")
		# Hide special event buttons since powerup is now active
		$SpecialEventButtons.visible = false
		# Mark button as pressed so event ends when special leaves, but don't end immediately
		special_event_manager.mark_button_pressed()
		# Re-enable spawning immediately so powerup has targets
		set_obstacle_spawning_enabled(true)
		set_foe_spawning_enabled(true)
		set_butterfly_spawning_enabled(true)

func _on_powerup_deactivated(_powerup_name: String):
	# Powerup was deactivated - ensure spawning is enabled
	# This handles the case where a special event ended while powerup was active
	# (special events don't update during powerups, so they might have ended via timeout)
	set_obstacle_spawning_enabled(true)
	set_foe_spawning_enabled(true)
	set_butterfly_spawning_enabled(true)
	print("[Main] Powerup deactivated - ensuring spawning is enabled")

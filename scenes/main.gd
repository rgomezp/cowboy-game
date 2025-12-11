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
var AudioSetupManager = preload("res://scenes/AudioSetupManager.gd")
var DifficultyManager = preload("res://scenes/DifficultyManager.gd")
var SpawningController = preload("res://scenes/SpawningController.gd")
var TNTExplosionHandler = preload("res://scenes/TNTExplosionHandler.gd")
var TimeOfDayController = preload("res://scenes/TimeOfDayController.gd")
# Preload PowerUpBase first to ensure class_name is registered
# This ensures the class is available when other powerup scripts extend it
@warning_ignore("unused_private_class_variable")
var _powerup_base = preload("res://scenes/powerups/PowerUpBase.gd")
var GokartPowerUp = preload("res://scenes/powerups/GokartPowerUp.gd")
var ShotgunPowerUp = preload("res://scenes/powerups/ShotgunPowerUp.gd")
var HeartPowerUp = preload("res://scenes/powerups/HeartPowerUp.gd")
var DayNightPowerUp = preload("res://scenes/powerups/DayNightPowerUp.gd")

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
var audio_setup_manager: Node
var difficulty_manager: Node
var spawning_controller: Node
var tnt_explosion_handler: Node
var time_of_day_controller: Node

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
var player_immune : bool = false  # Track if player is in immunity period
var touch_start_detected : bool = false  # Track if touch was detected to start game

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

	# Initialize time of day controller
	time_of_day_controller = TimeOfDayController.new()
	time_of_day_controller.name = "TimeOfDayController"
	add_child(time_of_day_controller)
	time_of_day_controller.initialize($ParallaxBackground, $Ground)

	# Initialize powerup manager first (needed by special event manager)
	powerup_manager = PowerUpManager.new()
	add_child(powerup_manager)
	var gokart_powerup = GokartPowerUp.new()
	var shotgun_powerup = ShotgunPowerUp.new()
	var heart_powerup = HeartPowerUp.new()
	var day_night_powerup = DayNightPowerUp.new()
	var powerups: Array[PowerUpBase] = [gokart_powerup, shotgun_powerup, heart_powerup, day_night_powerup]
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

	# Initialize audio manager for Connor's voice lines ONLY
	# NOTE: This mutex mechanism only applies to Connor's voice lines
	# Background music (MusicPlayer) and other audio are NOT affected by this mutex
	audio_manager = AudioManager.new()
	add_child(audio_manager)

	# Initialize audio setup manager
	audio_setup_manager = AudioSetupManager.new()
	add_child(audio_setup_manager)
	audio_setup_manager.initialize($MusicPlayer, audio_manager)
	audio_setup_manager.setup()

	# Initialize difficulty manager
	difficulty_manager = DifficultyManager.new()
	add_child(difficulty_manager)
	difficulty_manager.difficulty_level_changed.connect(_on_difficulty_level_changed)

	# Initialize spawning controller
	spawning_controller = SpawningController.new()
	add_child(spawning_controller)
	spawning_controller.initialize(obstacle_manager, foe_spawner, coin_spawner, butterfly_spawner, distance)

	# Initialize TNT explosion handler
	tnt_explosion_handler = TNTExplosionHandler.new()
	add_child(tnt_explosion_handler)
	tnt_explosion_handler.initialize(obstacle_manager, lives_manager, self)
	tnt_explosion_handler.explosion_started.connect(_on_explosion_started)
	tnt_explosion_handler.explosion_finished.connect(_on_explosion_finished)

func new_game():
	# Reset game over flag
	game_over_in_progress = false

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
	if difficulty_manager:
		difficulty_manager.reset()
	if tnt_explosion_handler:
		tnt_explosion_handler.reset()
	if time_of_day_controller:
		time_of_day_controller.reset()
	if $Hud:
		$Hud.reset()

	# Ensure all spawners are enabled (in case game was restarted during a special event)
	spawning_controller.set_all_spawning_enabled(true)

	game_running = false
	get_tree().paused = false
	distance = 0  # Reset distance
	spawning_controller.set_distance(distance)
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
	if audio_setup_manager:
		audio_setup_manager.reset_music()

	# Play "alright" when game starts/restarts
	if audio_manager:
		audio_manager.play_sound("alright")

func _on_difficulty_level_changed(_new_level: int):
	# Called when difficulty level changes - start speed transition
	difficulty_manager.start_speed_transition(speed)
	update_hud_difficulty_level()

func update_hud_difficulty_level():
	# Update HUD with current difficulty level for debugging
	var current_level = difficulty_manager.get_current_level()
	if not $Hud.has_node("DifficultyLevel"):
		# Create difficulty level label if it doesn't exist
		var level_label = Label.new()
		level_label.name = "DifficultyLevel"
		level_label.text = "Level: " + str(current_level)
		level_label.position = Vector2(54, 10)
		var font = load("res://assets/fonts/retro.ttf")
		if font:
			level_label.add_theme_font_override("font", font)
		level_label.add_theme_font_size_override("font_size", 40)
		$Hud.add_child(level_label)
	else:
		$Hud.get_node("DifficultyLevel").text = "Level: " + str(current_level)

# Game logic happens here
func _process(delta: float) -> void:
	if game_running:
		# Update powerup manager (only if initialized)
		if powerup_manager:
			powerup_manager.update(delta, self)

		# Update difficulty level based on distance
		difficulty_manager.update_difficulty_level(distance)

		# Calculate speed with gradual transition
		speed = difficulty_manager.update_speed_transition(delta, speed)

		# Apply powerup speed modifier (e.g., from gokart)
		speed *= powerup_manager.get_speed_modifier()

		# Update obstacle manager with current difficulty level
		obstacle_manager.set_difficulty_level(difficulty_manager.get_current_level())

		# Generate obstacles (returns array - single at level 1, pair at level 2+)
		# Use actual camera position for accurate spawning
		var new_obstacles = obstacle_manager.generate_obstacle(distance, $Camera2D.position.x)
		for new_obstacle in new_obstacles:
			if new_obstacle:
				obstacle_manager.add_obstacle(new_obstacle)

		# Update butterfly spawner with current difficulty level
		butterfly_spawner.set_difficulty_level(difficulty_manager.get_current_level())

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
		foe_spawner.set_difficulty_level(difficulty_manager.get_current_level())

		# Check foe spawning (always single, frequency adjusts with difficulty)
		# Use actual camera position for accurate spawning
		var foe = foe_spawner.update(distance, $Camera2D.position.x)
		if foe:
			foe_manager.add_foe(foe)

		# Move player position & camera (only if not in explosion)
		if not tnt_explosion_handler.is_explosion_in_progress():
			$Player.position.x += speed
			$Camera2D.position.x += speed

			# Update distance based on actual movement
			distance += int(speed)
			spawning_controller.set_distance(distance)

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
	if tnt_explosion_handler.handle_tnt_collision(obstacle):
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

func _on_explosion_started():
	# Called when TNT explosion starts
	pass

func _on_explosion_finished():
	# Called when TNT explosion finishes
	pass

func set_explosion_in_progress(value: bool) -> void:
	# Setter method for TNT script to control explosion state
	tnt_explosion_handler.set_explosion_in_progress(value)

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

# Spawning control methods for special events (delegate to SpawningController)
func set_obstacle_spawning_enabled(enabled: bool):
	spawning_controller.set_obstacle_spawning_enabled(enabled)

func set_foe_spawning_enabled(enabled: bool):
	spawning_controller.set_foe_spawning_enabled(enabled)

func set_coin_spawning_enabled(enabled: bool):
	spawning_controller.set_coin_spawning_enabled(enabled)

func set_butterfly_spawning_enabled(enabled: bool):
	spawning_controller.set_butterfly_spawning_enabled(enabled)

# Convenience method to enable/disable all spawning
func set_all_spawning_enabled(enabled: bool):
	spawning_controller.set_all_spawning_enabled(enabled)

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

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
# Preload PowerUpBase first to ensure class_name is registered
# This ensures the class is available when other powerup scripts extend it
@warning_ignore("unused_private_class_variable")
var _powerup_base = preload("res://scenes/powerups/PowerUpBase.gd")
var GokartPowerUp = preload("res://scenes/powerups/GokartPowerUp.gd")
var ShotgunPowerUp = preload("res://scenes/powerups/ShotgunPowerUp.gd")

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

const PLAYER_START_POS := Vector2i(19, 166)
const CAMERA_START_POS := Vector2i(540, 960)

var speed : float
const START_SPEED : int = 10
const SPEED_MODIFIER : int = 20_000
const MAX_SPEED : int = 15
var screen_size : Vector2i
var game_running : bool
var ground_height : int
var distance : int = 0  # Track actual distance traveled, separate from score
var game_over_in_progress : bool = false  # Track if game over is already triggered
var explosion_in_progress : bool = false  # Track if TNT explosion is playing (stops movement)

# Score delta display variables
var score_delta_timer: float = 0.0
var score_delta_color_white: bool = true  # Track color alternation

# Special event button result tracking
var special_button_result: String = ""  # "correct", "wrong", or "" (not pressed)
var special_button_reaction_time: float = -1.0  # Time taken for correct answers, -1.0 for incorrect/missed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_window().size
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	$GameOver.get_node("Button").pressed.connect(new_game)

	# Initialize managers
	setup_managers()

	# Hide score delta label initially
	$Hud.get_node("ScoreValueDelta").hide()

	# Setup music
	setup_music()

	new_game()

func setup_managers():
	# Create and add manager nodes
	score_manager = ScoreManager.new()
	add_child(score_manager)
	score_manager.score_updated.connect(_on_score_updated)
	score_manager.high_score_updated.connect(_on_high_score_updated)
	score_manager.score_delta.connect(_on_score_delta)

	obstacle_manager = ObstacleManager.new()
	add_child(obstacle_manager)
	obstacle_manager.obstacle_added.connect(_on_obstacle_added)

	var obstacle_types: Array[PackedScene] = [rock_scene, agave_scene, tnt_scene]
	var ground_sprite = $Ground.get_node("Sprite2D")
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

	# Initialize powerup manager first (needed by special event manager)
	powerup_manager = PowerUpManager.new()
	add_child(powerup_manager)
	var gokart_powerup = GokartPowerUp.new()
	var shotgun_powerup = ShotgunPowerUp.new()
	var powerups: Array[PowerUpBase] = [gokart_powerup,shotgun_powerup]
	powerup_manager.initialize(powerups, $PowerUpUI)
	powerup_manager.powerup_activated.connect(_on_powerup_activated)
	powerup_manager.powerup_deactivated.connect(_on_powerup_deactivated)
	$PowerUpUI.powerup_button_pressed.connect(powerup_manager.on_powerup_button_pressed)
	
	# Initialize powerup HUD
	$PowerUpHud.initialize(powerup_manager)

	special_event_manager = SpecialEventManager.new()
	add_child(special_event_manager)
	special_event_manager.special_event_started.connect(_on_special_event_started)
	special_event_manager.special_event_ended.connect(_on_special_event_ended)
	var special_types: Array[PackedScene] = [texas_flag_scene, us_flag_scene, cheerleader_scene, smoker_scene, devil_plush_scene, man_baby_scene]
	special_event_manager.initialize(special_types, screen_size, ground_sprite, $SpecialGround, $SpecialEventButtons, powerup_manager)

	# Connect button signals
	$SpecialEventButtons.button_pressed.connect(_on_special_button_pressed)
	$SpecialEventButtons.buttons_hidden.connect(_on_special_buttons_hidden)

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

func reset_music():
	# Stop the music and restart from the beginning
	if $MusicPlayer.playing:
		$MusicPlayer.stop()
	$MusicPlayer.play()

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

	# Ensure all spawners are enabled (in case game was restarted during a special event)
	set_all_spawning_enabled(true)

	game_running = false
	get_tree().paused = false
	distance = 0  # Reset distance

	# Reset the nodes
	$Player.position = PLAYER_START_POS
	$Player.velocity = Vector2i(0, 0)
	$Camera2D.position = CAMERA_START_POS
	$Ground.position = Vector2i(0, 0)

	# Reset HUD and game over scene
	$Hud.get_node("StartLabel").show()
	$GameOver.hide()

	# Hide score delta label
	var delta_label = $Hud.get_node("ScoreValueDelta")
	delta_label.hide()
	score_delta_timer = 0.0

	# Reset music to play from the beginning
	reset_music()


# Game logic happens here
func _process(delta: float) -> void:
	if game_running:
		# Update powerup manager (only if initialized)
		if powerup_manager:
			powerup_manager.update(delta, self)

		# Calculate speed based on distance traveled, not score
		@warning_ignore("integer_division")
		speed = START_SPEED + distance / SPEED_MODIFIER
		if speed > MAX_SPEED:
			speed = MAX_SPEED

		# Apply powerup speed modifier (e.g., from gokart)
		speed *= powerup_manager.get_speed_modifier()

		# Generate obstacles
		var new_obstacle = obstacle_manager.generate_obstacle(distance)
		if new_obstacle:
			obstacle_manager.add_obstacle(new_obstacle)

		# Check butterfly spawning
		var butterfly = butterfly_spawner.update(delta, distance)
		if butterfly:
			obstacle_manager.add_obstacle(butterfly)

		# Check coin spawning
		var coin = coin_spawner.update(delta, distance)
		if coin:
			coin_manager.add_coin(coin)

		# Check foe spawning
		var foe = foe_spawner.update(distance)
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

		# Update ground position
		if $Camera2D.position.x - $Ground.position.x > screen_size.x * 1.5:
			$Ground.position.x += screen_size.x

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
	else:
		if Input.is_action_pressed("ui_accept"):
			game_running = true
			$Hud.get_node("StartLabel").hide()

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
	# Prevent multiple game over triggers
	if game_over_in_progress:
		return
	
	# Check if obstacle is TNT - if so, play explosion animation before game over
	if _is_tnt(obstacle):
		# Remove from obstacle manager immediately
		if obstacle_manager.obstacles.has(obstacle):
			obstacle_manager.obstacles.erase(obstacle)
		
		# Trigger explosion (from_collision=true to handle player bounce)
		if obstacle.has_method("trigger_explosion"):
			# Connect to explosion finished signal before triggering
			if obstacle.has_signal("explosion_finished"):
				# Disconnect first to avoid duplicate connections
				if obstacle.explosion_finished.is_connected(_on_tnt_explosion_finished_game_over):
					obstacle.explosion_finished.disconnect(_on_tnt_explosion_finished_game_over)
				obstacle.explosion_finished.connect(_on_tnt_explosion_finished_game_over)
			obstacle.trigger_explosion(true)
		else:
			# Fallback if script not attached
			game_over()
	else:
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

func _on_tnt_explosion_finished_game_over() -> void:
	# Trigger game over after explosion animation finishes
	# Reset explosion flag (though game_over will pause anyway)
	explosion_in_progress = false
	game_over()

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
	# Only process button presses if sprite has entered view
	# This prevents scoring when buttons are pressed before the sprite is visible
	var buttons_ui = $SpecialEventButtons
	if not buttons_ui or not buttons_ui.has_sprite_entered_view():
		# Sprite hasn't entered view yet - buttons already hidden by button handler
		# Show "Too Early!" message
		$SpecialEventHud.show_outcome("too_early")
		return

	# Get the timer value (time since sprite entered view)
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
	else:
		# Wrong answer - deduct 500 points (500 * 100 = 50000 raw score)
		score_manager.add_score(-500 * 100, true)  # Show delta for penalty
		special_button_result = "wrong"
		special_button_reaction_time = -1.0  # Don't show time for wrong answers

	# Buttons are already hidden by the button press handler (which sets force_hide = true)
	# Mark that a button was pressed - event will end when special leaves screen
	special_event_manager.mark_button_pressed()

func _on_special_buttons_hidden(was_pressed: bool, too_early: bool):
	# Show outcome message when buttons are hidden
	if too_early:
		# Button was pressed too early - already handled in _on_special_button_pressed
		return

	if was_pressed:
		# Button was pressed - show result based on whether it was correct or wrong
		if special_button_result == "correct":
			$SpecialEventHud.show_outcome("nice", special_button_reaction_time)
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
	# Powerup was activated - mark that event should end when special leaves screen
	# Don't end immediately - let special object leave screen naturally
	# This ensures spawning resumes so the powerup has targets to use
	if special_event_manager.get_event_active():
		print("[Main] Powerup activated during special event - will end when special leaves screen")
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

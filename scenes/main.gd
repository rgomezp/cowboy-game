extends Node

# Preload obstacles
var rock_scene = preload("res://scenes/obstacles/rock.tscn")
var agave_scene = preload("res://scenes/obstacles/agave.tscn")
var tnt_scene = preload("res://scenes/obstacles/tnt.tscn")
var butterfly_scene = preload("res://scenes/obstacles/butterfly.tscn")
var coin_scene = preload("res://scenes/items/Coin.tscn")
var furry_scene = preload("res://scenes/foes/furry/furry.tscn")
var troll_scene = preload("res://scenes/foes/troll/troll.tscn")

# Preload manager scripts
var ScoreManager = preload("res://scenes/ScoreManager.gd")
var ObstacleManager = preload("res://scenes/ObstacleManager.gd")
var ButterflySpawner = preload("res://scenes/ButterflySpawner.gd")
var CoinSpawner = preload("res://scenes/CoinSpawner.gd")
var CoinManager = preload("res://scenes/CoinManager.gd")
var FoeSpawner = preload("res://scenes/FoeSpawner.gd")
var FoeManager = preload("res://scenes/FoeManager.gd")
var CollisionHandler = preload("res://scenes/CollisionHandler.gd")

# Manager instances
var score_manager: Node
var obstacle_manager: Node
var butterfly_spawner: Node
var coin_spawner: Node
var coin_manager: Node
var foe_spawner: Node
var foe_manager: Node
var collision_handler: Node

const PLAYER_START_POS := Vector2i(19, 166)
const CAMERA_START_POS := Vector2i(540, 960)

var speed : float
const START_SPEED : float = 10.0
const SPEED_MODIFIER : int = 20_000
const MAX_SPEED : int = 15
var screen_size : Vector2i
var game_running : bool
var ground_height : int
var distance : int = 0  # Track actual distance traveled, separate from score

# Score delta display variables
var score_delta_timer: float = 0.0
var score_delta_color_white: bool = true  # Track color alternation

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_window().size
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	$GameOver.get_node("Button").pressed.connect(new_game)

	# Initialize managers
	setup_managers()

	# Hide score delta label initially
	$Hud.get_node("ScoreValueDelta").hide()

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

	foe_spawner = FoeSpawner.new()
	add_child(foe_spawner)
	foe_spawner.foe_spawned.connect(_on_foe_spawned)
	var foe_types: Array[PackedScene] = [furry_scene, troll_scene]
	foe_spawner.initialize(foe_types, screen_size, ground_sprite)

	foe_manager = FoeManager.new()
	add_child(foe_manager)
	foe_manager.foe_added.connect(_on_foe_added)
	foe_manager.initialize(screen_size)

	collision_handler = CollisionHandler.new()
	add_child(collision_handler)
	collision_handler.player_hit_obstacle.connect(_on_player_hit_obstacle)
	collision_handler.player_bounced_on_butterfly.connect(_on_player_bounced_on_butterfly)
	collision_handler.player_jumped_on_foe.connect(_on_player_jumped_on_foe)
	collision_handler.initialize($Player)

func new_game():
	# Reset managers
	score_manager.reset()
	obstacle_manager.reset()
	butterfly_spawner.reset()
	coin_spawner.reset()
	coin_manager.reset()
	foe_spawner.reset()
	foe_manager.reset()

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


# Game logic happens here
func _process(delta: float) -> void:
	if game_running:
		# Calculate speed based on distance traveled, not score
		speed = START_SPEED + distance / SPEED_MODIFIER
		if speed > MAX_SPEED:
			speed = MAX_SPEED

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

		# Move player position & camera
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
func _on_score_updated(score: int):
	$Hud.get_node("ScoreValue").text = str(score_manager.get_display_score())

func _on_high_score_updated(high_score: int):
	$Hud.get_node("HighScoreValue").text = str(score_manager.get_display_high_score())

func _on_score_delta(delta: int):
	# Convert raw score to display score (divide by SCORE_MODIFIER which is 100)
	var display_delta = delta / 100

	# Only show meaningful score changes (filter out 0)
	if display_delta <= 0:
		return

	# Display the score delta for 1 second
	var delta_label = $Hud.get_node("ScoreValueDelta")

	# Format as +100, +10, etc.
	delta_label.text = "+" + str(display_delta)

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

func _on_butterfly_spawned(butterfly: Node):
	# Butterfly is already positioned by ButterflySpawner
	pass

func _on_coin_spawned(coin: Node):
	# Coin is already positioned by CoinSpawner
	pass

func _on_coin_added(coin: Node):
	# Coins handle their own collision detection, no need to connect signals
	pass

func _on_foe_spawned(foe: Node):
	# Foe is already positioned by FoeSpawner
	pass

func _on_foe_added(foe: Node):
	collision_handler.connect_obstacle_signals(foe)

func _on_player_hit_obstacle(obstacle: Node):
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
	score_manager.check_high_score()
	get_tree().paused = true
	game_running = false
	$GameOver.show()

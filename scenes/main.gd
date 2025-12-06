extends Node

# Preload obstacles
var rock_scene = preload("res://scenes/obstacles/rock.tscn")
var agave_scene = preload("res://scenes/obstacles/agave.tscn")
var butterfly_scene = preload("res://scenes/obstacles/butterfly.tscn")

# Preload manager scripts
var ScoreManager = preload("res://scenes/ScoreManager.gd")
var ObstacleManager = preload("res://scenes/ObstacleManager.gd")
var ButterflySpawner = preload("res://scenes/ButterflySpawner.gd")
var CollisionHandler = preload("res://scenes/CollisionHandler.gd")

# Manager instances
var score_manager: Node
var obstacle_manager: Node
var butterfly_spawner: Node
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_window().size
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	$GameOver.get_node("Button").pressed.connect(new_game)
	
	# Initialize managers
	setup_managers()
	
	new_game()

func setup_managers():
	# Create and add manager nodes
	score_manager = ScoreManager.new()
	add_child(score_manager)
	score_manager.score_updated.connect(_on_score_updated)
	score_manager.high_score_updated.connect(_on_high_score_updated)
	
	obstacle_manager = ObstacleManager.new()
	add_child(obstacle_manager)
	obstacle_manager.obstacle_added.connect(_on_obstacle_added)
	
	var obstacle_types: Array[PackedScene] = [rock_scene, agave_scene]
	var ground_sprite = $Ground.get_node("Sprite2D")
	obstacle_manager.initialize(obstacle_types, screen_size, ground_sprite)
	
	butterfly_spawner = ButterflySpawner.new()
	add_child(butterfly_spawner)
	butterfly_spawner.butterfly_spawned.connect(_on_butterfly_spawned)
	butterfly_spawner.initialize(butterfly_scene, screen_size)
	
	collision_handler = CollisionHandler.new()
	add_child(collision_handler)
	collision_handler.player_hit_obstacle.connect(_on_player_hit_obstacle)
	collision_handler.player_bounced_on_butterfly.connect(_on_player_bounced_on_butterfly)
	collision_handler.initialize($Player)

func new_game():
	# Reset managers
	score_manager.reset()
	obstacle_manager.reset()
	butterfly_spawner.reset()
	
	game_running = false
	get_tree().paused = false

	# Reset the nodes
	$Player.position = PLAYER_START_POS
	$Player.velocity = Vector2i(0, 0)
	$Camera2D.position = CAMERA_START_POS
	$Ground.position = Vector2i(0, 0)

	# Reset HUD and game over scene
	$Hud.get_node("StartLabel").show()
	$GameOver.hide()


# Game logic happens here
func _process(delta: float) -> void:
	if game_running:
		var current_score = score_manager.score
		speed = START_SPEED + current_score / SPEED_MODIFIER
		if speed > MAX_SPEED:
			speed = MAX_SPEED
		
		# Generate obstacles
		var new_obstacle = obstacle_manager.generate_obstacle(current_score)
		if new_obstacle:
			obstacle_manager.add_obstacle(new_obstacle)
		
		# Check butterfly spawning
		var butterfly = butterfly_spawner.update(delta, current_score)
		if butterfly:
			obstacle_manager.add_obstacle(butterfly)

		# Move player position & camera
		$Player.position.x += speed
		$Camera2D.position.x += speed

		# Update score
		score_manager.add_score(int(speed))

		# Update ground position
		if $Camera2D.position.x - $Ground.position.x > screen_size.x * 1.5:
			$Ground.position.x += screen_size.x

		# Cleanup off-screen obstacles
		obstacle_manager.cleanup_off_screen_obstacles($Camera2D.position.x)
	else:
		if Input.is_action_pressed("ui_accept"):
			game_running = true
			$Hud.get_node("StartLabel").hide()

# Signal handlers
func _on_score_updated(score: int):
	$Hud.get_node("ScoreValue").text = str(score_manager.get_display_score())

func _on_high_score_updated(high_score: int):
	$Hud.get_node("HighScoreValue").text = str(score_manager.get_display_high_score())

func _on_obstacle_added(obstacle: Node):
	collision_handler.connect_obstacle_signals(obstacle)

func _on_butterfly_spawned(butterfly: Node):
	# Butterfly is already positioned by ButterflySpawner
	pass

func _on_player_hit_obstacle(obstacle: Node):
	game_over()

func _on_player_bounced_on_butterfly(obstacle: Node):
	# Player jumped on the butterfly from the top - bounce and hide it
	var bounce_velocity = -1200  # Slightly less than jump velocity for a nice bounce
	$Player.velocity.y = bounce_velocity
	obstacle.hide()
	obstacle_manager.remove_obstacle(obstacle)

func game_over():
	score_manager.check_high_score()
	get_tree().paused = true
	game_running = false
	$GameOver.show()

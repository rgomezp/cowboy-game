extends "res://scenes/powerups/PowerUpBase.gd"

# Gokart powerup:
# - Pause all obstacle and foe spawns
# - Generate a wall of 40 coins
# - Double game speed (gradual: 5s ramp up, 5s ramp down)
# - Lasts 7 seconds
# - Switch to gokart animation (stub for now)

const RAMP_UP_DURATION: float = 5.0
const RAMP_DOWN_DURATION: float = 5.0
const COIN_WALL_SIZE: int = 40
const SPEED_MULTIPLIER: float = 2.0

var base_speed: float = 0.0
var speed_modifier: float = 1.0
var coin_wall_spawned: bool = false

func _init():
	super._init("gokart", 7.0)

func _on_activate(main_node: Node) -> void:
	# Store base speed
	base_speed = main_node.speed

	# Pause obstacle and foe spawns
	main_node.set_obstacle_spawning_enabled(false)
	main_node.set_foe_spawning_enabled(false)
	main_node.set_butterfly_spawning_enabled(false)

	# Switch to gokart animation (stub - will be implemented when animation is ready)
	# main_node.get_node("Player").get_node("AnimatedSprite2D").play("gokart")

	# Spawn coin wall
	spawn_coin_wall(main_node)

	coin_wall_spawned = true

func _on_update(_delta: float, _main_node: Node) -> void:
	var time_remaining = duration - elapsed_time

	# Calculate speed modifier based on ramp up/down
	if elapsed_time < RAMP_UP_DURATION:
		# Ramping up: 1.0 to SPEED_MULTIPLIER over RAMP_UP_DURATION seconds
		speed_modifier = 1.0 + (elapsed_time / RAMP_UP_DURATION) * (SPEED_MULTIPLIER - 1.0)
	elif time_remaining < RAMP_DOWN_DURATION:
		# Ramping down: SPEED_MULTIPLIER to 1 over RAMP_DOWN_DURATION seconds
		var ramp_down_progress = (RAMP_DOWN_DURATION - time_remaining) / RAMP_DOWN_DURATION
		speed_modifier = SPEED_MULTIPLIER - ramp_down_progress * (SPEED_MULTIPLIER - 1.0)
	else:
		# Full speed
		speed_modifier = SPEED_MULTIPLIER

	# Apply speed modifier to main node
	# The main node will read this via get_speed_modifier()
	# We'll store it in a variable that main can access

func _on_deactivate(main_node: Node) -> void:
	# Re-enable spawns
	main_node.set_obstacle_spawning_enabled(true)
	main_node.set_foe_spawning_enabled(true)
	main_node.set_butterfly_spawning_enabled(true)

	# Reset animation (stub)
	# main_node.get_node("Player").get_node("AnimatedSprite2D").play("running")

	speed_modifier = 1.0
	coin_wall_spawned = false

func spawn_coin_wall(main_node: Node) -> void:
	# Spawn a wall of 40 coins
	var coin_scene = main_node.coin_scene
	var coin_manager = main_node.coin_manager
	var screen_size = main_node.screen_size
	var ground_top_y = 1280.0
	var camera_x = main_node.get_node("Camera2D").position.x

	# Coin height offsets (same as CoinSpawner uses)
	var coin_height_offsets: Array[int] = [-200, -250, -300, -350, -400, -500]
	var horizontal_spacing: int = 50

	for i in range(COIN_WALL_SIZE):
		var coin = coin_scene.instantiate()
		var obs_x: int = int(camera_x + screen_size.x + GameConstants.SPAWN_OFFSET + (i * horizontal_spacing))
		var height_offset = coin_height_offsets[randi() % coin_height_offsets.size()]
		var obs_y: int = int(ground_top_y + height_offset)
		coin.position = Vector2i(obs_x, obs_y)
		coin_manager.add_coin(coin)

func get_speed_modifier() -> float:
	return speed_modifier

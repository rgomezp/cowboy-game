extends Node

signal coin_spawned(coin: Node)

var coin_scene: PackedScene
# Coin height offsets relative to ground top (negative = above ground)
# Ground top is at Y=1280, so coins should be above that
var coin_height_offsets: Array[int] = [-200, -250, -300, -350, -400, -500]  # Hovering above ground, all jump-reachable
var last_coin_time: float = 0.0
var next_coin_interval: float = 0.0
var screen_size: Vector2i
var ground_top_y: float = 1280.0  # Ground top Y position

# Wall of coins spawning variables
var last_wall_time: float = 0.0
var next_wall_interval: float = 0.0
var is_spawning_wall: bool = false
var wall_coins_spawned: int = 0
var wall_coins_total: int = 10
var wall_spawn_delay: float = 0.05  # Delay between each coin in the wall (rapid succession)
var last_wall_coin_time: float = 0.0
var spawning_enabled: bool = true  # Can be disabled for special events

func initialize(scene: PackedScene, size: Vector2i, ground_y: float = 1280.0):
	self.coin_scene = scene
	self.screen_size = size
	self.ground_top_y = ground_y

func reset():
	last_coin_time = 0.0
	next_coin_interval = randf_range(0.5, 2.0)  # Much more frequent than butterflies
	last_wall_time = 0.0
	next_wall_interval = randf_range(5.0, 10.0)  # Spawn wall every 5-10 seconds
	is_spawning_wall = false
	wall_coins_spawned = 0

func set_spawning_enabled(enabled: bool):
	var was_enabled = spawning_enabled
	spawning_enabled = enabled
	print("[CoinSpawner] Spawning enabled: ", enabled, " (was: ", was_enabled, ")")

func reset_timer():
	# When spawning is re-enabled, reset the timer to prevent immediate spawning
	# This ensures proper timing after a pause
	print("[CoinSpawner] reset_timer: Resetting coin spawner timers")
	last_coin_time = 0.0
	next_coin_interval = randf_range(0.5, 2.0)
	last_wall_time = 0.0
	next_wall_interval = randf_range(5.0, 10.0)
	is_spawning_wall = false
	wall_coins_spawned = 0
	print("[CoinSpawner] reset_timer: next_coin_interval=", next_coin_interval, ", next_wall_interval=", next_wall_interval)

func is_spawning_enabled() -> bool:
	return spawning_enabled

func update(delta: float, current_distance: int) -> Node:
	if not spawning_enabled:
		return null
	# Handle wall of coins spawning
	if is_spawning_wall:
		last_wall_coin_time += delta
		if last_wall_coin_time >= wall_spawn_delay:
			var coin = spawn_wall_coin(current_distance)
			wall_coins_spawned += 1
			last_wall_coin_time = 0.0

			if wall_coins_spawned >= wall_coins_total:
				# Finished spawning wall
				is_spawning_wall = false
				wall_coins_spawned = 0
				last_wall_time = 0.0
				next_wall_interval = randf_range(5.0, 10.0)  # Schedule next wall

			return coin
	else:
		# Check if it's time to start a new wall
		last_wall_time += delta
		if last_wall_time >= next_wall_interval:
			is_spawning_wall = true
			wall_coins_spawned = 0
			last_wall_coin_time = 0.0
			# Don't reset last_wall_time yet - we'll do it after the wall is complete

	# Handle regular random coin spawning (only when not spawning a wall)
	if not is_spawning_wall:
		last_coin_time += delta
		if last_coin_time >= next_coin_interval:
			var coin = spawn_coin(current_distance)
			last_coin_time = 0.0
			next_coin_interval = randf_range(0.5, 2.0)  # Spawn every 0.5-2 seconds
			return coin

	return null

func spawn_coin(current_distance: int) -> Node:
	var coin = coin_scene.instantiate()
	# Camera starts at 540, so calculate camera position from distance
	# This ensures coins spawn off-camera ahead, not mid-screen
	const CAMERA_START_X: int = 540
	var camera_x = CAMERA_START_X + current_distance
	var obs_x: int = int(camera_x + screen_size.x + GameConstants.SPAWN_OFFSET)
	# Position coin above ground at various heights (all jump-reachable)
	# Ground top is at 1600.5, so coins hover above it
	var height_offset = coin_height_offsets[randi() % coin_height_offsets.size()]
	var obs_y: int = int(ground_top_y + height_offset)
	coin.position = Vector2i(obs_x, obs_y)
	print("[CoinSpawner] spawn_coin: SPAWNED at distance=", current_distance, ", camera_x=", camera_x, ", position=(", obs_x, ", ", obs_y, ")")
	coin_spawned.emit(coin)
	return coin

func spawn_wall_coin(current_distance: int) -> Node:
	var coin = coin_scene.instantiate()
	# Space coins horizontally to create a wall effect
	# Each coin is spaced 50 pixels apart horizontally
	# Camera starts at 540, so calculate camera position from distance
	const CAMERA_START_X: int = 540
	var camera_x = CAMERA_START_X + current_distance
	var horizontal_spacing: int = 50
	var obs_x: int = int(camera_x + screen_size.x + GameConstants.SPAWN_OFFSET + (wall_coins_spawned * horizontal_spacing))
	# For wall coins, use random heights to create a more chaotic wall effect
	var height_offset = coin_height_offsets[randi() % coin_height_offsets.size()]
	var obs_y: int = int(ground_top_y + height_offset)
	coin.position = Vector2i(obs_x, obs_y)
	coin_spawned.emit(coin)
	return coin

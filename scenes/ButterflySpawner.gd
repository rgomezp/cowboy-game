extends Node

signal butterfly_spawned(butterfly: Node)

var butterfly_scene: PackedScene
var butterfly_heights: Array[int] = [150, -300]
var last_butterfly_time: float = 0.0
var next_butterfly_interval: float = 0.0
var screen_size: Vector2i
var spawning_enabled: bool = true  # Can be disabled for special events
var difficulty_level: int = 1  # Current difficulty level

func initialize(scene: PackedScene, size: Vector2i):
	self.butterfly_scene = scene
	self.screen_size = size

func set_difficulty_level(level: int):
	difficulty_level = level

func reset():
	last_butterfly_time = 0.0
	# Default to level 1 interval on reset (difficulty will be set before first spawn)
	next_butterfly_interval = randf_range(5.0, 15.0)

func set_spawning_enabled(enabled: bool):
	var was_enabled = spawning_enabled
	spawning_enabled = enabled
	print("[ButterflySpawner] Spawning enabled: ", enabled, " (was: ", was_enabled, ")")

func reset_timer():
	# When spawning is re-enabled, reset the timer to prevent immediate spawning
	# This ensures proper timing after a pause
	print("[ButterflySpawner] reset_timer: Resetting butterfly spawner timer")
	last_butterfly_time = 0.0
	# Adjust interval based on difficulty
	if difficulty_level == 1:
		next_butterfly_interval = randf_range(5.0, 15.0)
	elif difficulty_level == 2:
		next_butterfly_interval = randf_range(3.0, 10.0)
	else:  # Level 3
		next_butterfly_interval = randf_range(2.0, 7.0)
	print("[ButterflySpawner] reset_timer: next_butterfly_interval=", next_butterfly_interval)

func is_spawning_enabled() -> bool:
	return spawning_enabled

func update(delta: float, current_distance: int, camera_x: float) -> Node:
	# Always spawn single butterfly (frequency adjusts based on difficulty)
	if not spawning_enabled:
		return null
	
	last_butterfly_time += delta
	if last_butterfly_time >= next_butterfly_interval:
		# Use actual camera position passed from main.gd
		var base_x: int = int(camera_x) + screen_size.x + 100
		
		var butterfly = spawn_butterfly_at_position(current_distance, base_x)
		last_butterfly_time = 0.0
		# Adjust interval based on difficulty
		if difficulty_level == 1:
			next_butterfly_interval = randf_range(5.0, 15.0)
		elif difficulty_level == 2:
			next_butterfly_interval = randf_range(3.0, 10.0)
		else:  # Level 3
			next_butterfly_interval = randf_range(2.0, 7.0)
		
		return butterfly
	return null

func spawn_butterfly_at_position(current_distance: int, base_x_pos: int) -> Node:
	var butterfly = butterfly_scene.instantiate()
	var obs_x: int = base_x_pos + randi_range(-50, 50)
	var obs_y: int = butterfly_heights[randi() % butterfly_heights.size()]
	butterfly.position = Vector2i(obs_x, obs_y)
	print("[ButterflySpawner] spawn_butterfly_at_position: SPAWNED at distance=", current_distance, ", position=(", obs_x, ", ", obs_y, ")")
	butterfly_spawned.emit(butterfly)
	return butterfly

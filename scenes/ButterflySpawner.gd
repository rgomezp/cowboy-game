extends Node

signal butterfly_spawned(butterfly: Node)

var butterfly_scene: PackedScene
var butterfly_heights: Array[int] = [150, -300]
var last_butterfly_time: float = 0.0
var next_butterfly_interval: float = 0.0
var screen_size: Vector2i
var spawning_enabled: bool = true  # Can be disabled for special events

func initialize(scene: PackedScene, size: Vector2i):
	self.butterfly_scene = scene
	self.screen_size = size

func reset():
	last_butterfly_time = 0.0
	next_butterfly_interval = randf_range(1.0, 5.0)

func set_spawning_enabled(enabled: bool):
	var was_enabled = spawning_enabled
	spawning_enabled = enabled
	print("[ButterflySpawner] Spawning enabled: ", enabled, " (was: ", was_enabled, ")")

func reset_timer():
	# When spawning is re-enabled, reset the timer to prevent immediate spawning
	# This ensures proper timing after a pause
	print("[ButterflySpawner] reset_timer: Resetting butterfly spawner timer")
	last_butterfly_time = 0.0
	next_butterfly_interval = randf_range(1.0, 5.0)
	print("[ButterflySpawner] reset_timer: next_butterfly_interval=", next_butterfly_interval)

func is_spawning_enabled() -> bool:
	return spawning_enabled

func update(delta: float, current_distance: int) -> Node:
	if not spawning_enabled:
		return null
	last_butterfly_time += delta
	if last_butterfly_time >= next_butterfly_interval:
		var butterfly = spawn_butterfly(current_distance)
		last_butterfly_time = 0.0
		next_butterfly_interval = randf_range(5.0, 15.0)
		return butterfly
	return null

func spawn_butterfly(current_distance: int) -> Node:
	var butterfly = butterfly_scene.instantiate()
	# Camera starts at 540, so calculate camera position from distance
	# This ensures butterflies spawn off-camera ahead, not mid-screen
	const CAMERA_START_X: int = 540
	var camera_x = CAMERA_START_X + current_distance
	var obs_x: int = camera_x + screen_size.x + 100
	var obs_y: int = butterfly_heights[randi() % butterfly_heights.size()]
	butterfly.position = Vector2i(obs_x, obs_y)
	print("[ButterflySpawner] spawn_butterfly: SPAWNED at distance=", current_distance, ", camera_x=", camera_x, ", position=(", obs_x, ", ", obs_y, ")")
	butterfly_spawned.emit(butterfly)
	return butterfly

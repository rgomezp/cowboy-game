extends Node

signal obstacle_added(obstacle: Node)
signal obstacle_removed(obstacle: Node)

var obstacle_types: Array[PackedScene]
var obstacles: Array = []
var last_obstacle_distance: int = 0  # Track distance, not score
var screen_size: Vector2i
var ground_sprite: Sprite2D
var spawning_enabled: bool = true  # Can be disabled for special events

func initialize(obstacle_scenes: Array[PackedScene], size: Vector2i, ground: Sprite2D):
	obstacle_types = obstacle_scenes
	self.screen_size = size
	self.ground_sprite = ground

func reset():
	last_obstacle_distance = 0
	clear_all_obstacles()

func clear_all_obstacles():
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()

func should_generate_obstacle(current_distance: int) -> bool:
	if obstacles.is_empty():
		return true

	var distance_since_last = current_distance - last_obstacle_distance
	var min_spacing = randi_range(4000, 7000)
	var max_spacing = randi_range(10000, 20000)
	var required_spacing = randi_range(min_spacing, max_spacing)
	return distance_since_last >= required_spacing

func set_spawning_enabled(enabled: bool):
	var was_enabled = spawning_enabled
	spawning_enabled = enabled
	print("[ObstacleManager] Spawning enabled: ", enabled, " (was: ", was_enabled, ")")

func sync_distance(current_distance: int):
	# When spawning is re-enabled, adjust last_obstacle_distance to allow
	# immediate spawning by subtracting the minimum spacing requirement
	# This fixes timing issues after powerups where distance increased faster
	if spawning_enabled:
		var old_last_distance = last_obstacle_distance
		# Subtract minimum spacing so objects can spawn immediately
		# Use a value slightly less than min_spacing to ensure spawning happens soon
		last_obstacle_distance = current_distance - 3000
		print("[ObstacleManager] sync_distance: current_distance=", current_distance, 
			  ", old_last_obstacle_distance=", old_last_distance, 
			  ", new_last_obstacle_distance=", last_obstacle_distance,
			  ", distance_since_last=", current_distance - last_obstacle_distance)

func is_spawning_enabled() -> bool:
	return spawning_enabled

func generate_obstacle(current_distance: int) -> Node:
	if not spawning_enabled:
		return null
	if not should_generate_obstacle(current_distance):
		return null

	var obs_type = obstacle_types[randi() % obstacle_types.size()]
	var obs = obs_type.instantiate()

	# Handle both Sprite2D and AnimatedSprite2D
	var obs_sprite = null
	var obs_height = 0.0
	var obs_scale = Vector2(1, 1)
	var obs_sprite_offset = Vector2(0, 0)
	
	# Try to get Sprite2D first
	if obs.has_node("Sprite2D"):
		obs_sprite = obs.get_node("Sprite2D")
		if obs_sprite and obs_sprite.texture:
			obs_height = obs_sprite.texture.get_height()
			obs_scale = obs_sprite.scale
			obs_sprite_offset = obs_sprite.position
	# If not found, try AnimatedSprite2D
	elif obs.has_node("AnimatedSprite2D"):
		obs_sprite = obs.get_node("AnimatedSprite2D")
		if obs_sprite and obs_sprite.sprite_frames:
			# Get the first frame's texture to determine height
			var first_frame = obs_sprite.sprite_frames.get_frame_texture("default", 0)
			if first_frame:
				obs_height = first_frame.get_height()
			obs_scale = obs_sprite.scale
			obs_sprite_offset = obs_sprite.position
	
	# Fallback if we couldn't get sprite info
	if obs_height == 0.0:
		obs_height = 50.0  # Default fallback height

	var ground_top_y = ground_sprite.offset.y

	# Camera starts at 540, so calculate camera position from distance
	# This ensures obstacles spawn off-camera ahead, not mid-screen
	const CAMERA_START_X: int = 540
	var camera_x = CAMERA_START_X + current_distance
	# Add some randomness to the x position
	var base_x = camera_x + screen_size.x + 100
	var random_offset = randi_range(-50, 50)
	var obs_x: int = base_x + random_offset

	# Position obstacle so its bottom edge sits on top of the ground
	var obs_y: int = ground_top_y - obs_sprite_offset.y - (obs_height * obs_scale.y / 2) + 10

	# Set position on obstacle
	obs.position = Vector2i(obs_x, obs_y)

	var old_last_distance = last_obstacle_distance
	last_obstacle_distance = current_distance
	print("[ObstacleManager] generate_obstacle: SPAWNED at distance=", current_distance,
		  ", position=(", obs_x, ", ", obs_y, "), last_obstacle_distance: ", old_last_distance, " -> ", last_obstacle_distance)
	return obs

func add_obstacle(obs: Node):
	add_child(obs)
	obstacles.append(obs)
	obstacle_added.emit(obs)

func remove_obstacle(obs: Node):
	if obstacles.has(obs):
		obstacles.erase(obs)
		# Only queue_free if the object is still valid
		# (coins might already be queued for deletion)
		if is_instance_valid(obs):
			obs.queue_free()
		obstacle_removed.emit(obs)

func cleanup_off_screen_obstacles(camera_x: float):
	# Add a buffer to ensure obstacles are well off-screen before removal
	# This prevents butterflies and other obstacles from disappearing too early
	var cleanup_threshold = camera_x - screen_size.x * 2
	for obs in obstacles.duplicate():
		# Check if object is still valid (not freed)
		if not is_instance_valid(obs):
			# Remove invalid references from array
			obstacles.erase(obs)
			continue
		if obs.position.x < cleanup_threshold:
			remove_obstacle(obs)

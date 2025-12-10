extends Node

signal obstacle_added(obstacle: Node)
signal obstacle_removed(obstacle: Node)

var obstacle_types: Array[PackedScene]
var obstacles: Array = []
var last_obstacle_distance: int = 0  # Track distance, not score
var screen_size: Vector2i
var ground_sprite: Sprite2D
var spawning_enabled: bool = true  # Can be disabled for special events
var foe_manager: Node = null  # Reference to foe manager for coordination
var difficulty_level: int = 1  # Current difficulty level
const MIN_SPAWN_DISTANCE: int = 500  # Minimum X distance between obstacles and foes

func initialize(obstacle_scenes: Array[PackedScene], size: Vector2i, ground: Sprite2D, foe_mgr: Node = null):
	obstacle_types = obstacle_scenes
	self.screen_size = size
	self.ground_sprite = ground
	foe_manager = foe_mgr

func reset():
	last_obstacle_distance = 0
	clear_all_obstacles()

func clear_all_obstacles():
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()

func set_difficulty_level(level: int):
	difficulty_level = level

func should_generate_obstacle(current_distance: int) -> bool:
	if obstacles.is_empty():
		return true

	var distance_since_last = current_distance - last_obstacle_distance
	# Adjust spawn frequency based on difficulty level
	var min_spacing: int
	var max_spacing: int
	if difficulty_level == 1:
		# Level 1: infrequent spawns
		min_spacing = randi_range(4000, 7000)
		max_spacing = randi_range(10000, 20000)
	elif difficulty_level == 2:
		# Level 2: more frequent spawns
		min_spacing = randi_range(3000, 5000)
		max_spacing = randi_range(7000, 12000)
	else:  # Level 3
		# Level 3: even more frequent spawns
		min_spacing = randi_range(2000, 4000)
		max_spacing = randi_range(5000, 9000)

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

func is_position_too_close_to_foes(x_position: int) -> bool:
	# Check if position is too close to any existing foe
	if not foe_manager:
		return false

	for foe in foe_manager.foes:
		if not is_instance_valid(foe):
			continue
		var distance = abs(foe.position.x - x_position)
		if distance < MIN_SPAWN_DISTANCE:
			return true
	return false

func is_position_too_close_to_obstacles(x_position: int) -> bool:
	# Check if position is too close to any existing obstacle
	for obs in obstacles:
		if not is_instance_valid(obs):
			continue
		var distance = abs(obs.position.x - x_position)
		if distance < MIN_SPAWN_DISTANCE:
			return true
	return false

func generate_obstacle(current_distance: int, camera_x: float) -> Array:
	# Returns an array of obstacles (single obstacle at level 1, pair at level 2+)
	if not spawning_enabled:
		return []
	if not should_generate_obstacle(current_distance):
		return []

	var obstacles_to_spawn: Array = []

	# Determine spawn count based on difficulty level
	var spawn_count: int
	if difficulty_level == 1:
		spawn_count = 1
	elif difficulty_level == 2:
		# Level 2: spawn 1-2 obstacles
		spawn_count = randi_range(1, 2)
	else:  # Level 3
		# Level 3: spawn 1-3 obstacles
		spawn_count = randi_range(1, 3)

	# Use actual camera position passed from main.gd
	var base_x = int(camera_x) + screen_size.x + 100

	# Spawn obstacles with spacing between them (for pairs)
	var spacing_between = 200  # Space between obstacles in a pair

	for i in range(spawn_count):
		var obs_type = obstacle_types[randi() % obstacle_types.size()]
		var obs = obs_type.instantiate()

		# Position the obstacle
		var obs_x = base_x + (i * spacing_between) + randi_range(-50, 50)

		# Check if position is too close to existing obstacles or foes
		var attempts = 0
		var max_attempts = 10
		while (is_position_too_close_to_obstacles(obs_x) or is_position_too_close_to_foes(obs_x)) and attempts < max_attempts:
			obs_x = base_x + (i * spacing_between) + randi_range(-200, 200)
			attempts += 1

		# If still too close after attempts, skip this obstacle
		if is_position_too_close_to_obstacles(obs_x) or is_position_too_close_to_foes(obs_x):
			print("[ObstacleManager] generate_obstacle: Position too close, skipping spawn at x=", obs_x)
			obs.queue_free()
			continue

		# Get sprite info for positioning
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
				var first_frame = obs_sprite.sprite_frames.get_frame_texture("default", 0)
				if first_frame:
					obs_height = first_frame.get_height()
				obs_scale = obs_sprite.scale
				obs_sprite_offset = obs_sprite.position

		# Fallback if we couldn't get sprite info
		if obs_height == 0.0:
			obs_height = 50.0

		var ground_top_y = ground_sprite.offset.y
		var obs_y: int = int(ground_top_y - obs_sprite_offset.y - (obs_height * obs_scale.y / 2) + 10)

		obs.position = Vector2i(int(obs_x), obs_y)
		obstacles_to_spawn.append(obs)

	if obstacles_to_spawn.size() > 0:
		last_obstacle_distance = current_distance
		print("[ObstacleManager] generate_obstacle: SPAWNED ", obstacles_to_spawn.size(), " obstacle(s) at distance=", current_distance)

	return obstacles_to_spawn

func add_obstacle(obs: Node):
	add_child(obs)
	obstacles.append(obs)
	# Set butterflies to appear in front of coins (higher z_index)
	if obs.name == "Butterfly" or (obs.has_method("get_script") and obs.get_script() and "butterfly" in obs.get_script().resource_path.to_lower()):
		obs.z_index = 1  # Higher than coins (default 0)
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

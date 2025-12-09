extends Node

signal foe_spawned(foe: Node)

var foe_types: Array[PackedScene]
var last_foe_distance: int = 0
var screen_size: Vector2i
var ground_sprite: Sprite2D
var spawning_enabled: bool = true  # Can be disabled for special events
var obstacle_manager: Node = null  # Reference to obstacle manager for coordination
var foe_manager: Node = null  # Reference to foe manager for coordination
const MIN_SPAWN_DISTANCE: int = 500  # Minimum X distance between obstacles and foes

func initialize(foe_scenes: Array[PackedScene], size: Vector2i, ground: Sprite2D, obs_mgr: Node = null, foe_mgr: Node = null):
	foe_types = foe_scenes
	self.screen_size = size
	self.ground_sprite = ground
	obstacle_manager = obs_mgr
	foe_manager = foe_mgr

func reset():
	last_foe_distance = 0

func should_spawn_foe(current_distance: int) -> bool:
	var distance_since_last = current_distance - last_foe_distance
	# More sparse than obstacles - spawn every 15000-30000 distance units
	var min_spacing = randi_range(15000, 20000)
	var max_spacing = randi_range(25000, 30000)
	var required_spacing = randi_range(min_spacing, max_spacing)
	return distance_since_last >= required_spacing

func set_spawning_enabled(enabled: bool):
	var was_enabled = spawning_enabled
	spawning_enabled = enabled
	print("[FoeSpawner] Spawning enabled: ", enabled, " (was: ", was_enabled, ")")

func sync_distance(current_distance: int):
	# When spawning is re-enabled, adjust last_foe_distance to allow
	# immediate spawning by subtracting the minimum spacing requirement
	# This fixes timing issues after powerups where distance increased faster
	if spawning_enabled:
		var old_last_distance = last_foe_distance
		# Subtract minimum spacing so objects can spawn immediately
		# Use a value slightly less than min_spacing to ensure spawning happens soon
		last_foe_distance = current_distance - 10000
		print("[FoeSpawner] sync_distance: current_distance=", current_distance,
			  ", old_last_foe_distance=", old_last_distance,
			  ", new_last_foe_distance=", last_foe_distance,
			  ", distance_since_last=", current_distance - last_foe_distance)

func is_spawning_enabled() -> bool:
	return spawning_enabled

func _is_position_too_close(x_position: int) -> bool:
	# Check if position is too close to any existing obstacle
	if obstacle_manager:
		for obs in obstacle_manager.obstacles:
			if not is_instance_valid(obs):
				continue
			var distance = abs(obs.position.x - x_position)
			if distance < MIN_SPAWN_DISTANCE:
				return true
	
	# Check if position is too close to any existing foe
	if foe_manager:
		for foe in foe_manager.foes:
			if not is_instance_valid(foe):
				continue
			var distance = abs(foe.position.x - x_position)
			if distance < MIN_SPAWN_DISTANCE:
				return true
	return false

func update(current_distance: int) -> Node:
	if not spawning_enabled:
		return null
	if should_spawn_foe(current_distance):
		var foe = spawn_foe(current_distance)
		if foe:
			var old_last_distance = last_foe_distance
			last_foe_distance = current_distance
			print("[FoeSpawner] update: SPAWNED foe at distance=", current_distance,
				  ", position=(", foe.position.x, ", ", foe.position.y, "), last_foe_distance: ", old_last_distance, " -> ", last_foe_distance)
			return foe
		else:
			# Spawn was skipped due to position conflict, don't update last_foe_distance
			print("[FoeSpawner] update: Spawn skipped at distance=", current_distance, " due to position conflict")
	return null

func spawn_foe(current_distance: int) -> Node:
	var foe_type = foe_types[randi() % foe_types.size()]
	var foe = foe_type.instantiate()
	
	var foe_sprite = foe.get_node("AnimatedSprite2D")
	var foe_sprite_frames = foe_sprite.sprite_frames
	var foe_texture = foe_sprite_frames.get_frame_texture("default", 0)
	var foe_height = foe_texture.get_height()
	var foe_scale = foe_sprite.scale
	var foe_sprite_offset = foe_sprite.position
	
	var ground_top_y = self.ground_sprite.offset.y
	
	# Camera starts at 540, so calculate camera position from distance
	# This ensures foes spawn off-camera ahead, not mid-screen
	const CAMERA_START_X: int = 540
	var camera_x = CAMERA_START_X + current_distance
	# Add some randomness to the x position
	var base_x = camera_x + screen_size.x + 100
	var random_offset = randi_range(-50, 50)
	var foe_x: int = base_x + random_offset
	
	# Check if position is too close to existing obstacles or foes
	# Try multiple positions to find a valid spawn location
	var attempts = 0
	var max_attempts = 10
	while _is_position_too_close(foe_x) and attempts < max_attempts:
		random_offset = randi_range(-200, 200)  # Wider range for retry
		foe_x = base_x + random_offset
		attempts += 1
	
	# If still too close after attempts, skip spawning this foe
	if _is_position_too_close(foe_x):
		print("[FoeSpawner] spawn_foe: Position too close, skipping spawn at x=", foe_x)
		return null
	
	# Position foe on the ground (stationary)
	# Position so the bottom edge sits on top of the ground
	var foe_y: int = ground_top_y - foe_sprite_offset.y - (foe_height * foe_scale.y / 2) + 10
	
	foe.position = Vector2i(foe_x, foe_y)
	foe_spawned.emit(foe)
	return foe

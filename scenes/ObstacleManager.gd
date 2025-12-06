extends Node

signal obstacle_added(obstacle: Node)
signal obstacle_removed(obstacle: Node)

var obstacle_types: Array[PackedScene]
var obstacles: Array = []
var last_obstacle_score: int = 0
var screen_size: Vector2i
var ground_sprite: Sprite2D

func initialize(obstacle_scenes: Array[PackedScene], screen_size: Vector2i, ground_sprite: Sprite2D):
	obstacle_types = obstacle_scenes
	self.screen_size = screen_size
	self.ground_sprite = ground_sprite

func reset():
	last_obstacle_score = 0
	clear_all_obstacles()

func clear_all_obstacles():
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()

func should_generate_obstacle(current_score: int) -> bool:
	if obstacles.is_empty():
		return true
	
	var distance_since_last = current_score - last_obstacle_score
	var min_spacing = randi_range(4000, 7000)
	var max_spacing = randi_range(10000, 20000)
	var required_spacing = randi_range(min_spacing, max_spacing)
	return distance_since_last >= required_spacing

func generate_obstacle(current_score: int) -> Node:
	if not should_generate_obstacle(current_score):
		return null
	
	var obs_type = obstacle_types[randi() % obstacle_types.size()]
	var obs = obs_type.instantiate()
	
	var obs_sprite = obs.get_node("Sprite2D")
	var obs_height = obs_sprite.texture.get_height()
	var obs_scale = obs_sprite.scale
	var obs_sprite_offset = obs_sprite.position
	
	var ground_top_y = ground_sprite.offset.y
	
	# Add some randomness to the x position
	var base_x = screen_size.x + current_score + 100
	var random_offset = randi_range(-50, 50)
	var obs_x: int = base_x + random_offset
	
	# Position obstacle so its bottom edge sits on top of the ground
	var obs_y: int = ground_top_y - obs_sprite_offset.y - (obs_height * obs_scale.y / 2) + 10
	
	# Set position on obstacle
	obs.position = Vector2i(obs_x, obs_y)
	
	last_obstacle_score = current_score
	return obs

func add_obstacle(obs: Node):
	add_child(obs)
	obstacles.append(obs)
	obstacle_added.emit(obs)

func remove_obstacle(obs: Node):
	if obstacles.has(obs):
		obs.queue_free()
		obstacles.erase(obs)
		obstacle_removed.emit(obs)

func cleanup_off_screen_obstacles(camera_x: float):
	# Add a buffer to ensure obstacles are well off-screen before removal
	# This prevents butterflies and other obstacles from disappearing too early
	var cleanup_threshold = camera_x - screen_size.x * 2
	for obs in obstacles.duplicate():
		if obs.position.x < cleanup_threshold:
			remove_obstacle(obs)
